import 'user_trick.dart';

// Legacy stickFrequency (8 values, src/services/enums.js of the old app)
// indexed into this app's Consistency. Since `rarely` was added the two enums
// line up one-to-one; kept explicit so adding a Consistency value trips the
// length assertion in legacy_import_test.dart instead of silently shifting.
const legacyConsistencyByStickFrequency = <int>[0, 1, 2, 3, 4, 5, 6, 7];

Consistency consistencyFromStickFrequency(int stickFrequency) {
  if (stickFrequency < 0 ||
      stickFrequency >= legacyConsistencyByStickFrequency.length) {
    return Consistency.neverTried;
  }
  return Consistency.values[legacyConsistencyByStickFrequency[stickFrequency]];
}

class LegacyScan {
  const LegacyScan({
    required this.consistencyByTrickId,
    required this.untransferable,
    required this.customTricks,
  });

  final Map<int, Consistency> consistencyByTrickId;
  final int untransferable;
  final int customTricks;

  int get importable => consistencyByTrickId.length;
  bool get hasAnything => importable > 0 || untransferable > 0;
}

class LegacyImportResult {
  const LegacyImportResult({
    required this.written,
    required this.skippedNotHigher,
    required this.untransferable,
  });

  final int written;
  final int skippedNotHigher;
  final int untransferable;
}
