# Dhikr Counter — Master Product & Technical Specification

## 1. Product summary

**Working name:** Dhikr Counter

**Category:** Offline dhikr / tasbih utility

**Price:** Free

**Privacy model:** Local-first, no account, no cloud speech processing, no raw audio storage.

**Initial platforms:** Android and iOS via Flutter.

**Core promise:**

> Recite your selected dhikr naturally. The app counts the repetitions for you.

## 2. Problem

Traditional digital tasbih apps generally require repeated screen interaction, hardware tapping, or a device held in the hand. This project explores a hands-free alternative in which the user can recite while walking, resting, or performing another permissible activity without repeatedly touching the phone.

The product must not turn the experience into a conversation or require constant UI interaction.

## 3. Core user journey

### First use

1. Launch app.
2. See privacy explanation.
3. Grant microphone permission when starting voice counting.
4. Browse/select a dhikr.
5. Optionally set a target.
6. Start session.
7. Recite.
8. App counts accepted repetitions.
9. User may manually add +1.
10. User ends session.
11. Session is saved locally.

### Returning use

1. Open Home.
2. Pick a recent/favorite dhikr.
3. Start.
4. Recite.
5. Stop.
6. Session appears in local history.

## 4. Core requirements

### 4.1 Dhikr selection

Provide a local library of common short adhkar.

Each entry includes:

- stable ID
- Arabic text
- transliteration
- translation
- aliases/alternate text forms where appropriate
- category
- recognition metadata
- optional suggested target

Users can favorite entries.

Design for custom user-added short dhikr later.

### 4.2 Selected-dhikr recognition

MVP is primarily selected-dhikr mode.

When the user selects a target phrase, recognition should optimize for detecting that phrase rather than attempting to understand all speech.

### 4.3 Repetition counting

Count each accepted repetition as one.

Examples:

- `Astaghfirullah` → +1
- `Astaghfirullah Astaghfirullah` → +2
- four rapid repetitions → +4
- unrelated speech → +0 if confidently non-matching

The implementation must prevent double-counting of partial streaming hypotheses.

### 4.4 Confidence handling

Use recognition evidence plus phrase-matching confidence to classify candidate detections.

Conceptually:

- High confidence → accept/count.
- Low confidence → ignore.
- Ambiguous/uncertain → do not auto-count.

Thresholds must be calibrated experimentally, not chosen solely by intuition.

### 4.5 Manual fallback

Provide a clear `+1` control on the active session screen.

This is intentionally secondary to voice recognition.

### 4.6 Target

Target is optional.

When supplied, show:

- current count
- target
- remaining
- progress

When no target exists, show only the count.

Reaching the target does not end the session automatically unless a future explicit preference is enabled.

### 4.7 Sessions and history

Save locally:

- session ID
- dhikr ID
- start time
- end time
- count
- target if any
- duration
- completion state
- optional aggregate recognition quality fields that contain no audio

Do not save raw audio.

### 4.8 Presentation

Display:

- Arabic
- transliteration
- translation
- current count
- listening state
- target/progress where applicable

### 4.9 Haptics

Optional subtle haptic on accepted voice-count events.

Differentiate ordinary count feedback from target completion without excessive vibration.

### 4.10 Background/screen-off listening

Provide as an explicit opt-in capability.

The application must respect current Android/iOS lifecycle, microphone, foreground/background, and privacy restrictions. Where platform rules make the feature unavailable or unreliable, clearly surface the limitation rather than pretending it is active.

## 5. Privacy requirements

The following are prohibited for MVP:

- cloud ASR
- cloud transcription
- server-side audio processing
- analytics
- telemetry
- ad SDKs
- tracking SDKs
- user account requirement
- remote transcript storage
- raw-audio persistence

The ideal core demonstration is:

**Airplane Mode ON → app continues counting.**

## 6. Audio lifecycle

Use an in-memory microphone stream.

Desired conceptual lifecycle:

```text
Microphone
   ↓
short in-memory buffer
   ↓
VAD / local ASR
   ↓
phrase detection
   ↓
count event
   ↓
buffer discarded/reused
```

Do not create user-audio files as an ordinary implementation detail.

## 7. Recognition architecture

The application should use this conceptual layering:

