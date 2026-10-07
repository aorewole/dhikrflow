import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/recognition/recognition_config.dart';
import '../../domain/recognition/recognition_profile.dart';

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
  Future<bool> getBackgroundListeningOptIn();
  Future<void> setBackgroundListeningOptIn(bool enabled);
  Future<RecognitionProfile?> getVoiceProfile(String dhikrId);
  Future<void> setVoiceProfile(RecognitionProfile profile);
  Future<void> removeVoiceProfile(String dhikrId);
  Future<bool> getUseVoiceCalibration(String dhikrId);
  Future<void> setUseVoiceCalibration(String dhikrId, bool enabled);
  Future<bool> getHasCompletedOnboarding();
  Future<void> setHasCompletedOnboarding(bool completed);
  Future<bool> getHasCompletedSessionTutorial();
  Future<void> setHasCompletedSessionTutorial(bool completed);
}

/// SharedPreferences implementation of [SettingsRepository].
class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _keyHaptics = 'setting_haptics_enabled';
  static const _keyThemeMode = 'setting_theme_mode';
  static const _keyAutoSimulate = 'setting_auto_simulate_voice';
  static const _keyRecognitionConfig = 'setting_recognition_config';
  static const _keyBackgroundListening = 'setting_background_listening_opt_in';

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

  @override
  Future<bool> getBackgroundListeningOptIn() async {
    return _prefs.getBool(_keyBackgroundListening) ?? false;
  }

  @override
  Future<void> setBackgroundListeningOptIn(bool enabled) async {
    await _prefs.setBool(_keyBackgroundListening, enabled);
  }

  @override
  Future<RecognitionProfile?> getVoiceProfile(String dhikrId) async {
    final rawJson = _prefs.getString('setting_voice_profile_$dhikrId');
    if (rawJson == null) return null;
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return RecognitionProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setVoiceProfile(RecognitionProfile profile) async {
    final rawJson = jsonEncode(profile.toJson());
    await _prefs.setString('setting_voice_profile_${profile.dhikrId}', rawJson);
    await setUseVoiceCalibration(profile.dhikrId, true);
  }

  @override
  Future<void> removeVoiceProfile(String dhikrId) async {
    await _prefs.remove('setting_voice_profile_$dhikrId');
    await _prefs.remove('setting_use_calibration_$dhikrId');
  }

  @override
  Future<bool> getUseVoiceCalibration(String dhikrId) async {
    return _prefs.getBool('setting_use_calibration_$dhikrId') ?? true;
  }

  @override
  Future<void> setUseVoiceCalibration(String dhikrId, bool enabled) async {
    await _prefs.setBool('setting_use_calibration_$dhikrId', enabled);
  }

  @override
  Future<bool> getHasCompletedOnboarding() async {
    return _prefs.getBool('setting_onboarding_completed') ?? false;
  }

  @override
  Future<void> setHasCompletedOnboarding(bool completed) async {
    await _prefs.setBool('setting_onboarding_completed', completed);
  }

  @override
  Future<bool> getHasCompletedSessionTutorial() async {
    return _prefs.getBool('setting_session_tutorial_completed') ?? false;
  }

  @override
  Future<void> setHasCompletedSessionTutorial(bool completed) async {
    await _prefs.setBool('setting_session_tutorial_completed', completed);
  }
}
