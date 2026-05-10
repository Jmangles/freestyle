import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/profile.dart';
import '../models/tip.dart';
import '../models/tip_type.dart';
import '../services/auth_service.dart';
import '../services/tips_service.dart';
import '../utils/date_formatters.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  List<Tip> _tips = [];
  Profile? _profile;
  bool _initialLoading = true;
  bool _hasError = false;
  TipType? _typeFilter;
  late final TextEditingController _searchController;
  late final StreamSubscription _authSub;
  late final RealtimeChannel _tipsChannel;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _load(initial: true);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _load();
    });
    _tipsChannel = Supabase.instance.client
        .channel('public:tips')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tips',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _authSub.cancel();
    Supabase.instance.client.removeChannel(_tipsChannel);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _initialLoading = true;
        _hasError = false;
      });
    }
    try {
      final tipsFuture = TipsService.getApprovedTips();
      final profileFuture = AuthService.getCurrentProfile();
      final tips = await tipsFuture;
      final profile = await profileFuture;
      if (mounted) {
        setState(() {
          _tips = tips;
          _profile = profile;
          _initialLoading = false;
          _hasError = false;
        });
      }
    } catch (e, st) {
      debugPrint('TipsScreen._load error: $e\n$st');
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _hasError = true;
        });
      }
    }
  }

  List<Tip> get _filtered {
    final query = _searchController.text.toLowerCase();
    return _tips.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (query.isEmpty) return true;
      return t.title.toLowerCase().contains(query) ||
          t.header.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tipsNavLabel),
        actions: [
          if (_profile?.canEditTricks == true)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: l10n.adminLabel,
              onPressed: () => context.push('/admin'),
            ),
          IconButton(
            icon: Icon(AuthService.isLoggedIn ? Icons.person_outline : Icons.login),
            tooltip: AuthService.isLoggedIn ? l10n.profileTooltip : l10n.signInTooltip,
            onPressed: () =>
                context.push(AuthService.isLoggedIn ? '/profile' : '/login'),
          ),
        ],
      ),
      floatingActionButton: AuthService.isLoggedIn
          ? FloatingActionButton.extended(
              heroTag: 'tips_fab',
              onPressed: () async {
                await context.push('/tips/submit');
                _load();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.submitTipButton),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.failedToLoadTips,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: Text(l10n.retryButton)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.l10n.searchByNameHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        _TypeFilterBar(
          selected: _typeFilter,
          onChanged: (t) => setState(() => _typeFilter = t),
        ),
        Expanded(
          child: _tips.isEmpty
              ? Center(child: Text(l10n.noTipsYet))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(child: Text(l10n.noTipsYet)),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) => _TipTile(tip: _filtered[i]),
                        ),
                ),
        ),
      ],
    );
  }
}

class _TypeFilterBar extends StatelessWidget {
  final TipType? selected;
  final ValueChanged<TipType?> onChanged;

  const _TypeFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(l10n.allTypesFilter),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          const SizedBox(width: 8),
          for (final type in TipType.values) ...[
            FilterChip(
              avatar: Icon(_tipTypeIcon(type), size: 16),
              label: Text(type.localizedLabel(l10n)),
              selected: selected == type,
              onSelected: (_) => onChanged(selected == type ? null : type),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final Tip tip;

  const _TipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(_tipTypeIcon(tip.type), color: colorScheme.primary),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tip.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    tip.header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TypeChip(type: tip.type),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          SelectableText(tip.body),
          const SizedBox(height: 12),
          Text(
            l10n.submittedOnLabel(formatShortDate(tip.submittedOn)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final TipType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Chip(
      label: Text(type.localizedLabel(l10n)),
      avatar: Icon(_tipTypeIcon(type), size: 14),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: 9),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

IconData _tipTypeIcon(TipType type) => switch (type) {
      TipType.general => Icons.lightbulb_outline,
      TipType.rigging => Icons.construction_outlined,
      TipType.health => Icons.health_and_safety_outlined,
    };
