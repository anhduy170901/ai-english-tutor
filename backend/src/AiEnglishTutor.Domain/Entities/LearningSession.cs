using AiEnglishTutor.Domain.Enums;

namespace AiEnglishTutor.Domain.Entities
{
    public class LearningSession : BaseEntity
    {
        public string Topic { get; set; } = string.Empty;
        public CefrLevel TargetLevel { get; set; } = CefrLevel.B1;
        public SessionStatus Status { get; set; } = SessionStatus.Active;
        public DateTime? EndedAt { get; set; }
        public string? SummaryFeedback { get; set; }
        
        public virtual ICollection<SessionMessage> Messages { get; set; } = new List<SessionMessage>();

        public void CompleteSession(string? feedback = null)
        {
            Status = SessionStatus.Completed;
            EndedAt = DateTime.UtcNow;
            SummaryFeedback = feedback;
            UpdatedAt = DateTime.UtcNow;
        }
    }
}
