import 'package:flutter/material.dart';

/// Controller for user preferences and application configuration.
class SettingsController extends ChangeNotifier {
  bool _hapticsEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoSimulateVoiceInDebug = false;

  bool get hapticsEnabled => _hapticsEnabled;
  ThemeMode get themeMode => _themeMode;
  bool get autoSimulateVoiceInDebug => _autoSimulateVoiceInDebug;

  void setHapticsEnabled(bool value) {
    if (_hapticsEnabled != value) {
      _hapticsEnabled = value;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void setAutoSimulateVoiceInDebug(bool value) {
    if (_autoSimulateVoiceInDebug != value) {
      _autoSimulateVoiceInDebug = value;
      notifyListeners();
    }
  }
}
