using AiEnglishTutor.Application.Dtos;
using AiEnglishTutor.Application.Services;
using MediatR;

namespace AiEnglishTutor.Application.Usecases.Session.Queries.GetSessionDetail
{
    public record GetSessionDetailQuery(Guid SessionId) : IRequest<SessionDetailDto?>;

    public class GetSessionDetailQueryHandler : IRequestHandler<GetSessionDetailQuery, SessionDetailDto?>
    {
        private readonly ISessionQueryService _sessionQueryService;

        public GetSessionDetailQueryHandler(ISessionQueryService sessionQueryService)
        {
            _sessionQueryService = sessionQueryService;
        }

        public async Task<SessionDetailDto?> Handle(GetSessionDetailQuery request, CancellationToken cancellationToken)
        {
            return await _sessionQueryService.GetSessionByIdAsync(request.SessionId, cancellationToken);
        }
    }
}
