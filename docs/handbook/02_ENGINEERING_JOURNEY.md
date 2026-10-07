# 02. Engineering Journey, Hurdles & Solutions

Every significant engineering system evolves through hard-earned discoveries. This document chronicles the challenges faced during development, the hypotheses tested, the dead ends encountered, and the final solutions that shaped the Dhikr Counter into a robust, deterministic product.

---

## Hurdle 1: Neural ASR Hallucinations on Liturgical Chants

### The Challenge
Initially, we integrated on-device neural Automatic Speech Recognition (ASR) engines (evaluating **Whisper Base INT8**, **Whisper Tiny INT8**, **Moonshine Arabic ORT**, and **Tarteel Tiny Quran** via `sherpa-onnx`).

While these models performed acceptably on conversational Arabic or long Quranic verses, they exhibited severe degradation during **rapid, repetitive liturgical dhikr**:
* When a user rapidly recited *Astaghfirullah* once in an 800ms window, Moonshine had an estimated **~50% hallucination rate**, producing spurious Arabic sentences such as:
  * `"اكفي للنار"` (*"Sufficient for the fire"*)
  * `"مساء الخير يمه"` (*"Good evening mom"*)
  * `"نفهم"` (*"We understand"*)
  * `"ما عندك اي"` (*"You don't have any"*)
  * `"اوكي اوكي"` (*"Okay okay"*)
* The neural decoder tried to force short repetitive acoustic bursts into conversational grammar, causing false negatives (missed counts) and user frustration.

### The Fix
1. **Phoneme-Family Radical Gate:** We initially implemented a trilateral root matcher (`_isPlausibleTranscript`) that checked whether the ASR transcript shared Arabic root radicals (e.g. `غ-ف-ر` for *Astaghfirullah*). If not, the segment was immediately rejected as a hallucination.
2. **Full Decoupling of Neural ASR:** Ultimately, recognizing that neural ASR added ~150 MB to download size, consumed excessive CPU/battery, and was inherently probabilistic, we **decoupled the counting pipeline from ASR entirely**. Counting now relies on deterministic **Speech Envelope Analysis (ARe)**, while ASR remains strictly an optional, non-blocking background fallback.

---

## Hurdle 2: The Clap / Hand-Snap False Positive Dilemma

### The Challenge
During early testing with acoustic energy triggers, we noticed that non-speech sounds — such as a single hand clap, a finger snap, or a phone tapping against a desk — would falsely register as a dhikr repetition.

### The Physics & Signal Analysis
We inspected the raw PCM time-domain waveforms and discovered clear physical differentiators:
* **A Hand Clap:** An acoustic impulse with an extremely steep onset ($< 5\text{ms}$) and a total duration of **30ms to 120ms**.
* **Human Liturgical Speech:** Requires physical movement of articulators (tongue, lips, vocal cords). The shortest Arabic dhikr (*Allahu Akbar* or *Astaghfirullah*) physically takes **440ms to 900ms** to articulate.

### The Fix
1. **Physical Transient Floor:** In `LocalRecognitionEngine._handleSpeechSegment`, we established a hard duration floor:
   ```dart
   if (segment.duration.inMilliseconds < 200) {
     // Discard immediately: claps, snaps, and microphone thumps
     return;
   }
   ```
2. **Mean Repetition Duration Gate:** In `SpeechEnvelopeAnalyzer`, multi-repetition detection enforces `meanRepetitionDurationMs >= 440`. A burst of 3 rapid claps has an interval under 250ms and is rejected with 0 counts.
3. **Zero-Crossing Rate (ZCR) Verification:** Claps produce sharp broadband noise; speech produces alternating periodic vowel formants and fricative consonant bursts.

---

## Hurdle 3: The Native TTS "laha" Waqf / Sukūn Bug

### The Challenge
When using native Text-to-Speech (iOS `AVSpeechSynthesizer` and Android native TTS) to provide the audio speech guide, the engine was speaking:
> *"Astaghfirullaha"* instead of the proper liturgical pause *"Astaghfirullah"*.

