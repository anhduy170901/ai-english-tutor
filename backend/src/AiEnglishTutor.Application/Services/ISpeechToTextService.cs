namespace AiEnglishTutor.Application.Services
{
    public interface ISpeechToTextService
    {
        Task<string> TranscribeAudioAsync(Stream audioStream, CancellationToken cancellationToken = default);
        Task<string> TranscribeBytesAsync(byte[] audioBytes, CancellationToken cancellationToken = default);
    }
}
