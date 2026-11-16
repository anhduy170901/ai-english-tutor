using AiEnglishTutor.Domain.Enums;

namespace AiEnglishTutor.Domain.Entities
{
    public class SessionMessage : BaseEntity
    {
        public Guid SessionId { get; set; }
        public SenderType Sender { get; set; }
        public string Content { get; set; } = string.Empty;
        public string? GrammarFeedback { get; set; }
        public string? VocabularySuggestions { get; set; }
        public double? PronunciationScore { get; set; }

        public virtual LearningSession? Session { get; set; }
    }
}
