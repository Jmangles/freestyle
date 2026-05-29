import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/user_tricks_service.dart';
import '../utils/network_utils.dart';

class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _checkConnectivity();
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      _checkConnectivity();
      UserTricksService.flushPendingWrites().ignore();
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setDeviceConnectivity(result);
    if (mounted) setState(() => _isOffline = isDeviceOffline);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    setDeviceConnectivity(results);
    final offline = isDeviceOffline;
    if (!mounted || offline == _isOffline) return;
    setState(() => _isOffline = offline);
    if (!offline) UserTricksService.flushPendingWrites().ignore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) const _OfflineBanner(),
          Expanded(
            child: _isOffline
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.navigationShell,
                  )
                : widget.navigationShell,
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Text(
              "You're offline",
              style: TextStyle(color: scheme.onErrorContainer),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
