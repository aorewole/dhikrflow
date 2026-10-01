import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/dhikr_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/recognition/recognition_engine.dart';
import '../domain/session/session_controller.dart';
import '../domain/settings/settings_controller.dart';
import '../recognition/audio/record_audio_source.dart';
import '../recognition/mock_recognition_engine.dart';
import '../recognition/pipeline/audio_vad_pipeline.dart';
import '../recognition/vad/voice_activity_detector.dart';

/// Container for app-wide singletons and state controllers.
class AppDependencies {
  final DhikrRepository dhikrRepository;
  final SessionRepository sessionRepository;
  final RecognitionEngine recognitionEngine;
  final SessionController sessionController;
  final SettingsController settingsController;
  final AudioVadPipeline? audioVadPipeline;

  AppDependencies({
    required this.dhikrRepository,
    required this.sessionRepository,
    required this.recognitionEngine,
    required this.sessionController,
    required this.settingsController,
    this.audioVadPipeline,
  });

  /// Asynchronously initializes all persistent repositories, audio pipeline, and settings.
  static Future<AppDependencies> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsRepo = SharedPrefsSettingsRepository(prefs);
    final dhikrRepo = LocalDhikrRepository(prefs);
    final sessionRepo = LocalSessionRepository(prefs);

    // Audio & VAD pipeline setup
    final audioSource = RecordAudioSource();
    final vad = VoiceActivityDetector();
    final pipeline = AudioVadPipeline(audioSource: audioSource, vad: vad);

    final recognitionEngine = MockRecognitionEngine(pipeline: pipeline);
    final sessionController = SessionController(
      recognitionEngine: recognitionEngine,
      sessionRepository: sessionRepo,
    );
    final settingsController = SettingsController(repository: settingsRepo);
    await settingsController.loadSettings();

    return AppDependencies(
      dhikrRepository: dhikrRepo,
      sessionRepository: sessionRepo,
      recognitionEngine: recognitionEngine,
      sessionController: sessionController,
      settingsController: settingsController,
      audioVadPipeline: pipeline,
    );
  }

  /// Synchronous initialization for unit tests or in-memory testing.
  factory AppDependencies.forTesting({
    DhikrRepository? dhikrRepo,
    SessionRepository? sessionRepo,
    RecognitionEngine? recognitionEngine,
    SettingsRepository? settingsRepo,
    AudioVadPipeline? audioVadPipeline,
  }) {
    final dRepo = dhikrRepo ?? LocalDhikrRepository();
    final sRepo = sessionRepo ?? LocalSessionRepository();
    final engine = recognitionEngine ?? MockRecognitionEngine();
    final sController = SessionController(
      recognitionEngine: engine,
      sessionRepository: sRepo,
    );
    final setController = SettingsController(repository: settingsRepo);

    return AppDependencies(
      dhikrRepository: dRepo,
      sessionRepository: sRepo,
      recognitionEngine: engine,
      sessionController: sController,
      settingsController: setController,
      audioVadPipeline: audioVadPipeline,
    );
  }

  void dispose() {
    audioVadPipeline?.dispose();
    sessionController.dispose();
    settingsController.dispose();
  }
}

/// InheritedWidget providing [AppDependencies] to the Flutter widget hierarchy.
class AppScope extends InheritedWidget {
  final AppDependencies dependencies;

  const AppScope({super.key, required this.dependencies, required super.child});

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
