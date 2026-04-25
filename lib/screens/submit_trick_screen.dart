import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/trick.dart';
import '../models/position.dart';
import '../services/tricks_service.dart';

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
  int _difficultyTier = 5;
  DateTime? _datePerformed;
  int? _startPositionId;
  int? _endPositionId;
  List<int> _prerequisiteIds = [];

  late Future<(List<Position>, List<Trick>)> _metaFuture;

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
    if (t != null) {
      _difficultyTier = t.difficultyTier;
      _datePerformed = t.datePerformed;
      _startPositionId = t.startPositionId;
      _endPositionId = t.endPositionId;
      _prerequisiteIds = List.from(t.prerequisiteTrickIds);
    }
    _metaFuture = _loadMeta();
  }

  Future<(List<Position>, List<Trick>)> _loadMeta() async {
    final positions = await TricksService.getPositions();
    final tricks = await TricksService.getApprovedTricks();
    return (positions, tricks);
  }

  @override
  void dispose() {
    _givenName.dispose();
    _technicalName.dispose();
    _originalPerformer.dispose();
    _description.dispose();
    _tips.dispose();
    _videoLink.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEditing) {
        await TricksService.updateTrick(widget.existingTrick!.id, {
          'given_name': _givenName.text.trim(),
          'technical_name': _technicalName.text.trim().isEmpty
              ? null
              : _technicalName.text.trim(),
          'difficulty_tier': _difficultyTier,
          'date_performed':
              _datePerformed?.toIso8601String().split('T').first,
          'original_performer': _originalPerformer.text.trim().isEmpty
              ? null
              : _originalPerformer.text.trim(),
          'prerequisite_trick_ids': _prerequisiteIds,
          'description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          'tips': _tips.text.trim().isEmpty ? null : _tips.text.trim(),
          'video_link':
              _videoLink.text.trim().isEmpty ? null : _videoLink.text.trim(),
          'start_position_id': _startPositionId,
          'end_position_id': _endPositionId,
        });
      } else {
        final trick = Trick(
          id: 0,
          givenName: _givenName.text.trim(),
          technicalName: _technicalName.text.trim().isEmpty
              ? null
              : _technicalName.text.trim(),
          difficultyTier: _difficultyTier,
          dateSubmitted: DateTime.now(),
          datePerformed: _datePerformed,
          originalPerformer: _originalPerformer.text.trim().isEmpty
              ? null
              : _originalPerformer.text.trim(),
          prerequisiteTrickIds: _prerequisiteIds,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          tips: _tips.text.trim().isEmpty ? null : _tips.text.trim(),
          videoLink:
              _videoLink.text.trim().isEmpty ? null : _videoLink.text.trim(),
          startPositionId: _startPositionId,
          endPositionId: _endPositionId,
          status: 0,
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
              content: Text(e.toString()), backgroundColor: Colors.red),
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
      body: FutureBuilder<(List<Position>, List<Trick>)>(
        future: _metaFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final positions = snap.data?.$1 ?? [];
          final allTricks = snap.data?.$2 ?? [];
          return _buildForm(positions, allTricks);
        },
      ),
    );
  }

  Widget _buildForm(List<Position> positions, List<Trick> allTricks) {
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
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _difficultyTier == -1 ? 'TBD' : _difficultyTier.toString(),
              decoration: const InputDecoration(
                labelText: 'Difficulty (1–10 or TBD)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              onChanged: (v) {
                final s = v.trim().toUpperCase();
                if (s == 'TBD') {
                  setState(() => _difficultyTier = -1);
                } else {
                  final n = int.tryParse(s);
                  if (n != null) setState(() => _difficultyTier = n);
                }
              },
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final s = v.trim().toUpperCase();
                if (s == 'TBD') return null;
                final n = int.tryParse(s);
                if (n == null || n < 1 || n > 10) {
                  return 'Enter a number 1–10, or TBD';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Date performed
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_datePerformed == null
                  ? 'Date First Performed (optional)'
                  : 'Date First Performed: ${DateFormat('d MMM yyyy').format(_datePerformed!)}'),
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
            // Start position
            DropdownButtonFormField<int?>(
              initialValue: _startPositionId,
              decoration: const InputDecoration(
                  labelText: 'Start Position',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...positions.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _startPositionId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _endPositionId,
              decoration: const InputDecoration(
                  labelText: 'End Position',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...positions.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _endPositionId = v),
            ),
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
            labelText: label, border: const OutlineInputBorder()),
        maxLines: maxLines,
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      );
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
    final available =
        allTricks.where((t) => !selectedIds.contains(t.id)).toList();
    if (available.isEmpty) return;

    final picked = await showDialog<Trick>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select Prerequisite'),
        children: available
            .map((t) => SimpleDialogOption(
                  child: Text(t.givenName),
                  onPressed: () => Navigator.pop(context, t),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      onChanged([...selectedIds, picked.id]);
    }
  }
}
