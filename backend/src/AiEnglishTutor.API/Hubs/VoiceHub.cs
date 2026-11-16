using System.Text;
using System.Text.RegularExpressions;
using AiEnglishTutor.Application.Repositories;
using AiEnglishTutor.Application.Services;
using AiEnglishTutor.Application.Usecases.Session.Commands.SendMessage;
using AiEnglishTutor.Application.Usecases.Session.Commands.StartSession;
using AiEnglishTutor.Domain.Enums;
using MediatR;
using Microsoft.AspNetCore.SignalR;

namespace AiEnglishTutor.API.Hubs
{
    public class VoiceHub : Hub
    {
        private readonly IMediator _mediator;
        private readonly IOllamaService _ollamaService;
        private readonly ISpeechToTextService _sttService;
        private readonly ITextToSpeechService _ttsService;
        private readonly ISessionRepository _sessionRepository;
        private readonly ILogger<VoiceHub> _logger;

        public VoiceHub(
            IMediator mediator,
            IOllamaService ollamaService,
            ISpeechToTextService sttService,
            ITextToSpeechService ttsService,
            ISessionRepository sessionRepository,
            ILogger<VoiceHub> logger)
        {
            _mediator = mediator;
            _ollamaService = ollamaService;
            _sttService = sttService;
            _ttsService = ttsService;
            _sessionRepository = sessionRepository;
            _logger = logger;
        }

        /// <summary>
        /// Starts a new session and pins it to the current connection.
        /// </summary>
        public async Task<Guid> StartSession(string topic, CefrLevel level = CefrLevel.B1)
        {
            if (string.IsNullOrWhiteSpace(topic) || topic.Trim().Length > 255)
            {
                throw new HubException("Topic is required and must not exceed 255 characters.");
            }

            var sessionId = await _mediator.Send(new StartSessionCommand(topic.Trim(), level), Context.ConnectionAborted);
            Context.Items["SessionId"] = sessionId;
            _logger.LogInformation("Client {ConnectionId} started session {SessionId}", Context.ConnectionId, sessionId);
            return sessionId;
        }

        /// <summary>
        /// Pins an existing active session to this connection (e.g. after reconnecting).
        /// NOTE: This validates session existence and active status to prevent cross-session interference on this connection.
        /// Full IDOR mitigation requires user authentication and UserId ownership checks (scheduled for Phase 3).
        /// </summary>
        public async Task<bool> JoinSession(Guid sessionId)
        {
            var session = await _sessionRepository.GetByIdAsync(sessionId, Context.ConnectionAborted);
            if (session == null || session.Status != SessionStatus.Active)
            {
                throw new HubException($"Session {sessionId} is not active or does not exist.");
            }

            Context.Items["SessionId"] = sessionId;
            _logger.LogInformation("Client {ConnectionId} joined session {SessionId}", Context.ConnectionId, sessionId);
            return true;
        }

