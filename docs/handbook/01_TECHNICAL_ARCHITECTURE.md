# 01. Technical Architecture & Engineering Deep Dive

## 1. Architectural Overview & System Design

The application is engineered using **Flutter (Dart)** following strict clean-architecture boundaries: **Presentation**, **Domain**, **Data**, **Recognition / Audio DSP**, and **Platform Services**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                             │
│   ActiveSessionScreen   │  DhikrDetailScreen   │   SettingsScreen       │
│   - RecitationLetterSweep (ShaderMask RTL visual rhythm)               │
│   - Acoustic Telemetry Monitor (Real-time DSP inspection)              │
└────────────────────────────────────────────────────────────────────────┘
                                    │ consumes domain events
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                            DOMAIN LAYER                                │
│   SessionController          SettingsController    DhikrDefinition     │
│   - Session lifecycle        - Feedback modes      - 27 Sunnah prayers │
│   - Manual/Voice counting    - Pacing parameters   - Waqf sukūn codas  │
└────────────────────────────────────────────────────────────────────────┘
         │                                               │
         ▼                                               ▼
┌─────────────────────────────────┐   ┌──────────────────────────────────┐
│        DATA & PERSISTENCE       │   │        SERVICES & PLATFORM       │
│   LocalSessionRepository        │   │   ArabicSpeechGuideService       │
│   - SQLite / SharedPreferences  │   │   - Native TTS with pausal waqf  │
│   - Lifecycle draft restoration │   │   BackgroundListeningService     │
└─────────────────────────────────┘   └──────────────────────────────────┘
                                    ▲
                                    │ emits DhikrCountEvents
┌────────────────────────────────────────────────────────────────────────┐
│                   RECOGNITION & AUDIO DSP PIPELINE                     │
│                                                                        │
│   [Microphone Input] (RecordAudioSource - 16kHz mono PCM 16-bit)      │
│          │                                                             │
│          ▼                                                             │
│   [Voice Activity Detector] (Energy dBFS + adaptive noise floor)       │
│          │                                                             │
│          ▼                                                             │
│   [Transient Rejection Shield] (Duration floor < 200ms rejects claps)  │
│          │                                                             │
│          ▼                                                             │
│   [Speech Envelope Analyzer (ARe)]                                     │
│   ├── Root-Mean-Square (RMS) Energy Tracking (25ms sliding window)     │
│   ├── Zero-Crossing Rate (ZCR) voiced/unvoiced consonant gating        │
│   ├── Inter-peak valley depth evaluation (depth >= 0.22)               │
│   └── Temporal duration validation (minRepDurationMs >= 440ms)         │
│          │                                                             │
│          ▼                                                             │
│   [Streaming Repetition Detector & Cadence Tracker]                    │
│   └── Emits discrete DhikrCountEvent(source: voice, increment: N)      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Audio Processing Pipeline: How Waveform Counting Works

Rather than passing audio to cloud servers or running high-latency neural networks, repetitions are evaluated directly from raw 16-bit linear PCM audio buffers sampled at 16,000 Hz.

### A. Raw PCM Stream Ingestion (`RecordAudioSource`)
* Uses Flutter audio capture plugins configured for low latency, single-channel 16 kHz, 16-bit signed integer PCM.
* Buffers are emitted in real-time chunks of 100ms (1,600 samples) to ensure zero perceptible lag.

### B. Voice Activity Detector (`VoiceActivityDetector`)
* Computes real-time Root Mean Square (RMS) decibels relative to full scale:
  $$\text{dBFS} = 20 \log_{10}\left(\sqrt{\frac{1}{N} \sum_{i=1}^N x[i]^2}\right)$$
* Maintains an adaptive ambient noise floor using an exponential moving average ($\alpha = 0.05$).
* Distinguishes speech from silence using dynamic hangover windows:
  * **Short Dhikr (1-2 tokens):** 800ms hangover to bridge liturgical pauses between repetitions.
  * **Medium Dhikr (3-4 tokens):** 400ms hangover.
  * **Long Dhikr (5+ tokens):** 350ms hangover.

### C. Physical Transient & Clap Shield
Non-speech acoustic impulses (hand claps, table thumps, finger snaps, microphone handling) have distinct physical acoustic signatures compared to human speech:
* **Impulse Duration:** Hand claps exhibit an acoustic onset-to-decay duration of **30ms to 120ms**.
* **Physical Speech Constraints:** Articulating Arabic phonemes with vocal fold vibration physically requires at least **440ms to 800ms**.
* **Implementation:** Any segment arriving with duration $< 200\text{ms}$ is unconditionally dropped by `LocalRecognitionEngine` as an acoustic transient.

