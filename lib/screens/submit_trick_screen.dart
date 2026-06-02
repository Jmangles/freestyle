import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../utils/safe_state.dart';
import '../models/approval_status.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/position.dart';
import '../services/tricks_service.dart';
import '../utils/date_formatters.dart';
import 'trick_form_controller.dart';

class SubmitTrickScreen extends StatefulWidget {
  /// When provided, operates in admin-edit mode instead of submission mode.
  final Trick? existingTrick;

  /// When provided, operates in suggestion mode: form pre-fills from this
  /// trick and submitting creates a trick_suggestion rather than editing.
  final Trick? suggestionForTrick;

  const SubmitTrickScreen({super.key, this.existingTrick, this.suggestionForTrick});

  @override
  State<SubmitTrickScreen> createState() => _SubmitTrickScreenState();
}

class _SubmitTrickScreenState extends State<SubmitTrickScreen>
    with SafeStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late final TrickFormController _form;
  late Future<SubmitMeta> _metaFuture;
  late final VoidCallback _nameListener;

  bool get _isEditing => widget.existingTrick != null;
  bool get _isSuggesting => widget.suggestionForTrick != null;

  @override
  void initState() {
    super.initState();
    _form = TrickFormController.fromTrick(
        widget.existingTrick ?? widget.suggestionForTrick);
    if (widget.existingTrick != null) _form.isCore = widget.existingTrick!.isCore;
    _metaFuture = _loadMeta();
    _nameListener = () => setState(() {});
    _form.givenName.addListener(_nameListener);
    _form.technicalName.addListener(_nameListener);
  }

  Future<SubmitMeta> _loadMeta() async {
    final positions = await TricksService.getPositions();
    final tricks = await TricksService.getApprovedTricks();
    return SubmitMeta(positions: positions, tricks: tricks);
  }

  @override
  void dispose() {
    _form.givenName.removeListener(_nameListener);
    _form.technicalName.removeListener(_nameListener);
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEditing) {
        await TricksService.updateTrick(widget.existingTrick!.id, _form.formFields);
      } else if (_isSuggesting) {
        final delta = _form.computeSuggestionDelta(widget.suggestionForTrick!);
        if (delta.isEmpty) {
          showInfoSnackBar(context.l10n.suggestionNoChanges);
          setState(() => _loading = false);
          return;
        }
        await TricksService.submitTrickSuggestion(
          trickId: widget.suggestionForTrick!.id,
          fields: delta,
        );
      } else {
        final trick = Trick(
          id: 0,
          givenName: _form.givenName.text.trim(),
          technicalName: _form.formFields['technical_name'] as String?,
          difficultyTier: _form.difficultyTier,
          dateSubmitted: DateTime.now(),
          datePerformed: _form.datePerformed,
          originalPerformer: _form.formFields['original_performer'] as String?,
          prerequisiteTrickIds: _form.prerequisiteIds,
          description: _form.formFields['description'] as String?,
          tips: _form.formFields['tips'] as String?,
          videoLink: _form.formFields['video_link'] as String?,
          videoStart: _form.formFields['video_start'] as int?,
          videoEnd: _form.formFields['video_end'] as int?,
          startPositionId: _form.startPositionId,
          endPositionId: _form.endPositionId,
          status: ApprovalStatus.pending,
        );
        await TricksService.submitTrick(trick);
      }
      if (mounted) {
        showInfoSnackBar(_isEditing
            ? context.l10n.trickUpdated
            : _isSuggesting
                ? context.l10n.suggestionSubmittedForReview
                : context.l10n.trickSubmittedForReview);
        context.pop();
      }
    } catch (e) {
      showErrorSnackBar(e.toString());
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
          ? l10n.editTrickTitle
          : _isSuggesting
              ? l10n.suggestEditTitle
              : l10n.submitTrickTitle),
      ),
      body: FutureBuilder<SubmitMeta>(
        future: _metaFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final positions = snap.data?.positions ?? [];
          final allTricks = snap.data?.tricks ?? [];
          return _buildForm(context, positions, allTricks);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Position> positions, List<Trick> allTricks) {
    final l10n = context.l10n;
    final sortedPositions = [...positions]..sort((a, b) => a.name.compareTo(b.name));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, _form.givenName, l10n.givenNameLabel, required: true),
            const SizedBox(height: 12),
            _field(context, _form.technicalName, l10n.technicalNameLabel),
            if (!_isEditing) _SimilarTricksWarning(
              givenQuery: _form.givenName.text.trim(),
              technicalQuery: _form.technicalName.text.trim(),
              allTricks: allTricks,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _form.difficultyTier,
              decoration: InputDecoration(
                labelText: l10n.difficultyRequiredLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: -1, child: Text(l10n.tbdOption)),
                for (int v = 1; v <= 30; v++)
                  DropdownMenuItem(value: v, child: Text(Trick.tierLabel(v))),
              ],
              onChanged: (v) => setState(() => _form.difficultyTier = v!),
              validator: (v) => v == null ? l10n.requiredValidator : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _form.startPositionId,
              decoration: InputDecoration(
                  labelText: l10n.startPositionRequiredLabel,
                  border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noneOption)),
                ...sortedPositions.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _form.startPositionId = v),
              validator: (v) => v == null ? l10n.requiredValidator : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _form.endPositionId,
              decoration: InputDecoration(
                  labelText: l10n.endPositionRequiredLabel,
                  border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noneOption)),
                ...sortedPositions.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _form.endPositionId = v),
              validator: (v) => v == null ? l10n.requiredValidator : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_form.datePerformed == null
                  ? l10n.dateFirstPerformedOptional
                  : l10n.dateFirstPerformedWithDate(formatDisplayDate(_form.datePerformed!))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_form.datePerformed != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _form.datePerformed = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _field(context, _form.originalPerformer, l10n.originalPerformerLabel),
            const SizedBox(height: 12),
            _PrerequisiteSelector(
              allTricks: allTricks
                  .where((t) =>
                      !_isEditing || t.id != widget.existingTrick!.id)
                  .toList(),
              selectedIds: _form.prerequisiteIds,
              onChanged: (ids) => setState(() => _form.prerequisiteIds = ids),
            ),
            const SizedBox(height: 12),
            _field(context, _form.description, l10n.descriptionLabel, maxLines: 4),
            const SizedBox(height: 12),
            _field(context, _form.tips, l10n.tipsLabel, maxLines: 4),
            const SizedBox(height: 12),
            _field(context, _form.videoLink, l10n.videoLinkUrlLabel),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _form.videoStart,
                    decoration: InputDecoration(
                      labelText: l10n.loopStartLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _form.videoEnd,
                    decoration: InputDecoration(
                      labelText: l10n.loopEndLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_isEditing) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.coreTrickLabel),
                subtitle: Text(l10n.coreTrickSubtitle),
                value: _form.isCore,
                onChanged: (v) => setState(() => _form.isCore = v),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing
                      ? l10n.saveChangesButton
                      : _isSuggesting
                          ? l10n.suggestChangesButton
                          : l10n.submitForReviewButton),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _form.datePerformed ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _form.datePerformed = picked);
  }

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    final l10n = context.l10n;
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder()),
      maxLines: maxLines,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? l10n.requiredValidator : null
          : null,
    );
  }
}

