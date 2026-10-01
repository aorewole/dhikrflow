# Dhikr Counter — Antigravity Build Roadmap

## How to use this roadmap

Work one phase at a time. After each phase, run tests, inspect the diff, and update the relevant documentation.

Never use “finish the whole app” as a development prompt.

---

## Phase 0 — Environment and architecture audit

### Goal

Know exactly what is installed before selecting tools.

### Agent task

```text
Audit this project environment and implement Phase 0 only.

Check:
- Flutter SDK
- Dart SDK
- Android SDK/tools
- connected Android devices/emulators
- Xcode and iOS tooling where available
- CocoaPods where relevant
- Git
- local storage/database options
- microphone/audio packages
- local/offline ASR candidates

Research current compatible package/model options and licenses.
Do not modify the app substantially yet.
Create docs/ENVIRONMENT_REPORT.md and docs/MODEL_EVALUATION_RESULTS.md with findings.
End by recommending the next implementation phase.
```

### Done when

- environment report exists
- model candidates documented
- licensing concerns documented
- no cloud dependency selected

---

## Phase 1 — Flutter skeleton + UI with fake recognition

### Goal

Build the full navigation and visual shell without real speech recognition.

### Agent task

```text
Implement Phase 1 only.

Create the Flutter application skeleton and the following screens:
- onboarding
- home
- dhikr library
- dhikr detail
- active session
- session complete
- history
- settings

Use a mock RecognitionEngine that emits deterministic count events for development.
Implement local domain/session models and state management without binding the UI to a speech SDK.

Do not implement real microphone or ASR yet.
Do not add analytics, auth, cloud APIs, or raw audio storage.

Run formatter, analyzer, and tests.
```

### Done when

A developer can navigate the complete user experience using fake count events.

---

## Phase 2 — Local persistence

### Goal

Sessions, settings, favorites, and dhikr definitions persist locally.

### Agent task

```text
Implement Phase 2 only.

Add the local persistence layer.
Persist:
- dhikr definitions
- favorites
- settings
- sessions

Make session saving resilient to ordinary lifecycle interruptions.
Keep persistence behind repository interfaces.
Add tests.

Do not add cloud sync or authentication.
```

---

## Phase 3 — Audio + VAD proof of concept

### Goal

Get live microphone data into a local pipeline and detect speech activity without ASR.

### Agent task

```text
Implement Phase 3 only.

Create the platform-aware audio input abstraction and local VAD pipeline.

Requirements:
- no raw-audio persistence
- clear microphone permission handling
- stop microphone immediately when the session ends
- configurable VAD thresholds
- diagnostic UI/state in debug mode

Test on a real Android device first when possible.
Document platform limitations.
```

---

## Phase 4 — Offline ASR integration

### Goal

Replace fake recognition with real local speech recognition.

### Agent task

```text
Implement Phase 4 only.

Integrate the selected local/offline ASR engine documented in docs/MODEL_EVALUATION_RESULTS.md.

Requirements:
- on-device processing
- streaming recognition if the chosen engine supports it
- no cloud endpoint
- no raw audio files
- model provenance and license documented
- engine isolated behind RecognitionEngine
- diagnostic logging available only in development builds

Start with one selected dhikr: Astaghfirullah.

Do not implement auto-detect or personalization yet.
```

---

## Phase 5 — Arabic normalization + phrase matcher

### Goal

Turn ASR output into reliable target-phrase candidates.

### Agent task

```text
Implement Phase 5 only.

Build:
- Arabic normalization module
- canonical phrase model
- controlled fuzzy matching
- confidence calculation hooks
- unit tests for normalization and matching

Use Astaghfirullah as the primary test phrase.

Do not mutate the session count directly from the matcher.
Emit candidate count events only after the repetition/de-duplication layer validates them.
```

---

## Phase 6 — Streaming repetition detector

### Goal

Solve the core product problem.

### Agent task

