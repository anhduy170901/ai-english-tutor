namespace AiEnglishTutor.Application.Services
{
    public interface ITextToSpeechService
    {
        IAsyncEnumerable<byte[]> StreamAudioAsync(string text, string voice = "en-US-JennyNeural", CancellationToken cancellationToken = default);
        Task<byte[]> SynthesizeAudioAsync(string text, string voice = "en-US-JennyNeural", CancellationToken cancellationToken = default);
    }
}
