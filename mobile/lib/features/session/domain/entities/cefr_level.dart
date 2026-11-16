enum CefrLevel {
  // Values match backend AiEnglishTutor.Domain.Enums.CefrLevel exactly (1-based),
  // otherwise every session is persisted one level off from what the user picked.
  a1(1, 'A1', 'Beginner', 'Basic greetings and simple everyday words'),
  a2(2, 'A2', 'Elementary', 'Routine exchanges and simple tasks'),
  b1(3, 'B1', 'Intermediate', 'Conversations on familiar matters and work'),
  b2(4, 'B2', 'Upper-Intermediate', 'Fluent spontaneous discussion and nuance'),
  c1(5, 'C1', 'Advanced', 'Complex academic, professional expressions'),
  c2(6, 'C2', 'Proficient', 'Mastery with natural native-level precision');

  final int value;
  final String code;
  final String label;
  final String description;

  const CefrLevel(this.value, this.code, this.label, this.description);

  static CefrLevel fromValue(int val) {
    return CefrLevel.values.firstWhere((e) => e.value == val, orElse: () => CefrLevel.b1);
  }
}
