# Dhikr Counter — Persistent Agent Rules

These instructions are continuously active for this project.

## Product mission

Build a free, privacy-first, offline hands-free dhikr counter.

The primary experience is:

**Select dhikr → Start → Recite → count repetitions automatically.**

The app is not a voice assistant and is not a cloud transcription service.

## Non-negotiable privacy rules

- Core functionality must work with no Internet connection.
- Speech recognition must happen locally on the device.
- Never upload microphone audio.
- Never persist raw microphone audio as an application feature.
- Do not add analytics or telemetry.
- Do not add Firebase unless a future requirement explicitly changes the privacy model; until then, it is prohibited.
- Do not add cloud speech-to-text APIs.
- Do not add advertising SDKs.
- Do not add user accounts/authentication for the MVP.
- Do not transmit recognition transcripts remotely.
- Do not require network permission for the core feature if it can reasonably be avoided.
- Local notifications may be used for reminders without a server.

## Product scope rules

MVP must prioritize:

- Android + iOS through Flutter.
- Selected-dhikr mode.
- Local VAD.
- Offline Arabic-capable speech recognition.
- Repetition detection in continuous/rapid recitation.
- Confidence-aware counting.
- Manual +1 fallback.
- Optional target.
- Local session history.
- Arabic + transliteration + translation.
- Optional haptics.
- Optional screen-off/background listening where platform rules permit it.

Do not expand MVP with social features, cloud sync, accounts, smart watches, large statistics systems, or auto-detect before the core recognition/counting experience is reliable.

Auto-detect and personalized voice calibration are future-ready architectural requirements, not reasons to complicate V1.

## Recognition architecture rules

Treat the speech engine as replaceable.

Required conceptual pipeline:

Microphone
→ audio stream
→ VAD
→ local ASR
→ Arabic normalization
→ phrase matching
→ confidence evaluation
→ streaming de-duplication/repetition detection
→ count event

The UI must consume domain-level recognition/count events rather than raw ASR output.

Never count every partial transcript emitted by a streaming recognizer. Partial hypotheses must be reconciled into newly committed content or equivalent stable events before phrase matches become count events.

A single continuous speech stream may contain several repetitions. The system must be able to produce multiple count events from one recognition segment.

Example:

`Astaghfirullah Astaghfirullah Astaghfirullah Astaghfirullah`

must be capable of producing `+4`.

Do not use an arbitrary hard-coded delay as the sole mechanism for counting repetitions.

Confidence thresholds must be configurable and calibrated with test data.

## Personal calibration rules

If calibration is implemented later, call it **personal calibration**, not model training.

The user may provide examples of their own recitation. Process them locally. Do not retain raw example audio unless a future requirement explicitly requires it and the privacy model is deliberately updated.

Do not attempt full neural-network training/fine-tuning on the phone for MVP.

## Model selection rules

Do not blindly choose a speech model.

Evaluate candidate local models using:

- Arabic recognition quality.
- phrase-level recall.
- false-positive rate.
- repeated-phrase accuracy.
- fast-recitation behavior.
- low-volume behavior.
- model size.
- peak and steady-state memory use.
- CPU utilization.
- latency.
- real-time factor.
- battery implications.
- Android/iOS compatibility.
- package compatibility.
- license and redistribution terms.

sherpa-onnx is a candidate to investigate because it provides offline/on-device speech recognition options and Flutter/platform integrations, but it is not a mandatory dependency. Verify current docs and model licenses at implementation time.

Never bundle model weights without documenting the exact source, version, license, and redistribution conditions.

## Flutter architecture rules

Prefer a clean, feature-oriented architecture with clear separation between:

- presentation
- domain
- data
- recognition
- platform integration

Keep Dart business logic platform-independent wherever possible.

Platform-specific audio/background behavior should sit behind interfaces/services rather than leak through the UI.

Avoid dependency sprawl.

Every third-party dependency must have a documented reason for inclusion.

## Code quality

- Use null-safe Dart.
- Keep files cohesive and reasonably small.
- Prefer clear names over clever abstractions.
- Avoid premature abstractions that do not support an actual requirement.
- Keep recognition components independently testable.
- Add unit tests for non-trivial domain logic.
- Use integration tests for microphone/session behavior where practical.
- Run formatter, analyzer, and tests before considering a phase complete.
- Do not hide build failures behind ignored errors.

## UI/UX rules

The UI should be calm, modern, accessible, and uncluttered.

The active session screen should emphasize:

- count
- Arabic dhikr
- transliteration
- translation
- listening state
- target/progress when enabled
- manual +1
- pause/end controls

Do not make the screen look like a chatbot.

Avoid excessive decorative Islamic motifs. Let typography, spacing, subtle motion, and hierarchy carry the visual language.

Support light and dark themes.

Respect large text/accessibility settings.

## Session rules

Sessions are local.

Persist enough state to survive ordinary lifecycle interruptions.

A user-provided target is optional.

If no target is set, do not fabricate one.

Reaching a target must not automatically stop a session unless the user explicitly enables that behavior in a future setting.

Manual +1 must be available as fallback.

## Security and privacy review

Before each milestone, ask:

- Did we introduce network access?
- Did we introduce a new permission?
- Did we store raw audio?
- Did we introduce telemetry?
- Did we add a package that phones home?
- Did we bundle any model with unclear licensing?
- Can the core feature still work in Airplane Mode?

If any answer is problematic, stop and document it rather than silently proceeding.

## Development process

Work in small verified phases.

Before a large implementation:

1. Inspect existing files.
2. Read the relevant project docs.
3. Make a concrete plan.
4. Implement the smallest useful slice.
5. Run tests and static analysis.
6. Review the diff.
7. Update project documentation.

Do not rewrite unrelated files.

Do not ask broad product questions that have already been answered by the project documents.

When a genuine technical ambiguity remains, make the safest reversible choice and document the assumption.
