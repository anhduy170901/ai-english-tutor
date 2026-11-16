using AiEnglishTutor.Application.Dtos;

namespace AiEnglishTutor.Application.Services
{
    public interface ISessionQueryService
    {
        Task<SessionDetailDto?> GetSessionByIdAsync(Guid id, CancellationToken cancellationToken = default);
        Task<IEnumerable<SessionSummaryDto>> GetActiveSessionsAsync(CancellationToken cancellationToken = default);
    }
}
