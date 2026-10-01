# Dhikr Counter — Implementation Plan

**Current Milestone:** Phase 1 (Flutter Skeleton + Domain Logic + Mock Recognition UI)  
**Tracking Roadmap:** `docs/BUILD_ROADMAP.md`

---

## Task Breakdown for Phase 1

### Task 1.1: Flutter Project Scaffold
- Scaffold Flutter application with bundle identifier `com.dhikrcounter.dhikr_counter`.
- Configure `pubspec.yaml` with zero unnecessary dependencies:
  - Null-safe Dart 3.13+ / Flutter 3.47+.
  - Clean architecture directory layout (`lib/app`, `lib/core`, `lib/domain`, `lib/data`, `lib/recognition`, `lib/features`).
  - Strict lint rules (`package:flutter_lints`).

### Task 1.2: Domain Layer & Recognition Abstractions
- Create `DhikrDefinition` entity with initial vetted adhkar (Astaghfirullah, SubhanAllah, Alhamdulillah, Allahu Akbar, etc.).
- Create `DhikrSession` entity tracking session timestamps, counts, target progress, and completion states.
- Create domain events: `DhikrCountEvent` and `ManualCountEvent`.
- Define `RecognitionEngine` interface with lifecycle methods (`start`, `stop`, `pause`, `resume`) and reactive streams (`countEvents`, `stateStream`).
- Implement `MockRecognitionEngine` supporting controllable, deterministic voice count emissions for UI validation and unit tests.

### Task 1.3: Session State Management
- Implement `SessionController` (ChangeNotifier / ValueNotifier) encapsulating single-source-of-truth count mutations.
- Ensure voice events and manual +1 events unify into the single session count.
- Implement optional target logic: calculate progress, trigger target achievement flags, and ensure session does **not** terminate prematurely on target reach.

### Task 1.4: Calm, Modern UI Implementation (8 Core Screens)
- Theme: Calm Islamic minimalist aesthetic (deep slate / warm sand tones, clean typography, high contrast, dark/light theme support).
- Screen 1: `OnboardingScreen` (Clear privacy guarantee: offline-only, zero audio uploads).
- Screen 2: `HomeScreen` (Quick start, recent session highlights, library shortcuts).
- Screen 3: `DhikrLibraryScreen` (Searchable library of short adhkar with categories).
- Screen 4: `DhikrDetailScreen` (Arabic calligraphy display, transliteration, translation, optional target picker).
- Screen 5: `ActiveSessionScreen` (Large count, Arabic text, live listening state, manual +1 fallback, pause/finish, simulated voice trigger in debug mode).
- Screen 6: `SessionCompleteScreen` (Session summary, count achieved, duration, return home).
- Screen 7: `HistoryScreen` (Chronological session records, daily aggregations).
- Screen 8: `SettingsScreen` (Haptics preference, theme preference, privacy information).

### Task 1.5: Unit Testing & Verification
- Unit test suite for `SessionController` (target reached without exit, voice + manual counting concurrency, pause/resume behavior).
- Unit test suite for `MockRecognitionEngine` and domain events.
- Unit test suite for `DhikrDefinition` repository and library content.
- Code quality checks: `dart format`, `flutter analyze` (0 warnings/errors), `flutter test` (100% passing).
- Privacy verification: zero analytics SDKs, zero cloud endpoints, zero audio storage.
