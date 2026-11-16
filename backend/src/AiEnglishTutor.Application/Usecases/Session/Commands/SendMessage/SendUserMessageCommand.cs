using AiEnglishTutor.Domain.Entities;
using AiEnglishTutor.Domain.Enums;
using MediatR;

namespace AiEnglishTutor.Application.Usecases.Session.Commands.SendMessage
{
    public record SendUserMessageCommand(
        Guid SessionId,
        string Content,
        double? PronunciationScore = null,
        SenderType Sender = SenderType.User,
        DateTime? CreatedAt = null
    ) : IRequest<SessionMessage>;

    public class SendUserMessageCommandHandler : IRequestHandler<SendUserMessageCommand, SessionMessage>
    {
        private readonly Repositories.ISessionRepository _sessionRepository;

        public SendUserMessageCommandHandler(Repositories.ISessionRepository sessionRepository)
        {
            _sessionRepository = sessionRepository;
        }

        public async Task<SessionMessage> Handle(SendUserMessageCommand request, CancellationToken cancellationToken)
        {
            var session = await _sessionRepository.GetByIdAsync(request.SessionId, cancellationToken);
            if (session == null)
            {
                throw new KeyNotFoundException($"Session {request.SessionId} not found");
            }

            if (session.Status != SessionStatus.Active)
            {
                throw new InvalidOperationException($"Cannot add message: Session {request.SessionId} is already {session.Status}");
            }

            var message = new SessionMessage
            {
                SessionId = session.Id,
                Sender = request.Sender,
                Content = request.Content,
                PronunciationScore = request.PronunciationScore,
                CreatedAt = request.CreatedAt ?? DateTime.UtcNow
            };

            await _sessionRepository.AddMessageAsync(message, cancellationToken);
            session.UpdatedAt = DateTime.UtcNow;
            await _sessionRepository.SaveChangesAsync(cancellationToken);

            return message;
        }
    }
}
