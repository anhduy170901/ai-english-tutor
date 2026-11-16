using AiEnglishTutor.Application.Repositories;
using AiEnglishTutor.Domain.Entities;
using AiEnglishTutor.Persistence.Context;
using Microsoft.EntityFrameworkCore;

namespace AiEnglishTutor.Persistence.Repositories
{
    public class SessionRepository : BaseRepository<LearningSession>, ISessionRepository
    {
        public SessionRepository(TutorWriteDbContext context) : base(context) { }

        public async Task<LearningSession?> GetSessionWithMessagesAsync(Guid id, CancellationToken cancellationToken = default)
        {
            return await _dbSet
                .Include(s => s.Messages)
                .FirstOrDefaultAsync(s => s.Id == id, cancellationToken);
        }

        public async Task AddMessageAsync(SessionMessage message, CancellationToken cancellationToken = default)
        {
            await _context.Messages.AddAsync(message, cancellationToken);
        }
    }
}
