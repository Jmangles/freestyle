import 'position.dart';
import 'profile.dart';
import 'tip.dart';
import 'trick.dart';
import 'trick_suggestion.dart';
import 'trick_vote_stats.dart';
import 'user_trick.dart';

class HighValueTarget {
  final Trick trick;
  final int unlockCount;

  const HighValueTarget({required this.trick, required this.unlockCount});
}

class WhatsNextData {
  final List<Trick> unlocked;
  final List<Trick> partiallyUnlocked;
  final List<HighValueTarget> highValue;

  const WhatsNextData({
    required this.unlocked,
    required this.partiallyUnlocked,
    required this.highValue,
  });

  bool get isEmpty =>
      unlocked.isEmpty && partiallyUnlocked.isEmpty && highValue.isEmpty;
}

class TrickDetailData {
  final Trick trick;
  final List<Trick> prerequisites;
  final UserTrick? userTrick;
  final bool canEditTricks;
  final TrickVoteStats voteStats;

  const TrickDetailData({
    required this.trick,
    required this.prerequisites,
    this.userTrick,
    required this.canEditTricks,
    required this.voteStats,
  });
}

class SubmitMeta {
  final List<Position> positions;
  final List<Trick> tricks;

  const SubmitMeta({required this.positions, required this.tricks});
}

class UserTrickEntry {
  final UserTrick userTrick;
  final Trick? trick;

  const UserTrickEntry({required this.userTrick, this.trick});
}

class ProfileData {
  final Profile? profile;
  final List<UserTrickEntry> entries;
  final WhatsNextData whatsNext;

  const ProfileData({
    this.profile,
    required this.entries,
    required this.whatsNext,
  });
}

class AdminData {
  final List<Trick> pendingTricks;
  final List<TrickSuggestion> pendingSuggestions;
  final Map<int, Trick> originalTricks;
  final List<Tip> pendingTips;
  final Profile? profile;

  const AdminData({
    required this.pendingTricks,
    required this.pendingSuggestions,
    required this.originalTricks,
    required this.pendingTips,
    this.profile,
  });
}
