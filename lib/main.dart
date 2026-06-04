import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations_extension.dart';
import 'router.dart';
import 'services/local_database.dart';
import 'services/tricks_service.dart';
import 'services/user_tricks_service.dart';
import 'video/offline_video_service.dart';
import 'supabase_config.dart';
import 'theme_controller.dart';
import 'utils/av1_support.dart';
import 'utils/network_utils.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await ThemeController.init();
  await LocalDatabase.init();
  await initAv1Support();

  if (!kIsWeb) {
    final connectivity = await Connectivity().checkConnectivity();
    setDeviceConnectivity(connectivity);
  }

  unawaited(_runStartupTasks());

  runApp(const HighlineApp());
}

Future<void> _runStartupTasks() async {
  if (!kIsWeb) unawaited(OfflineVideoService.loadSavedTrickIds());
  if (kIsWeb || isDeviceOffline) return;
  try {
    await UserTricksService.flushPendingWrites();
    await _refreshStaleCache();
  } catch (e) {
    debugPrint('startup tasks: $e');
  }
}

Future<void> _refreshStaleCache() async {
  final threshold =
      DateTime.now().toUtc().subtract(const Duration(hours: 24));

  final tricksSynced = await LocalDatabase.getMeta('tricks_last_synced');
  if (tricksSynced == null ||
      DateTime.parse(tricksSynced).isBefore(threshold)) {
    try {
      await TricksService.getApprovedTricks();
    } catch (_) {}
  }

  final positionsSynced = await LocalDatabase.getMeta('positions_last_synced');
  if (positionsSynced == null ||
      DateTime.parse(positionsSynced).isBefore(threshold)) {
    try {
      await TricksService.getPositions();
    } catch (_) {}
  }

  final userTricksSynced =
      await LocalDatabase.getMeta('user_tricks_last_synced');
  if (userTricksSynced == null ||
      DateTime.parse(userTricksSynced).isBefore(threshold)) {
    try {
      await UserTricksService.getUserTricks();
    } catch (_) {}
  }
}

class HighlineApp extends StatelessWidget {
  const HighlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (_, mode, __) => MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A90D9),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF),
            brightness: Brightness.dark,
            primary: const Color(0xFFFF5F00),
          ),
          useMaterial3: true,
        ),
        themeMode: mode,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
