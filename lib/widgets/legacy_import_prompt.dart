import 'package:flutter/material.dart';

import '../l10n/app_localizations_extension.dart';
import '../models/legacy_import.dart';
import '../services/auth_service.dart';
import '../services/legacy_import_service.dart';

// Runs the import and reports the outcome; returns true when the legacy data
// has been dealt with and the prompt should disappear.
Future<bool> runLegacyImport(BuildContext context, LegacyScan scan) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final result = await LegacyImportService.import(scan);
    messenger.showSnackBar(SnackBar(
      content: Text(result.written > 0
          ? l10n.legacyImportSucceeded(result.written)
          : l10n.legacyImportNothingNew),
    ));
    return true;
  } catch (e, st) {
    debugPrint('runLegacyImport: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text(l10n.legacyImportFailed)));
    return false;
  }
}

Future<bool> showLegacyImportDialog(BuildContext context, LegacyScan scan) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.legacyImportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.legacyImportFound(scan.importable)),
          if (scan.untransferable > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.legacyImportUntransferable(scan.untransferable),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!AuthService.isLoggedIn) ...[
            const SizedBox(height: 12),
            Text(l10n.legacyImportSignInHint),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.legacyImportLaterButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(AuthService.isLoggedIn
              ? l10n.legacyImportButton
              : l10n.legacyImportSignInButton),
        ),
      ],
    ),
  );
  return result ?? false;
}

// Entry point for anyone who dismissed the banner: stays available until the
// legacy data has actually been imported.
class LegacyImportCard extends StatefulWidget {
  const LegacyImportCard({super.key, this.onImported});

  final VoidCallback? onImported;

  @override
  State<LegacyImportCard> createState() => _LegacyImportCardState();
}

class _LegacyImportCardState extends State<LegacyImportCard> {
  LegacyScan? _scan;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    LegacyImportService.scan().then((scan) {
      if (mounted) setState(() => _scan = scan);
    });
  }

  Future<void> _import() async {
    setState(() => _running = true);
    final imported = await runLegacyImport(context, _scan!);
    if (!mounted) return;
    setState(() {
      _running = false;
      if (imported) _scan = null;
    });
    if (imported) widget.onImported?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    if (scan == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(l10n.legacyImportTitle),
        subtitle: Text(l10n.legacyImportFound(scan.importable)),
        trailing: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton(
                onPressed: _import,
                child: Text(l10n.legacyImportButton),
              ),
      ),
    );
  }
}

class LegacyImportBanner extends StatelessWidget {
  const LegacyImportBanner({
    super.key,
    required this.scan,
    required this.busy,
    required this.onImport,
    required this.onDismiss,
  });

  final LegacyScan scan;
  final bool busy;
  final VoidCallback onImport;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final onColor = theme.colorScheme.onSecondaryContainer;
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.legacyImportBanner(scan.importable),
                    style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
                  ),
                  // Signed-out users are the ones who still have everything to
                  // lose: the data exists only in this browser until it is
                  // attached to an account.
                  if (!AuthService.isLoggedIn)
                    Text(
                      l10n.legacyImportSignInHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onColor.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              FilledButton(
                onPressed: onImport,
                child: Text(AuthService.isLoggedIn
                    ? l10n.legacyImportButton
                    : l10n.legacyImportSignInButton),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                tooltip: l10n.legacyImportLaterButton,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
