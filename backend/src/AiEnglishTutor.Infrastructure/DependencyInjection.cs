using AiEnglishTutor.Application.Services;
using AiEnglishTutor.Infrastructure.Ollama;
using AiEnglishTutor.Infrastructure.Speech;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AiEnglishTutor.Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddSingleton<IOllamaService, OllamaService>();
            services.AddSingleton<ISpeechToTextService, WhisperSttService>();

            var ttsProvider = configuration["Tts:Provider"] ?? "Kokoro";
            if (ttsProvider.Equals("Kokoro", StringComparison.OrdinalIgnoreCase))
            {
                services.AddHttpClient("KokoroTts", client =>
                {
                    client.Timeout = TimeSpan.FromSeconds(30);
                });

                services.AddSingleton<KokoroTtsService>(sp =>
                {
                    var factory = sp.GetRequiredService<IHttpClientFactory>();
                    var config = sp.GetRequiredService<IConfiguration>();
                    var logger = sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<KokoroTtsService>>();
                    var client = factory.CreateClient("KokoroTts");
                    return new KokoroTtsService(client, config, logger);
                });

                services.AddSingleton<ITextToSpeechService>(sp => sp.GetRequiredService<KokoroTtsService>());
            }
            else
            {
                services.AddSingleton<ITextToSpeechService, EdgeTtsService>();
            }

            return services;
        }
    }
}
