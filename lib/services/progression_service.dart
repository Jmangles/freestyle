import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';

/// Pure computation for the "What's Next" progression logic, separated from
/// the profile screen so it can be tested and reused independently.
class ProgressionService {
  ProgressionService._();

  static WhatsNextData computeWhatsNext(
    List<UserTrick> userTricks,
    List<Trick> allTricks,
  ) {
    final landedIds = <int>{
      for (final ut in userTricks)
        if (ut.consistency.isLanded) ut.trickId,
    };

    // Qualifying variations (tier >= base tier, both > 0) satisfy their base trick for progression.
    final trickById = {for (final t in allTricks) t.id: t};
    final effectiveLandedIds = {...landedIds};
    for (final t in allTricks) {
      if (t.baseTrickIds.isEmpty || !landedIds.contains(t.id) || t.difficultyTier <= 0) continue;
      for (final baseId in t.baseTrickIds) {
        final base = trickById[baseId];
        if (base != null && base.difficultyTier > 0 && t.difficultyTier >= base.difficultyTier) {
          effectiveLandedIds.add(baseId);
        }
      }
    }

    final trackedIds = {for (final ut in userTricks) ut.trickId};

    // Category 1: all prerequisites effectively met, not yet tracked.
    final unlocked = allTricks
        .where((t) =>
            !trackedIds.contains(t.id) &&
            t.prerequisiteTrickIds.isNotEmpty &&
            t.prerequisiteTrickIds.every((id) => effectiveLandedIds.contains(id)))
        .toList()
      ..sort((a, b) => a.difficultyTier.compareTo(b.difficultyTier));

    // Category 2: at least one but not all prerequisites effectively met, not tracked.
    final partiallyUnlocked = allTricks
        .where((t) =>
            !trackedIds.contains(t.id) &&
            t.prerequisiteTrickIds.isNotEmpty &&
            t.prerequisiteTrickIds.any((id) => effectiveLandedIds.contains(id)) &&
            !t.prerequisiteTrickIds.every((id) => effectiveLandedIds.contains(id)))
        .toList()
      ..sort((a, b) {
        final aCount =
            a.prerequisiteTrickIds.where((id) => effectiveLandedIds.contains(id)).length;
        final bCount =
            b.prerequisiteTrickIds.where((id) => effectiveLandedIds.contains(id)).length;
        return bCount.compareTo(aCount);
      });

    // Category 3: tricks that, once landed, unlock the most immediate next
    // tricks — prioritises high-leverage moves to learn next.
    final unlockCountMap = <int, int>{};
    for (final t in allTricks) {
      if (effectiveLandedIds.contains(t.id)) continue;
      for (final prereqId in t.prerequisiteTrickIds) {
        if (!effectiveLandedIds.contains(prereqId)) {
          final othersAllLanded = t.prerequisiteTrickIds
              .where((id) => id != prereqId)
              .every((id) => effectiveLandedIds.contains(id));
          if (othersAllLanded) {
            unlockCountMap[prereqId] = (unlockCountMap[prereqId] ?? 0) + 1;
          }
        }
      }
    }

    final highValue = allTricks
        .where((t) => !effectiveLandedIds.contains(t.id) && (unlockCountMap[t.id] ?? 0) > 0)
        .map((t) =>
            HighValueTarget(trick: t, unlockCount: unlockCountMap[t.id]!))
        .toList()
      ..sort((a, b) => b.unlockCount.compareTo(a.unlockCount));

    return WhatsNextData(
      unlocked: unlocked,
      partiallyUnlocked: partiallyUnlocked,
      highValue: highValue.take(10).toList(),
    );
  }
}
