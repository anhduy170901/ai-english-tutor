using System.Text;
using AiEnglishTutor.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace AiEnglishTutor.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TestController : ControllerBase
    {
        private readonly IOllamaService _ollamaService;
        private readonly ITextToSpeechService _ttsService;
        private readonly ISpeechToTextService _sttService;
        private readonly IWebHostEnvironment _environment;

        public TestController(
            IOllamaService ollamaService, 
            ITextToSpeechService ttsService, 
            ISpeechToTextService sttService,
            IWebHostEnvironment environment)
        {
            _ollamaService = ollamaService;
            _ttsService = ttsService;
            _sttService = sttService;
            _environment = environment;
        }

        [HttpPost("chat")]
        public async Task<IActionResult> TestChat([FromBody] ChatRequest request)
        {
            if (!_environment.IsDevelopment()) return NotFound();

            var response = await _ollamaService.GenerateResponseAsync(request.Message);
            return Ok(new { Reply = response });
        }

        [HttpPost("tts")]
        public async Task<IActionResult> TestTts([FromBody] TtsRequest request)
        {
            if (!_environment.IsDevelopment()) return NotFound();

            var pcmBytes = await _ttsService.SynthesizeAudioAsync(request.Text, request.Voice ?? "en-US-JennyNeural");
            var wavBytes = WrapPcmInWav(pcmBytes, 24000, 1, 16);
            return File(wavBytes, "audio/wav", "speech.wav");
        }

        private static byte[] WrapPcmInWav(byte[] pcmBytes, int sampleRate = 24000, short channels = 1, short bitsPerSample = 16)
        {
            using var ms = new MemoryStream();
            using var bw = new BinaryWriter(ms);

            // RIFF chunk descriptor
            bw.Write(Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(36 + pcmBytes.Length);
            bw.Write(Encoding.ASCII.GetBytes("WAVE"));

            // "fmt " sub-chunk
            bw.Write(Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16); // Subchunk1Size (16 for PCM)
            bw.Write((short)1); // AudioFormat (1 for PCM)
            bw.Write(channels);
            bw.Write(sampleRate);
            bw.Write(sampleRate * channels * (bitsPerSample / 8)); // ByteRate
            bw.Write((short)(channels * (bitsPerSample / 8))); // BlockAlign
            bw.Write(bitsPerSample);

            // "data" sub-chunk
            bw.Write(Encoding.ASCII.GetBytes("data"));
            bw.Write(pcmBytes.Length);
            bw.Write(pcmBytes);

            return ms.ToArray();
        }

        [HttpPost("stt")]
        public async Task<IActionResult> TestStt(IFormFile file)
        {
            if (!_environment.IsDevelopment()) return NotFound();

            if (file == null || file.Length == 0)
                return BadRequest("No audio file provided");

            using var ms = new MemoryStream();
            await file.CopyToAsync(ms);
            var text = await _sttService.TranscribeBytesAsync(ms.ToArray());
            return Ok(new { TranscribedText = text });
        }
    }

    public record ChatRequest(string Message);
    public record TtsRequest(string Text, string? Voice = null);
}
