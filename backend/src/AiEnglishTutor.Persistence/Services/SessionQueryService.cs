using AiEnglishTutor.Application.Dtos;
using AiEnglishTutor.Application.Services;
using AiEnglishTutor.Domain.Enums;
using AiEnglishTutor.Persistence.Context;
using Microsoft.EntityFrameworkCore;

namespace AiEnglishTutor.Persistence.Services
{
    public class SessionQueryService : ISessionQueryService
    {
        private readonly TutorReadDbContext _readContext;

        public SessionQueryService(TutorReadDbContext readContext)
        {
            _readContext = readContext;
        }

        public async Task<SessionDetailDto?> GetSessionByIdAsync(Guid id, CancellationToken cancellationToken = default)
        {
            return await _readContext.Sessions
                .Where(s => s.Id == id)
                .Select(s => new SessionDetailDto(
                    s.Id,
                    s.Topic,
                    s.TargetLevel,
                    s.Status,
                    s.CreatedAt,
                    s.EndedAt,
                    s.SummaryFeedback,
                    s.Messages.OrderBy(m => m.CreatedAt).Select(m => new MessageDto(
                        m.Id,
                        m.Sender,
                        m.Content,
                        m.GrammarFeedback,
                        m.VocabularySuggestions,
                        m.PronunciationScore,
                        m.CreatedAt
                    )).ToList()
                ))
                .FirstOrDefaultAsync(cancellationToken);
        }

        public async Task<IEnumerable<SessionSummaryDto>> GetActiveSessionsAsync(CancellationToken cancellationToken = default)
        {
            return await _readContext.Sessions
                .Where(s => s.Status == SessionStatus.Active)
                .OrderByDescending(s => s.CreatedAt)
                .Select(s => new SessionSummaryDto(
                    s.Id,
                    s.Topic,
                    s.TargetLevel,
                    s.Status,
                    s.Messages.Count,
                    s.CreatedAt
                ))
                .ToListAsync(cancellationToken);
        }
    }
}
