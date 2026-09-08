import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  /// The currently selected app theme.
  ThemeMode get themeMode => _themeMode;

  // Kept for the existing theme switch UI.
  ThemeMode get mode => _themeMode;

  /// Restores the user's saved choice, or uses the device theme by default.
  Future<void> loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_themeModeKey);

    _themeMode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' || _ => ThemeMode.system,
    };
    notifyListeners();
  }

  /// Applies the new theme immediately and persists it for the next launch.
  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode != value) {
      _themeMode = value;
      notifyListeners();
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, value.name);
  }

  // Backwards-compatible API for the existing switch UI.
  Future<void> setMode(ThemeMode value) => setThemeMode(value);
}