### The Linguistic Cause
In classical Arabic grammar (*Naḥw*), words possess case endings (*I'rāb*). In continuous sentence speech, *Allāh* takes a fatḥa accusative (*Allāha* in *Astaghfiru-llāh-a*). However, in devotional dhikr and Quranic recitation, one must execute **Waqf** (pausal termination), where the final vowel is dropped and pronounced with a **Sukūn** (*Allāh*).

Because standard mobile TTS engines read Arabic as standard modern prose rather than liturgical recitation, they mechanically voiced the terminal short vowel unless a pausal boundary was explicitly enforced.

### The Fix
1. **Sukūn Standardization across the Canonical Library:** In `DhikrRepository`, we scrubbed all trailing case diacritics and standardized terminal words with explicit Sukūn / Waqf codas.
2. **Algorithmic Diacritic Stripping:** Created `ArabicNormalizer.enforceSukunCoda(text)`:
   ```dart
   // Strips trailing fatḥa (\u064E), ḍamma (\u064F), kasra (\u0650), etc.
   // and ensures terminal waqf representation.
   ```
3. **Pausal Boundary Injection:** In `ArabicSpeechGuideService.speakDhikr()`, we append an explicit grammatical sentence stop (`.`) to the cleaned text (`'$clean.'`). This forces iOS and Android speech synthesis engines to treat the phrase as an isolated pausal sentence boundary, producing a crisp, authentic *"lah"*.

---

## Hurdle 4: Screen Entrance Race Conditions & Visual Glitches

### The Challenge
When a user opened the active session screen:
1. The letter sweep animation started before the screen had even finished rendering its transition animation.
2. The breath cycle indicator showed `0 / 3` instead of clearly displaying the current step.
3. When reaching the target (e.g. 7 out of 7), the counter would reset back to `0` instantaneously before the user could even see that repetition `7 / 7` was reached.

### The Fix
1. **Gentle Settling Delay:** In `ActiveSessionScreen.didChangeDependencies`, added a `1200ms` settling timer before initiating the first repetition sweep. This gives the user time to settle and orient themselves.
2. **Target Holding State:** When the final repetition in a breath cycle completes (e.g. 3/3 or 7/7), the state keeps `_tripletCount` at full value during the 1.8-second breathing pause. The UI displays `3 / 3 • Take a breath... 🌿`, only resetting to `0` when the pause completes.
3. **Resilient Pause/Resume:** Wired `_pauseGuide()` and `_resumeGuide(dhikr)` into the session controller, ensuring that timers and animations freeze and resume seamlessly without skipping repetitions.

---

## Hurdle 5: Massive APK File Size (350 MB $\to$ 44 MB)

### The Challenge
When the first Android debug APK was compiled, its file size was **350 MB**, far too large for an offline utility app.

### Diagnostic Breakdown (`unzip -l app-debug.apk`)
1. **Fat Multi-Architecture Bundling:** The debug APK contained shared libraries (`libflutter.so`, `libonnxruntime.so`) compiled for three separate CPU architectures (`arm64-v8a`, `armeabi-v7a`, `x86_64`) simultaneously (~120 MB).
2. **Uncompressed Debug Symbols:** `kernel_blob.bin` and Dart VM debug snapshots accounted for ~55 MB.
3. **Unneeded Neural Model Weights:** The `assets/models/moonshine_arabic/` folder included ~141 MB of ONNX model binaries.

### The Fix
1. **Unbundled Heavy Neural Weights:** Because our mathematical waveform engine decoupled the need for local neural ASR, we commented out model asset bundling from `pubspec.yaml`.
2. **Ahead-of-Time (AOT) Tree-Shaking:** Compiled with `--release`, tree-shaking icons from 1.6 MB down to 9 KB (99.5% reduction) and compiling Dart to lean machine code.
3. **Split Per ABI (`--split-per-abi`):** Split the release build into targeted packages:
   * **`app-arm64-v8a-release.apk`:** **44.7 MB** (Modern 64-bit devices)
   * **`app-armeabi-v7a-release.apk`:** **33.7 MB** (Older 32-bit devices)
   * **Result:** **88% reduction in total application footprint.**
