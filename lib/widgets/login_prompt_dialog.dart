import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';

/// Popup telling a logged-out user to log in, with a login-icon button that
/// leads to the login page and an X in the top-right corner.
Future<void> showLoginPromptDialog(BuildContext context, String message) {
  final l10n = context.l10n;
  final router = GoRouter.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(message),
              ),
              const SizedBox(height: 20),
              Center(
                child: IconButton.filled(
                  icon: const Icon(Icons.login),
                  tooltip: l10n.signInTooltip,
                  style: IconButton.styleFrom(minimumSize: const Size(120, 44)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    router.push('/login');
                  },
                ),
              ),
            ],
          ),
          Positioned(
            top: -12,
            right: -12,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.closeButton,
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}
