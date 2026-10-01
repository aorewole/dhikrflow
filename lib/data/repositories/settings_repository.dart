import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/recognition/recognition_config.dart';

/// Interface for persisting user settings locally.
abstract interface class SettingsRepository {
  Future<bool> getHapticsEnabled();
  Future<void> setHapticsEnabled(bool enabled);
  Future<ThemeMode> getThemeMode();
  Future<void> setThemeMode(ThemeMode mode);
  Future<bool> getAutoSimulateVoice();
  Future<void> setAutoSimulateVoice(bool enabled);
  Future<RecognitionConfig> getRecognitionConfig();
  Future<void> setRecognitionConfig(RecognitionConfig config);
}

/// SharedPreferences implementation of [SettingsRepository].
class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _keyHaptics = 'setting_haptics_enabled';
  static const _keyThemeMode = 'setting_theme_mode';
  static const _keyAutoSimulate = 'setting_auto_simulate_voice';
  static const _keyRecognitionConfig = 'setting_recognition_config';

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

  @override
  Future<RecognitionConfig> getRecognitionConfig() async {
    final rawJson = _prefs.getString(_keyRecognitionConfig);
    if (rawJson == null) return RecognitionConfig.balanced;
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return RecognitionConfig.fromJson(map);
    } catch (_) {
      return RecognitionConfig.balanced;
    }
  }

  @override
  Future<void> setRecognitionConfig(RecognitionConfig config) async {
    final rawJson = jsonEncode(config.toJson());
    await _prefs.setString(_keyRecognitionConfig, rawJson);
  }
}
