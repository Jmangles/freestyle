import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/utils/trick_progression_graph.dart';

void main() {
  // Edges: (prereqId, trickId) — i.e. prereqId → trickId
  //
  // Graph used in most tests:
  //   1 → 2 → 4
  //       2 → 5
  //   1 → 3
  const edges = [
    (1, 2),
    (1, 3),
    (2, 4),
    (2, 5),
  ];

  group('computeRelevantIds', () {
    test('always includes the focal node itself', () {
      expect(computeRelevantIds([], 99), equals({99}));
    });

    test('includes direct ancestors', () {
      final ids = computeRelevantIds(edges, 2);
      expect(ids, contains(1)); // 1 → 2
    });

    test('includes transitive ancestors', () {
      // 1 → 2 → 4, so hovering 4 should include 1
      final ids = computeRelevantIds(edges, 4);
      expect(ids, containsAll([1, 2, 4]));
    });

    test('includes direct descendants', () {
      final ids = computeRelevantIds(edges, 2);
      expect(ids, containsAll([4, 5])); // 2 → 4, 2 → 5
    });

    test('does not include unrelated nodes', () {
      // Hovering node 3 (child of 1, no further connections).
      // Node 2, 4, 5 are unrelated to 3 except through their shared ancestor 1.
      final ids = computeRelevantIds(edges, 3);
      expect(ids, containsAll([1, 3])); // ancestor 1 and self
      expect(ids, isNot(containsAll([4, 5]))); // 4 and 5 are not descendants of 3
    });

    test('isolated node returns only itself', () {
      final ids = computeRelevantIds(edges, 99);
      expect(ids, equals({99}));
    });

    test('works with an empty edge list', () {
      expect(computeRelevantIds([], 1), equals({1}));
    });

    test('includes all nodes in a linear chain when focal is the middle', () {
      // Chain: 1 → 2 → 3
      final chain = [(1, 2), (2, 3)];
      final ids = computeRelevantIds(chain, 2);
      expect(ids, equals({1, 2, 3}));
    });
  });
}
