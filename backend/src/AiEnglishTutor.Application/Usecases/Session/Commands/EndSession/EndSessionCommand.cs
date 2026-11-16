using MediatR;

namespace AiEnglishTutor.Application.Usecases.Session.Commands.EndSession
{
    public record EndSessionCommand(Guid SessionId, string? Feedback = null) : IRequest<bool>;

    public class EndSessionCommandHandler : IRequestHandler<EndSessionCommand, bool>
    {
        private readonly Repositories.ISessionRepository _sessionRepository;

        public EndSessionCommandHandler(Repositories.ISessionRepository sessionRepository)
        {
            _sessionRepository = sessionRepository;
        }

        public async Task<bool> Handle(EndSessionCommand request, CancellationToken cancellationToken)
        {
            var session = await _sessionRepository.GetByIdAsync(request.SessionId, cancellationToken);
            if (session == null) return false;

            session.CompleteSession(request.Feedback);
            _sessionRepository.Update(session);
            await _sessionRepository.SaveChangesAsync(cancellationToken);

            return true;
        }
    }
}
