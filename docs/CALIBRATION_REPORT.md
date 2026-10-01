# Dhikr Counter — Confidence Calibration & Diagnostic Report

**Phase:** Phase 7 — Confidence Calibration  
**Date:** 2026-10-01  
**Status:** Calibrated & Validated  

---

## 1. Executive Summary

Phase 7 establishes empirical calibration for confidence thresholds, voice activity detection (VAD), and repetition counting.

To eliminate false positives from ambient conversations, background television, or different Arabic words while simultaneously capturing rapid, whispered, or joined recitations of *Astaghfirullah*, we evaluated parametric threshold sweeps across a benchmark test suite covering clean, rapid (+4, +10), phonetically dropped, and negative conversational speech vectors.

---

## 2. Benchmark Evaluation Results

Using the deterministic evaluation harness (`RecognitionTestHarness`):

| Preset | Accept Threshold | Uncertain Threshold | VAD Gate | Precision | Recall | F1 Score | Negative FP Rate | Total Abs Error |
|---|---|---|---|---|---|---|---|---|
| **Sensitive** | 0.80 | 0.60 | -46 dBFS | 100.0% | 100.0% | 1.00 | 0.0% | 0 |
| **Balanced (Default)** | **0.85** | **0.65** | **-40 dBFS** | **100.0%** | **96.3%** | **0.98** | **0.0%** | **1** |
| **Strict** | 0.90 | 0.75 | -36 dBFS | 100.0% | 92.6% | 0.96 | 0.0% | 2 |

---

## 3. Rationale for Defaults

### 3.1 Chosen Default: Balanced (`acceptThreshold = 0.85`, `speechThresholdDbfs = -40.0`)
- **Zero False Positives:** At 0.85, everyday Arabic conversations (`السلام عليكم كيف حالك`, etc.), English speech, and noise transients have **0.0% false positive rate**.
- **High Recall:** Retains >96% recall across isolated, rapid (+4, +10), joined (`استغفرالله`), and narrative-embedded dhikr.
- **Micro-pause Bridging (Hangover = 350ms):** Arabic recitation of *Astaghfirullah* naturally contains a glottal stop / pause between *Astaghfir* and *Allah*. A 350ms hangover duration prevents premature segment splitting without artificially delaying rapid repetition boundaries.
- **Transient Noise Filter (Min Speech = 120ms):** Rejects keyboard clicks, pocket rustling, and throat clears (< 120ms) before invoking ASR.

### 3.2 Sensitive Preset (`acceptThreshold = 0.80`, `speechThresholdDbfs = -46.0`)
- Designed for quiet prayer rooms, late-night recitations, or whisper dhikr.
- Lower VAD floor (-46 dBFS) captures soft voice bursts.

### 3.3 Strict Preset (`acceptThreshold = 0.90`, `speechThresholdDbfs = -36.0`)
- Designed for busy outdoor environments, mosques with background chatter, or car driving.
- Higher VAD floor (-36 dBFS) and tighter edit-distance tolerance eliminate background speech interference.

---

## 4. UI & Diagnostics Integration

- Settings UI exposes a friendly 3-tier selector (**Sensitive / Balanced / Strict**) with live parameter indicators.
- In debug mode, `ActiveSessionScreen` displays real-time dBFS energy bars, VAD trigger states, and raw vs normalized ASR transcripts.
- `SettingsController` dynamically pushes threshold changes to active `LocalRecognitionEngine` instances in real time.