```text
AudioSource
   ↓
VoiceActivityDetector
   ↓
StreamingSpeechRecognizer
   ↓
ArabicNormalizer
   ↓
PhraseMatcher
   ↓
ConfidenceEvaluator
   ↓
TranscriptCommitTracker
   ↓
RepetitionDetector
   ↓
DhikrCountEvent
   ↓
SessionController
   ↓
UI + persistence
```

The UI should not call the speech SDK directly.

## 8. Model strategy

Candidate engines/models should be benchmarked.

sherpa-onnx should be evaluated as one possible local stack because it offers on-device/offline recognition capabilities and Flutter-related integrations.

Do not assume the largest model is best.

Do not assume the smallest model is accurate enough.

Choose based on measured phrase-level performance and device cost.

## 9. Personal calibration

Future capability, designed behind an abstraction.

User flow:

```text
Personal calibration

Say Astaghfirullah 10 times.
Say Subhanallah 10 times.
...
```

The goal is not to retrain the neural network on-device. The goal is to derive a compact user-specific profile that can improve phrase matching/calibration.

Raw calibration audio should be discarded after processing unless a deliberate future feature requires otherwise.

## 10. Auto-detect

Future capability.

MVP: selected phrase.

Later mode:

```text
Audio → ASR → normalized text → compare with local dhikr library → best supported match → confidence → count
```

Auto-detect must not silently switch targets in the middle of a user session without a clear UX decision.

## 11. UI map

### Home

- greeting/time-appropriate neutral copy
- Start Dhikr action
- favorites/recent dhikr
- recent sessions

### Dhikr library

- search
- categories
- favorites
- dhikr cards

### Dhikr detail

- Arabic
- transliteration
- translation
- start button
- target selector

### Active session

- large count
- Arabic
- transliteration
- translation
- listening indicator
- progress if target exists
- +1
- pause
- end

### Session complete

- final count
- target status if applicable
- duration
- date/time

### History

- grouped by date
- session details

### Settings

- haptics
- voice recognition
- optional background listening
- personal calibration
- theme
- privacy information

## 12. Accessibility

The app should support:

- large text where possible
- semantic labels
- sufficient contrast
- large touch targets
- screen-reader-friendly controls
- clear listening state without relying on color alone

## 13. Data model

Conceptual entities:

### DhikrDefinition

- id
- Arabic
- transliteration
- translation
- aliases
- category
- recognition metadata
- default target (optional)

### Session

- id
- dhikrId
- startedAt
- endedAt
- count
- target
- duration
- status

### RecognitionProfile

- id
- phraseId/profile scope
- version
- calibration metadata
- threshold overrides where used
- createdAt
- updatedAt

No raw audio field.

## 14. Architecture

Suggested project structure:

```text
lib/
  app/
  core/
  domain/
  data/
  recognition/
  platform/
  features/
    onboarding/
    home/
    dhikr_library/
    dhikr_detail/
    session/
    history/
    settings/
    calibration/
```

## 15. Dependency policy

For every dependency, document:

- why it is needed
- current compatible version
- license
- whether it adds network behavior
- whether it adds platform-specific risks

Prefer mature, minimal dependencies.

## 16. MVP acceptance criteria

The MVP is not complete until all of the following are true:

1. Android build succeeds.
2. iOS build succeeds on a supported macOS/iOS toolchain.
3. User can select a dhikr.
4. User can start a voice session.
5. Microphone permission is requested only when needed.
6. Recognition happens locally.
7. Repeated phrases can generate multiple count events.
8. Partial hypotheses do not double-count.
9. Unrelated speech is not normally counted.
10. Manual +1 works.
11. Target is optional.
12. Sessions are saved locally.
13. History is visible.
14. Raw audio is not persisted.
15. Core operation works without Internet access.
16. Privacy review finds no unexpected telemetry/network dependency.
17. Recognition test results are documented.
18. Model/license provenance is documented.

## 17. V1 non-goals

- general voice assistant
- cloud sync
- accounts
- social features
- advertisements
- auto-detect across the full library
- on-device neural-network fine-tuning
- wearable apps
- large analytics dashboards

## 18. Later roadmap

### V1.5

- better personalization
- auto-detect mode
- improved recognition on difficult accents/noise
- more custom dhikr support

### V2

- morning/evening adhkar routines
- configurable sequences
- wearables where practical
- richer local statistics
- desktop support

## 19. Success definition

The product succeeds technically when a normal user can put the phone down, recite a selected dhikr naturally, and trust that the final count closely tracks their actual repetitions without needing to touch the screen between repetitions.
