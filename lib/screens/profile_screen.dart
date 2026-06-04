import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/profile.dart';
import '../models/screen_data.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/progression_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../theme_controller.dart';
import '../utils/safe_state.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/profile_main_card.dart';
import '../widgets/profile_stats_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SafeStateMixin {
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
    final whatsNext = ProgressionService.computeWhatsNext(userTricks, allTricks);

    return ProfileData(profile: profile, entries: entries, whatsNext: whatsNext);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _updateConsistency(int trickId, Consistency consistency) async {
    await UserTricksService.setConsistency(trickId, consistency);
    _refresh();
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.signOutTooltip,
      content: l10n.signOutConfirmMessage,
      confirmLabel: l10n.signOutTooltip,
      cancelLabel: l10n.cancelButton,
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
                child: Text(context.l10n.errorWithDetail(snap.error.toString())));
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
                        icon:
                            Icon(isDark ? Icons.dark_mode : Icons.light_mode),
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
            Card(child: ProfileStatsCard(entries: entries)),
            const SizedBox(height: 12),
          ],
          ProfileMainCard(
            entries: entries,
            whatsNext: whatsNext,
            onConsistencyChanged: _updateConsistency,
          ),
        ],
      ),
    );
  }
}
