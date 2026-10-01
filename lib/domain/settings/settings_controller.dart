import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';

/// Controller for user preferences and application configuration.
class SettingsController extends ChangeNotifier {
  final SettingsRepository? repository;

  bool _hapticsEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoSimulateVoiceInDebug = false;

  SettingsController({this.repository});

  bool get hapticsEnabled => _hapticsEnabled;
  ThemeMode get themeMode => _themeMode;
  bool get autoSimulateVoiceInDebug => _autoSimulateVoiceInDebug;

  /// Load persisted settings from repository.
  Future<void> loadSettings() async {
    if (repository == null) return;
    _hapticsEnabled = await repository!.getHapticsEnabled();
    _themeMode = await repository!.getThemeMode();
    _autoSimulateVoiceInDebug = await repository!.getAutoSimulateVoice();
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled != value) {
      _hapticsEnabled = value;
      notifyListeners();
      await repository?.setHapticsEnabled(value);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      await repository?.setThemeMode(mode);
    }
  }

  Future<void> setAutoSimulateVoiceInDebug(bool value) async {
    if (_autoSimulateVoiceInDebug != value) {
      _autoSimulateVoiceInDebug = value;
      notifyListeners();
      await repository?.setAutoSimulateVoice(value);
    }
  }
}
