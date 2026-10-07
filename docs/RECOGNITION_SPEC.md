# Dhikr Counter — Recognition Engineering Specification

## 1. Goal

Recognize repetitions of a selected short dhikr locally and turn them into count events with low false-positive and low missed-count rates.

The recognizer is **not** required to transcribe the user's entire environment perfectly.

The target output is:

```text
DhikrCountEvent(
  phraseId,
  confidence,
  timestamp,
  source = voice | manual,
)
```

## 2. Pipeline

```text
Microphone
   ↓
Audio stream
   ↓
VAD
   ↓
Streaming local ASR
   ↓
Partial transcript
   ↓
Commit/segment tracking
   ↓
Arabic normalization
   ↓
Phrase matching
   ↓
Candidate repetitions
   ↓
Confidence evaluation
   ↓
De-duplication
   ↓
Count events
```

## 3. Audio constraints

Prefer a simple mobile-friendly audio format such as mono PCM at a sample rate supported by the selected model.

Do not hard-code an audio format until the chosen ASR model is verified.

The audio source should expose an abstraction such as:

```dart
abstract interface class AudioSource {
  Stream<AudioChunk> get chunks;
  Future<void> start();
  Future<void> stop();
}
```

## 4. VAD

VAD should reduce ASR work during silence.

Desired behavior:

- idle when there is no speech
- start recognition work when speech begins
- stop/reduce work when speech ends
- recover from short intra-phrase pauses without prematurely splitting the phrase

VAD parameters must be configurable and testable.

Avoid using a simple fixed timer as the only segment boundary.

## 5. Streaming recognition

The engine may expose partial and final/committed hypotheses.

Example:

```text
P0: "استغفر"
P1: "استغفر الله"
P2: "استغفر الله استغفر"
P3: "استغفر الله استغفر الله"
```

The system must not count the same occurrence repeatedly across P0/P1/P2/P3.

Maintain a committed/transcript state or equivalent event identity.

## 6. Arabic normalization

Centralize normalization in one module.

Potential transformations include, subject to test evidence:

- removing diacritics for comparison
- normalizing common alef variants
- normalizing spacing
- removing punctuation
- canonicalizing recognized Arabic forms

Keep canonical display text separate from normalized recognition text.

Do not alter the visible Qur'anic/Arabic source text merely to make matching easier.

## 7. Phrase dictionary

Each phrase can maintain:

- canonical Arabic
- normalized Arabic
- transliteration
- aliases
- optional alternative recognized forms
- category

Example conceptual representation:

```text
canonical:
أستغفر الله

normalized:
استغفر الله

aliases:
استغفر بالله   [only if validated; do not invent]
```

Do not add linguistic aliases without evidence that they are appropriate.

## 8. Phrase matching

MVP should prefer high-precision matching for a selected phrase.

Potential matching layers:

### Layer 1 — exact normalized text

Fastest and strongest signal.

### Layer 2 — controlled fuzzy text similarity

Useful for ASR spelling/segmentation variation.

### Layer 3 — acoustic/model-level evidence

Use only if the selected model/tooling exposes a useful signal.

### Layer 4 — personal calibration

Future enhancement.

The final confidence should combine available evidence rather than rely on one arbitrary threshold.

## 9. Repetition detection

The hardest requirement is multiple repetitions in a continuous stream.

Example input:

```text
Astaghfirullah Astaghfirullah Astaghfirullah Astaghfirullah
```

Expected:

```text
+4
```

If a recognizer returns one long transcript, tokenize/align it to identify four non-overlapping occurrences.

If the recognizer returns evolving partial transcripts, calculate newly committed phrase occurrences so the same occurrence is not counted twice.

## 10. Rapid speech

Do not require the user to pause for a preset long delay between repetitions.

The user should be allowed to repeat the same dhikr naturally and quickly.

Use speech evidence, transcript alignment, token timing when available, or another robust event-identification mechanism instead of assuming a repetition boundary is always a fixed number of milliseconds.

