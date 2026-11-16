using System.Text;
using AiEnglishTutor.Application.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Whisper.net;
using Whisper.net.Ggml;

namespace AiEnglishTutor.Infrastructure.Speech
{
    public class WhisperSttService : ISpeechToTextService, IAsyncDisposable
    {
        private readonly string _modelPath;
        private readonly ILogger<WhisperSttService> _logger;
        private WhisperFactory? _factory;
        private readonly SemaphoreSlim _initLock = new(1, 1);

        public WhisperSttService(IConfiguration configuration, ILogger<WhisperSttService> logger)
        {
            _logger = logger;
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            _modelPath = configuration["Whisper:ModelPath"] 
                ?? Path.Combine(appData, ".ai-english-tutor", "models", "ggml-base.en.bin");
        }

        private async Task EnsureModelLoadedAsync(CancellationToken cancellationToken)
        {
            if (_factory != null) return;

            await _initLock.WaitAsync(cancellationToken);
            try
            {
                if (_factory != null) return;

                var dir = Path.GetDirectoryName(_modelPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }

                if (!File.Exists(_modelPath) || new FileInfo(_modelPath).Length < 10000000)
                {
                    if (File.Exists(_modelPath))
                    {
                        try { File.Delete(_modelPath); } catch { }
                    }
                    _logger.LogInformation("Whisper model not found or incomplete at {Path}. Downloading ggml-base.en.bin (~140MB)...", _modelPath);
                    using var modelStream = await WhisperGgmlDownloader.Default.GetGgmlModelAsync(GgmlType.BaseEn, cancellationToken: cancellationToken);
                    using var fileStream = File.Create(_modelPath);
                    await modelStream.CopyToAsync(fileStream, cancellationToken);
                    _logger.LogInformation("Whisper model downloaded successfully.");
                }

                _factory = WhisperFactory.FromPath(_modelPath);
            }
            finally
            {
                _initLock.Release();
            }
        }

        private static void ValidateWavHeader(byte[] header)
        {
            if (header.Length < 12 ||
                header[0] != 'R' || header[1] != 'I' || header[2] != 'F' || header[3] != 'F' ||
                header[8] != 'W' || header[9] != 'A' || header[10] != 'V' || header[11] != 'E')
            {
                throw new ArgumentException("Audio format is invalid. Expected a 16kHz 16-bit mono WAV (RIFF/WAVE) format.");
            }
        }

        public async Task<string> TranscribeAudioAsync(Stream audioStream, CancellationToken cancellationToken = default)
        {
            if (audioStream == null)
            {
                throw new ArgumentNullException(nameof(audioStream));
            }

            if (audioStream.CanSeek)
            {
                if (audioStream.Length < 44)
                {
                    throw new ArgumentException("Audio stream is too short to be a valid WAV file (minimum 44 bytes required).");
                }

                var header = new byte[12];
                var originalPosition = audioStream.Position;
                var bytesRead = await audioStream.ReadAsync(header.AsMemory(0, 12), cancellationToken);
                audioStream.Position = originalPosition;

                if (bytesRead == 12)
                {
                    ValidateWavHeader(header);
                }
            }

            await EnsureModelLoadedAsync(cancellationToken);

            using var processor = _factory!.CreateBuilder()
                .WithLanguage("en")
                .Build();

            var sb = new StringBuilder();
            await foreach (var segment in processor.ProcessAsync(audioStream, cancellationToken))
            {
                if (!string.IsNullOrWhiteSpace(segment.Text))
                {
                    sb.Append(segment.Text.Trim()).Append(' ');
                }
            }

            return sb.ToString().Trim();
        }

        private static bool IsAudioSilent(byte[] audioBytes, double thresholdRms = 100.0)
        {
            if (audioBytes.Length <= 44) return true;
            long sumSquares = 0;
            int sampleCount = (audioBytes.Length - 44) / 2;
            if (sampleCount == 0) return true;

            for (int i = 44; i < audioBytes.Length - 1; i += 2)
            {
                short sample = (short)(audioBytes[i] | (audioBytes[i + 1] << 8));
                sumSquares += (long)sample * sample;
            }

            double rms = Math.Sqrt((double)sumSquares / sampleCount);
            return rms < thresholdRms;
        }

        public async Task<string> TranscribeBytesAsync(byte[] audioBytes, CancellationToken cancellationToken = default)
        {
            if (audioBytes == null || audioBytes.Length < 44)
            {
                throw new ArgumentException("Audio data is null or too short to be a valid WAV file (minimum 44 bytes required).");
            }

            ValidateWavHeader(audioBytes.AsSpan(0, 12).ToArray());

            if (IsAudioSilent(audioBytes))
            {
                _logger.LogInformation("Audio is completely silent (RMS below threshold). Skipping Whisper hallucination.");
                return string.Empty;
            }

            using var memoryStream = new MemoryStream(audioBytes);
            return await TranscribeAudioAsync(memoryStream, cancellationToken);
        }

        public ValueTask DisposeAsync()
        {
            _factory?.Dispose();
            _initLock.Dispose();
            return ValueTask.CompletedTask;
        }
    }
}
