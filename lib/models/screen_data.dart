import 'position.dart';
import 'profile.dart';
import 'trick.dart';
import 'user_trick.dart';

class TrickDetailData {
  final Trick trick;
  final List<Trick> prerequisites;
  final UserTrick? userTrick;
  final bool isAdmin;

  const TrickDetailData({
    required this.trick,
    required this.prerequisites,
    this.userTrick,
    required this.isAdmin,
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
  final Profile? profile;

  const AdminData({required this.pendingTricks, this.profile});
}
