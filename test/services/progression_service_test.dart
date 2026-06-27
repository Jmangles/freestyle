import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/models/approval_status.dart';
import 'package:freestyle_highline/models/trick.dart';
import 'package:freestyle_highline/models/user_trick.dart';
import 'package:freestyle_highline/services/progression_service.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Trick _trick({
  required int id,
  int tier = 5,
  List<int> prereqs = const [],
  List<int> baseTricks = const [],
}) =>
    Trick(
      id: id,
      givenName: 'Trick $id',
      difficultyTier: tier,
      dateSubmitted: _epoch,
      prerequisiteTrickIds: prereqs,
      baseTrickIds: baseTricks,
      status: ApprovalStatus.approved,
    );

UserTrick _landed(int trickId) => UserTrick(
      id: trickId,
      userId: 1,
      trickId: trickId,
      consistency: Consistency.once,
      updatedAt: _epoch,
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('ProgressionService.computeWhatsNext — variation satisfies base', () {
    // Base graph used in most tests:
    //   A (tier 5) ← A' is a variation of A
    //   B requires A
    late Trick a, aPrime, b;

    setUp(() {
      a = _trick(id: 1, tier: 5);
      aPrime = _trick(id: 2, tier: 5, baseTricks: [1]);
      b = _trick(id: 3, tier: 8, prereqs: [1]);
    });

    test('same-tier variation satisfies base — unlocks B', () {
      final result = ProgressionService.computeWhatsNext(
        [_landed(aPrime.id)],
        [a, aPrime, b],
      );
      expect(result.unlocked.map((t) => t.id), contains(b.id));
    });

    test('higher-tier variation satisfies base — unlocks B', () {
      final highVariation = _trick(id: 2, tier: 8, baseTricks: [1]);
      final result = ProgressionService.computeWhatsNext(
        [_landed(highVariation.id)],
        [a, highVariation, b],
      );
      expect(result.unlocked.map((t) => t.id), contains(b.id));
    });

    test('lower-tier variation does not satisfy base — B stays locked', () {
      final lowVariation = _trick(id: 2, tier: 4, baseTricks: [1]);
      final result = ProgressionService.computeWhatsNext(
        [_landed(lowVariation.id)],
        [a, lowVariation, b],
      );
      expect(result.unlocked.map((t) => t.id), isNot(contains(b.id)));
    });

    test('TBD-tier variation (tier <= 0) never satisfies base', () {
      for (final tbdTier in [-1, 0]) {
        final tbdVariation = _trick(id: 2, tier: tbdTier, baseTricks: [1]);
        final result = ProgressionService.computeWhatsNext(
          [_landed(tbdVariation.id)],
          [a, tbdVariation, b],
        );
        expect(
          result.unlocked.map((t) => t.id),
          isNot(contains(b.id)),
          reason: 'tier $tbdTier should not count',
        );
      }
    });

    test('TBD-tier base (tier <= 0) is never considered satisfied', () {
      for (final tbdTier in [-1, 0]) {
        final tbdBase = _trick(id: 1, tier: tbdTier);
        final trick = _trick(id: 3, tier: 8, prereqs: [1]);
        final result = ProgressionService.computeWhatsNext(
          [_landed(aPrime.id)],
          [tbdBase, aPrime, trick],
        );
        expect(
          result.unlocked.map((t) => t.id),
          isNot(contains(trick.id)),
          reason: 'base tier $tbdTier should not be satisfiable',
        );
      }
    });

    test('unlanded variation has no effect', () {
      final never = UserTrick(
        id: aPrime.id,
        userId: 1,
        trickId: aPrime.id,
        consistency: Consistency.never,
        updatedAt: _epoch,
      );
      final result = ProgressionService.computeWhatsNext(
        [never],
        [a, aPrime, b],
      );
      expect(result.unlocked.map((t) => t.id), isNot(contains(b.id)));
    });

    test('variation satisfies all qualifying bases in baseTrickIds', () {
      // A' is a variation of both A (tier 5) and C (tier 3) — qualifies for both.
      // D requires A, E requires C.
      final c = _trick(id: 4, tier: 3);
      final multiVariation = _trick(id: 2, tier: 5, baseTricks: [1, 4]);
      final d = _trick(id: 5, prereqs: [1]);
      final e = _trick(id: 6, prereqs: [4]);
      final result = ProgressionService.computeWhatsNext(
        [_landed(multiVariation.id)],
        [a, c, multiVariation, d, e],
      );
      final ids = result.unlocked.map((t) => t.id).toList();
      expect(ids, containsAll([d.id, e.id]));
    });

    test('variation does not satisfy a higher-tier base via chain', () {
      // A'' is a variation of A' (tier 5). A' is a variation of A (tier 5).
      // Landing A'' satisfies A' but should NOT transitively satisfy A.
      final aDouble = _trick(id: 3, tier: 5, baseTricks: [aPrime.id]);
      final result = ProgressionService.computeWhatsNext(
        [_landed(aDouble.id)],
        [a, aPrime, aDouble, b],
      );
      expect(result.unlocked.map((t) => t.id), isNot(contains(b.id)));
    });

    test('directly landing the base trick still works (regression)', () {
      final result = ProgressionService.computeWhatsNext(
        [_landed(a.id)],
        [a, aPrime, b],
      );
      expect(result.unlocked.map((t) => t.id), contains(b.id));
    });
  });

  group('ProgressionService.computeWhatsNext — partiallyUnlocked', () {
    test('effective prereq counts toward partially unlocked', () {
      // C requires [A, X]. A is effectively satisfied via A', X is not landed.
      final a = _trick(id: 1, tier: 5);
      final aPrime = _trick(id: 2, tier: 5, baseTricks: [1]);
      final x = _trick(id: 3, tier: 5);
      final c = _trick(id: 4, tier: 8, prereqs: [1, 3]);

      final result = ProgressionService.computeWhatsNext(
        [_landed(aPrime.id)],
        [a, aPrime, x, c],
      );
      expect(result.partiallyUnlocked.map((t) => t.id), contains(c.id));
    });

    test('effective prereq is not double-counted with a direct land', () {
      // Both A and A' are landed. C (prereqs [A, X]) should only count A once.
      final a = _trick(id: 1, tier: 5);
      final aPrime = _trick(id: 2, tier: 5, baseTricks: [1]);
      final x = _trick(id: 3, tier: 5);
      final c = _trick(id: 4, prereqs: [1, 3]);

      final result = ProgressionService.computeWhatsNext(
        [_landed(a.id), _landed(aPrime.id)],
        [a, aPrime, x, c],
      );
      // C still has one unmet prereq (X), so it's partially — not fully — unlocked.
      expect(result.partiallyUnlocked.map((t) => t.id), contains(c.id));
      expect(result.unlocked.map((t) => t.id), isNot(contains(c.id)));
    });
  });

  group('ProgressionService.computeWhatsNext — highValue', () {
    test('effectively-landed base does not appear as high-value target', () {
      // A would normally be high-value because landing it unlocks B.
      // But A is effectively satisfied by A', so it should not appear.
      final a = _trick(id: 1, tier: 5);
      final aPrime = _trick(id: 2, tier: 5, baseTricks: [1]);
      final b = _trick(id: 3, prereqs: [1]);

      final result = ProgressionService.computeWhatsNext(
        [_landed(aPrime.id)],
        [a, aPrime, b],
      );
      expect(result.highValue.map((hv) => hv.trick.id), isNot(contains(a.id)));
    });

    test('high-value target still appears for unrelated unmet prereqs', () {
      // P is the only thing blocking B. A is effectively satisfied (unrelated).
      final a = _trick(id: 1, tier: 5);
      final aPrime = _trick(id: 2, tier: 5, baseTricks: [1]);
      final p = _trick(id: 3, tier: 4);
      final b = _trick(id: 4, prereqs: [1, 3]); // requires both A and P
      // A is effectively landed, P is the only blocker for B.
      // So P should be a high-value target (landing P unlocks B).

      final result = ProgressionService.computeWhatsNext(
        [_landed(aPrime.id)],
        [a, aPrime, p, b],
      );
      expect(result.highValue.map((hv) => hv.trick.id), contains(p.id));
    });
  });
}
