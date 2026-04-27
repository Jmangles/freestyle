import 'trick.dart';
import 'user_trick.dart';

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
    final map = <String, List<Trick>>{};
    for (final t in tricks) {
      map.putIfAbsent(_groupLabel(t, consistencyMap), () => []).add(t);
    }

    final entries = map.entries.toList()
      ..sort((a, b) {
        final cmp = _compareGroups(a.key, b.key);
        return ascending ? cmp : -cmp;
      });

    for (final e in entries) {
      e.value.sort((a, b) {
        final cmp = _compareWithin(a, b, consistencyMap);
        return ascending ? cmp : -cmp;
      });
    }

    return [for (final e in entries) (e.key, e.value)];
  }

  String _groupLabel(Trick t, Map<int, Consistency> consistencyMap) {
    switch (primary) {
      case PrimarySort.difficulty:
        return t.difficultyTier == -1 ? 'To Be Determined' : 'Difficulty ${t.difficultyTier}';
      case PrimarySort.startPosition:
        return t.startPositionName ?? 'Unknown';
      case PrimarySort.yearLanded:
        return t.datePerformed?.year.toString() ?? 'Unknown';
      case PrimarySort.consistency:
        final c = consistencyMap[t.id];
        if (c == null) return 'Never Attempted';
        if (c == Consistency.never) return 'Attempting';
        return 'Landed';
    }
  }

  int _compareGroups(String a, String b) {
    switch (primary) {
      case PrimarySort.difficulty:
        if (a == 'To Be Determined') return 1;
        if (b == 'To Be Determined') return -1;
        final ta = int.tryParse(a.replaceFirst('Difficulty ', '')) ?? 0;
        final tb = int.tryParse(b.replaceFirst('Difficulty ', '')) ?? 0;
        return ta.compareTo(tb);
      case PrimarySort.startPosition:
      case PrimarySort.yearLanded:
        if (a == 'Unknown') return 1;
        if (b == 'Unknown') return -1;
        return a.compareTo(b);
      case PrimarySort.consistency:
        const order = {'Never Attempted': 0, 'Attempting': 1, 'Landed': 2};
        return (order[b] ?? 0).compareTo(order[a] ?? 0);
    }
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
