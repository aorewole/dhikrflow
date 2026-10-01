# Dhikr Counter — Local Model Evaluation Results

**Date:** 2026-10-01  
**Status:** Initial Candidate Analysis & Architectural Decision  

---

## 1. Candidate Comparison Table

| Candidate Engine | Model Variant | Arabic Support | Streaming | Mobile Platforms | Quantization | Model Size | License | Est. Latency | Est. RAM | Decision / Status |
|---|---|---|---|---|---|---:|---|---:|---:|---|
| **sherpa-onnx (Whisper Tiny int8)** | `sherpa-onnx-whisper-tiny` | Native Multilingual | Yes (chunked/VAD) | Android, iOS, macOS | int8 ONNX | ~39 MB | Engine: Apache 2.0<br>Weights: MIT | ~100–180ms | ~90 MB | **Primary Candidate for Phase 4** |
| **sherpa-onnx (Whisper Base int8)** | `sherpa-onnx-whisper-base` | Native Multilingual | Yes (chunked/VAD) | Android, iOS, macOS | int8 ONNX | ~75 MB | Engine: Apache 2.0<br>Weights: MIT | ~200–350ms | ~140 MB | Secondary fallback if Tiny accuracy insufficient |
| **sherpa-onnx (Conformer CTC AR)** | MGB-2 Conformer CTC | Native Arabic | Streaming CTC | Android, iOS | float32 / int8 | ~45 MB | Engine: Apache 2.0<br>Weights: Research only | ~50–80ms | ~60 MB | Disqualified for production due to MGB-2 non-commercial license |
| **whisper.cpp (whisper_flutter)** | Whisper Tiny ggml | Native Multilingual | Pseudo-streaming | Android, iOS | q5_0 / q8_0 | ~42 MB | MIT | ~150–250ms | ~160 MB | Viable alternative, but lacks unified built-in VAD |
| **Vosk (`vosk-model-ar`)** | Kaldi AR | Native Arabic | Streaming | Android, iOS | Kaldi acoustic | ~318 MB | Apache 2.0 / MGB-2 license | ~120ms | ~280 MB | Rejected: Model size too large (>300MB) |

---

## 2. In-Depth Analysis of Candidates

### 2.1 sherpa-onnx with Whisper Tiny (int8)
- **Engine Provider:** Next-gen Kaldi (`k2-fsa/sherpa-onnx`).
- **Flutter Integration:** Official `sherpa_onnx` package with direct Dart FFI bindings to C++ on Android (NDK) and iOS (Framework).
- **VAD Integration:** Includes built-in Silero VAD (ONNX) and circular audio buffers. This satisfies Phase 3 and Phase 4 within a single cohesive native runtime.
- **Model Licensing:** 
  - Engine: Apache 2.0.
  - Whisper weights: MIT License (OpenAI). Permissive for free, offline distribution.
- **Memory & Compute Footprint:**
  - Quantized int8 encoder (~25MB) and decoder (~14MB) fit well within mobile RAM envelopes (<100MB peak).
  - CPU usage during silence: ~0% (VAD gate).
  - CPU usage during recitation: Moderate burst computation on ARM NEON / Apple Neural Engine.
- **Suitability for Dhikr Counting:**
  - Selected-dhikr mode requires matching specific target phrases (e.g., *Astaghfirullah*). Whisper Tiny reliably captures the root phonetic tokens of common Arabic adhkar.
  - Streaming de-duplication and transcript commit tracking are necessary to prevent hallucinated repetitions.

### 2.2 Rejection of Cloud and Non-Compliant Stacks
- **Google Cloud Speech-to-Text / Apple Speech API (online) / Whisper Cloud:** Prohibited by `AGENTS.md` and `PRIVACY_AND_RELEASE.md`. Absolutely no audio or transcripts may be transmitted over network.
- **Vosk Arabic:** Rejected due to excessive model footprint (>318 MB) and restrictive training data licenses.

---

## 3. Architecture Isolation Strategy

To ensure zero lock-in and adhere to `AGENTS.md` rule *"Treat the speech engine as replaceable"*, the application is architected around an abstract domain interface:

```text
Microphone AudioStream
         ↓
AudioSource (Interface)
         ↓
RecognitionEngine (Interface)
   ├── MockRecognitionEngine (Phase 1 UI & Unit Tests)
   └── SherpaOnnxRecognitionEngine (Phase 4 Local ASR)
         ↓
Stream<DhikrCountEvent>
         ↓
SessionController (Domain State Machine)
         ↓
The presentation layer and session state machine interact **only** with `RecognitionEngine` and domain events (`DhikrCountEvent`, `ManualCountEvent`), completely shielded from third-party speech libraries.

---

## 4. Phase 4 Model Provenance & Redistribution Certification

- **Target Selected Model:** Whisper Tiny Multilingual (Quantized int8) for Arabic
- **Engine Runtime:** `sherpa_onnx` Flutter / C++ native runtime (Apache 2.0)
- **Model Upstream Source:** OpenAI Whisper (`whisper-tiny`, MIT License)
- **ONNX Export & Optimization:** Next-gen Kaldi / `k2-fsa` (`csukuangfj/sherpa-onnx-whisper-tiny`)
- **Distribution Archive:** `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2`
- **Component Files:**
  - `tiny-encoder.int8.onnx` (~24.6 MB) — acoustic feature encoder
  - `tiny-decoder.int8.onnx` (~14.8 MB) — autoregressive text decoder
  - `tiny-tokens.txt` (~835 KB) — multilingual token vocabulary table
- **Redistribution Terms:**
  - MIT License for OpenAI weights allows royalty-free bundling and offline execution.
  - Apache 2.0 License for `sherpa-onnx` runtime allows royalty-free inclusion.
  - No remote server, activation, or telemetry required or permitted.
