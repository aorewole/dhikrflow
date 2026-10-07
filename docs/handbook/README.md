# Dhikr Counter Project Compendium & Knowledge Archive

> **A 100% Offline, Privacy-First, Hands-Free Intelligent Dhikr Companion for iOS & Android.**

---

## Welcome to the Project Compendium

This directory contains the definitive, comprehensive documentation of the **Dhikr Counter** application — from its foundational product philosophy to its deep mathematical audio engineering, its journey through neural speech models and eventual decoupling, and user guides for both general readers and systems engineers.

```
docs/handbook/
├── 00_EXECUTIVE_SUMMARY.md      <-- Non-technical overview: What the app is & why it matters
├── 01_TECHNICAL_ARCHITECTURE.md <-- Deep engineering dive: Signal processing, state & pipeline
├── 02_ENGINEERING_JOURNEY.md    <-- All historical hurdles, dead-ends, ASR findings & solutions
└── 03_USER_GUIDE.md             <-- Features, pacing modes, feedback styles & usage walkthrough
```

---

## Quick Navigation

| Document | Target Audience | Primary Focus |
| :--- | :--- | :--- |
| [**00. Executive Summary**](file:///Users/ammaarorewole/Documents/dhikr_counter_antigravity_starter/docs/handbook/00_EXECUTIVE_SUMMARY.md) | Regular users, product managers, stakeholders | Purpose, core philosophy, non-negotiable privacy guarantee, key features, and plain-English explanation of how it counts without tapping. |
| [**01. Technical Architecture**](file:///Users/ammaarorewole/Documents/dhikr_counter_antigravity_starter/docs/handbook/01_TECHNICAL_ARCHITECTURE.md) | Mobile engineers, DSP specialists, developers | Architectural diagrams, Layer separation, Speech Envelope Analyzer (ARe), zero-crossing rates, VAD, state machine, and local persistence. |
| [**02. Engineering Journey & Hurdles**](file:///Users/ammaarorewole/Documents/dhikr_counter_antigravity_starter/docs/handbook/02_ENGINEERING_JOURNEY.md) | Technical leads, archive reviewers | Complete post-mortem: Whisper vs Moonshine hallucinations, the clap-burst dilemma, waqf/sukūn TTS case vowel bugs, memory footprints, and decoupling. |
| [**03. User & Operational Guide**](file:///Users/ammaarorewole/Documents/dhikr_counter_antigravity_starter/docs/handbook/03_USER_GUIDE.md) | End users, QA testers | Screen walkthroughs, pacing speeds (Slow/Medium/Fast), breath cadence customization, feedback modes (Mute/Haptic/Voice), and manual tap fallback. |

---

## Core Tenets at a Glance

1. **Zero Internet Dependency:** The application functions fully in Airplane Mode. Not a single byte of audio or metadata ever leaves the physical phone.
2. **Deterministic Waveform Mathematics:** Repetitions are counted via speech envelope energy dynamics, zero-crossing rates, and liturgical pacing constraints — completely avoiding cloud latency and neural model hallucinations.
3. **Calm, Distraction-Free UI:** Designed specifically for worship and remembrance: serene typography, predictable visual rhythm, gentle haptics, and non-intrusive controls.
4. **Authentic Prophetic Adhkar:** 27 authentic Sunnah adhkar across 6 categories, with rigorous terminal waqf (sukūn) rules, accurate transliterations, and clear translations.
