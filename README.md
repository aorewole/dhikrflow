# Dhikr Counter (أذكار)

A free, privacy-first, offline hands-free dhikr counter built with Flutter for iOS and Android.

---

## 🌟 Mission & User Experience

The primary experience is:
**Select dhikr → Start → Recite → count repetitions automatically.**

The app is **not** a voice assistant and is **not** a cloud transcription service. It is an intentional, privacy-respecting companion for remembrance of Allah (dhikr).

---

## 🔒 Non-Negotiable Privacy Guarantees

1. **100% Offline (Airplane Mode Ready):** Core functionality operates entirely with no Internet connection. No network permissions are required or requested.
2. **Zero Cloud Speech APIs:** Speech recognition is executed locally on-device.
3. **No Microphone Audio Persistence:** Raw microphone audio is held only as transient in-memory PCM buffers during active VAD/ASR processing and is immediately discarded. Never saved to disk, never uploaded.
4. **Zero Telemetry & Tracking:** No Firebase, no analytics, no crashlytics, no telemetry SDKs, and no advertising networks.
5. **No Accounts or Logins:** Sessions, preferences, and favorites are stored entirely in local on-device storage.

---

## 🏗️ Architecture Pipeline

The application isolates speech mechanics behind a domain-level `RecognitionEngine`:

```
Microphone
    │
    ▼
In-Memory Audio Stream (PCM 16-bit 16kHz)
    │
    ▼
Voice Activity Detector (VAD)
  • Adaptive noise-floor tracking
  • 350ms hangover duration for Arabic phonetics
  • 7s max segment memory bounding
    │
    ▼
Local Offline ASR (sherpa-onnx + OpenAI Whisper Tiny int8)
    │
    ▼
Arabic Normalization (Diacritic stripping, Alef/Yeh unification)
    │
    ▼
Controlled Fuzzy Phrase Matcher (Levenshtein distance & confidence tiers)
    │
    ▼
Streaming Repetition Detector (Deduplicates partial hypotheses; counts +1, +2, +4)
    │
    ▼
Domain DhikrCountEvent ──► SessionController ──► UI & Local Persistence
```

---

## 📖 Canonical Dhikr Library

Includes 10 authentic Sunnah adhkar with Arabic text, transliteration, and English translation:

1. **Astaghfirullah** (أَسْتَغْفِرُ ٱللَّٰهَ)
2. **SubhanAllah** (سُبْحَانَ ٱللَّٰهِ)
3. **Alhamdulillah** (ٱلْحَمْدُ لِلَّٰهِ)
4. **Allahu Akbar** (ٱللَّٰهُ أَكْبَرُ)
5. **La ilaha illallah** (لَا إِلَٰهَ إِلَّا ٱللَّٰهُ)
6. **SubhanAllahi wa bihamdihi** (سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ)
7. **SubhanAllahil Azeem** (سُبْحَانَ ٱللَّٰهِ ٱلْعَظِيمِ)
8. **La hawla wa la quwwata illa billah** (لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ)
9. **HasbunAllahu wa ni'mal wakeel** (حَسْبُنَا ٱللَّٰهُ وَنِعْمَ ٱلْوَكِيلُ)
10. **Allahumma salli 'ala Muhammad** (ٱللَّٰهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ)

---

## 🚀 Key Features

- **Hands-Free Repetition Counting:** Accurately counts individual and rapid consecutive repetitions (+1, +2, +4, +10).
- **Target Progress & Haptics:** Optional repetition targets with real-time progress and subtle haptic feedback. Sessions never terminate abruptly upon reaching target.
- **Manual +1 Fallback:** Giant on-screen tactile button always available.
- **Screen-Off / Background Listening (Opt-In):** Optional mode to continue counting when screen is locked, adhering to OS foreground/audio guidelines with immediate microphone release on finish.
- **Session Interruption Recovery:** Automatically saves draft sessions to survive phone calls or app restarts.
- **Personal Calibration (Prototype):** Privacy-preserving on-device acoustic tuning without neural network training.
- **Auto-Detect (Prototype):** Experimental phrase detection with two-phase lock state machine to prevent accidental silent target switching.

---

## 🛠️ Development & Testing

### Prerequisites
- Flutter SDK (>= 3.47)
- Xcode (for iOS) / Android SDK (for Android)

### Running Tests
```bash
# Run unit & domain tests (82 passing tests)
flutter test

# Run static analysis
flutter analyze
```

---

## 📜 Documentation Index

- [`AGENTS.md`](./AGENTS.md): Core product rules and non-negotiable privacy constraints
- [`docs/MASTER_SPEC.md`](./docs/MASTER_SPEC.md): Full product specification
- [`docs/RECOGNITION_SPEC.md`](./docs/RECOGNITION_SPEC.md): Recognition pipeline & repetition algorithm
- [`docs/BUILD_ROADMAP.md`](./docs/BUILD_ROADMAP.md): 14-phase implementation roadmap
- [`docs/DEPENDENCIES.md`](./docs/DEPENDENCIES.md): Dependency rationale and open-source licenses
- [`docs/CALIBRATION_REPORT.md`](./docs/CALIBRATION_REPORT.md): Empirical confidence threshold benchmarks
- [`docs/PERFORMANCE_REPORT.md`](./docs/PERFORMANCE_REPORT.md): Memory, buffering, and battery profiling
- [`docs/BACKGROUND_AUDIO.md`](./docs/BACKGROUND_AUDIO.md): Platform-specific background audio architecture
- [`docs/CALIBRATION_EXPERIMENT.md`](./docs/CALIBRATION_EXPERIMENT.md): Personal calibration findings
- [`docs/AUTO_DETECT_REPORT.md`](./docs/AUTO_DETECT_REPORT.md): Auto-detect safety and complexity benchmarks
- [`docs/RELEASE_CHECKLIST.md`](./docs/RELEASE_CHECKLIST.md): Production release readiness audit
