import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeController._() : super(ThemeMode.system);

  static final instance = ThemeController._();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') {
      instance.value = ThemeMode.light;
    } else if (stored == 'dark') {
      instance.value = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
