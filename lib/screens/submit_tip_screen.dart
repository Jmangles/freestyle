import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/tip.dart';
import '../models/tip_type.dart';
import '../services/auth_service.dart';
import '../services/tips_service.dart';

class SubmitTipScreen extends StatefulWidget {
  final Tip? existingTip;

  const SubmitTipScreen({super.key, this.existingTip});

  @override
  State<SubmitTipScreen> createState() => _SubmitTipScreenState();
}

class _SubmitTipScreenState extends State<SubmitTipScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _bodyCtrl;
  late TipType _type;
  bool _saving = false;

  bool get _isEdit => widget.existingTip != null;

  @override
  void initState() {
    super.initState();
    final tip = widget.existingTip;
    _titleCtrl = TextEditingController(text: tip?.title ?? '');
    _headerCtrl = TextEditingController(text: tip?.header ?? '');
    _bodyCtrl = TextEditingController(text: tip?.body ?? '');
    _type = tip?.type ?? TipType.general;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _headerCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await TipsService.updateTip(
          id: widget.existingTip!.id,
          title: _titleCtrl.text.trim(),
          header: _headerCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: _type,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.tipUpdated)),
          );
          Navigator.pop(context);
        }
      } else {
        final profile = await AuthService.getCurrentProfile();
        await TipsService.submitTip(
          title: _titleCtrl.text.trim(),
          header: _headerCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: _type,
          submittedBy: profile?.intId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.tipSubmittedForReview)),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorWithDetail(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editTipTitle : l10n.submitTipTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.tipTitleLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.requiredValidator : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _headerCtrl,
              decoration: InputDecoration(
                labelText: l10n.tipHeaderLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.requiredValidator : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            _ResizableBodyField(
              controller: _bodyCtrl,
              labelText: l10n.tipBodyLabel,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.requiredValidator : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.tipTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: TipType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.localizedLabel(l10n)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit
                      ? l10n.saveChangesButton
                      : l10n.submitForReviewButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResizableBodyField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;

  const _ResizableBodyField({
    required this.controller,
    required this.labelText,
    this.validator,
  });

  @override
  State<_ResizableBodyField> createState() => _ResizableBodyFieldState();
}

class _ResizableBodyFieldState extends State<_ResizableBodyField> {
  static const double _minHeight = 120.0;
  static const double _maxHeight = 800.0;
  static const double _defaultHeight = 240.0;

  double _height = _defaultHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline;
    final handleColor = colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _height,
          child: TextFormField(
            controller: widget.controller,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              labelText: widget.labelText,
              alignLabelWithHint: true,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: colorScheme.primary, width: 2),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.error),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: colorScheme.error, width: 2),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ),
            validator: widget.validator,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _height =
                  (_height + details.delta.dy).clamp(_minHeight, _maxHeight);
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: handleColor,
                border: Border(
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(4)),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
