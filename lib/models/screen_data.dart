import 'position.dart';
import 'profile.dart';
import 'trick.dart';
import 'trick_suggestion.dart';
import 'trick_vote_stats.dart';
import 'user_trick.dart';

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

  const ProfileData({this.profile, required this.entries});
}

class AdminData {
  final List<Trick> pendingTricks;
  final List<TrickSuggestion> pendingSuggestions;
  final Map<int, Trick> originalTricks;
  final Profile? profile;

  const AdminData({
    required this.pendingTricks,
    required this.pendingSuggestions,
    required this.originalTricks,
    this.profile,
  });
}
