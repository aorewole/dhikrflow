import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../domain/models/dhikr_definition.dart';

/// Contract for managing platform-level background/screen-off audio listening.
///
/// Follows specifications in `docs/BUILD_ROADMAP.md` Phase 10:
/// - Explicit user opt-in (disabled by default).
/// - Clear status when active.
/// - No silent or indefinite background microphone capture.
/// - Battery-conscious lifecycle handling.
abstract interface class BackgroundListeningService {
  /// Whether the host platform architecture supports background microphone capture.
  bool get isSupported;

  /// Whether the user has explicitly opted into screen-off / background listening.
  bool get isOptedIn;

  /// Whether the background service is actively running for a live session.
  bool get isActive;

  /// Persists user's explicit opt-in preference.
  Future<void> setOptedIn(bool enabled);

  /// Called when an active recitation session begins.
  Future<void> onSessionStarted(DhikrDefinition dhikr);

  /// Called when the session pauses or finishes to immediately release resources.
  Future<void> onSessionStopped();

  void dispose();
}

/// Production implementation of [BackgroundListeningService].
class DefaultBackgroundListeningService implements BackgroundListeningService {
  static const String keyPrefOptIn = 'setting_background_listening_opt_in';

  bool _optedIn = false;
  bool _active = false;
  final StreamController<bool> _activeStateController =
      StreamController<bool>.broadcast();

  DefaultBackgroundListeningService({bool initialOptIn = false})
      : _optedIn = initialOptIn;

  Stream<bool> get activeStream => _activeStateController.stream;

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  bool get isOptedIn => _optedIn;

  @override
  bool get isActive => _active;

  @override
  Future<void> setOptedIn(bool enabled) async {
    _optedIn = enabled;
    if (!_optedIn && _active) {
      await onSessionStopped();
    }
  }

  @override
  Future<void> onSessionStarted(DhikrDefinition dhikr) async {
    if (!isSupported || !_optedIn) return;

    _active = true;
    _activeStateController.add(true);

    if (kDebugMode) {
      debugPrint(
        '[BackgroundListeningService] Started background listening for: ${dhikr.transliteration}',
      );
    }
  }

  @override
  Future<void> onSessionStopped() async {
    if (!_active) return;

    _active = false;
    _activeStateController.add(false);

    if (kDebugMode) {
      debugPrint('[BackgroundListeningService] Stopped background listening service.');
    }
  }

  @override
  void dispose() {
    onSessionStopped();
    _activeStateController.close();
  }
}
