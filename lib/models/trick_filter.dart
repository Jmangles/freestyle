import 'trick.dart';
import 'user_trick.dart';

enum TrickStatus {
  neverAttempted('Never Attempted'),
  attempting('Attempting'),
  landed('Landed at least once');

  const TrickStatus(this.label);
  final String label;
}

class TrickFilter {
  final int? tierMin;
  final int? tierMax;
  final bool includeTbd;
  final String? startPosition;
  final String? endPosition;
  final Set<TrickStatus> statuses;
  final int? yearLanded;
  final String performerQuery;
  final String nameQuery;
  final bool coreOnly;

  const TrickFilter({
    this.tierMin,
    this.tierMax,
    this.includeTbd = true,
    this.startPosition,
    this.endPosition,
    this.statuses = const {},
    this.yearLanded,
    this.performerQuery = '',
    this.nameQuery = '',
    this.coreOnly = false,
  });

  bool get isActive =>
      tierMin != null ||
      tierMax != null ||
      !includeTbd ||
      startPosition != null ||
      endPosition != null ||
      statuses.isNotEmpty ||
      yearLanded != null ||
      performerQuery.isNotEmpty ||
      nameQuery.isNotEmpty ||
      coreOnly;

  int get activeCount =>
      ((tierMin != null || tierMax != null) ? 1 : 0) +
      (!includeTbd ? 1 : 0) +
      (startPosition != null ? 1 : 0) +
      (endPosition != null ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (yearLanded != null ? 1 : 0) +
      (performerQuery.isNotEmpty ? 1 : 0) +
      (nameQuery.isNotEmpty ? 1 : 0) +
      (coreOnly ? 1 : 0);

  List<Trick> apply(List<Trick> tricks, Map<int, Consistency> consistencyMap) {
    return tricks.where((t) {
      if (coreOnly && !t.isCore) return false;
      if (t.difficultyTier == -1) {
        if (!includeTbd) return false;
      } else {
        if (tierMin != null && t.difficultyTier < tierMin!) return false;
        if (tierMax != null && t.difficultyTier > tierMax!) return false;
      }
      if (startPosition != null && t.startPositionName != startPosition) return false;
      if (endPosition != null && t.endPositionName != endPosition) return false;
      if (statuses.isNotEmpty && !statuses.contains(_statusFor(t.id, consistencyMap))) return false;
      if (yearLanded != null && t.datePerformed?.year != yearLanded) return false;
      if (performerQuery.isNotEmpty) {
        final q = performerQuery.toLowerCase();
        if (!(t.originalPerformer?.toLowerCase().contains(q) ?? false)) return false;
      }
      if (nameQuery.isNotEmpty) {
        final q = nameQuery.toLowerCase();
        final matchesGiven = t.givenName.toLowerCase().contains(q);
        final matchesTechnical = t.technicalName?.toLowerCase().contains(q) ?? false;
        if (!matchesGiven && !matchesTechnical) return false;
      }
      return true;
    }).toList();
  }

  TrickStatus _statusFor(int trickId, Map<int, Consistency> consistencyMap) {
    final c = consistencyMap[trickId];
    if (c == null) return TrickStatus.neverAttempted;
    if (c == Consistency.never) return TrickStatus.attempting;
    return TrickStatus.landed;
  }
}
