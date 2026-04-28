import 'trick.dart';
import 'user_trick.dart';
import '../utils/difficulty_tier.dart';

enum PrimarySort {
  difficulty('Difficulty Tier'),
  startPosition('Start Position'),
  yearLanded('Year Landed'),
  consistency('Consistency');

  const PrimarySort(this.label);
  final String label;
}

enum SecondarySort {
  difficulty('Difficulty Tier'),
  startPosition('Start Position'),
  endPosition('End Position'),
  consistency('Consistency'),
  alphabetical('Alphabetical');

  const SecondarySort(this.label);
  final String label;
}

// Sentinel sort key used to push "unknown" groups to the end when sorting ascending.
const _kUnknownLast = 0x7FFFFFFF;

class TrickSorter {
  final PrimarySort primary;
  final SecondarySort secondary;
  final bool ascending;

  const TrickSorter({
    this.primary = PrimarySort.difficulty,
    this.secondary = SecondarySort.alphabetical,
    this.ascending = true,
  });

  List<(String, List<Trick>)> buildGroups(
    List<Trick> tricks,
    Map<int, Consistency> consistencyMap,
  ) {
    // Key is (displayLabel, sortOrder) so ordering never requires re-parsing the label.
    final map = <(String, int), List<Trick>>{};
    for (final t in tricks) {
      map.putIfAbsent(_groupKey(t, consistencyMap), () => []).add(t);
    }

    final entries = map.entries.toList()
      ..sort((a, b) {
        final cmp = _compareKeys(a.key, b.key);
        return ascending ? cmp : -cmp;
      });

    for (final e in entries) {
      e.value.sort((a, b) {
        final cmp = _compareWithin(a, b, consistencyMap);
        return ascending ? cmp : -cmp;
      });
    }

    return [for (final e in entries) (e.key.$1, e.value)];
  }

  // Returns a (displayLabel, sortOrder) pair for the group this trick belongs to.
  (String, int) _groupKey(Trick t, Map<int, Consistency> consistencyMap) {
    switch (primary) {
      case PrimarySort.difficulty:
        if (t.difficultyTier == -1) return ('To Be Determined', _kUnknownLast);
        final tier = DifficultyTier.logicalTier(t.difficultyTier);
        return ('Difficulty $tier', tier);
      case PrimarySort.startPosition:
        final name = t.startPositionName ?? 'Unknown';
        // sortOrder=0 for all real positions so they fall back to alphabetical label comparison.
        return (name, name == 'Unknown' ? _kUnknownLast : 0);
      case PrimarySort.yearLanded:
        final year = t.datePerformed?.year;
        if (year == null) return ('Unknown', _kUnknownLast);
        return (year.toString(), year);
      case PrimarySort.consistency:
        final c = consistencyMap[t.id];
        // Sort order: Landed(0) first, Attempting(1), Never Attempted(2) last when ascending.
        if (c == null) return ('Never Attempted', 2);
        if (c == Consistency.never) return ('Attempting', 1);
        return ('Landed', 0);
    }
  }

  int _compareKeys((String, int) a, (String, int) b) {
    final bySortOrder = a.$2.compareTo(b.$2);
    if (bySortOrder != 0) return bySortOrder;
    // Tied sort order (e.g. multiple start positions): compare labels alphabetically.
    return a.$1.compareTo(b.$1);
  }

  int _compareWithin(Trick a, Trick b, Map<int, Consistency> consistencyMap) {
    switch (secondary) {
      case SecondarySort.difficulty:
        if (a.difficultyTier == b.difficultyTier) return 0;
        if (a.difficultyTier == -1) return 1;
        if (b.difficultyTier == -1) return -1;
        return a.difficultyTier.compareTo(b.difficultyTier);
      case SecondarySort.startPosition:
        return (a.startPositionName ?? 'zzz').toLowerCase()
            .compareTo((b.startPositionName ?? 'zzz').toLowerCase());
      case SecondarySort.endPosition:
        return (a.endPositionName ?? 'zzz').toLowerCase()
            .compareTo((b.endPositionName ?? 'zzz').toLowerCase());
      case SecondarySort.consistency:
        return _consistencyRank(a.id, consistencyMap)
            .compareTo(_consistencyRank(b.id, consistencyMap));
      case SecondarySort.alphabetical:
        return a.givenName.toLowerCase().compareTo(b.givenName.toLowerCase());
    }
  }

  int _consistencyRank(int trickId, Map<int, Consistency> consistencyMap) {
    final c = consistencyMap[trickId];
    if (c == null) return 0;
    if (c == Consistency.never) return 1;
    return 2;
  }
}
