import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/dhikr_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/recognition/recognition_engine.dart';
import '../domain/session/session_controller.dart';
import '../domain/settings/settings_controller.dart';
import '../recognition/asr/model_asset_extractor.dart';
import '../recognition/asr/sherpa_onnx_asr_engine.dart';
import '../recognition/audio/record_audio_source.dart';
import '../recognition/local_recognition_engine.dart';
import '../recognition/mock_recognition_engine.dart';
import '../recognition/pipeline/audio_vad_pipeline.dart';
import '../recognition/vad/voice_activity_detector.dart';
import '../services/background_listening_service.dart';

/// Container for app-wide singletons and state controllers.
class AppDependencies {
  final DhikrRepository dhikrRepository;
  final SessionRepository sessionRepository;
  final RecognitionEngine recognitionEngine;
  final SessionController sessionController;
  final SettingsController settingsController;
  final AudioVadPipeline? audioVadPipeline;
  final BackgroundListeningService? backgroundListeningService;

  AppDependencies({
    required this.dhikrRepository,
    required this.sessionRepository,
    required this.recognitionEngine,
    required this.sessionController,
    required this.settingsController,
    this.audioVadPipeline,
    this.backgroundListeningService,
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

    // Ensure offline Whisper Tiny ONNX model files are extracted from assets
    try {
      await ModelAssetExtractor.ensureModelsExtracted();
    } catch (e) {
      debugPrint('[AppDependencies] Model asset extraction note: $e');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final tarteelTinyDir = '${docsDir.path}/models/tarteel_tiny_quran';
    final moonshineDir = '${docsDir.path}/models/moonshine_arabic';
    final baseDir = '${docsDir.path}/models/whisper_base';
    final tinyDir = '${docsDir.path}/models/whisper_tiny';

    final SherpaOnnxAsrEngine asrEngine;
    final tarteelEngine = SherpaOnnxAsrEngine.whisper(
      encoderPath: '$tarteelTinyDir/tarteel-tiny-encoder.int8.onnx',
      decoderPath: '$tarteelTinyDir/tarteel-tiny-decoder.int8.onnx',
      tokensPath: '$tarteelTinyDir/tarteel-tiny-tokens.txt',
    );
    final moonshineEngine = SherpaOnnxAsrEngine.moonshine(
      encoderPath: '$moonshineDir/encoder_model.ort',
      decoderPath: '$moonshineDir/decoder_model_merged.ort',
      tokensPath: '$moonshineDir/tokens.txt',
    );
    final baseEngine = SherpaOnnxAsrEngine.whisper(
      encoderPath: '$baseDir/base-encoder.int8.onnx',
      decoderPath: '$baseDir/base-decoder.int8.onnx',
      tokensPath: '$baseDir/base-tokens.txt',
    );

    final tinyEngine = SherpaOnnxAsrEngine.whisper(
      encoderPath: '$tinyDir/tiny-encoder.int8.onnx',
      decoderPath: '$tinyDir/tiny-decoder.int8.onnx',
      tokensPath: '$tinyDir/tiny-tokens.txt',
    );

    if (moonshineEngine.areModelFilesPresent) {
      asrEngine = moonshineEngine;
      debugPrint('[AppDependencies] Using dedicated Moonshine Arabic model.');
    } else if (tarteelEngine.areModelFilesPresent) {
      asrEngine = tarteelEngine;
      debugPrint('[AppDependencies] Using fine-tuned Tarteel Tiny Quran model.');
    } else if (baseEngine.areModelFilesPresent) {
      asrEngine = baseEngine;
      debugPrint('[AppDependencies] Using Whisper Base model.');
    } else if (tinyEngine.areModelFilesPresent) {
      asrEngine = tinyEngine;
      debugPrint('[AppDependencies] Using Whisper Tiny model.');
    } else {
      asrEngine = moonshineEngine;
      debugPrint('[AppDependencies] Using fallback Moonshine Arabic model.');
    }

    final settingsController = SettingsController(repository: settingsRepo);
    await settingsController.loadSettings();

    final RecognitionEngine recognitionEngine;
    final localEngine = LocalRecognitionEngine(
      pipeline: pipeline,
      asrEngine: asrEngine.areModelFilesPresent ? asrEngine : null,
      config: settingsController.recognitionConfig,
    );
    settingsController.addListener(() {
      localEngine.updateConfig(settingsController.recognitionConfig);
    });
    recognitionEngine = localEngine;

    final backgroundListeningService = DefaultBackgroundListeningService(
      initialOptIn: settingsController.backgroundListeningOptIn,
    );

    final sessionController = SessionController(
      recognitionEngine: recognitionEngine,
      sessionRepository: sessionRepo,
      settingsController: settingsController,
      backgroundListeningService: backgroundListeningService,
    );

    return AppDependencies(
      dhikrRepository: dhikrRepo,
      sessionRepository: sessionRepo,
      recognitionEngine: recognitionEngine,
      sessionController: sessionController,
      settingsController: settingsController,
      audioVadPipeline: pipeline,
      backgroundListeningService: backgroundListeningService,
    );
  }

  /// Synchronous initialization for unit tests or in-memory testing.
  factory AppDependencies.forTesting({
    DhikrRepository? dhikrRepo,
    SessionRepository? sessionRepo,
    RecognitionEngine? recognitionEngine,
    SettingsRepository? settingsRepo,
    AudioVadPipeline? audioVadPipeline,
    BackgroundListeningService? backgroundListeningService,
  }) {
    final dRepo = dhikrRepo ?? LocalDhikrRepository();
    final sRepo = sessionRepo ?? LocalSessionRepository();
    final engine = recognitionEngine ?? MockRecognitionEngine();
    final sController = SessionController(
      recognitionEngine: engine,
      sessionRepository: sRepo,
      backgroundListeningService: backgroundListeningService,
    );
    final setController = SettingsController(repository: settingsRepo);

    return AppDependencies(
      dhikrRepository: dRepo,
      sessionRepository: sRepo,
      recognitionEngine: engine,
      sessionController: sController,
      settingsController: setController,
      audioVadPipeline: audioVadPipeline,
      backgroundListeningService: backgroundListeningService,
    );
  }

  void dispose() {
    audioVadPipeline?.dispose();
    backgroundListeningService?.dispose();
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
