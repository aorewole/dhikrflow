# Dhikr Counter — Background & Screen-Off Audio Architecture

**Phase:** Phase 10 — Screen-off / Background Listening  
**Date:** 2026-10-01  
**Status:** Architecture Specified & Platform Service Implemented  

---

## 1. Principles & Privacy Guarantees

In accordance with `AGENTS.md`:
1. **Explicit Opt-In Only:** Background microphone capture is disabled by default. The user must deliberately enable "Background & Screen-Off Recitation" in Settings.
2. **No Indefinite / Silent Listening:** Microphone capture exists solely during an active, user-initiated session. When a session is paused or completed, background audio capture is terminated immediately.
3. **No Audio Storage:** All background frames are processed in-memory and discarded. Zero audio is stored to disk or transmitted remotely.

---

## 2. Android Architecture & Limitations

### 2.1 OS Requirements & Permissions
- **Android 9 (API 28) and below:** Background audio was unconstrained, which created battery and privacy vulnerabilities.
- **Android 10 to 13 (API 29–33):** Requires a Foreground Service declared with:
  ```xml
  android:foregroundServiceType="microphone"
  ```
- **Android 14+ (API 34+):**
  - Requires explicit permission:
    ```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    ```
  - The foreground service must be launched **while the application is in the foreground**. Attempting to start microphone capture while already in the background throws a `ForegroundServiceStartNotAllowedException`.
  - Android displays a persistent, non-dismissible notification in the system shade with a live microphone indicator dot.

### 2.2 OEM Battery Managers (Doze Mode)
- Aggressive OEM battery killers (e.g. Xiaomi MIUI, Huawei EMUI, Samsung OneUI) may terminate long-running foreground services if battery optimization exemptions are not granted.
- The app handles sudden lifecycle termination gracefully via Phase 2 `LocalSessionRepository` active draft persistence.

---

## 3. iOS Architecture & Limitations

### 3.1 OS Requirements & Entitlements
- **Info.plist Requirement:**
  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>audio</string>
  </array>
  ```
- **AVAudioSession Category:** Must be configured to `AVAudioSessionCategoryPlayAndRecord` or `AVAudioSessionCategoryRecord` with `.mixWithOthers` or `.allowBluetooth`.
- **System Privacy Indicators:** iOS renders a persistent orange microphone indicator dot at the top of the screen and on the dynamic island / lock screen.

### 3.2 App Store Review Guidelines (5.1.1 & 2.5.4)
- Apple enforces strict scrutiny on apps declaring `UIBackgroundModes: audio` for recording.
- Reviewers require clear demonstration that audio input is directly initiated by the user for an ongoing task (e.g. continuous dhikr recitation) and terminates as soon as the session ends.
- If rejected by review teams in specific jurisdictions, the app's `BackgroundListeningService` provides a clean graceful fallback where background capture is disabled while screen-on hands-free recitation continues uninterrupted.

---

## 4. Service Abstraction (`BackgroundListeningService`)

All platform-specific mechanics are isolated behind the `BackgroundListeningService` interface in `lib/services/background_listening_service.dart`:

```dart
abstract interface class BackgroundListeningService {
  bool get isSupported;
  bool get isOptedIn;
  bool get isActive;
  Future<void> setOptedIn(bool enabled);
  Future<void> onSessionStarted(DhikrDefinition dhikr);
  Future<void> onSessionStopped();
}
```

The presentation layer and recognition engine interact solely through this service, ensuring 100% platform independence.