### D. The Speech Envelope Analyzer (`SpeechEnvelopeAnalyzer`)
The core repetition detection algorithm extracts the acoustic energy envelope across the segment:
1. **Windowed Energy Profiling:** Audio is sliced into overlapping 25ms frames with 10ms hops. The RMS energy is computed for each frame:
   $$E[k] = \sqrt{\frac{1}{M}\sum_{j=0}^{M-1} x[k \cdot H + j]^2}$$
2. **Smoothing:** A 5-point moving average filter removes high-frequency pitch jitter while retaining syllable and word-boundary dips.
3. **Valley & Peak Detection:**
   * Prominent energy peaks ($P_i$) and inter-repetition energy troughs ($V_i$) are identified.
   * A valid repetition boundary requires an energy drop of at least 22% relative to peak amplitude:
     $$\text{Depth} = \frac{\min(P_i, P_{i+1}) - V_i}{\min(P_i, P_{i+1})} \ge 0.22$$
4. **Zero-Crossing Rate (ZCR) Verification:**
   * Voiced vowels (like *a, u, i* in *Subhān*, *Allāh*) feature low ZCR and high periodic energy.
   * Sibilant consonants (like *s* in *Subhān*, *gh* in *Astaghfirullah*) feature high ZCR.
   * The presence of alternating ZCR and voiced segments verifies human phonetic articulation rather than monochromatic noise (fans, engines).
5. **Cadence Consistency:**
   * For multi-repetition segments (e.g. reciting *Astaghfirullah* 3 times in one continuous breath), the algorithm computes the variance of peak-to-peak durations:
     $$\text{Consistency} = 1.0 - \min\left(1.0, \frac{\sigma_{\text{intervals}}}{\mu_{\text{intervals}}}\right)$$
   * If intervals are rhythmic ($\ge 0.50$) and the mean repetition duration exceeds the minimum threshold ($\ge 440\text{ms}$), the segment produces an exact count event (e.g. $+3$).

---

## 3. UI/UX Architecture: Synchronized Multi-Sensory Rhythm

The active session interface is built around predictable visual and tactile rhythm.

### A. RTL Recitation Letter Sweep (`RecitationLetterSweep`)
* Uses custom Flutter `ShaderMask` and `LinearGradient` shaders moving from **Right to Left** (`Alignment.centerRight` $\to$ `Alignment.centerLeft`) to align with Arabic reading direction.
* **Three Visual States:**
  1. *Unread text:* Subdued 28% opacity.
  2. *Active reading cursor:* Glowing teal/cyan cursor highlighting the current letter.
  3. *Accepted text:* Radiant amber gold.
* **Celebration Pulse:** Upon every repetition increment ($+1$), a spring-physics scale animation flashes the entire Arabic phrase in radiant green.

### B. Breath Cadence Cycle State Machine
Liturgical chanting without breathing leads to fatigue. The screen implements a deterministic breath cycle:
```
Repetition 1 ──▶ Repetition 2 ──▶ Repetition 3 ──▶ BREATH PAUSE (1.8s) ──▶ Repetition 1
```
* **Customizable Cadence:** Users can configure breathing intervals from **1 to 10 repetitions** (default: 3).
* **Pause Behavior:** During the 1.8-second breathing pause:
  * The letter sweep stops.
  * TTS speech guide is silenced immediately.
  * A calming banner appears: `3 / 3 • Take a breath... 🌿`.
  * Haptic feedback vibrates softly to signal the user to inhale.
  * Cycle dots reset cleanly upon resumption.

---

## 4. State Management & Lifecycle Resilience

* **`SessionController` (ChangeNotifier):** Manages the authoritative state of the current session (`DhikrSession`), tracking count, elapsed active duration, target, status (`active`, `paused`, `completed`), and pacing.
* **Pause-Proof Manual Counter:** When a session is paused:
  * Speech recognition and microphone streams are stopped.
  * Sweep animations and TTS audio are frozen.
  * The `Manual +1 Tap` button remains 100% active. Clicking it updates the session count, triggers light haptic feedback, and updates persistent storage.
* **Draft Auto-Save:** Every single increment is persisted synchronously to `SharedPreferences` as an active draft. If the phone receives a phone call, runs out of battery, or the user switches apps, the session state is restored seamlessly upon return.
