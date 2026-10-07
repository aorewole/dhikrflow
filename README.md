# DhikrPulse (ذِكْر بَلْس)

A free, 100% offline, privacy-first, hands-free Arabic dhikr counter built with Flutter for iOS, Android, and Desktop.

[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS-0D5C54.svg)](https://flutter.dev)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20%7C%20Zero%20Telemetry-2A8B78.svg)](#-non-negotiable-privacy-guarantees)
[![Tests](https://img.shields.io/badge/Tests-136%20Passed-success.svg)](#-development--testing)

---

## 🌟 Mission & User Experience

**Select Dhikr → Start → Recite naturally → Count repetitions automatically.**

DhikrPulse is **not** a voice assistant and does **not** rely on cloud services. It is an intentional, privacy-respecting spiritual companion designed for effortless hands-free remembrance of Allah.

---

## 🔒 Non-Negotiable Privacy Guarantees

1. **100% Offline (Airplane Mode Ready):** Core functionality operates entirely with zero Internet connection. No network permissions are requested.
2. **Zero Cloud Speech APIs:** Speech recognition and DSP analysis execute entirely on-device.
3. **No Microphone Audio Persistence:** Raw microphone audio is held only as transient in-memory PCM buffers during active processing and is immediately discarded. Never saved to disk, never uploaded.
4. **Zero Telemetry & Tracking:** No Firebase, no analytics, no crashlytics, no tracking SDKs, and no ads.
5. **No Accounts or Logins:** Sessions, preferences, and favorites are stored strictly on-device using local SQLite and SharedPreferences.

---

## 🚀 Key Features

* **Real-Time Hands-Free Counting:** Dual-engine fusion combining phonetic matching with mathematical energy envelope analysis (`SpeechEnvelopeAnalyzer`) to accurately count repetitions in continuous recitation.
* **Hardware Acoustic Echo Cancellation (AEC):** Activates device-level communication DSP (`AVAudioSessionModeVoiceChat` on iOS, `VOICE_COMMUNICATION` on Android) so you can recite in unison with the spoken guide without feedback.
* **Mindful Breath Cadence:** Automatic rhythmic pauses after every cycle (e.g. 3 or 7 repetitions) with a soothing 3-stage decrescendo tactile breath wave (`Heavy` $\to$ `Medium` $\to$ `Light`).
* **Tartil Letter-Sweep Pacing:** Visual golden highlighter synchronized to classical tajweed pacing with adjustable speeds (Slow, Medium, Fast).
* **27 Canonical Sunnah Adhkar:** Curated library categorized into Praise & Tasbih, Forgiveness & Istighfar, Tahlil & Tawheed, Protection & Morning/Evening, and Salawat.
* **Fixed Classical Orthography:** Pure `ٱللّٰه` Unicode representation with liturgical waqf codas (sukūn codas eliminating unwanted case endings).
* **Interactive Spotlight Tour:** Multi-step guided walkthrough on the counting screen with instant replay via the `?` Help button or Settings.
* **Silent & Pocket Modes:** Choose between spoken Arabic Voice Guide, tactile Pocket Haptic mode, or Mute.
* **Manual +1 Fallback:** Large tactile thumb button accessible anytime, even when paused.
* **Session Interruption Recovery:** Automatically persists active drafts to survive phone calls or app restarts.

---

## 🏗️ Architecture Pipeline

```
Microphone
    │
    ▼
In-Memory Audio Stream (PCM 16-bit 16kHz)
    │  [Hardware AEC: AudioRecord / AVAudioSession VoiceChat]
    ▼
Dual Recognition & Repetition Pipeline
    ├── Voice Activity Detector (VAD) + ASR / Keyword Spotter
    │       │
    │       ▼
    │   Arabic Normalizer (Waqf sukūn coda enforcement, ligature cleanup)
    │       │
    │       ▼
    │   Streaming Repetition Detector (Deduplicates partials, counts +1, +2, +4)
    │
    └── Mathematical Envelope Analyzer (ARe)
            │
            ▼
        DSP Waveform Energy Peaks & Valleys Rhythm Validation
    │
    ▼
Acoustic Fusion Gate ──► DhikrCountEvent ──► SessionController ──► UI & Local DB
```

---

## 📱 Releases & APK Installation

Download pre-compiled release APKs from the [GitHub Releases](https://github.com/aorewole/dhikrpulse/releases) page:

* **ARM64 (64-bit)**: `app-arm64-v8a-release.apk` (Recommended for modern Android phones)
* **ARMv7 (32-bit)**: `app-armeabi-v7a-release.apk` (For older 32-bit devices)
* **x86_64**: `app-x86_64-release.apk` (For Android emulators & Chromebooks)

### Quick Install via ADB
```bash
adb install -r app-arm64-v8a-release.apk
```

---

## 🛠️ Development & Testing

### Prerequisites
- Flutter SDK (`>= 3.47.0`)
- Xcode 15+ (for iOS / macOS)
- Android SDK / NDK (for Android)

### Running Tests
```bash
# Run the complete test suite (136 tests)
flutter test

# Run static analysis (0 warnings / errors)
flutter analyze
```

### Building Release APKs
```bash
flutter build apk --split-per-abi --release
```

---

## 📜 Documentation Index

* [`THE_STORY_OF_DHIKRPULSE.md`](./THE_STORY_OF_DHIKRPULSE.md): The full founder chronicle — from cloud doubts and the neural AI trap to pure mathematical signal processing
* [`docs/handbook/`](./docs/handbook/): Complete architectural handbook, hurdles, and technical deep-dives

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
