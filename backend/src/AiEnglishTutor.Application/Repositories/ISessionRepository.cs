using AiEnglishTutor.Domain.Entities;

namespace AiEnglishTutor.Application.Repositories
{
    public interface ISessionRepository : IBaseRepository<LearningSession>
    {
        Task<LearningSession?> GetSessionWithMessagesAsync(Guid id, CancellationToken cancellationToken = default);
        Task AddMessageAsync(SessionMessage message, CancellationToken cancellationToken = default);
    }
}
