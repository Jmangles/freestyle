class TrickVoteStats {
  final Map<int, int> difficultyVotes; // raw tier value (1–30) → count
  final Map<int, int> leashPositions;  // LeashPosition.index → count

  const TrickVoteStats({
    required this.difficultyVotes,
    required this.leashPositions,
  });

  bool get hasDifficultyVotes => difficultyVotes.isNotEmpty;
  bool get hasLeashVotes => leashPositions.isNotEmpty;
  bool get hasAnyData => hasDifficultyVotes || hasLeashVotes;

  factory TrickVoteStats.empty() =>
      const TrickVoteStats(difficultyVotes: {}, leashPositions: {});

  factory TrickVoteStats.fromRpc(Map<String, dynamic> json) {
    final dv = json['difficulty_votes'] as Map<String, dynamic>? ?? {};
    final lp = json['leash_positions'] as Map<String, dynamic>? ?? {};
    return TrickVoteStats(
      difficultyVotes: {
        for (final e in dv.entries) int.parse(e.key): (e.value as num).toInt(),
      },
      leashPositions: {
        for (final e in lp.entries) int.parse(e.key): (e.value as num).toInt(),
      },
    );
  }
}