## 11. Confidence policy & Bayesian Cadence Prior

The system must support at minimum:

```text
ACCEPT
IGNORE
UNCERTAIN
```

For MVP, uncertain candidates do not increment the automatic counter unless rescued by rhythmic cadence.

### Bayesian Cadence Prior (Temporal Rhythm Matching)

In Selected-Dhikr Mode, reciters naturally lock into a predictable rhythmic pace (cadence) during cyclical tasbih (e.g. 900ms – 1300ms per repetition). The system tracks the rolling median duration of confirmed recitations:

1. **Tier 1 (High Acoustic Match $\ge$ acceptThreshold)**: Accepts unconditionally and updates the `RecitationCadenceTracker`.
2. **Tier 2 (Cadence-Assisted Near-Miss Rescue)**: If acoustic similarity is in the near-match band (`uncertainThreshold` $\le$ score $<$ `acceptThreshold`) AND the speech segment duration matches the user's established cadence window ($\pm 35\%$), a cadence bonus (+0.18) is applied to promote the candidate to **ACCEPT (+1)**.
3. **Tier 3 (Noise / Unrelated speech $<$ uncertainThreshold)**: Rejected regardless of duration.

Expose recognition diagnostics in developer/test builds so thresholds and pace metrics can be inspected without exposing technical clutter to normal users.

## 12. Count-event semantics

Only one authoritative layer should mutate the session count.

Recommended:

```text
Recognition engine
       ↓
CountEvent stream
       ↓
SessionController
       ↓
Session state
       ↓
Persistence
```

The UI must not independently increment the count when it renders a recognition event.

## 13. Manual fallback semantics

Manual +1 is a direct domain event:

```text
ManualCountEvent
```

It should pass through the same SessionController that handles voice count events.

## 14. Personal calibration

Do not implement end-to-end model training for MVP.

Future calibration may use:

- phrase-specific thresholds
- user-specific acoustic statistics
- local embeddings/reranking where supported
- pronunciation/segmentation patterns learned from examples

Calibration data must be stored without raw audio by default.

## 15. Auto-detect

Future architecture:

```text
Speech
 ↓
ASR
 ↓
Normalization
 ↓
Local phrase candidates
 ↓
Similarity / confidence
 ↓
Selected best supported phrase
 ↓
Count event
```

Must include safeguards against accidental target switching.

## 16. Candidate technology evaluation

Investigate local/offline engines that work well with Flutter/mobile.

sherpa-onnx is one candidate because it provides local/offline recognition and Flutter examples/integration. Verify the exact current Flutter API, model availability, licenses, and platform compatibility at implementation time.

The final engine choice must be recorded in `docs/MODEL_EVALUATION_RESULTS.md` with:

- engine/model name
- exact version/commit/model date where applicable
- model size
- quantization
- license
- Android results
- iOS results
- accuracy metrics
- CPU/memory metrics
- latency metrics
- reason for decision

## 17. Recognition proof-of-concept test set

Create test audio with consent from test speakers or synthetic/permissioned test material.

Test:

### Speech speed

- slow
- normal
- fast
- rapid continuous

### Volume

- quiet
- normal
- loud

### Speaker variation

- multiple voices
- different accents/dialects
- different microphones

### Environment

- quiet room
- fan noise
- street noise
- background conversation

### Phrase scenarios

1. Single target phrase.
2. Two target repetitions.
3. Four fast target repetitions.
4. Ten target repetitions.
5. Target mixed with unrelated speech.
6. Other dhikr mixed with target.
7. Partial/noisy speech.

## 18. Metrics

Record:

- repetition recall
- false-positive count
- missed repetition count
- precision
- count error per session
- median recognition latency
- worst-case recognition latency
- peak memory
- average CPU during active recognition
- battery impact where practical

For a session with ground truth `N` and detected count `D`:

```text
count_error = D - N
absolute_count_error = abs(D - N)
```

The goal is not merely high generic ASR word accuracy. The primary product metric is correct dhikr repetition counting.
