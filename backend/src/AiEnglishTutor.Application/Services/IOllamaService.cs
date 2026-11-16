namespace AiEnglishTutor.Application.Services
{
    public interface IOllamaService
    {
        IAsyncEnumerable<string> StreamResponseAsync(string prompt, string? systemPrompt = null, CancellationToken cancellationToken = default);
        Task<string> GenerateResponseAsync(string prompt, string? systemPrompt = null, CancellationToken cancellationToken = default);
    }
}
