import 'package:flutter/material.dart';
import '../models/trick_annotation.dart';
import '../utils/date_formatters.dart';

class AnnotationDotPainter extends CustomPainter {
  final List<TrickAnnotation> annotations;
  final int totalMs;
  final Color color;

  // Flutter's default RoundSliderOverlayShape has overlayRadius 12, which
  // becomes the horizontal inset of the track inside the Slider widget.
  static const double _trackPadding = 12.0;
  static const double _dotRadius = 4.0;

  const AnnotationDotPainter({
    required this.annotations,
    required this.totalMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMs == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final trackWidth = size.width - _trackPadding * 2;
    final centerY = size.height / 2;
    for (final a in annotations) {
      final x = (_trackPadding + a.startMs / totalMs * trackWidth)
          .clamp(_trackPadding, size.width - _trackPadding);
      canvas.drawCircle(Offset(x, centerY), _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(AnnotationDotPainter old) =>
      annotations != old.annotations || totalMs != old.totalMs;
}

class AnnotationSidebar extends StatefulWidget {
  final List<TrickAnnotation> annotations;
  final Duration position;
  final void Function(TrickAnnotation) onTap;

  const AnnotationSidebar({
    super.key,
    required this.annotations,
    required this.position,
    required this.onTap,
  });

  @override
  State<AnnotationSidebar> createState() => _AnnotationSidebarState();
}

class _AnnotationSidebarState extends State<AnnotationSidebar> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.annotations]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _expanded ? 288 : 43,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _expanded ? _buildExpanded(sorted) : _buildCollapsed(),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white54),
          iconSize: 24,
          padding: EdgeInsets.zero,
          tooltip: 'Show annotations',
          onPressed: () => setState(() => _expanded = true),
        ),
      ],
    );
  }

  Widget _buildExpanded(List<TrickAnnotation> sorted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 5, 5),
          child: Row(
            children: [
              const Text(
                'ANNOTATIONS',
                style: TextStyle(
                    color: Colors.white38, fontSize: 12, letterSpacing: 1.2),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white38),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Hide annotations',
                onPressed: () => setState(() => _expanded = false),
              ),
            ],
          ),
        ),
        Builder(builder: (context) {
          final activeId = sorted
              .where((a) => a.isActiveAt(widget.position))
              .fold<TrickAnnotation?>(
                null,
                (best, a) =>
                    best == null || a.startMs >= best.startMs ? a : best,
              )
              ?.id;
          return ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: sorted.length,
            separatorBuilder: (context, i) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, i) {
              final a = sorted[i];
              final isActive = a.id == activeId;
              return GestureDetector(
                onTap: () => widget.onTap(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.text,
                        style: TextStyle(
                          color: isActive ? Colors.black : Colors.white,
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDuration(Duration(milliseconds: a.startMs))} – ${formatDuration(Duration(milliseconds: a.endMs))}',
                        style: TextStyle(
                          color: isActive
                              ? Colors.black.withValues(alpha: 0.7)
                              : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class MobileAnnotationOverlay extends StatefulWidget {
  final List<TrickAnnotation> annotations;
  final Duration position;
  final void Function(TrickAnnotation) onTap;

  const MobileAnnotationOverlay({
    super.key,
    required this.annotations,
    required this.position,
    required this.onTap,
  });

  @override
  State<MobileAnnotationOverlay> createState() =>
      _MobileAnnotationOverlayState();
}

class _MobileAnnotationOverlayState extends State<MobileAnnotationOverlay> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.annotations]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _expanded ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          child: _expanded
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final a in sorted)
                        _AnnotationChip(
                          annotation: a,
                          isActive: a.isActiveAt(widget.position),
                          onTap: () => widget.onTap(a),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AnnotationChip extends StatelessWidget {
  final TrickAnnotation annotation;
  final bool isActive;
  final VoidCallback onTap;

  const _AnnotationChip({
    required this.annotation,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isActive ? Colors.black : Colors.white;
    final timeColor = isActive ? Colors.black54 : Colors.white38;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.92)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  annotation.text,
                  maxLines: isActive ? null : 2,
                  overflow:
                      isActive ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatDuration(Duration(milliseconds: annotation.startMs))} – ${formatDuration(Duration(milliseconds: annotation.endMs))}',
                  style: TextStyle(color: timeColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
