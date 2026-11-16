using System.Runtime.CompilerServices;
using System.Text;
using AiEnglishTutor.Application.Services;
using AiEnglishTutor.Infrastructure.Prompts;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using OllamaSharp;
using OllamaSharp.Models.Chat;
using OllamaSharp.Models;

namespace AiEnglishTutor.Infrastructure.Ollama
{
    public class OllamaService : IOllamaService
    {
        private readonly OllamaApiClient _client;
        private readonly string _modelName;
        private readonly ILogger<OllamaService> _logger;

        public OllamaService(IConfiguration configuration, ILogger<OllamaService> logger)
        {
            _logger = logger;
            var uriString = configuration["Ollama:Endpoint"] ?? "http://127.0.0.1:11434";
            _modelName = configuration["Ollama:Model"] ?? "llama3.2:latest";
            _client = new OllamaApiClient(new Uri(uriString))
            {
                SelectedModel = _modelName
            };
        }

        public async IAsyncEnumerable<string> StreamResponseAsync(
            string prompt, 
            string? systemPrompt = null, 
            [EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            var sys = systemPrompt ?? EnglishTutorPrompts.DefaultSystemPrompt;
            var chat = new Chat(_client)
            {
                Options = new RequestOptions
                {
                    Temperature = 0.7f,
                    NumPredict = 256
                }
            };
            chat.Messages.Add(new Message(ChatRole.System, sys));

            await foreach (var token in chat.SendAsync(prompt, cancellationToken))
            {
                if (!string.IsNullOrEmpty(token))
                {
                    yield return token;
                }
            }
        }

        public async Task<string> GenerateResponseAsync(
            string prompt, 
            string? systemPrompt = null, 
            CancellationToken cancellationToken = default)
        {
            var sb = new StringBuilder();
            await foreach (var token in StreamResponseAsync(prompt, systemPrompt, cancellationToken))
            {
                sb.Append(token);
            }
            return sb.ToString();
        }
    }
}
