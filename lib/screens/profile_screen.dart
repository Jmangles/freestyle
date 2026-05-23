import 'dart:math';

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

  int _activeTab = 0;

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

    return ProfileData(
        profile: profile, entries: entries, whatsNext: whatsNext);
  }

  WhatsNextData _computeWhatsNext(
      List<UserTrick> userTricks, List<Trick> allTricks) {
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
        final aCount =
            a.prerequisiteTrickIds.where((id) => landedIds.contains(id)).length;
        final bCount =
            b.prerequisiteTrickIds.where((id) => landedIds.contains(id)).length;
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
        .where(
            (t) => !landedIds.contains(t.id) && (unlockCountMap[t.id] ?? 0) > 0)
        .map((t) =>
            HighValueTarget(trick: t, unlockCount: unlockCountMap[t.id]!))
        .toList()
      ..sort((a, b) => b.unlockCount.compareTo(a.unlockCount));

    return WhatsNextData(
      unlocked: unlocked,
      partiallyUnlocked: partiallyUnlocked,
      highValue: highValue.take(10).toList(),
    );
  }

  void _refresh() => setState(() {
        _future = _load();
        _activeTab = 0;
      });

  Future<void> _updateConsistency(int trickId, Consistency consistency) async {
    await UserTricksService.setConsistency(trickId, consistency);
    _refresh();
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutTooltip),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.signOutTooltip),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
            return Center(
                child:
                    Text(context.l10n.errorWithDetail(snap.error.toString())));
          }
          final data = snap.data!;
          return _buildContent(data.profile, data.entries, data.whatsNext);
        },
      ),
    );
  }

  Widget _buildContent(
      Profile? profile, List<UserTrickEntry> entries, WhatsNextData whatsNext) {
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
                                  color: theme.colorScheme.onTertiaryContainer),
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
          const SizedBox(height: 20),
          if (entries.isNotEmpty) ...[
            Card(child: _buildTierBarGraph(entries)),
            const SizedBox(height: 12),
          ],
          _buildMainCard(entries, whatsNext, theme),
        ],
      ),
    );
  }

  Color _levelColor(int level) => switch (level) {
        0 => const Color(0xFF9E9E9E),
        <= 3 => const Color(0xFF4CAF50),
        <= 6 => const Color(0xFF8BC34A),
        <= 10 => const Color(0xFFFFCA28),
        <= 15 => const Color(0xFFFFA726),
        <= 20 => const Color(0xFFFF7043),
        <= 30 => const Color(0xFFEF5350),
        _ => const Color(0xFF7B0000),
      };

  double _xpRequiredForLevel(int level) {
    if (level <= 0) return 0;
    return 12 * pow(level, 1.4).toDouble();
  }

  int _computeLevel(num totalPoints) {
    int level = 0;
    while (_xpRequiredForLevel(level + 1) <= totalPoints) {
      level++;
    }
    return level;
  }

  num _getPointScoreByDifficulty(int rawDifficulty) {
    if (rawDifficulty < 0) {
      return 0;
    }

    const tierModifier = 0.1;
    final modifier = rawDifficulty % 3;

    final tier = rawDifficulty / 3 - tierModifier * (1 + modifier);

    return pow(1.5, tier - 1);
  }

  num _computeTotalPoints(List<UserTrickEntry> entries) {
    return entries.where((e) => e.userTrick.consistency.isLanded).fold(0,
        (sum, e) => sum + _getPointScoreByDifficulty(e.trick!.difficultyTier));
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
    final colors =
        Consistency.values.map((c) => c.borderColor(brightness)).toList();
    final lower = value.floor().clamp(0, colors.length - 2);
    final t = (value - lower).clamp(0.0, 1.0);
    return Color.lerp(colors[lower], colors[lower + 1], t)!;
  }

  Widget _buildLevelProgress(num totalPoints,
      {bool asColumn = false, bool asNarrowRow = false}) {
    final theme = Theme.of(context);
    final level = _computeLevel(totalPoints);
    final currentLevelXp = _xpRequiredForLevel(level);
    final nextLevelXp = _xpRequiredForLevel(level + 1);
    final progress =
        ((totalPoints - currentLevelXp) / (nextLevelXp - currentLevelXp))
            .clamp(0.0, 1.0);
    final ptsToNext = (nextLevelXp - totalPoints).ceil();

    final levelLabel = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Level',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$level',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _levelColor(level),
          ),
        ),
      ],
    );

    final pointsLabel = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          totalPoints.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.pointScoreLabel,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    final progressBar = Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 24,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(_levelColor(level)),
          ),
        ),
        Stack(
          children: [
            Text(
              context.l10n.ptsToNextLevel(ptsToNext, level + 1),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = theme.colorScheme.surface,
              ),
            ),
            Text(
              context.l10n.ptsToNextLevel(ptsToNext, level + 1),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.inverseSurface,
              ),
            ),
          ],
        ),
      ],
    );

    if (asNarrowRow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [levelLabel, pointsLabel],
          ),
          const SizedBox(height: 8),
          progressBar,
        ],
      );
    }

    if (asColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          levelLabel,
          const SizedBox(height: 8),
          progressBar,
          const SizedBox(height: 8),
          pointsLabel,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        levelLabel,
        const SizedBox(width: 24),
        Expanded(child: progressBar),
        const SizedBox(width: 24),
        pointsLabel,
      ],
    );
  }

  Widget _buildTierBarGraph(List<UserTrickEntry> entries) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final totalPoints = _computeTotalPoints(entries);

    final counts = <int, int>{};
    final tierConsistencies = <int, List<int>>{};
    for (final entry in entries) {
      final tier = entry.trick?.difficultyLogicalTier ?? -1;
      if (tier < 1) continue;
      counts[tier] = (counts[tier] ?? 0) + 1;
      tierConsistencies
          .putIfAbsent(tier, () => [])
          .add(entry.userTrick.consistency.index);
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final tiers = counts.keys.toList()..sort();
    const barAreaHeight = 64.0;

    Widget barChart() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.tricksByTierTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.coloredByConsistency,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tiers.map((tier) {
                final count = counts[tier]!;
                final fraction = count / maxCount;
                final median = _computeMedian(tierConsistencies[tier]!);
                final barColor =
                    _interpolateConsistencyColor(median, brightness);
                final barHeight =
                    (barAreaHeight * fraction).clamp(3.0, barAreaHeight);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: barAreaHeight + 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Spacer(),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
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
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          if (isWide) {
            final levelWidth = (constraints.maxWidth * 0.45).clamp(350.0, 650.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: levelWidth,
                  child: _buildLevelProgress(totalPoints, asColumn: true),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 80, color: Theme.of(context).dividerColor),
                const SizedBox(width: 16),
                Expanded(child: barChart()),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              barChart(),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _buildLevelProgress(totalPoints, asNarrowRow: true),
            ],
          );
        },
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
              Expanded(child: Text(l10n.columnTrick, style: labelStyle)),
              SizedBox(
                  width: 56,
                  child: Text(l10n.columnTier,
                      textAlign: TextAlign.center, style: labelStyle)),
              SizedBox(
                  width: 88,
                  child: Text(l10n.columnConsistency,
                      textAlign: TextAlign.right, style: labelStyle)),
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
            final consistencyColor =
                userTrick.consistency.borderColor(brightness);
            return InkWell(
              onTap: () => _showConsistencySheet(entry),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
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
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildMainCard(
      List<UserTrickEntry> entries, WhatsNextData whatsNext, ThemeData theme) {
    final l10n = context.l10n;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    var idx = 0;
    final myTricksTab = idx++;
    final unlockedTab = whatsNext.unlocked.isNotEmpty ? idx++ : -1;
    final partialTab = whatsNext.partiallyUnlocked.isNotEmpty ? idx++ : -1;
    final highValueTab = whatsNext.highValue.isNotEmpty ? idx++ : -1;
    final tabCount = idx;
    final tab = _activeTab.clamp(0, tabCount - 1);

    final landedCount =
        entries.where((e) => e.userTrick.consistency.isLanded).length;
    final attemptingCount =
        entries.where((e) => !e.userTrick.consistency.isLanded).length;

    final descriptions = {
      myTricksTab: entries.isEmpty
          ? l10n.noTricksTracked
          : l10n.tricksProgress(landedCount, attemptingCount),
      unlockedTab: l10n.tabReadyToStartDesc,
      partialTab: l10n.tabMakingProgressDesc,
      highValueTab: l10n.tabHighValueDesc,
    };

    Widget tabBtn(String label, IconData icon, Color color, int index,
        {bool iconsOnly = false}) {
      final selected = tab == index;
      final iconColor =
          selected ? color : theme.colorScheme.onSurfaceVariant;
      return Tooltip(
        message: iconsOnly ? label : '',
        child: InkWell(
          onTap: () => setState(() => _activeTab = index),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: iconsOnly ? 16 : 14, vertical: 14),
            child: iconsOnly
                ? Icon(icon, size: 22, color: iconColor)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? color
                                : theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab row
          LayoutBuilder(builder: (context, constraints) {
            final iconsOnly = constraints.maxWidth < 500;
            return Row(
              children: [
                tabBtn(l10n.tabMyTricks, Icons.list, theme.colorScheme.primary,
                    myTricksTab, iconsOnly: iconsOnly),
                if (unlockedTab >= 0)
                  tabBtn(l10n.tabReadyToStart, Icons.lock_open,
                      theme.colorScheme.primary, unlockedTab,
                      iconsOnly: iconsOnly),
                if (partialTab >= 0)
                  tabBtn(l10n.tabMakingProgress, Icons.trending_up,
                      theme.colorScheme.primary, partialTab,
                      iconsOnly: iconsOnly),
                if (highValueTab >= 0)
                  tabBtn(l10n.tabHighValue, Icons.star,
                      theme.colorScheme.primary, highValueTab,
                      iconsOnly: iconsOnly),
              ],
            );
          }),
          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text(
              descriptions[tab] ?? '',
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),

          // My Tricks tab
          if (tab == myTricksTab) ...[
            if (entries.isNotEmpty) _buildTricksTable(entries),
          ],

          // What's Next tabs: column headers then rows
          if (tab != myTricksTab) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.columnTrick, style: labelStyle)),
                  SizedBox(
                      width: 56,
                      child: Text(l10n.columnTier,
                          textAlign: TextAlign.right, style: labelStyle)),
                  if (tab == highValueTab)
                    SizedBox(
                        width: 72,
                        child: Text(l10n.columnUnlocks,
                            textAlign: TextAlign.right, style: labelStyle)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (tab == unlockedTab) ...[
              for (int i = 0; i < whatsNext.unlocked.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () =>
                      context.push('/trick/${whatsNext.unlocked[i].id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(
                          child: Text(whatsNext.unlocked[i].givenName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))),
                      SizedBox(
                          width: 56,
                          child: Text(whatsNext.unlocked[i].difficultyLabel,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant))),
                    ]),
                  ),
                ),
              ],
            ],
            if (tab == partialTab) ...[
              for (int i = 0; i < whatsNext.partiallyUnlocked.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () => context
                      .push('/trick/${whatsNext.partiallyUnlocked[i].id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(
                          child: Text(whatsNext.partiallyUnlocked[i].givenName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))),
                      SizedBox(
                          width: 56,
                          child: Text(
                              whatsNext.partiallyUnlocked[i].difficultyLabel,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant))),
                    ]),
                  ),
                ),
              ],
            ],
            if (tab == highValueTab) ...[
              for (int i = 0; i < whatsNext.highValue.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () =>
                      context.push('/trick/${whatsNext.highValue[i].trick.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(
                          child: Text(whatsNext.highValue[i].trick.givenName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))),
                      SizedBox(
                          width: 56,
                          child: Text(
                              whatsNext.highValue[i].trick.difficultyLabel,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant))),
                      SizedBox(
                          width: 72,
                          child: Text('${whatsNext.highValue[i].unlockCount}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.tertiary))),
                    ]),
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
