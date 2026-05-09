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
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark ||
                      (mode == ThemeMode.system &&
                          MediaQuery.platformBrightnessOf(context) ==
                              Brightness.dark);
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode),
                    title: Text(l10n.darkModeLabel),
                    value: isDark,
                    onChanged: (on) => ThemeController.instance
                        .setMode(on ? ThemeMode.dark : ThemeMode.light),
                  );
                },
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

          Text(
            l10n.myTricksCount(entries.length),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(child: Text(l10n.noTricksTracked)),
            )
          else
            ...entries.map((entry) {
              final userTrick = entry.userTrick;
              final trick = entry.trick;
              if (trick == null) return const SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(trick.givenName,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${trick.difficultyLabel} · ${userTrick.consistency.localizedLabel(l10n)}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ConsistencySelector(
                        selected: userTrick.consistency,
                        onChanged: (c) =>
                            _updateConsistency(trick.id, c),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  List<Widget> _buildWhatsNextSections(WhatsNextData whatsNext, ThemeData theme) {
    return [
      if (whatsNext.unlocked.isNotEmpty)
        _whatsNextCard(
          title: 'Ready to Start',
          subtitle: 'All prerequisites met — start working on these',
          icon: Icons.lock_open,
          color: theme.colorScheme.primary,
          tricks: whatsNext.unlocked,
        ),
      if (whatsNext.partiallyUnlocked.isNotEmpty)
        _whatsNextCard(
          title: 'Making Progress',
          subtitle: 'You have at least one prerequisite for these',
          icon: Icons.trending_up,
          color: theme.colorScheme.secondary,
          tricks: whatsNext.partiallyUnlocked,
        ),
      if (whatsNext.highValue.isNotEmpty)
        _highValueCard(whatsNext.highValue, theme),
    ];
  }

  Widget _whatsNextCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Trick> tricks,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        initiallyExpanded: false,
        children: tricks.map((t) => ListTile(
          title: Text(t.givenName),
          subtitle: Text(t.difficultyLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/trick/${t.id}'),
        )).toList(),
      ),
    );
  }

  Widget _highValueCard(List<HighValueTarget> targets, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(Icons.star, color: theme.colorScheme.tertiary),
        title: const Text('High-Value Targets', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Landing these unlocks the most new tricks'),
        initiallyExpanded: false,
        children: targets.map((hv) => ListTile(
          title: Text(hv.trick.givenName),
          subtitle: Text(hv.trick.difficultyLabel),
          trailing: Chip(
            label: Text('unlocks ${hv.unlockCount}'),
            backgroundColor: theme.colorScheme.tertiaryContainer,
            labelStyle: TextStyle(
              color: theme.colorScheme.onTertiaryContainer,
              fontSize: 12,
            ),
            visualDensity: VisualDensity.compact,
          ),
          onTap: () => context.push('/trick/${hv.trick.id}'),
        )).toList(),
      ),
    );
  }
}
