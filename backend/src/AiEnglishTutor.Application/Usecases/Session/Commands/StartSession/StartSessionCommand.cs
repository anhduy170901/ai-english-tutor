using AiEnglishTutor.Domain.Enums;
using MediatR;

namespace AiEnglishTutor.Application.Usecases.Session.Commands.StartSession
{
    public record StartSessionCommand(string Topic, CefrLevel TargetLevel = CefrLevel.B1) : IRequest<Guid>;

    public class StartSessionCommandHandler : IRequestHandler<StartSessionCommand, Guid>
    {
        private readonly Repositories.ISessionRepository _sessionRepository;

        public StartSessionCommandHandler(Repositories.ISessionRepository sessionRepository)
        {
            _sessionRepository = sessionRepository;
        }

        public async Task<Guid> Handle(StartSessionCommand request, CancellationToken cancellationToken)
        {
            var session = new Domain.Entities.LearningSession
            {
                Topic = request.Topic,
                TargetLevel = request.TargetLevel,
                Status = SessionStatus.Active
            };

            await _sessionRepository.AddAsync(session, cancellationToken);
            await _sessionRepository.SaveChangesAsync(cancellationToken);

            return session.Id;
        }
    }
}
