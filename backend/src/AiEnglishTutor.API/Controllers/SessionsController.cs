using System.ComponentModel.DataAnnotations;
using AiEnglishTutor.Application.Dtos;
using AiEnglishTutor.Application.Services;
using AiEnglishTutor.Application.Usecases.Session.Commands.EndSession;
using AiEnglishTutor.Application.Usecases.Session.Commands.StartSession;
using AiEnglishTutor.Application.Usecases.Session.Queries.GetSessionDetail;
using AiEnglishTutor.Domain.Enums;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace AiEnglishTutor.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SessionsController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly ISessionQueryService _sessionQueryService;

        public SessionsController(IMediator mediator, ISessionQueryService sessionQueryService)
        {
            _mediator = mediator;
            _sessionQueryService = sessionQueryService;
        }

        [HttpPost]
        public async Task<ActionResult<Guid>> StartSession([FromBody] StartSessionRequest request)
        {
            var id = await _mediator.Send(new StartSessionCommand(request.Topic, request.TargetLevel));
            return Ok(new { SessionId = id });
        }

        [HttpGet("{id:guid}")]
        public async Task<ActionResult<SessionDetailDto>> GetSessionById(Guid id)
        {
            var session = await _mediator.Send(new GetSessionDetailQuery(id));
            if (session == null) return NotFound();
            return Ok(session);
        }

        [HttpGet("active")]
        public async Task<ActionResult<IEnumerable<SessionSummaryDto>>> GetActiveSessions()
        {
            var sessions = await _sessionQueryService.GetActiveSessionsAsync();
            return Ok(sessions);
        }

        [HttpPost("{id:guid}/complete")]
        public async Task<IActionResult> CompleteSession(Guid id, [FromBody] CompleteSessionRequest request)
        {
            var success = await _mediator.Send(new EndSessionCommand(id, request.Feedback));
            if (!success) return NotFound();
            return Ok(new { Message = "Session completed successfully" });
        }
    }

    public record StartSessionRequest(
        [Required(ErrorMessage = "Topic is required")]
        [StringLength(255, MinimumLength = 1, ErrorMessage = "Topic must be between 1 and 255 characters")]
        string Topic, 
        CefrLevel TargetLevel = CefrLevel.B1);

    public record CompleteSessionRequest(
        [StringLength(2000, ErrorMessage = "Feedback cannot exceed 2000 characters")]
        string? Feedback = null);
}
