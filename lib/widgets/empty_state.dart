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
            // Bound BOTH dimensions: with only a height set, SvgPicture's
            // width collapses to 0 under the Column's loose constraints and
            // nothing paints. BoxFit.contain keeps the art's aspect ratio.
            SizedBox(
              height: illustrationHeight,
              width: illustrationHeight,
              child: SvgPicture.asset(
                asset,
                fit: BoxFit.contain,
                semanticsLabel: message,
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
