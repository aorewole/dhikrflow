import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';
import '../../services/background_listening_service.dart';
import '../recognition/recognition_config.dart';

/// Controller for user preferences and application configuration.
class SettingsController extends ChangeNotifier {
  final SettingsRepository? repository;

  bool _hapticsEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoSimulateVoiceInDebug = false;
  RecognitionConfig _recognitionConfig = RecognitionConfig.balanced;
  bool _backgroundListeningOptIn = false;
  bool _hasCompletedOnboarding = false;
  bool _hasCompletedSessionTutorial = false;

  SettingsController({this.repository});

  bool get hapticsEnabled => _hapticsEnabled;
  ThemeMode get themeMode => _themeMode;
  bool get autoSimulateVoiceInDebug => _autoSimulateVoiceInDebug;
  RecognitionConfig get recognitionConfig => _recognitionConfig;
  bool get backgroundListeningOptIn => _backgroundListeningOptIn;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get hasCompletedSessionTutorial => _hasCompletedSessionTutorial;

  /// Load persisted settings from repository.
  Future<void> loadSettings() async {
    if (repository == null) return;
    _hapticsEnabled = await repository!.getHapticsEnabled();
    _themeMode = await repository!.getThemeMode();
    _autoSimulateVoiceInDebug = await repository!.getAutoSimulateVoice();
    _recognitionConfig = await repository!.getRecognitionConfig();
    _backgroundListeningOptIn = await repository!.getBackgroundListeningOptIn();
    _hasCompletedOnboarding = await repository!.getHasCompletedOnboarding();
    _hasCompletedSessionTutorial = await repository!.getHasCompletedSessionTutorial();
    notifyListeners();
  }

  Future<void> setHasCompletedOnboarding(bool value) async {
    if (_hasCompletedOnboarding != value) {
      _hasCompletedOnboarding = value;
      notifyListeners();
      await repository?.setHasCompletedOnboarding(value);
    }
  }

  Future<void> setHasCompletedSessionTutorial(bool value) async {
    if (_hasCompletedSessionTutorial != value) {
      _hasCompletedSessionTutorial = value;
      notifyListeners();
      await repository?.setHasCompletedSessionTutorial(value);
    }
  }

  Future<void> setRecognitionConfig(RecognitionConfig config) async {
    _recognitionConfig = config;
    notifyListeners();
    await repository?.setRecognitionConfig(config);
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

  Future<void> setBackgroundListeningOptIn(
    bool value, {
    BackgroundListeningService? backgroundService,
  }) async {
    if (_backgroundListeningOptIn != value) {
      _backgroundListeningOptIn = value;
      notifyListeners();
      await repository?.setBackgroundListeningOptIn(value);
      await backgroundService?.setOptedIn(value);
    }
  }
}
