# The Story of DhikrPulse (ذِكْر بَلْس)

> **A Founder’s Chronicle: From Cloud Doubts and the Neural AI Trap to the Triumph of Pure Mathematical Signal Processing**  
> *By Ammaar Orewole — with Google Antigravity as AI Engineering Partner*  
> *Documenting the complete vision, every dead end, acoustic hurdles, breakthrough architecture, and open-sourcing the finished application for the global Ummah.*

---

## 💡 Prologue: The Simple Question

Every great project begins with a personal itch that existing technology refuses to scratch. For me, it started with a quiet question:

**Why isn't there a truly free, 100% offline, privacy-first, hands-free Dhikr counter in the world?**

In our daily spiritual lives as Muslims, performing *Adhkar* (sacred liturgical phrases of remembrance like *SubhanAllah*, *Alhamdulillah*, *Allahu Akbar*, and *Astaghfirullah*) often occurs in hands-occupied or serene moments:
* Driving during long morning commutes,
* Rocking an infant to sleep in the dark,
* Walking outdoors,
* Or sitting in peaceful contemplation before dawn.

Existing digital tasbih counters force users into a mechanical ritual: tapping a physical phone screen over and over again. Every tap breaks *khushū‘* (spiritual presence), demands visual focus, and turns remembrance into mindless screen interaction.

Meanwhile, the few voice-activated apps on app stores were plagued by compromises:
1. Cluttered with intrusive full-screen video ads,
2. Demanding user signups and social logins, or worst of all,
3. **Streaming private microphone audio over the internet to commercial cloud servers.**

For a Muslim in quiet prayer, streaming intimate recitations and raw bedroom/car audio to remote cloud machines was an absolute non-starter. 

I established non-negotiable architectural boundaries from Day One:
* **100% Offline (Airplane Mode Ready):** Not a single byte of audio or telemetry can ever leave the device.
* **Zero Audio Persistence:** Raw microphone audio must never be saved to flash storage or retained.
* **Zero Commercial Distractions:** No ads, no tracking, no paid subscriptions.
* **Effortless Hands-Free Recitation:** Place the phone down, recite naturally, and let the counter advance automatically.

What began as an apparently simple app turned into an intense deep-tech journey through neural speech recognition, mobile DSP, hardware acoustic echo cancellation, and ultimately, a profound revelation about the limits of modern AI.

---

## Chapter 1: The Neural AI Mirage

Naturally, my initial instinct was to look at modern deep learning speech recognition. I investigated on-device Automatic Speech Recognition (ASR) engines, evaluating **OpenAI Whisper Base INT8**, **Whisper Tiny INT8**, and **Moonshine Arabic ORT** running locally on mobile hardware via ONNX Runtime.

The theoretical appeal was obvious: an on-device neural model would listen to microphone audio, transcribe the spoken Arabic words, and match them against the active dhikr phrase.

### The Catastrophic Hallucination Reality
When I took these models out of static benchmarks and tested them on real-world continuous recitation, the illusion shattered.

Sacred liturgical dhikr has unique acoustic properties: people recite phrases rapidly, softly, and repeatedly in rhythmic cycles (e.g. repeating *Astaghfirullah, Astaghfirullah, Astaghfirullah* in rapid succession). 

When a user rapidly recited *Astaghfirullah* once in an 800ms window, the neural model hallucinated with a staggering **~50% error rate**. Instead of recognizing the phrase, the neural sequence decoder tried to force short repetitive acoustic bursts into modern conversational Arabic grammar, producing absurd dialect sentences:
* `"اكفي للنار"` (*"Sufficient for the fire"*)
* `"مساء الخير يمه"` (*"Good evening mom"*)
* `"ما عندك اي"` (*"You don't have any"*)
* `"نفهم"` (*"We understand"*)
* `"اوكي اوكي"` (*"Okay okay"*)

Because the decoded text was random dialect nonsense, the phrase matcher missed the count completely. A user pouring their heart into repentance was met with a frozen counter.

