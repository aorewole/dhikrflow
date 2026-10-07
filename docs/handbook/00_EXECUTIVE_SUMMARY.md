# 00. Executive & Non-Technical Summary

## 1. What is the Dhikr Counter?

The **Dhikr Counter** is an intelligent, hands-free mobile companion built for Muslims to perform their daily *adhkar* (words of remembrance and praise of God) without needing to manually click beads, tap their phone screen, or look down at a display while reciting.

Traditional digital tasbih counters force the user to tap a button every time they repeat a phrase. This breaks focus (*khushū‘*), requires holding the phone constantly, and can feel mechanical. 

The Dhikr Counter allows you to set your phone on a table, stand in prayer, walk, or sit calmly, select your dhikr, and begin reciting. The phone listens directly to your voice and advances the counter automatically as you speak.

---

## 2. The Core Experience

```
Select Dhikr ──▶ Set Target (Optional) ──▶ Recite Hands-Free ──▶ Automatic Count
```

1. **Select an Authentic Dhikr:** Choose from a curated library of 27 authentic prophetic phrases across 6 categories (Praise & Tasbih, Forgiveness, Tahlil & Tawhid, Morning & Evening, Protection, and Salawat).
2. **Pacing & Breath Cadence:** Set your recitation tempo (Slow, Medium, or Fast). The app guides you and pauses every 3 repetitions (customizable from 1 to 10) so you can breathe naturally without feeling rushed.
3. **Gentle Feedback:** Keep your phone in your pocket or face-down. With tactile vibration (Haptic mode), you receive a soft pulse each time a repetition is counted and a distinct vibration when your target is reached.
4. **Manual Freedom:** If you are in a quiet masjid or around others and prefer not to recite aloud, pause the session and use the prominent **Manual +1 Tap** button to count silently.

---

## 3. Our Non-Negotiable Privacy Promise

Privacy is not an afterthought or an optional toggle in this app — it is the fundamental foundation:

* **Zero Audio Uploads:** Your voice is **never** sent to any server, cloud service, or third party. Everything is processed purely within the physical microchip of your phone.
* **No Raw Audio Storage:** The app never records or saves your voice files to disk. Audio is analyzed in the phone's live memory in tiny fractions of a second and immediately cleared.
* **100% Airplane Mode Ready:** The app works anywhere on Earth — in remote deserts, airplanes, or deep indoors — with zero internet connection required.
* **No Telemetry, No Accounts, No Ads:** There are no login screens, no tracking SDKs, no Google Analytics, and no advertisements. Your spiritual devotion remains strictly between you and your Creator.

---

## 4. How Does It Count Without Tapping? (In Plain English)

You might wonder: *How does an app know when I recite a phrase without sending my voice to Siri, Google, or ChatGPT?*

Earlier in the project, we tried using heavy artificial intelligence speech models that transcribe speech into written text. However, we discovered that when someone recites sacred phrases rapidly or softly (like repeating *Astaghfirullah, Astaghfirullah, Astaghfirullah*), AI speech models get confused and make mistakes.

Instead, we built a **Mathematical Acoustic Waveform Engine**:

1. **The Human Voice Detector (VAD):** The phone first checks if sound entering the microphone is human speech or just room background noise.
2. **The Clap & Noise Shield:** Claps, snaps, coughs, and phone bumps make sharp, ultra-short bursts of sound (usually lasting less than 0.1 seconds). Human speech physically requires taking time to shape vowels and consonants (at least 0.4 to 0.9 seconds per dhikr). The app instantly rejects sharp sounds and claps, preventing accidental counts.
3. **The Voice Rhythm Analyzer (ARe):** When you recite, your voice naturally swells during words and dips into soft valleys during transitions. The engine watches the shape ("envelope") of this audio energy. It counts repetitions by identifying these natural voice rhythms matching the tempo of the selected dhikr.
4. **Predictable Breath Cadence:** The app creates a calm, rhythmic prayer rhythm. After every 3 repetitions (or whatever number you prefer), it pauses all guidance and prompts: *"Take a breath... 🌿"*, resetting your lungs before beginning the next cycle.

---

## 5. Summary of Key User Benefits

* **No Screen Addiction:** You don't have to look at the screen to know your count. Subtle haptics let you feel progress with your eyes closed.
* **Tiny App Footprint:** Optimized from over 350 MB down to **44 MB**, so it takes up minimal space on your phone and installs in seconds.
* **Battery Friendly:** By using mathematical signal processing instead of power-hungry AI neural networks, your phone stays cool and battery drain is negligible.
* **Accessible & Calm:** Beautiful dark and light modes, dignified Arabic typography, correct phonetic transliterations, and English translations for every prayer.
