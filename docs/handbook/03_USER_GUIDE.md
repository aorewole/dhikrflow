# 03. User & Operational Guide

## 1. Application Walkthrough & User Flow

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   HOME SCREEN   │ ────▶ │  DETAIL SCREEN  │ ────▶ │ ACTIVE SESSION  │
│ - Category tabs │       │ - Arabic card   │       │ - Letter sweep  │
│ - Search & list │       │ - Target chips  │       │ - Breath cycle  │
│ - Quick start   │       │ - Start button  │       │ - Manual +1 tap │
└─────────────────┘       └─────────────────┘       └─────────────────┘
```

---

## 2. Navigating the Adhkar Library

The app features **27 authentic prophetic adhkar** organized across 6 category tabs at the top of the Home Screen:

1. **Praise & Tasbih (7):**
   * *Subhan Allah* (Glory be to Allah)
   * *Alhamdulillah* (Praise be to Allah)
   * *Allahu Akbar* (Allah is the Greatest)
   * *Subhan Allah wa bihamdihi* (Glory be to Allah and His is the praise)
   * *Subhan Allah al-’Azeem* (Glory be to Allah the Magnificent)
   * *Subhanak Allahumma wa bihamdika...*
   * *Subhana Rabbiyal A'la* (Glory be to my Lord Most High)
2. **Forgiveness (5):**
   * *Astaghfirullah* (I seek forgiveness from Allah)
   * *Astaghfirullah wa atubu ilayh*
   * *Sayyid al-Istighfar* (The Chief of Prayers for Forgiveness)
   * *Rabbighfir li wa tub 'alayya...*
   * *Astaghfirullah al-’Azeem wa atubu ilayh*
3. **Tahlil & Tawhid (4):**
   * *La ilaha illallah* (None has the right to be worshipped but Allah)
   * *La ilaha illallahu wahdahu la sharika lah...*
   * *La hawla wa la quwwata illa billah*
   * *Raditu billahi Rabba...*
4. **Morning & Evening (4):**
   * *Hasbiyallahu la ilaha illa Huwa...*
   * *Bismillahilladhi la yadurru ma'asmihi shay'...*
   * *Ya Hayyu Ya Qayyum bi-rahmatika astagheeth*
   * *Ayat al-Kursi* (The Throne Verse)
5. **Protection & Trust (4):**
   * *Tawakkaltu 'alallah...*
   * *A'udhu bi-kalimatillahi t-tammati...*
   * *Surah Al-Ikhlas*
   * *Al-Mu'awwidhatayn* (*Al-Falaq & An-Nas*)
6. **Salawat (3):**
   * *As-Salat 'alan-Nabi (Mukhtasar)*
   * *Allahumma salli 'ala Muhammad*
   * *As-Salat al-Ibrahimiyyah*

---

## 3. Configuring Your Session

Before tapping **Start Hands-Free Session**:
* **Select a Target Repetition:** Choose from convenient presets (`33`, `100`, `10`, `3`, or `None`). If no target is set, the app will count continuously without fabricating a target limit.
* **Review Details:** You can read the authentic Arabic script, phonetic transliteration, and English translation to verify your recitation.

---

## 4. The Active Session Screen

During an active session, the screen is laid out for maximum clarity and thumb accessibility:

### A. Counter & Timer (Top Display)
* Displays your total count in large typography.
* Shows elapsed active recitation time.
* If a target is active, a subtle progress bar reflects your progress and glows green upon completion. Reaching a target never abruptly stops your session.

### B. Recitation Letter Sweep (Center Display)
* A glowing teal cursor glides across the Arabic text in natural Right-to-Left (RTL) reading order.
* As you recite, letters change into a radiant amber gold.
* When a repetition is registered, the entire phrase pulses green with gentle scale physics.

### C. Collapsible Pacing & Guide Settings (Thumb Reach)
Tap the **Pacing & Guide** card to expand or adjust controls at any time:
1. **Recitation Pacing Speed:**
   * **Slow:** 1,200ms per word — ideal for contemplative, meditative recitation or longer litanies.
   * **Medium (Default):** 750ms per word — standard natural recitation cadence.
   * **Fast:** 480ms per word — swift liturgical repetitions.
2. **Feedback Accompaniment Mode:**
   * **Haptic (Default):** Discrete tactile vibration pulses at every repetition count and at the target completion. Perfect for keeping the screen off or in your pocket.
   * **Mute:** Completely silent operation with visual guidance only.
   * **Voice:** Native Arabic speech synthesis accompanies each repetition to teach pacing and pronunciation.
3. **Breath Cadence Selector:**
   * Adjust how many repetitions to complete before taking a breath (from **1 to 10**, default: **3**).
   * After the configured count, the app automatically pauses for 1.8 seconds, displaying: `3 / 3 • Take a breath... 🌿` with a gentle inhale reminder.

### D. Manual +1 Tap Fallback Bar
* A large, tactile button at the bottom of the screen: **Manual +1 Tap**.
* **Always Available:** Works seamlessly both when the session is actively listening and when the session is **paused**.
* If you enter a quiet room, or simply want to count without speaking aloud, tap **Pause** and use this button as a traditional digital tasbih.

### E. Acoustic Telemetry (Developer & Inspection Panel)
* Tap the troubleshoot icon in the top right app bar to reveal the live **Acoustic Telemetry** card.
* Displays live DSP status:
  * **Wave:** Envelope waveform repetition estimation and confidence score.
  * **Guard:** Indicates whether impulsive noises (<200ms) or claps were shielded.
  * **Pacing & Breath:** Real-time state of the cadence engine.
  * **Recent History:** A log of the latest recognized speech events with a **Copy Log** button.