---

## Chapter 2: The Fork in the Road & The Abandoned AI Training Pipeline

Faced with this failure, I initially considered the conventional AI route:
> *"What if I train a dedicated, fine-tuned neural model specifically on liturgical Arabic dhikr? I could set up an open voice donation initiative, collect thousands of community recordings, and train a specialized neural acoustic model."*

I mapped out dataset schemas, augmentation pipelines, and audio collection strategies. 

**Then I stopped and questioned my fundamental premise.**

Taking the custom neural AI route meant:
1. Asking users to donate private voice recordings—contradicting my core privacy philosophy.
2. Managing complex dataset infrastructure, cloud training costs, and retraining cycles.
3. Forcing every mobile user to download **100 MB to 200 MB** of neural model weights.
4. Burning phone battery and heating mobile processors running matrix multiplications on every spoken second.
5. Inherent unpredictability: neural decoders are probabilistic by design and can still hallucinate in noisy environments.

I asked myself: **Do I actually need a multi-million-parameter neural network just to count repetitions of a phrase the user has already explicitly selected?**

The answer was a resounding **no**.

---

## Chapter 3: The Breakthrough — Pure Native Dart Mathematical Signal Processing

The user already tells the app which dhikr they are reciting: *SubhanAllah*, *Alhamdulillah*, or *Astaghfirullah*. The task is not open-domain transcription; it is **rhythmic acoustic repetition verification**.

I scrapped the neural models entirely. No ONNX runtime, no PyTorch exports, no voice donation pipeline, and no heavy neural weights.

Instead, I engineered a native Dart digital signal processing engine: the **Speech Envelope Analyzer (ARe)**.

```
Microphone Stream (16kHz Mono 16-bit Linear PCM)
        │
        ▼
Voice Activity Detector (VAD) (Adaptive dBFS Noise Floor)
        │
        ▼
Physical Transient Shield (<200ms drops claps & table bumps)
        │
        ▼
Mathematical Speech Envelope Analyzer (ARe)
├── 25ms Overlapping Sliding Window RMS Energy Extraction
├── 5-Point Moving Average Smoothing Filter
├── Prominent Energy Peak (Pi) & Trough (Vi) Valley Detection (Depth >= 0.22)
└── Zero-Crossing Rate (ZCR) Voiced/Unvoiced Consonant Formant Gate
        │
        ▼
Streaming Repetition Detector & Cadence Tracker
        │
        ▼
Discrete DhikrCountEvent (Increment: +1, +2, +4) ──► Session State & UI
```

### Why Mathematical DSP Won Decisively:
* **0 MB Weight Footprint:** Zero neural weight files. The entire acoustic engine is compiled directly into native Dart machine code.
* **Microsecond Execution Time:** Frame analysis runs in fractions of a millisecond on the CPU, using virtually zero battery.
* **Deterministic Precision:** Math does not hallucinate. An energy valley between two spoken words is a physical acoustic fact, not a probabilistic guess.
* **Rapid Recitation Mastery:** A single continuous breath containing `Astaghfirullah Astaghfirullah Astaghfirullah Astaghfirullah` naturally produces 4 distinct energy peaks and valleys, cleanly registering an exact `+4` count event.

---

## Chapter 4: Conquering Real-World Hardware Hurdles

Building on real hardware revealed hurdles that theoretical designs never anticipate. Each was diagnosed and conquered:

### Hurdle 1: The Hand-Clap & Table-Bump Dilemma
Early tests showed that a sharp hand clap or phone bump against a desk could cause a false count.  
**The Solution:** I analyzed the time-domain waveforms. A clap is a mechanical impulse lasting only **30ms to 120ms**. Human vocal tract phonation physically requires at least **440ms to 800ms** to articulate syllables. I established a hard physical duration floor: any sound under **200ms** is unconditionally discarded, and repetition periods under **440ms** are rejected. Claps, snaps, and knocks produce zero false counts.

