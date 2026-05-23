import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/profile.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../widgets/consistency_selector.dart';
import '../theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileData> _future;

  final _unlockedCtrl = ExpansibleController();
  final _partiallyUnlockedCtrl = ExpansibleController();
  final _highValueCtrl = ExpansibleController();
  final _myTricksCtrl = ExpansibleController();

  void _collapseOthers(ExpansibleController active) {
    for (final ctrl in [_unlockedCtrl, _partiallyUnlockedCtrl, _highValueCtrl, _myTricksCtrl]) {
      if (!identical(ctrl, active)) {
        try { ctrl.collapse(); } catch (_) {}
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProfileData> _load() async {
    final profile = await AuthService.getCurrentProfile();
    final (userTricks, allTricks) = await (
      UserTricksService.getUserTricks(),
      TricksService.getApprovedTricks(),
    ).wait;

    final trickMap = {for (final t in allTricks) t.id: t};

    final entries = userTricks
        .map((ut) => UserTrickEntry(userTrick: ut, trick: trickMap[ut.trickId]))
        .toList();

    final whatsNext = _computeWhatsNext(userTricks, allTricks);

    return ProfileData(profile: profile, entries: entries, whatsNext: whatsNext);
  }

  WhatsNextData _computeWhatsNext(List<UserTrick> userTricks, List<Trick> allTricks) {
    final landedIds = <int>{
      for (final ut in userTricks)
        if (ut.consistency.isLanded) ut.trickId,
    };
    final trackedIds = {for (final ut in userTricks) ut.trickId};

    // Category 1: all prerequisites met, not yet tracked
    final unlocked = allTricks
        .where((t) =>
            !trackedIds.contains(t.id) &&
            t.prerequisiteTrickIds.isNotEmpty &&
            t.prerequisiteTrickIds.every((id) => landedIds.contains(id)))
        .toList()
      ..sort((a, b) => a.difficultyTier.compareTo(b.difficultyTier));

    // Category 2: at least one but not all prerequisites met, not tracked
    final partiallyUnlocked = allTricks
        .where((t) =>
            !trackedIds.contains(t.id) &&
            t.prerequisiteTrickIds.isNotEmpty &&
            t.prerequisiteTrickIds.any((id) => landedIds.contains(id)) &&
            !t.prerequisiteTrickIds.every((id) => landedIds.contains(id)))
        .toList()
      ..sort((a, b) {
        final aCount = a.prerequisiteTrickIds.where((id) => landedIds.contains(id)).length;
        final bCount = b.prerequisiteTrickIds.where((id) => landedIds.contains(id)).length;
        return bCount.compareTo(aCount);
      });

    // Category 3: tricks that, once landed, unlock the most immediate next tricks
    final unlockCountMap = <int, int>{};
    for (final t in allTricks) {
      if (landedIds.contains(t.id)) continue;
      for (final prereqId in t.prerequisiteTrickIds) {
        if (!landedIds.contains(prereqId)) {
          final othersAllLanded = t.prerequisiteTrickIds
              .where((id) => id != prereqId)
              .every((id) => landedIds.contains(id));
          if (othersAllLanded) {
            unlockCountMap[prereqId] = (unlockCountMap[prereqId] ?? 0) + 1;
          }
        }
      }
    }

    final highValue = allTricks
        .where((t) => !landedIds.contains(t.id) && (unlockCountMap[t.id] ?? 0) > 0)
        .map((t) => HighValueTarget(trick: t, unlockCount: unlockCountMap[t.id]!))
        .toList()
      ..sort((a, b) => b.unlockCount.compareTo(a.unlockCount));

    return WhatsNextData(
      unlocked: unlocked,
      partiallyUnlocked: partiallyUnlocked,
      highValue: highValue.take(10).toList(),
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _updateConsistency(
      int trickId, Consistency consistency) async {
    await UserTricksService.setConsistency(trickId, consistency);
    _refresh();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOutTooltip,
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<ProfileData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(context.l10n.errorWithDetail(snap.error.toString())));
          }
          final data = snap.data!;
          return _buildContent(data.profile, data.entries, data.whatsNext);
        },
      ),
    );
  }

  Widget _buildContent(Profile? profile, List<UserTrickEntry> entries, WhatsNextData whatsNext) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final user = AuthService.currentUser;

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.username ?? l10n.unknownUser,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (user?.email != null)
                          Text(user!.email!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        if (profile?.canEditTricks == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Chip(
                              label: Text(l10n.adminLabel),
                              backgroundColor:
                                  theme.colorScheme.tertiaryContainer,
                              labelStyle: TextStyle(
                                  color:
                                      theme.colorScheme.onTertiaryContainer),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.instance,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark ||
                          (mode == ThemeMode.system &&
                              MediaQuery.platformBrightnessOf(context) ==
                                  Brightness.dark);
                      return IconButton(
                        icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                        tooltip: l10n.darkModeLabel,
                        onPressed: () => ThemeController.instance
                            .setMode(isDark ? ThemeMode.light : ThemeMode.dark),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          if (!whatsNext.isEmpty) ...[
            const SizedBox(height: 20),
            Text(
              "What's Next",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._buildWhatsNextSections(whatsNext, theme),
          ],

          const SizedBox(height: 20),

          _buildMyTricksCard(entries),
        ],
      ),
    );
  }

  Widget _buildMyTricksCard(List<UserTrickEntry> entries) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        controller: _myTricksCtrl,
        onExpansionChanged: (expanded) {
          if (expanded) _collapseOthers(_myTricksCtrl);
        },
        leading: Icon(Icons.list, color: theme.colorScheme.primary),
        title: Text(
          l10n.myTricksCount(entries.length),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        initiallyExpanded: false,
        children: entries.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text(l10n.noTricksTracked)),
                ),
              ]
            : [
                const Divider(height: 1),
                _buildTierBarGraph(entries),
                const Divider(height: 1),
                _buildTricksTable(entries),
              ],
      ),
    );
  }

  double _computeMedian(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final n = sorted.length;
    return n.isOdd
        ? sorted[n ~/ 2].toDouble()
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  Color _interpolateConsistencyColor(double value, Brightness brightness) {
    final colors = Consistency.values.map((c) => c.borderColor(brightness)).toList();
    final lower = value.floor().clamp(0, colors.length - 2);
    final t = (value - lower).clamp(0.0, 1.0);
    return Color.lerp(colors[lower], colors[lower + 1], t)!;
  }

  Widget _buildTierBarGraph(List<UserTrickEntry> entries) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final counts = <int, int>{};
    final tierConsistencies = <int, List<int>>{};
    for (final entry in entries) {
      final tier = entry.trick?.difficultyLogicalTier ?? -1;
      if (tier < 1) continue;
      counts[tier] = (counts[tier] ?? 0) + 1;
      tierConsistencies.putIfAbsent(tier, () => []).add(entry.userTrick.consistency.index);
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final tiers = counts.keys.toList()..sort();
    const barAreaHeight = 64.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TRICKS BY TIER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· Colored by Consistency',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: tiers.map((tier) {
              final count = counts[tier]!;
              final fraction = count / maxCount;
              final median = _computeMedian(tierConsistencies[tier]!);
              final barColor = _interpolateConsistencyColor(median, brightness);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: barAreaHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: (barAreaHeight * fraction).clamp(3.0, barAreaHeight),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tier',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTricksTable(List<UserTrickEntry> entries) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final brightness = theme.brightness;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text('TRICK', style: labelStyle)),
                SizedBox(width: 56, child: Text('TIER', textAlign: TextAlign.center, style: labelStyle)),
                SizedBox(width: 88, child: Text('CONSISTENCY', textAlign: TextAlign.right, style: labelStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            Builder(builder: (context) {
              final entry = entries[i];
              final trick = entry.trick;
              if (trick == null) return const SizedBox.shrink();
              final userTrick = entry.userTrick;
              final consistencyColor = userTrick.consistency.borderColor(brightness);
              return InkWell(
                onTap: () => _showConsistencySheet(entry),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          trick.givenName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          trick.difficultyLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Text(
                          userTrick.consistency.localizedLabel(l10n),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: consistencyColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 4),
        ],
    );
  }

  void _showConsistencySheet(UserTrickEntry entry) {
    final trick = entry.trick!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trick.givenName,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              trick.difficultyLabel,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ConsistencySelector(
              selected: entry.userTrick.consistency,
              onChanged: (c) {
                Navigator.pop(ctx);
                _updateConsistency(trick.id, c);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWhatsNextSections(WhatsNextData whatsNext, ThemeData theme) {
    return [
      if (whatsNext.unlocked.isNotEmpty)
        _whatsNextCard(
          title: 'Ready to Start',
          subtitle: 'All prerequisites complete',
          icon: Icons.lock_open,
          color: theme.colorScheme.primary,
          tricks: whatsNext.unlocked,
          controller: _unlockedCtrl,
        ),
      if (whatsNext.partiallyUnlocked.isNotEmpty)
        _whatsNextCard(
          title: 'Making Progress',
          subtitle: 'Landed at least one prerequisite',
          icon: Icons.trending_up,
          color: theme.colorScheme.secondary,
          tricks: whatsNext.partiallyUnlocked,
          controller: _partiallyUnlockedCtrl,
        ),
      if (whatsNext.highValue.isNotEmpty)
        _highValueCard(whatsNext.highValue, theme, _highValueCtrl),
    ];
  }

  Widget _whatsNextCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Trick> tricks,
    required ExpansibleController controller,
  }) {
    final theme = Theme.of(context);
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        controller: controller,
        onExpansionChanged: (expanded) {
          if (expanded) _collapseOthers(controller);
        },
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        initiallyExpanded: false,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text('TRICK', style: labelStyle)),
                SizedBox(width: 56, child: Text('TIER', textAlign: TextAlign.right, style: labelStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < tricks.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            InkWell(
              onTap: () => context.push('/trick/${tricks[i].id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tricks[i].givenName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        tricks[i].difficultyLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _highValueCard(List<HighValueTarget> targets, ThemeData theme, ExpansibleController controller) {
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        controller: controller,
        onExpansionChanged: (expanded) {
          if (expanded) _collapseOthers(controller);
        },
        leading: Icon(Icons.star, color: theme.colorScheme.tertiary),
        title: const Text('High-Value Targets', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Unlocks the most new tricks'),
        initiallyExpanded: false,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text('TRICK', style: labelStyle)),
                SizedBox(width: 56, child: Text('TIER', textAlign: TextAlign.center, style: labelStyle)),
                SizedBox(width: 72, child: Text('UNLOCKS', textAlign: TextAlign.right, style: labelStyle)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int i = 0; i < targets.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            InkWell(
              onTap: () => context.push('/trick/${targets[i].trick.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(targets[i].trick.givenName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        targets[i].trick.difficultyLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${targets[i].unlockCount}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