        public async Task ProcessUserAudio(byte[] audioBytes, Guid turnId, Guid? sessionId = null)
        {
            _logger.LogInformation("ProcessUserAudio called by {ConnectionId}: {BytesLength} bytes, turnId: {TurnId}, sessionId: {SessionId}", Context.ConnectionId, audioBytes?.Length ?? 0, turnId, sessionId);
            var cancellationToken = BeginNewTurn(turnId);

            try
            {
                var resolvedSessionId = await ResolveSessionAsync(sessionId, cancellationToken);

                // 1. STT: Transcribe speech to text
                await Clients.Caller.SendAsync("StatusUpdate", "Transcribing speech...", cancellationToken);
                string transcribedText;
                try
                {
                    transcribedText = await _sttService.TranscribeBytesAsync(audioBytes, cancellationToken);
                }
                catch (ArgumentException ex)
                {
                    _logger.LogWarning(ex, "Invalid audio format received from client {ConnectionId}", Context.ConnectionId);
                    await Clients.Caller.SendAsync("StatusUpdate", $"Audio error: {ex.Message}", cancellationToken);
                    return;
                }

                if (string.IsNullOrWhiteSpace(transcribedText))
                {
                    await Clients.Caller.SendAsync("StatusUpdate", "Could not detect speech. Please try speaking again.", cancellationToken);
                    return;
                }

                // Send transcribed text back to client immediately
                await Clients.Caller.SendAsync("UserTranscribedText", transcribedText, cancellationToken);

                // 2. Process text through LLM and Stream TTS
                await ProcessUserTextInternal(transcribedText, resolvedSessionId, turnId, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                _logger.LogInformation("ProcessUserAudio canceled: Client {ConnectionId} disconnected.", Context.ConnectionId);
            }
            catch (HubException ex)
            {
                // The client calls this via send() (fire-and-forget), not invoke(), so it never
                // awaits a completion/error response — push it as a StatusUpdate instead of
                // just throwing, or the client would never learn the turn failed.
                await Clients.Caller.SendAsync("StatusUpdate", ex.Message, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error in ProcessUserAudio for client {ConnectionId}", Context.ConnectionId);
                await Clients.Caller.SendAsync("StatusUpdate", "An error occurred while processing your audio.", cancellationToken);
            }
        }

        public async Task ProcessUserText(string userText, Guid turnId, Guid? sessionId = null)
        {
            var cancellationToken = BeginNewTurn(turnId);

            try
            {
                var resolvedSessionId = await ResolveSessionAsync(sessionId, cancellationToken);
                await ProcessUserTextInternal(userText, resolvedSessionId, turnId, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                _logger.LogInformation("ProcessUserText canceled: Client {ConnectionId} disconnected.", Context.ConnectionId);
            }
            catch (HubException ex)
            {
                // Same reasoning as ProcessUserAudio — client uses send(), so surface this via
                // StatusUpdate rather than relying on the invoke() error path it no longer uses.
                await Clients.Caller.SendAsync("StatusUpdate", ex.Message, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error in ProcessUserText for client {ConnectionId}", Context.ConnectionId);
                await Clients.Caller.SendAsync("StatusUpdate", "An error occurred while processing your message.", cancellationToken);
            }
        }

        private async Task ProcessUserTextInternal(string userText, Guid sessionId, Guid turnId, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(userText)) return;

            var turnStartTime = DateTime.UtcNow;

            // Save user message (CQRS Write) with turnStartTime
            await _mediator.Send(new SendUserMessageCommand(sessionId, userText, null, SenderType.User, turnStartTime), Context.ConnectionAborted);

            await Clients.Caller.SendAsync("StatusUpdate", "AI is thinking...", cancellationToken);

            var fullResponse = new StringBuilder();
            var sentenceBuffer = new StringBuilder();

            try
            {
                // Stream from Llama 3.2 (cancelled when new turn arrives, preserving partial text)
                await foreach (var token in _ollamaService.StreamResponseAsync(userText, cancellationToken: cancellationToken))
                {
                    fullResponse.Append(token);
                    sentenceBuffer.Append(token);

                    // Stream subtitle token to UI, tagged with this turn's id so the client can
                    // drop it if a newer turn has already started (barge-in race mitigation).
                    await Clients.Caller.SendAsync("ReceiveSubtitleToken", token, turnId, cancellationToken);

                    // Check for sentence end (. ? ! \n) or clause boundary (, ; :) with at least 4 words
                    var currentText = sentenceBuffer.ToString();
                    var isSentenceEnd = Regex.IsMatch(currentText, @"(?<!\b(Mr|Mrs|Ms|Dr|Prof|e\.g|i\.e|vs|\d))\s*[.?!]\s*$|\n$");
                    var isClauseEnd = false;

                    if (!isSentenceEnd && Regex.IsMatch(currentText, @"[,;:]\s*$"))
                    {
                        var wordCount = currentText.Split(new[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries).Length;
                        if (wordCount >= 4)
                        {
                            isClauseEnd = true;
                        }
                    }

                    if (isSentenceEnd || isClauseEnd)
                    {
                        var phraseToSpeak = currentText.Trim();
                        if (!string.IsNullOrWhiteSpace(phraseToSpeak) && phraseToSpeak.Length >= 2)
                        {
                            sentenceBuffer.Clear();
                            await StreamAudioSentenceToClient(phraseToSpeak, turnId, cancellationToken);
                        }
                    }
                }

                // Speak remaining buffer if any
                if (sentenceBuffer.Length > 0)
                {
                    var remaining = sentenceBuffer.ToString().Trim();
                    if (!string.IsNullOrWhiteSpace(remaining))
                    {
                        await StreamAudioSentenceToClient(remaining, turnId, cancellationToken);
                    }
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                // Barge-in: a new turn interrupted this one. Fall through to save whatever was generated so far
            }

            var connectionAborted = Context.ConnectionAborted;

            if (fullResponse.Length > 0)
            {
                // Save AI tutor message (CQRS Write) paired right after user message (turnStartTime + 1ms)
                await _mediator.Send(new SendUserMessageCommand(sessionId, fullResponse.ToString(), null, SenderType.Tutor, turnStartTime.AddMilliseconds(1)), connectionAborted);
            }

            await Clients.Caller.SendAsync("TurnCompleted", fullResponse.ToString(), connectionAborted);
        }

        private async Task StreamAudioSentenceToClient(string phrase, Guid turnId, CancellationToken cancellationToken)
        {
            try
            {
                await foreach (var pcmChunk in _ttsService.StreamAudioAsync(phrase, cancellationToken: cancellationToken))
                {
                    if (pcmChunk.Length > 0 && !cancellationToken.IsCancellationRequested)
                    {
                        // Tagged with turnId: if this chunk was already past its cancellation check
                        // and in flight when a barge-in happened, the client still discards it by
                        // comparing turnId against whatever turn it's currently listening for.
                        await Clients.Caller.SendAsync("ReceiveAudioChunk", pcmChunk, turnId, cancellationToken);
                    }
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                // Normal client disconnect
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "TTS generation failed for phrase: {Phrase}", phrase);
                await Clients.Caller.SendAsync("StatusUpdate", "Voice synthesis unavailable for this phrase.", cancellationToken);
            }
        }

        /// <summary>
        /// Cancels whichever turn (ProcessUserAudio/ProcessUserText call) is currently in flight on this
        /// connection, if any, and starts a fresh cancellation scope for the new one, identified by the
        /// client-supplied <paramref name="turnId"/>. This is what makes barge-in work: sending new input
        /// while the AI is still generating/speaking interrupts the old turn's LLM streaming and TTS
        /// synthesis immediately instead of queuing behind it.
        /// Requires HubOptions.MaximumParallelInvocationsPerClient &gt; 1 (see Program.cs) — otherwise
        /// SignalR itself queues the new invocation and its body never starts running until the old one
        /// finishes on its own.
        /// The client generates turnId (not the server) so it can start filtering out any stale
        /// ReceiveAudioChunk/ReceiveSubtitleToken from the old turn — which may still be in flight over
        /// the network when cancellation fires — the instant it decides to start a new one, with no
        /// round-trip needed to learn the id first.
        /// </summary>
        private CancellationToken BeginNewTurn(Guid turnId)
        {
            // Context.Items is not thread-safe against concurrent invocations on the same connection;
            // lock on it (a stable, per-connection object) rather than introducing a separate field.
            lock (Context.Items)
            {
                if (Context.Items.TryGetValue("TurnCts", out var existing) && existing is CancellationTokenSource previousCts)
                {
                    if (!previousCts.IsCancellationRequested)
                    {
                        _logger.LogInformation("Connection {ConnectionId} started turn {TurnId} — interrupting the previous one.", Context.ConnectionId, turnId);
                        previousCts.Cancel();
                    }
                }

                var turnCts = CancellationTokenSource.CreateLinkedTokenSource(Context.ConnectionAborted);
                Context.Items["TurnCts"] = turnCts;
                Context.Items["TurnId"] = turnId;
                return turnCts.Token;
            }
        }

        /// <summary>
        /// Resolves and pins the session ID for this connection.
        /// Prevents a connection bound to Session A from sending into Session B (Session Hijacking / Cross-talk mitigation).
        /// </summary>
        private async Task<Guid> ResolveSessionAsync(Guid? requestedSessionId, CancellationToken cancellationToken)
        {
            var hasPinned = Context.Items.TryGetValue("SessionId", out var sId) && sId is Guid pinnedId && pinnedId != Guid.Empty;

            if (hasPinned)
            {
                var establishedId = (Guid)sId!;
                if (requestedSessionId.HasValue && requestedSessionId.Value != Guid.Empty && requestedSessionId.Value != establishedId)
                {
                    _logger.LogWarning("Connection {ConnectionId} attempted cross-session access: requested {RequestedId}, pinned to {PinnedId}",
                        Context.ConnectionId, requestedSessionId.Value, establishedId);
                    throw new HubException("Unauthorized: Connection is bound to a different session.");
                }
                return establishedId;
            }

            // Connection has not yet pinned a session, but client supplied one (e.g. Flutter client reconnecting)
            if (requestedSessionId.HasValue && requestedSessionId.Value != Guid.Empty)
            {
                var session = await _sessionRepository.GetByIdAsync(requestedSessionId.Value, cancellationToken);
                if (session == null || session.Status != SessionStatus.Active)
                {
                    throw new HubException($"Session {requestedSessionId.Value} does not exist or is no longer active.");
                }

                Context.Items["SessionId"] = requestedSessionId.Value;
                _logger.LogInformation("Connection {ConnectionId} dynamically pinned to active session {SessionId}",
                    Context.ConnectionId, requestedSessionId.Value);
                return requestedSessionId.Value;
            }

            throw new HubException("No active session initialized for this connection. Please start or join a session first.");
        }
    }
}
