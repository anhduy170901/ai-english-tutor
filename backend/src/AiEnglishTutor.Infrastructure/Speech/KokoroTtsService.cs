using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using AiEnglishTutor.Application.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace AiEnglishTutor.Infrastructure.Speech
{
    public class KokoroTtsService : ITextToSpeechService
    {
        private readonly HttpClient _httpClient;
        private readonly string _endpoint;
        private readonly string _defaultVoice;
        private readonly ILogger<KokoroTtsService> _logger;

        public KokoroTtsService(HttpClient httpClient, IConfiguration configuration, ILogger<KokoroTtsService> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
            _endpoint = configuration["Tts:KokoroEndpoint"] ?? "http://localhost:8880/v1/audio/speech";
            _defaultVoice = configuration["Tts:DefaultVoice"] ?? "af_heart";
        }

        private string ResolveVoice(string requestedVoice)
        {
            // If the requested voice is the legacy Jenny Neural or empty, map to Kokoro default voice
            if (string.IsNullOrWhiteSpace(requestedVoice) || 
                requestedVoice.Equals("en-US-JennyNeural", StringComparison.OrdinalIgnoreCase))
            {
                return _defaultVoice;
            }

            return requestedVoice;
        }

        public async IAsyncEnumerable<byte[]> StreamAudioAsync(
            string text, 
            string voice = "en-US-JennyNeural", 
            [EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(text)) yield break;

            var actualVoice = ResolveVoice(voice);
            var requestBody = new
            {
                model = "kokoro",
                input = text,
                voice = actualVoice,
                response_format = "pcm",
                stream = true
            };

            HttpResponseMessage response;
            try
            {
                var request = new HttpRequestMessage(HttpMethod.Post, _endpoint)
                {
                    Content = JsonContent.Create(requestBody)
                };

                response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
                response.EnsureSuccessStatusCode();
            }
            catch (OperationCanceledException)
            {
                // Turn was interrupted (barge-in) or the client disconnected — not a real TTS failure.
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to Kokoro TTS at {Endpoint}", _endpoint);
                throw new InvalidOperationException($"Failed to generate speech with Kokoro TTS: {ex.Message}", ex);
            }

            using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            var buffer = new byte[4096];
            byte? leftoverByte = null;

            int bytesRead;
            while ((bytesRead = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken)) > 0)
            {
                int totalAvailable = (leftoverByte.HasValue ? 1 : 0) + bytesRead;
                int yieldLength = totalAvailable - (totalAvailable % 2);

                if (yieldLength > 0)
                {
                    var chunk = new byte[yieldLength];
                    int destOffset = 0;
                    int srcOffset = 0;

                    if (leftoverByte.HasValue)
                    {
                        chunk[0] = leftoverByte.Value;
                        destOffset = 1;
                        leftoverByte = null;
                    }

                    int toCopy = yieldLength - destOffset;
                    Array.Copy(buffer, srcOffset, chunk, destOffset, toCopy);
                    srcOffset += toCopy;

                    int remainingInBuf = bytesRead - srcOffset;
                    if (remainingInBuf == 1)
                    {
                        leftoverByte = buffer[srcOffset];
                    }

                    yield return chunk;
                }
                else
                {
                    if (!leftoverByte.HasValue && bytesRead == 1)
                    {
                        leftoverByte = buffer[0];
                    }
                }
            }

            if (leftoverByte.HasValue)
            {
                _logger.LogWarning("Discarding 1 orphaned byte at end of Kokoro PCM stream");
                leftoverByte = null;
            }
        }

        public async Task<byte[]> SynthesizeAudioAsync(
            string text, 
            string voice = "en-US-JennyNeural", 
            CancellationToken cancellationToken = default)
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
