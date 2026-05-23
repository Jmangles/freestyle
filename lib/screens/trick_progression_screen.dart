import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/trick.dart';
import '../widgets/back_home_leading.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../utils/difficulty_tier.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class _GraphData {
  final int focalId;
  final Map<int, Trick> tricks;
  final Map<int, int> layers;     // trickId → layer (0 = focal, neg = prereqs, pos = unlocks)
  final List<(int, int)> edges;   // (prereqId, trickId)
  final Map<int, UserTrick> userProgress;

  const _GraphData({
    required this.focalId,
    required this.tricks,
    required this.layers,
    required this.edges,
    required this.userProgress,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class TrickProgressionScreen extends StatefulWidget {
  final int trickId;

  const TrickProgressionScreen({super.key, required this.trickId});

  @override
  State<TrickProgressionScreen> createState() => _TrickProgressionScreenState();
}

class _TrickProgressionScreenState extends State<TrickProgressionScreen> {
  late Future<_GraphData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_GraphData> _load() async {
    const maxPrereqDepth = 4;
    const maxUnlockDepth = 3;

    final focal = await TricksService.getTrickById(widget.trickId);
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

    return _GraphData(
      focalId: focal.id,
      tricks: tricks,
      layers: layers,
      edges: edges,
      userProgress: userProgress,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 96,
        leading: const BackHomeLeading(showHome: true),
        title: Text(context.l10n.trickProgressionTitle),
      ),
      body: FutureBuilder<_GraphData>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(context.l10n.errorWithDetail(snap.error.toString())));
          }
          return _GraphView(data: snap.data!);
        },
      ),
    );
  }
}

// ─── Graph view ──────────────────────────────────────────────────────────────

class _GraphView extends StatefulWidget {
  final _GraphData data;

  const _GraphView({required this.data});

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _fadeController;
  late final Animation<double> _dimAnim;
  bool _initialTransformSet = false;
  int? _hoveredId;
  int _hoverGeneration = 0;
  Set<int>? _relevantIds;

  static const double _cardW = 150;
  static const double _cardH = 58;
  static const double _hGap = 20;
  static const double _vGap = 72;
  static const double _pad = 48;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _dimAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onHoverStart(int id) {
    _hoverGeneration++;
    if (_hoveredId != id) {
      setState(() {
        _hoveredId = id;
        _relevantIds = _computeRelevantIds(id);
      });
    }
    _fadeController.forward();
  }

  void _onHoverEnd() {
    final gen = ++_hoverGeneration;
    _fadeController.reverse().then((_) {
      if (mounted && _hoverGeneration == gen) {
        setState(() {
          _hoveredId = null;
          _relevantIds = null;
        });
      }
    });
  }