class _SimilarTricksWarning extends StatelessWidget {
  final String givenQuery;
  final String technicalQuery;
  final List<Trick> allTricks;

  const _SimilarTricksWarning({
    required this.givenQuery,
    required this.technicalQuery,
    required this.allTricks,
  });

  bool _matches(Trick t, String q) {
    if (q.length < 3) return false;
    final given = t.givenName.toLowerCase();
    final technical = (t.technicalName ?? '').toLowerCase();
    return given.contains(q) || q.contains(given) ||
        (technical.isNotEmpty && (technical.contains(q) || q.contains(technical)));
  }

  List<Trick> get _matchedTricks {
    final gq = givenQuery.toLowerCase();
    final tq = technicalQuery.toLowerCase();
    final seen = <int>{};
    return allTricks.where((t) {
      if (!seen.add(t.id)) return false;
      return _matches(t, gq) || _matches(t, tq);
    }).take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matchedTricks;
    if (matches.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onSecondaryContainer),
                const SizedBox(width: 6),
                Text(
                  context.l10n.similarTricksWarning,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSecondaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final t in matches)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  t.technicalName != null ? '• ${t.givenName} - ${t.technicalName}' : '• ${t.givenName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrerequisiteSelector extends StatelessWidget {
  final List<Trick> allTricks;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;

  const _PrerequisiteSelector({
    required this.allTricks,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected =
        allTricks.where((t) => selectedIds.contains(t.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.prerequisitesLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addButton),
              onPressed: () => _showPicker(context),
            ),
          ],
        ),
        if (selected.isEmpty)
          Text(l10n.noneOption,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant))
        else
          Wrap(
            spacing: 8,
            children: selected
                .map((t) => Chip(
                      label: Text(t.givenName),
                      onDeleted: () {
                        final ids = List<int>.from(selectedIds)
                          ..remove(t.id);
                        onChanged(ids);
                      },
                    ))
                .toList(),
          ),
      ],
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final l10n = context.l10n;
    final available = allTricks
        .where((t) => !selectedIds.contains(t.id))
        .toList()
      ..sort((a, b) =>
          a.givenName.toLowerCase().compareTo(b.givenName.toLowerCase()));
    if (available.isEmpty) return;

    final searchCtrl = TextEditingController();
    final picked = await showDialog<Trick>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? available
              : available
                  .where((t) => t.givenName.toLowerCase().contains(query))
                  .toList();
          return AlertDialog(
            title: Text(l10n.selectPrerequisiteTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(filtered[i].givenName),
                        onTap: () => Navigator.pop(ctx, filtered[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancelButton),
              ),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
    if (picked != null) {
      onChanged([...selectedIds, picked.id]);
    }
  }
}
