import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interface for persisting user settings locally.
abstract interface class SettingsRepository {
  Future<bool> getHapticsEnabled();
  Future<void> setHapticsEnabled(bool enabled);
  Future<ThemeMode> getThemeMode();
  Future<void> setThemeMode(ThemeMode mode);
  Future<bool> getAutoSimulateVoice();
  Future<void> setAutoSimulateVoice(bool enabled);
}

/// SharedPreferences implementation of [SettingsRepository].
class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _keyHaptics = 'setting_haptics_enabled';
  static const _keyThemeMode = 'setting_theme_mode';
  static const _keyAutoSimulate = 'setting_auto_simulate_voice';

  final SharedPreferences _prefs;

  SharedPrefsSettingsRepository(this._prefs);

  @override
  Future<bool> getHapticsEnabled() async {
    return _prefs.getBool(_keyHaptics) ?? true;
  }

  @override
  Future<void> setHapticsEnabled(bool enabled) async {
    await _prefs.setBool(_keyHaptics, enabled);
  }

  @override
  Future<ThemeMode> getThemeMode() async {
    final modeName = _prefs.getString(_keyThemeMode);
    if (modeName == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  @override
  Future<bool> getAutoSimulateVoice() async {
    return _prefs.getBool(_keyAutoSimulate) ?? false;
  }

  @override
  Future<void> setAutoSimulateVoice(bool enabled) async {
    await _prefs.setBool(_keyAutoSimulate, enabled);
  }
}
