import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/approval_status.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/position.dart';
import '../services/tricks_service.dart';
import '../utils/date_formatters.dart';
import '../utils/string_utils.dart';

class SubmitTrickScreen extends StatefulWidget {
  /// When provided, operates in admin-edit mode instead of submission mode.
  final Trick? existingTrick;

  const SubmitTrickScreen({super.key, this.existingTrick});

  @override
  State<SubmitTrickScreen> createState() => _SubmitTrickScreenState();
}

class _SubmitTrickScreenState extends State<SubmitTrickScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Form controllers
  late final TextEditingController _givenName;
  late final TextEditingController _technicalName;
  late final TextEditingController _originalPerformer;
  late final TextEditingController _description;
  late final TextEditingController _tips;
  late final TextEditingController _videoLink;
  late final TextEditingController _videoStart;
  late final TextEditingController _videoEnd;
  int _difficultyTier = -1;
  DateTime? _datePerformed;
  int? _startPositionId;
  int? _endPositionId;
  List<int> _prerequisiteIds = [];

  late Future<SubmitMeta> _metaFuture;
  late final VoidCallback _nameListener;

  bool get _isEditing => widget.existingTrick != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTrick;
    _givenName = TextEditingController(text: t?.givenName);
    _technicalName = TextEditingController(text: t?.technicalName);
    _originalPerformer = TextEditingController(text: t?.originalPerformer);
    _description = TextEditingController(text: t?.description);
    _tips = TextEditingController(text: t?.tips);
    _videoLink = TextEditingController(text: t?.videoLink);
    _videoStart = TextEditingController(
        text: t?.videoStart != null ? '${t!.videoStart}' : '');
    _videoEnd = TextEditingController(
        text: t?.videoEnd != null ? '${t!.videoEnd}' : '');
    if (t != null) {
      _difficultyTier = t.difficultyTier;
      _datePerformed = t.datePerformed;
      _startPositionId = t.startPositionId;
      _endPositionId = t.endPositionId;
      _prerequisiteIds = List.from(t.prerequisiteTrickIds);
    }
    _metaFuture = _loadMeta();
    _nameListener = () => setState(() {});
    _givenName.addListener(_nameListener);
    _technicalName.addListener(_nameListener);
  }

  Future<SubmitMeta> _loadMeta() async {
    final positions = await TricksService.getPositions();
    final tricks = await TricksService.getApprovedTricks();
    return SubmitMeta(positions: positions, tricks: tricks);
  }

  @override
  void dispose() {
    _givenName.removeListener(_nameListener);
    _technicalName.removeListener(_nameListener);
    _givenName.dispose();
    _technicalName.dispose();
    _originalPerformer.dispose();
    _description.dispose();
    _tips.dispose();
    _videoLink.dispose();
    _videoStart.dispose();
    _videoEnd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEditing) {
        await TricksService.updateTrick(widget.existingTrick!.id, {
          'given_name': _givenName.text.trim(),
          'technical_name': trimToNull(_technicalName.text),
          'difficulty_tier': _difficultyTier,
          'date_performed':
              _datePerformed?.toIso8601String().split('T').first,
          'original_performer': trimToNull(_originalPerformer.text),
          'prerequisite_trick_ids': _prerequisiteIds,
          'description': trimToNull(_description.text),
          'tips': trimToNull(_tips.text),
          'video_link': trimToNull(_videoLink.text),
          'video_start': int.tryParse(_videoStart.text.trim()),
          'video_end': int.tryParse(_videoEnd.text.trim()),
          'start_position_id': _startPositionId,
          'end_position_id': _endPositionId,
        });
      } else {
        final trick = Trick(
          id: 0,
          givenName: _givenName.text.trim(),
          technicalName: trimToNull(_technicalName.text),
          difficultyTier: _difficultyTier,
          dateSubmitted: DateTime.now(),
          datePerformed: _datePerformed,
          originalPerformer: trimToNull(_originalPerformer.text),
          prerequisiteTrickIds: _prerequisiteIds,
          description: trimToNull(_description.text),
          tips: trimToNull(_tips.text),
          videoLink: trimToNull(_videoLink.text),
          videoStart: int.tryParse(_videoStart.text.trim()),
          videoEnd: int.tryParse(_videoEnd.text.trim()),
          startPositionId: _startPositionId,
          endPositionId: _endPositionId,
          status: ApprovalStatus.pending,
        );
        await TricksService.submitTrick(trick);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Trick updated.'
              : 'Trick submitted for review!'),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Trick' : 'Submit a Trick'),
      ),
      body: FutureBuilder<SubmitMeta>(
        future: _metaFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final positions = snap.data?.positions ?? [];
          final allTricks = snap.data?.tricks ?? [];
          return _buildForm(positions, allTricks);
        },
      ),
    );
  }

  Widget _buildForm(List<Position> positions, List<Trick> allTricks) {
    final sortedPositions = [...positions]..sort((a, b) => a.name.compareTo(b.name));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_givenName, 'Given Name', required: true),
            const SizedBox(height: 12),
            _field(_technicalName, 'Technical Name'),
            if (!_isEditing) _SimilarTricksWarning(
              givenQuery: _givenName.text.trim(),
              technicalQuery: _technicalName.text.trim(),
              allTricks: allTricks,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _difficultyTier,
              decoration: const InputDecoration(
                labelText: 'Difficulty *',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: -1, child: Text('TBD')),
                for (int v = 1; v <= 30; v++)
                  DropdownMenuItem(value: v, child: Text(Trick.tierLabel(v))),
              ],
              onChanged: (v) => setState(() => _difficultyTier = v!),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Start position
            DropdownButtonFormField<int?>(
              initialValue: _startPositionId,
              decoration: const InputDecoration(
                  labelText: 'Start Position *',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...sortedPositions.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _startPositionId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _endPositionId,
              decoration: const InputDecoration(
                  labelText: 'End Position *',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...sortedPositions.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _endPositionId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Date performed
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_datePerformed == null
                  ? 'Date First Performed (optional)'
                  : 'Date First Performed: ${formatDisplayDate(_datePerformed!)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_datePerformed != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _datePerformed = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _field(_originalPerformer, 'Original Performer'),
            const SizedBox(height: 12),
            // Prerequisites
            _PrerequisiteSelector(
              allTricks: allTricks
                  .where((t) =>
                      !_isEditing || t.id != widget.existingTrick!.id)
                  .toList(),
              selectedIds: _prerequisiteIds,
              onChanged: (ids) => setState(() => _prerequisiteIds = ids),
            ),
            const SizedBox(height: 12),
            _field(_description, 'Description', maxLines: 4),
            const SizedBox(height: 12),
            _field(_tips, 'Tips', maxLines: 4),
            const SizedBox(height: 12),
            _field(_videoLink, 'Video Link (URL)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _videoStart,
                    decoration: const InputDecoration(
                      labelText: 'Loop start (s)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _videoEnd,
                    decoration: const InputDecoration(
                      labelText: 'Loop end (s)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Submit for Review'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePerformed ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _datePerformed = picked);
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder()),
        maxLines: maxLines,
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      );
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
                  'Tricks with similar names:',
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
    final selected =
        allTricks.where((t) => selectedIds.contains(t.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Prerequisites',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () => _showPicker(context),
            ),
          ],
        ),
        if (selected.isEmpty)
          Text('None',
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
            title: const Text('Select Prerequisite'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
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
                child: const Text('Cancel'),
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