### Hurdle 2: Voice Guide Speaker-to-Mic Feedback Loop (Hardware AEC)
In Voice Guide mode, the phone's speaker chants the dhikr to set the pace while the user recites along in unison. But the phone's microphone was picking up the speaker's own output, counting even when the user remained silent!  
**The Solution:** I enabled device-level **Acoustic Echo Cancellation (AEC)** by routing audio through hardware communication channels (`AVAudioSessionModeVoiceChat` on iOS and `VOICE_COMMUNICATION` audio source on Android). The operating system's dedicated DSP chip cancels the speaker output from the microphone feed in real time, enabling the user to recite alongside the audio guide without feedback loops.

### Hurdle 3: The Classical Waqf & Sukūn Coda Bug
Native speech synthesizers were pronouncing *"Astaghfirullaha"* with an accusative fatḥa case ending instead of the proper devotional pause *"Astaghfirullah"*.  
**The Solution:** In classical Arabic grammar, devotional chanting requires **Waqf** (pausal termination) with a **Sukūn** on terminal letters. I algorithmically scrubbed trailing case vowels from all 27 canonical adhkar and injected sentence boundaries (`.`) into the audio guide pipeline to enforce authentic pausal recitation.

### Hurdle 4: The iOS Shadda-Fatḥa Glyph Glitch
On iOS CoreText, combining standard Unicode tashkeel on the sacred name of Allah (*Lafdh al-Jalālah*) caused a floating, superimposed fatḥa to render on top of the shadda.  
**The Solution:** I replaced composed text strings with the canonical Quranic Unicode representation `ٱللّٰه`, rendering classical Uthmani typography with pristine beauty across all iOS and Android devices.

---

## Chapter 5: Designing a Sanctuary of Calm

Technology should serve worship, not distract from it. Every visual and tactile element in DhikrPulse was crafted with spiritual intentionality:

* **3-Stage Decrescendo Breath Wave:** To distinguish counting vibrations from breathing alerts for pocket recitation, breathing triggers a gentle 3-stage tactile wave (`Heavy` $\to$ `Medium` $\to$ `Light`), paired with a soothing reminder: *"3 / 3 • Take a breath... 🌿"*.
* **Golden Tajweed Letter Sweep:** A custom shader highlights Arabic script from Right to Left at authentic Slow, Medium, or Fast tempos.
* **Pause-Proof Manual +1 Button:** If you enter a quiet masjid or someone sits next to you, tap Pause. The manual thumb button remains 100% active, updating your count and session draft silently.
* **Interactive Spotlight Tour:** New users are greeted with a quiet, interactive walkthrough highlighting the core controls. The tour never annoys you again, but can be summoned anytime via the `?` Help button.
* **Tiny 45 MB Footprint:** Stripped of unnecessary debug snapshots and neural weights, the standalone release APK dropped from 350 MB to **44.7 MB**.

---

## Chapter 6: An Open-Source Gift to the Ummah

Today, **DhikrPulse (ذِكْر بَلْس)** is complete, thoroughly tested (136 unit and integration tests passing), and released to the world under the permissive **MIT License**.

There are no servers to maintain, no cloud subscriptions to renew, and no AI models to train. It is a complete, self-contained, privacy-respecting work of engineering.

### To Fellow Developers & Creators:
You can clone this repository, inspect how mathematical acoustic envelope tracking outperforms neural networks on constrained mobile devices, and build upon it:
* Fork the repo on GitHub: [github.com/aorewole/dhikrpulse](https://github.com/aorewole/dhikrpulse)
* Run `flutter test` and explore the mathematical tests in `test/recognition/speech_envelope_analyzer_test.dart`.
* Port it, translate it, or adapt the DSP algorithms for your own community.

May this application bring peace, presence, and consistent remembrance to Muslims everywhere.

**— Ammaar Orewole**  
*Creator of DhikrPulse*