```text
Implement Phase 6 only.

Build a streaming repetition detector that:
- handles evolving partial hypotheses
- prevents double counting
- detects multiple occurrences in a continuous transcript
- handles rapid repetitions
- emits one count event per accepted occurrence

Mandatory tests:
1. One Astaghfirullah → +1
2. Two repetitions → +2
3. Four rapid repetitions → +4
4. Ten repetitions → +10
5. Partial hypothesis updates for one repetition → still +1
6. Unrelated speech → +0
7. Target mixed with unrelated words → count only accepted target occurrences

Create a deterministic test harness independent of the microphone.
```

---

## Phase 7 — Confidence calibration

### Goal

Reduce false positives without making the app unusably insensitive.

### Agent task

```text
Implement Phase 7 only.

Create configurable confidence thresholds and diagnostic reporting.

Use the recognition test harness to measure:
- precision
- recall
- missed repetitions
- false positives
- count error

Do not guess the final threshold from one device.
Document chosen defaults and why.
```

---

## Phase 8 — Manual counting + targets + session integration

### Goal

Finish the core usable counting experience.

### Agent task

```text
Implement Phase 8 only.

Integrate voice CountEvents and ManualCountEvents into one SessionController.
Add:
- optional target
- progress
- remaining
- target completion state
- session persistence
- haptic feedback

Reaching the target must not automatically end the session.
```

---

## Phase 9 — More dhikr

### Goal

Expand from one proof phrase to a local library.

### Agent task

```text
Implement Phase 9 only.

Expand the local dhikr library using validated source material.

For every entry store:
- canonical Arabic
- transliteration
- translation
- stable ID
- recognition normalization

Do not invent aliases or Arabic text.
Keep content/data separate from UI code.
Add phrase-level tests for each supported MVP dhikr.
```

---

## Phase 10 — Screen-off/background listening

### Goal

Add opt-in background listening where the OS supports it correctly.

### Agent task

```text
Implement Phase 10 only.

Research current Android and iOS requirements for microphone capture while the app is backgrounded or the screen is locked.

Implement platform-specific behavior behind a BackgroundListeningService abstraction.

Requirements:
- explicit user opt-in
- clear status when active
- no silent background microphone capture
- correct platform permissions/entitlements
- graceful fallback when unavailable
- battery-conscious lifecycle handling

Test on real devices.
Document limitations separately for Android and iOS.
```

---

## Phase 11 — Performance and battery optimization

### Goal

Make the recognition light enough for practical phones.

### Agent task

```text
Implement Phase 11 only.

Profile the active recognition pipeline.
Optimize:
- VAD activity
- ASR invocation
- buffering
- UI rebuilds
- model loading
- memory usage
- background behavior

Measure before/after CPU, memory, latency, and battery where practical.
Do not trade large accuracy losses for tiny CPU gains without documenting the tradeoff.
```

---

## Phase 12 — Personal calibration prototype

### Goal

Experiment with personalized recognition without training a neural network on-device.

### Agent task

```text
Implement Phase 12 as an experiment behind a feature flag.

Allow the user to provide a small number of recitation examples.
Process locally.
Discard raw audio.
Create a compact RecognitionProfile.

Compare baseline vs calibrated performance using the same test harness.
If calibration does not materially help, document the result and do not force the feature into release.
```

---

## Phase 13 — Auto-detect prototype

### Goal

Let the user optionally recite supported dhikr without preselecting a specific target.

### Agent task

```text
Implement Auto Detect as an experimental mode.

Use the local dhikr library to generate candidate matches from recognized speech.
Require sufficient confidence before producing a count event.

Prevent accidental silent target switching.

Benchmark CPU/battery cost versus selected-dhikr mode.
Keep selected-dhikr mode as the default.
```

---

## Phase 14 — Release hardening

### Goal

Prepare for a real free release.

### Agent task

```text
Perform a full release-readiness audit.

Verify:
- Android build
- iOS build
- offline behavior
- privacy
- permissions
- background behavior
- model license
- dependency licenses
- crash/error handling
- session persistence
- accessibility
- localization readiness
- store metadata prerequisites

Run the full test suite.
Create docs/RELEASE_CHECKLIST.md.
```