  Set<int> _computeRelevantIds(int id) {
    final ids = <int>{id};

    // BFS upward through all prerequisites
    var frontier = <int>{id};
    while (frontier.isNotEmpty) {
      final next = <int>{};
      for (final (pid, tid) in widget.data.edges) {
        if (frontier.contains(tid) && ids.add(pid)) next.add(pid);
      }
      frontier = next;
    }

    // BFS downward through all unlocks
    frontier = {id};
    while (frontier.isNotEmpty) {
      final next = <int>{};
      for (final (pid, tid) in widget.data.edges) {
        if (frontier.contains(pid) && ids.add(tid)) next.add(tid);
      }
      frontier = next;
    }

    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;

    if (data.tricks.length <= 1 && data.edges.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(data.tricks[data.focalId]!.givenName,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(context.l10n.noPrerequisitesFound,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Group tricks by layer
    final byLayer = <int, List<int>>{};
    for (final entry in data.layers.entries) {
      byLayer.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final sortedLayers = byLayer.keys.toList()..sort();
    final minLayer = sortedLayers.first;
    final maxLayer = sortedLayers.last;

    final maxCount = byLayer.values.map((l) => l.length).reduce(math.max);
    final canvasW =
        math.max(maxCount * (_cardW + _hGap) - _hGap + _pad * 2, 300.0);
    final canvasH =
        (maxLayer - minLayer + 1) * (_cardH + _vGap) - _vGap + _pad * 2;

    // Barycenter layout: sort each layer by the average x-position of its
    // already-positioned neighbors, processing outward from the focal node.
    // This minimises edge crossings compared to plain alphabetical ordering.
    final xCenters = <int, double>{};

    double barycenter(int id) {
      final xs = <double>[];
      for (final (pid, tid) in data.edges) {
        if (pid == id) { final x = xCenters[tid]; if (x != null) xs.add(x); }
        if (tid == id) { final x = xCenters[pid]; if (x != null) xs.add(x); }
      }
      return xs.isEmpty
          ? double.infinity
          : xs.reduce((a, b) => a + b) / xs.length;
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
      final rowW = ids.length * _cardW + (ids.length - 1) * _hGap;
      final startX = (canvasW - rowW) / 2;
      for (int i = 0; i < ids.length; i++) {
        xCenters[ids[i]] = startX + i * (_cardW + _hGap) + _cardW / 2;
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
        xCenters[id]! - _cardW / 2,
        (layer - minLayer) * (_cardH + _vGap) + _pad,
      );
    }

    final isMobile = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fitScale = math.min(
                math.min(
                  constraints.maxWidth / canvasW,
                  constraints.maxHeight / canvasH,
                ),
                1.0,
              );

              if (!_initialTransformSet) {
                _initialTransformSet = true;
                final dx = (constraints.maxWidth - canvasW * fitScale) / 2;
                final dy = (constraints.maxHeight - canvasH * fitScale) / 2;
                _transformController.value =
                    Matrix4.translationValues(dx, dy, 0)..scaleByDouble(fitScale, fitScale, fitScale, 1.0);
              }

              return InteractiveViewer(
                constrained: false,
                boundaryMargin: EdgeInsets.all(double.infinity),
                minScale: fitScale,
                maxScale: 2.5,
                scaleFactor: 600,
                transformationController: _transformController,
                child: SizedBox(
                  width: canvasW,
                  height: canvasH,
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _dimAnim,
                        builder: (context, _) => CustomPaint(
                          size: Size(canvasW, canvasH),
                          painter: _EdgePainter(
                            edges: data.edges,
                            positions: positions,
                            cardW: _cardW,
                            cardH: _cardH,
                            color: theme.colorScheme.outlineVariant,
                            highlightedIds: _relevantIds,
                            dimFactor: _dimAnim.value,
                          ),
                        ),
                      ),
                      for (final entry in positions.entries)
                        Positioned(
                          left: entry.value.dx,
                          top: entry.value.dy,
                          width: _cardW,
                          height: _cardH,
                          child: MouseRegion(
                            onEnter: (_) => _onHoverStart(entry.key),
                            onExit: (_) => _onHoverEnd(),
                            child: AnimatedBuilder(
                              animation: _dimAnim,
                              builder: (context, child) {
                                final isRelevant = _relevantIds == null ||
                                    _relevantIds!.contains(entry.key);
                                final opacity = isRelevant
                                    ? 1.0
                                    : 1.0 - _dimAnim.value * 0.85;
                                return Opacity(opacity: opacity, child: child);
                              },
                              child: _TrickCard(
                                trick: data.tricks[entry.key]!,
                                isFocal: entry.key == data.focalId,
                                userTrick: data.userProgress[entry.key],
                                onTap: isMobile
                                    ? () {
                                        if (_hoveredId == entry.key) {
                                          if (entry.key != data.focalId) {
                                            context.push('/trick/${entry.key}');
                                          } else {
                                            _onHoverEnd();
                                          }
                                        } else {
                                          _onHoverStart(entry.key);
                                        }
                                      }
                                    : entry.key == data.focalId
                                        ? null
                                        : () => context.push('/trick/${entry.key}'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _Legend(showProgress: data.userProgress.isNotEmpty),
      ],
    );
  }
}

// ─── Edge painter ─────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  final List<(int, int)> edges;
  final Map<int, Offset> positions;
  final double cardW;
  final double cardH;
  final Color color;
  final Set<int>? highlightedIds;
  final double dimFactor;

  const _EdgePainter({
    required this.edges,
    required this.positions,
    required this.cardW,
    required this.cardH,
    required this.color,
    required this.highlightedIds,
    required this.dimFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final (pid, tid) in edges) {
      final from = positions[pid];
      final to = positions[tid];
      if (from == null || to == null) continue;

      final isHighlighted = highlightedIds == null ||
          (highlightedIds!.contains(pid) && highlightedIds!.contains(tid));
      final opacity = isHighlighted ? 1.0 : 1.0 - dimFactor * 0.85;
      final edgeColor = color.withValues(alpha: opacity);

      final linePaint = Paint()
        ..color = edgeColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      final fillPaint = Paint()
        ..color = edgeColor
        ..style = PaintingStyle.fill;

      final start = Offset(from.dx + cardW / 2, from.dy + cardH);
      final end = Offset(to.dx + cardW / 2, to.dy);
      final midY = (start.dy + end.dy) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
      canvas.drawPath(path, linePaint);

      _drawArrowHead(canvas, fillPaint, end);
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset tip) {
    // Arrow pointing downward (direction of travel = into the card from above)
    const size = 7.0;
    const angle = math.pi / 2; // pointing down
    final p1 = Offset(
      tip.dx - size * math.cos(angle - math.pi / 6),
      tip.dy - size * math.sin(angle - math.pi / 6),
    );
    final p2 = Offset(
      tip.dx - size * math.cos(angle + math.pi / 6),
      tip.dy - size * math.sin(angle + math.pi / 6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges ||
      old.positions != positions ||
      old.color != color ||
      old.highlightedIds != highlightedIds ||
      old.dimFactor != dimFactor;
}

// ─── Trick card ───────────────────────────────────────────────────────────────

class _TrickCard extends StatelessWidget {
  final Trick trick;
  final bool isFocal;
  final UserTrick? userTrick;
  final VoidCallback? onTap;

  const _TrickCard({
    required this.trick,
    required this.isFocal,
    this.userTrick,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DifficultyTier.badgeColors(trick.difficultyTier);
    final isLanded = userTrick?.consistency.isLanded ?? false;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isFocal) {
      bgColor = theme.colorScheme.primaryContainer;
      borderColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimaryContainer;
    } else if (isLanded) {
      bgColor = theme.colorScheme.tertiaryContainer;
      borderColor = theme.colorScheme.tertiary;
      textColor = theme.colorScheme.onTertiaryContainer;
    } else {
      bgColor = theme.colorScheme.surface;
      borderColor = theme.colorScheme.outlineVariant;
      textColor = theme.colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isFocal ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLanded && !isFocal) ...[
                  Icon(Icons.check_circle,
                      size: 12, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    trick.givenName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight:
                          isFocal ? FontWeight.bold : FontWeight.w500,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (colors != null) ...[
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.$1,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trick.difficultyLabel,
                  style: TextStyle(
                    color: colors.$2,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final bool showProgress;

  const _Legend({required this.showProgress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _LegendItem(
            color: theme.colorScheme.primaryContainer,
            borderColor: theme.colorScheme.primary,
            label: context.l10n.thisTrickLegend,
          ),
          if (showProgress)
            _LegendItem(
              color: theme.colorScheme.tertiaryContainer,
              borderColor: theme.colorScheme.tertiary,
              label: context.l10n.youveLandedThisLegend,
              icon: Icons.check_circle,
              iconColor: theme.colorScheme.tertiary,
            ),
          _LegendItem(
            color: theme.colorScheme.surface,
            borderColor: theme.colorScheme.outlineVariant,
            label: context.l10n.notYetLandedLegend,
          ),
          Text(context.l10n.pinchToZoom,
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: icon != null
              ? Icon(icon, size: 9, color: iconColor)
              : null,
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
