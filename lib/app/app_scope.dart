import 'package:flutter/material.dart';

import '../data/repositories/dhikr_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/recognition/recognition_engine.dart';
import '../domain/session/session_controller.dart';
import '../domain/settings/settings_controller.dart';
import '../recognition/mock_recognition_engine.dart';

/// Container for app-wide singletons and state controllers.
class AppDependencies {
  final DhikrRepository dhikrRepository;
  final SessionRepository sessionRepository;
  final RecognitionEngine recognitionEngine;
  final SessionController sessionController;
  final SettingsController settingsController;

  AppDependencies({
    required this.dhikrRepository,
    required this.sessionRepository,
    required this.recognitionEngine,
    required this.sessionController,
    required this.settingsController,
  });

  factory AppDependencies.initialize() {
    final dhikrRepo = InMemoryDhikrRepository();
    final sessionRepo = InMemorySessionRepository();
    final recognitionEngine = MockRecognitionEngine();
    final sessionController = SessionController(
      recognitionEngine: recognitionEngine,
      sessionRepository: sessionRepo,
    );
    final settingsController = SettingsController();

    return AppDependencies(
      dhikrRepository: dhikrRepo,
      sessionRepository: sessionRepo,
      recognitionEngine: recognitionEngine,
      sessionController: sessionController,
      settingsController: settingsController,
    );
  }

  void dispose() {
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
