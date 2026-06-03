import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/trick_annotation.dart';
import '../utils/date_formatters.dart';

const _kLanguages = [
  ('en', 'English'),
  ('es', 'Spanish'),
  ('fr', 'French'),
  ('de', 'German'),
  ('pt', 'Portuguese'),
  ('it', 'Italian'),
  ('ja', 'Japanese'),
  ('zh', 'Chinese'),
];

/// Shows the annotations management bottom sheet.
/// [onAnnotationTap] is called when the user taps an annotation row to seek to it.
/// [onAddTapped] is called when the user taps the Add button (after the sheet closes).
/// [onEditTapped] is called when the user taps edit on a row (after the sheet closes).
/// [onDeleteAnnotation] is called when the user confirms deletion; returning false
/// from the future leaves the sheet open, returning true removes the annotation.
void showAnnotationsSheet(
  BuildContext context, {
  required List<TrickAnnotation> annotations,
  required Duration currentPosition,
  required void Function(TrickAnnotation) onAnnotationTap,
  required VoidCallback onAddTapped,
  required void Function(TrickAnnotation) onEditTapped,
  required Future<bool> Function(TrickAnnotation) onDeleteAnnotation,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(context.l10n.annotationsTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n
                      .addAtTime(formatDuration(currentPosition))),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onAddTapped();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (annotations.isEmpty)
            Expanded(
                child: Center(child: Text(context.l10n.noAnnotationsYet)))
          else
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: annotations.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final a = annotations[i];
                  return ListTile(
                    title: Text(a.text),
                    subtitle: Text(
                      '${formatDuration(Duration(milliseconds: a.startMs))} – '
                      '${formatDuration(Duration(milliseconds: a.endMs))}',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAnnotationTap(a);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.pop(ctx);
                            onEditTapped(a);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final ok = await onDeleteAnnotation(a);
                            if (ok && ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

/// Shows the add/edit annotation form dialog.
/// Returns a tuple (startMs, endMs, text, language) on save, or null on cancel.
Future<(int, int, String, String)?> showAnnotationFormDialog(
  BuildContext context, {
  required int startMs,
  required int endMs,
  required String text,
  required String language,
}) {
  final textCtrl = TextEditingController(text: text);
  final startCtrl = TextEditingController(text: (startMs / 1000).toStringAsFixed(2));
  final endCtrl = TextEditingController(text: (endMs / 1000).toStringAsFixed(2));
  String selectedLanguage = _kLanguages.any((l) => l.$1 == language) ? language : 'en';

  return showDialog<(int, int, String, String)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(text.isEmpty
            ? context.l10n.addAnnotationTitle
            : context.l10n.editAnnotationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textCtrl,
              decoration: InputDecoration(
                  labelText: context.l10n.annotationTextLabel,
                  border: const OutlineInputBorder()),
              autofocus: true,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    decoration: InputDecoration(
                        labelText: context.l10n.annotationStartLabel,
                        border: const OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    decoration: InputDecoration(
                        labelText: context.l10n.annotationEndLabel,
                        border: const OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedLanguage,
              decoration: InputDecoration(
                  labelText: context.l10n.annotationLanguageLabel,
                  border: const OutlineInputBorder()),
              items: _kLanguages
                  .map((l) => DropdownMenuItem(value: l.$1, child: Text(l.$2)))
                  .toList(),
              onChanged: (v) =>
                  setDialogState(() => selectedLanguage = v ?? 'en'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () {
              final t = textCtrl.text.trim();
              if (t.isEmpty) return;
              final s = ((double.tryParse(startCtrl.text) ?? 0) * 1000).round();
              final e = ((double.tryParse(endCtrl.text) ?? 0) * 1000).round();
              if (s < 0 || e <= s) return;
              Navigator.pop(ctx, (s, e, t, selectedLanguage));
            },
            child: Text(context.l10n.saveButton),
          ),
        ],
      ),
    ),
  );
}

/// Prompts the user to confirm saving/downloading when storage is low.
/// Returns true if the user wants to continue, false if they cancelled.
Future<bool> showStorageWarning(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.lowStorageTitle),
          content: Text(context.l10n.lowStorageMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.continueButton),
            ),
          ],
        ),
      ) ??
      false;
}

/// Prompts the user to confirm deleting the saved video from their device.
/// Returns true if confirmed, false/null if cancelled.
Future<bool?> showDeleteVideoDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.removeFromDevice),
      content: Text(context.l10n.deleteVideoMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.cancelButton),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.deleteButton),
        ),
      ],
    ),
  );
}
