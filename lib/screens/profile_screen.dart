import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../models/screen_data.dart';
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
    final userTricks = await UserTricksService.getUserTricks();

    if (userTricks.isEmpty) return ProfileData(profile: profile, entries: []);

    final trickIds = userTricks.map((ut) => ut.trickId).toList();
    final tricks = await TricksService.getTricksByIds(trickIds);
    final trickMap = {for (final t in tricks) t.id: t};

    final entries = userTricks
        .map((ut) => UserTrickEntry(userTrick: ut, trick: trickMap[ut.trickId]))
        .toList();

    return ProfileData(profile: profile, entries: entries);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
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
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data!;
          return _buildContent(data.profile, data.entries);
        },
      ),
    );
  }

  Widget _buildContent(Profile? profile, List<UserTrickEntry> entries) {
    final theme = Theme.of(context);
    final user = AuthService.currentUser;

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.username ?? 'Unknown User',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (user?.email != null)
                    Text(user!.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  if (profile?.isAdmin == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Chip(
                        label: const Text('Admin'),
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

          // Settings
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
                    title: const Text('Dark Mode'),
                    value: isDark,
                    onChanged: (on) => ThemeController.instance
                        .setMode(on ? ThemeMode.dark : ThemeMode.light),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'My Tricks (${entries.length})',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                  child: Text(
                      'No tricks tracked yet.\nBrowse the trick list and set your consistency!')),
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
                    '${trick.difficultyLabel} · ${userTrick.consistency.label}',
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
}
