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

  void _refresh() => setState(() { _future = _load(); _activeTab = 0; });

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

  Widget _buildMainCard(List<UserTrickEntry> entries, WhatsNextData whatsNext, ThemeData theme) {
    final l10n = context.l10n;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    var idx = 0;
    final myTricksTab  = idx++;
    final unlockedTab  = whatsNext.unlocked.isNotEmpty         ? idx++ : -1;
    final partialTab   = whatsNext.partiallyUnlocked.isNotEmpty ? idx++ : -1;
    final highValueTab = whatsNext.highValue.isNotEmpty         ? idx++ : -1;
    final tabCount = idx;
    final tab = _activeTab.clamp(0, tabCount - 1);

    final landedCount     = entries.where((e) => e.userTrick.consistency.isLanded).length;
    final attemptingCount = entries.where((e) => !e.userTrick.consistency.isLanded).length;

    final descriptions = {
      myTricksTab:  entries.isEmpty ? l10n.noTricksTracked : '$landedCount tricks landed, $attemptingCount tricks in progress',
      unlockedTab:  'All prerequisites met — start working on these',
      partialTab:   'You have at least one prerequisite for these',
      highValueTab: 'Landing these unlocks the most new tricks',
    };

    Widget tabBtn(String label, IconData icon, Color color, int index) {
      final selected = tab == index;
      return InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16,
                  color: selected ? color : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
              )),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                tabBtn('My Tricks',      Icons.list,        theme.colorScheme.primary, myTricksTab),
                if (unlockedTab  >= 0) tabBtn('Ready to Start',  Icons.lock_open,  theme.colorScheme.primary, unlockedTab),
                if (partialTab   >= 0) tabBtn('Making Progress', Icons.trending_up, theme.colorScheme.primary, partialTab),
                if (highValueTab >= 0) tabBtn('High Value',      Icons.star,        theme.colorScheme.primary, highValueTab),
              ],
            ),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text(
              descriptions[tab] ?? '',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
                  Expanded(child: Text('TRICK', style: labelStyle)),
                  SizedBox(width: 56, child: Text('TIER', textAlign: TextAlign.right, style: labelStyle)),
                  if (tab == highValueTab)
                    SizedBox(width: 72, child: Text('UNLOCKS', textAlign: TextAlign.right, style: labelStyle)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (tab == unlockedTab) ...[
              for (int i = 0; i < whatsNext.unlocked.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () => context.push('/trick/${whatsNext.unlocked[i].id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(child: Text(whatsNext.unlocked[i].givenName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      SizedBox(width: 56, child: Text(whatsNext.unlocked[i].difficultyLabel, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                    ]),
                  ),
                ),
              ],
            ],
            if (tab == partialTab) ...[
              for (int i = 0; i < whatsNext.partiallyUnlocked.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () => context.push('/trick/${whatsNext.partiallyUnlocked[i].id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(child: Text(whatsNext.partiallyUnlocked[i].givenName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      SizedBox(width: 56, child: Text(whatsNext.partiallyUnlocked[i].difficultyLabel, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                    ]),
                  ),
                ),
              ],
            ],
            if (tab == highValueTab) ...[
              for (int i = 0; i < whatsNext.highValue.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () => context.push('/trick/${whatsNext.highValue[i].trick.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(children: [
                      Expanded(child: Text(whatsNext.highValue[i].trick.givenName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      SizedBox(width: 56, child: Text(whatsNext.highValue[i].trick.difficultyLabel, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                      SizedBox(width: 72, child: Text('${whatsNext.highValue[i].unlockCount}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.tertiary))),
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
