import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the Highline Freestyle wordmark, swapping between the dark and
/// white SVG variants based on the current theme brightness.
///
/// Use [AppLogo.small] inside dense surfaces (e.g. an [AppBar]) and
/// [AppLogo.big] for prominent placements (e.g. the login screen header).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.variant = LogoVariant.big,
    this.height,
  });

  const AppLogo.big({super.key, this.height = 56})
      : variant = LogoVariant.big;

  const AppLogo.small({super.key, this.height = 32})
      : variant = LogoVariant.small;

  final LogoVariant variant;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = switch ((variant, isDark)) {
      (LogoVariant.big, false) => 'assets/logos/logo_big.svg',
      (LogoVariant.big, true) => 'assets/logos/logo_big_white.svg',
      (LogoVariant.small, false) => 'assets/logos/logo_small.svg',
      (LogoVariant.small, true) => 'assets/logos/logo_small_white.svg',
    };
    return SvgPicture.asset(
      asset,
      height: height,
      semanticsLabel: 'Highline Freestyle',
    );
  }
}

enum LogoVariant { big, small }
