import 'dart:math' as math;
import 'dart:ui' show Offset;
import '../models/trick.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';

class TrickProgressionGraphData {
  final int focalId;
  final Map<int, Trick> tricks;
  final Map<int, int> layers;     // trickId → layer (0 = focal, neg = prereqs, pos = unlocks)
  final List<(int, int)> edges;   // (prereqId, trickId)
  final Map<int, UserTrick> userProgress;

  const TrickProgressionGraphData({
    required this.focalId,
    required this.tricks,
    required this.layers,
    required this.edges,
    required this.userProgress,
  });
}

Future<TrickProgressionGraphData> loadTrickProgressionGraph(int trickId) async {
  const maxPrereqDepth = 4;
  const maxUnlockDepth = 3;

  final focal = await TricksService.getTrickById(trickId);
  final Map<int, Trick> tricks = {focal.id: focal};

  // BFS upward through prerequisites
  Set<int> frontier = {focal.id};
  for (int d = 0; d < maxPrereqDepth && frontier.isNotEmpty; d++) {
    final next = <int>{};
    for (final id in frontier) {
      for (final pid in tricks[id]!.prerequisiteTrickIds) {
        if (!tricks.containsKey(pid)) next.add(pid);
      }
    }
    if (next.isNotEmpty) {
      final fetched = await TricksService.getTricksByIds(next.toList());
      for (final t in fetched) { tricks[t.id] = t; }
    }
    frontier = next;
  }

  // BFS downward through unlocks
  frontier = {focal.id};
  for (int d = 0; d < maxUnlockDepth && frontier.isNotEmpty; d++) {
    final next = <int>{};
    for (final id in frontier) {
      final unlocked = await TricksService.getTricksRequiring(id);
      for (final t in unlocked) {
        if (!tricks.containsKey(t.id)) {
          tricks[t.id] = t;
          next.add(t.id);
        }
      }
    }
    frontier = next;
  }

  // Build edge list within the graph
  final edges = <(int, int)>[];
  for (final trick in tricks.values) {
    for (final pid in trick.prerequisiteTrickIds) {
      if (tricks.containsKey(pid)) edges.add((pid, trick.id));
    }
  }

  // Build reverse map for downward layer assignment
  final Map<int, List<int>> unlockMap = {};
  for (final (pid, tid) in edges) {
    unlockMap.putIfAbsent(pid, () => []).add(tid);
  }

  // Assign layers via BFS from focal
  final layers = <int, int>{focal.id: 0};

  // Upward: prereqs get lower layers
  final upQueue = [focal.id];
  while (upQueue.isNotEmpty) {
    final id = upQueue.removeAt(0);
    for (final pid in tricks[id]!.prerequisiteTrickIds) {
      if (!tricks.containsKey(pid)) continue;
      final nl = layers[id]! - 1;
      if (!layers.containsKey(pid) || layers[pid]! > nl) {
        layers[pid] = nl;
        upQueue.add(pid);
      }
    }
  }

  // Downward: unlocks get higher layers
  final downQueue = [focal.id];
  while (downQueue.isNotEmpty) {
    final id = downQueue.removeAt(0);
    for (final uid in unlockMap[id] ?? <int>[]) {
      final nl = layers[id]! + 1;
      if (!layers.containsKey(uid) || layers[uid]! < nl) {
        layers[uid] = nl;
        downQueue.add(uid);
      }
    }
  }

  final userProgress = AuthService.isLoggedIn
      ? await UserTricksService.getUserTricksForTrickIds(tricks.keys.toList())
      : <int, UserTrick>{};

  return TrickProgressionGraphData(
    focalId: focal.id,
    tricks: tricks,
    layers: layers,
    edges: edges,
    userProgress: userProgress,
  );
}

/// Returns the set of IDs connected to [id] through the graph (ancestors + descendants).
Set<int> computeRelevantIds(List<(int, int)> edges, int id) {
  final ids = <int>{id};

  // BFS upward through all prerequisites
  var frontier = <int>{id};
  while (frontier.isNotEmpty) {
    final next = <int>{};
    for (final (pid, tid) in edges) {
      if (frontier.contains(tid) && ids.add(pid)) next.add(pid);
    }
    frontier = next;
  }

  // BFS downward through all unlocks
  frontier = {id};
  while (frontier.isNotEmpty) {
    final next = <int>{};
    for (final (pid, tid) in edges) {
      if (frontier.contains(pid) && ids.add(tid)) next.add(tid);
    }
    frontier = next;
  }

  return ids;
}

class TrickProgressionLayout {
  final Map<int, Offset> positions;
  final double canvasW;
  final double canvasH;

  const TrickProgressionLayout({
    required this.positions,
    required this.canvasW,
    required this.canvasH,
  });
}

/// Computes node positions using barycenter heuristic to minimise edge crossings.
TrickProgressionLayout computeGraphLayout(
  TrickProgressionGraphData data, {
  required double cardW,
  required double cardH,
  required double hGap,
  required double vGap,
  required double pad,
}) {
  final byLayer = <int, List<int>>{};
  for (final entry in data.layers.entries) {
    byLayer.putIfAbsent(entry.value, () => []).add(entry.key);
  }

  final sortedLayers = byLayer.keys.toList()..sort();
  final minLayer = sortedLayers.first;
  final maxLayer = sortedLayers.last;

  final maxCount = byLayer.values.map((l) => l.length).reduce(math.max);
  final canvasW = math.max(maxCount * (cardW + hGap) - hGap + pad * 2, 300.0);
  final canvasH = (maxLayer - minLayer + 1) * (cardH + vGap) - vGap + pad * 2;

  final xCenters = <int, double>{};

  double barycenter(int id) {
    final xs = <double>[];
    for (final (pid, tid) in data.edges) {
      if (pid == id) { final x = xCenters[tid]; if (x != null) xs.add(x); }
      if (tid == id) { final x = xCenters[pid]; if (x != null) xs.add(x); }
    }
    return xs.isEmpty ? double.infinity : xs.reduce((a, b) => a + b) / xs.length;
  }

  void sortAndRecord(List<int> ids) {
    ids.sort((a, b) {
      if (a == data.focalId) return -1;
      if (b == data.focalId) return 1;
      final cmp = barycenter(a).compareTo(barycenter(b));
      return cmp != 0
          ? cmp
          : data.tricks[a]!.givenName.compareTo(data.tricks[b]!.givenName);
    });
    final rowW = ids.length * cardW + (ids.length - 1) * hGap;
    final startX = (canvasW - rowW) / 2;
    for (int i = 0; i < ids.length; i++) {
      xCenters[ids[i]] = startX + i * (cardW + hGap) + cardW / 2;
    }
  }

  sortAndRecord(byLayer[0]!);
  for (int L = 1; L <= maxLayer; L++) {
    if (byLayer.containsKey(L)) sortAndRecord(byLayer[L]!);
  }
  for (int L = -1; L >= minLayer; L--) {
    if (byLayer.containsKey(L)) sortAndRecord(byLayer[L]!);
  }

  final positions = <int, Offset>{};
  for (final id in data.tricks.keys) {
    final layer = data.layers[id]!;
    positions[id] = Offset(
      xCenters[id]! - cardW / 2,
      (layer - minLayer) * (cardH + vGap) + pad,
    );
  }

  return TrickProgressionLayout(
    positions: positions,
    canvasW: canvasW,
    canvasH: canvasH,
  );
}
