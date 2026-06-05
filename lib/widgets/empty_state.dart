import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Centered illustration + message used when something the user expected to
/// see isn't there (empty list, no search matches, missing page).
///
/// Pass [action] to offer a way out (e.g. a "Go home" button on a 404).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.asset,
    required this.message,
    this.illustrationHeight = 250,
    this.action,
  });

  /// Path to an SVG illustration under `assets/img/`.
  final String asset;
  final double illustrationHeight;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: illustrationHeight,
              width: illustrationHeight,
              child: SvgPicture.asset(
                asset,
                fit: BoxFit.contain,
                semanticsLabel: message,
                colorMapper: _EmptyStateColorMapper(
                  outline: Theme.of(context).colorScheme.onSurface,
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Remaps the illustrations' two hard-coded source colors to theme colors.
@immutable
class _EmptyStateColorMapper extends ColorMapper {
  const _EmptyStateColorMapper({required this.outline, required this.accent});

  /// Outline slot — pure green (#00FF00) in the source SVGs.
  static const Color _sourceOutline = Color(0xFF00FF00);

  /// Accent slot — pure magenta (#FF00FF) in the source SVGs.
  static const Color _sourceAccent = Color(0xFFFF00FF);

  final Color outline;
  final Color accent;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == _sourceOutline) return outline;
    if (color == _sourceAccent) return accent;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is _EmptyStateColorMapper &&
      other.outline == outline &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(outline, accent);
}
