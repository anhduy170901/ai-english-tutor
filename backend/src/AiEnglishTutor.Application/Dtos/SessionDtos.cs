using AiEnglishTutor.Domain.Enums;

namespace AiEnglishTutor.Application.Dtos
{
    public record MessageDto(
        Guid Id,
        SenderType Sender,
        string Content,
        string? GrammarFeedback,
        string? VocabularySuggestions,
        double? PronunciationScore,
        DateTime CreatedAt
    );

    public record SessionDetailDto(
        Guid Id,
        string Topic,
        CefrLevel TargetLevel,
        SessionStatus Status,
        DateTime CreatedAt,
        DateTime? EndedAt,
        string? SummaryFeedback,
        List<MessageDto> Messages
    );

    public record SessionSummaryDto(
        Guid Id,
        string Topic,
        CefrLevel TargetLevel,
        SessionStatus Status,
        int MessageCount,
        DateTime CreatedAt
    );
}
