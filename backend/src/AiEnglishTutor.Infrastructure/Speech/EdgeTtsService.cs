using System.Buffers.Binary;
using System.Net.WebSockets;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;
using System.Text;
using AiEnglishTutor.Application.Services;
using Microsoft.Extensions.Logging;
using NLayer;

namespace AiEnglishTutor.Infrastructure.Speech
{
    public class EdgeTtsService : ITextToSpeechService
    {
        private const string TrustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
        private const string SecMsGecVersion = "1-143.0.3650.75";
        private const string EdgeWssUrl = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=" + TrustedClientToken;
        private readonly ILogger<EdgeTtsService> _logger;

        public EdgeTtsService(ILogger<EdgeTtsService> logger)
        {
            _logger = logger;
        }

        private static string GenerateSecMsGec()
        {
            long unixSeconds = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            long ticks = unixSeconds + 11644473600L;
            ticks -= ticks % 300L;
            ticks *= 10000000L;

            string strToHash = $"{ticks}{TrustedClientToken}";
            byte[] hash = SHA256.HashData(Encoding.ASCII.GetBytes(strToHash));
            return Convert.ToHexString(hash).ToUpperInvariant();
        }

        public async IAsyncEnumerable<byte[]> StreamAudioAsync(
            string text, 
            string voice = "en-US-JennyNeural", 
            [EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(text)) yield break;

            var connectionId = Guid.NewGuid().ToString("N");
            var secMsGec = GenerateSecMsGec();
            var uri = new Uri($"{EdgeWssUrl}&ConnectionId={connectionId}&Sec-MS-GEC={secMsGec}&Sec-MS-GEC-Version={SecMsGecVersion}");

            using var ws = new ClientWebSocket();
            ws.Options.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0");
            ws.Options.SetRequestHeader("Origin", "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold");
            ws.Options.SetRequestHeader("Pragma", "no-cache");
            ws.Options.SetRequestHeader("Cache-Control", "no-cache");
            ws.Options.SetRequestHeader("Cookie", $"muid={Guid.NewGuid():N};");

            try
            {
                await ws.ConnectAsync(uri, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                // Turn was interrupted (barge-in) or the client disconnected — not a real TTS failure.
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to Edge TTS WebSocket service");
                throw new InvalidOperationException("Failed to connect to Edge TTS WebSocket service.", ex);
            }

            // 1. Send speech.config (audio-24khz-48kbitrate-mono-mp3 is natively supported by Edge ReadAloud)
            var timestamp = DateTime.UtcNow.ToString("r");
            var configMessage = $"X-Timestamp:{timestamp}\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n" +
                "{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}";
            await ws.SendAsync(Encoding.UTF8.GetBytes(configMessage), WebSocketMessageType.Text, true, cancellationToken);

            // 2. Send SSML request
            var requestId = Guid.NewGuid().ToString("N");
            var ssml = $"<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>" +
                       $"<voice name='{voice}'>{System.Security.SecurityElement.Escape(text)}</voice></speak>";
            var ssmlMessage = $"X-RequestId:{requestId}\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:{timestamp}Z\r\nPath:ssml\r\n\r\n{ssml}";
            await ws.SendAsync(Encoding.UTF8.GetBytes(ssmlMessage), WebSocketMessageType.Text, true, cancellationToken);

            // 3. Receive audio stream with proper WebSocket message accumulation (handling EndOfMessage fragmentation)
            using var mp3Stream = new MemoryStream();
            var buffer = new byte[32 * 1024];

            while (ws.State == WebSocketState.Open && !cancellationToken.IsCancellationRequested)
            {
                WebSocketReceiveResult result;
                using var messageStream = new MemoryStream();

                do
                {
                    result = await ws.ReceiveAsync(buffer, cancellationToken);
                    if (result.MessageType == WebSocketMessageType.Close) break;

                    await messageStream.WriteAsync(buffer.AsMemory(0, result.Count), cancellationToken);
                } 
                while (!result.EndOfMessage && !cancellationToken.IsCancellationRequested);

                if (result.MessageType == WebSocketMessageType.Close) break;

                if (result.MessageType == WebSocketMessageType.Binary && messageStream.Length > 2)
                {
                    var msgBytes = messageStream.ToArray();
                    int headerLength = BinaryPrimitives.ReadInt16BigEndian(msgBytes.AsSpan(0, 2));
                    if (msgBytes.Length > 2 + headerLength)
                    {
                        var audioLength = msgBytes.Length - (2 + headerLength);
                        mp3Stream.Write(msgBytes, 2 + headerLength, audioLength);
                    }
                }
                else if (result.MessageType == WebSocketMessageType.Text)
                {
                    var msg = Encoding.UTF8.GetString(messageStream.GetBuffer(), 0, (int)messageStream.Length);
                    if (msg.Contains("Path:turn.end"))
                    {
                        break;
                    }
                }
            }

            try
            {
                if (ws.State == WebSocketState.Open)
                {
                    await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "Complete", cancellationToken);
                }
            }
            catch { }

            // 4. Decode MP3 to raw PCM 16-bit 24kHz mono and stream PCM chunks to client
            if (mp3Stream.Length > 0 && !cancellationToken.IsCancellationRequested)
            {
                mp3Stream.Position = 0;
                using var mpeg = new MpegFile(mp3Stream);
                var sampleBuffer = new float[2048];
                var pcmChunk = new byte[4096]; // 2048 16-bit samples (always even length)
                int chunkOffset = 0;
                int read;

                while ((read = mpeg.ReadSamples(sampleBuffer, 0, sampleBuffer.Length)) > 0)
                {
                    if (cancellationToken.IsCancellationRequested) yield break;

                    for (int i = 0; i < read; i++)
                    {
                        float sample = Math.Clamp(sampleBuffer[i], -1.0f, 1.0f);
                        short val = (short)(sample * 32767f);
                        pcmChunk[chunkOffset++] = (byte)(val & 0xFF);
                        pcmChunk[chunkOffset++] = (byte)((val >> 8) & 0xFF);

                        if (chunkOffset == pcmChunk.Length)
                        {
                            var chunkToYield = new byte[pcmChunk.Length];
                            Array.Copy(pcmChunk, chunkToYield, pcmChunk.Length);
                            yield return chunkToYield;
                            chunkOffset = 0;
                        }
                    }
                }

                if (chunkOffset > 0)
                {
                    var finalChunk = new byte[chunkOffset];
                    Array.Copy(pcmChunk, finalChunk, chunkOffset);
                    yield return finalChunk;
                }
            }
        }

        public async Task<byte[]> SynthesizeAudioAsync(string text, string voice = "en-US-JennyNeural", CancellationToken cancellationToken = default)
        {
            using var ms = new MemoryStream();
            await foreach (var chunk in StreamAudioAsync(text, voice, cancellationToken))
            {
                await ms.WriteAsync(chunk, cancellationToken);
            }
            return ms.ToArray();
        }
    }
}
