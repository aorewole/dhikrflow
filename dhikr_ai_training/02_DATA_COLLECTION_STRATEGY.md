# 02 — Data Collection Strategy & Sourcing Audio

The single most important factor determining whether your Dhikr AI model succeeds or fails is **the quality and diversity of your audio dataset**. 

"Garbage in, garbage out" is especially true in speech AI. This guide details how to collect, structure, and synthesize your Dhikr audio dataset without spending thousands of dollars.

---

## 1. How Much Audio Do You Actually Need?

Because Dhikr has a **closed vocabulary** (15–30 phrases), you do **not** need 75,000 hours of speech.

| Model Scope | Samples per Phrase | Total Hours Needed | Accuracy Target |
| :--- | :--- | :--- | :--- |
| **Proof-of-Concept (Personal Model)** | 50–100 recordings | ~1–2 hours | 95%+ for your voice/accent |
| **Production MVP (General Public)** | 300–600 recordings | ~8–15 hours | 96%+ across common accents |
| **High-Precision Global Model** | 1,000–2,000 recordings | ~30–50 hours | 99%+ across global dialects |

Each individual recording should be 1 to 4 seconds long (either a single recitation or 2–3 continuous repetitions).

---

## 2. The 4 Sourcing Strategies (Ranked by Cost & Speed)

### Strategy A: Record Yourself & Friends/Family (Fastest & Free)
- **Cost:** \$0
- **Time:** 1 weekend
- **How:** 
  1. Use your iPhone's Voice Memos or the provided Python recording script.
  2. For each dhikr phrase, record:
     - 20 slow & clear recitations.
     - 20 normal conversational recitations.
     - 20 rapid/fast repetitions (e.g. 3x in one breath).
     - 20 whispered/low-volume recitations.
  3. Ask 4–5 friends or family members (ideally with different vocal pitches, male/female) to do the same.
  4. With 5 people × 80 recordings = **400 real recordings per phrase**.
  5. Combine with **Data Augmentation** (explained below), which automatically multiplies this into 2,000+ training samples!

---

### Strategy B: Synthetic Audio Generation (AI Text-to-Speech)
- **Cost:** \$0 to \$15
- **Time:** A few hours automated
- **How:**
  - Modern neural Arabic TTS systems (like ElevenLabs, Google Cloud TTS, or open-source Piper/Coqui TTS) can generate crystal-clear Arabic speech across dozens of distinct male and female voices.
  - You can write a Python loop to synthesize each dhikr phrase across 30 different voice personas at speeds `0.8x`, `1.0x`, and `1.2x`.
  - **Verdict:** Fantastic for bootstrapping baseline phonetic features, though real human audio is still needed for authentic rapid cadences.

---

### Strategy C: Crowdsourced Community Portal / In-App Voice Donation
- **Cost:** Free (hosted on GitHub Pages, Vercel, or Streamlit)
- **Time:** Ongoing community effort
- **How:**
  1. Build a simple 1-page mobile-friendly web app (using Python Streamlit or basic HTML/JS) with a prompt:
     > *"Please recite 'SubhanAllah' 3 times into your microphone."*
  2. The user taps Record → speaks → taps Submit.
  3. Audio is saved as an anonymous `.wav` file into a free storage bucket (e.g. Supabase, Firebase Free Tier, or Cloudflare R2).
  4. Share the link with Islamic study circles, university MSA groups, family groups on WhatsApp/Telegram.
  5. In 1–2 weeks, you can easily gather 1,000+ authentic community samples representing Egyptian, Gulf, South Asian, West African, and European Muslim accents.

---

### Strategy D: Mining Public YouTube & Islamic Audio Archives
- **Cost:** Free
- **Time:** Moderate (requires cutting/segmenting)
- **How:**
  - Hundreds of YouTube videos feature *"Morning and Evening Adhkar (Adhkar al-Sabah wal-Masaa)"* or *"100x Astaghfirullah"*.
  - You can use Python (`yt-dlp`) and VAD to automatically download and slice these recitations into isolated phrase segments.
  - Sources:
    - *Islamway.net* audio libraries.
    - *EveryAyah.com* (for phrases that are also Ayahs, like *Alhamdulillah* or *Hasbunallah*).
    - YouTube dhikr compilations.

---

## 3. The Dataset Directory Structure

Organize your raw audio files strictly as follows:

```
dataset/
├── raw_audio/
│   ├── astaghfirullah/
│   │   ├── user1_normal_001.wav
│   │   ├── user1_fast_002.wav
│   │   ├── user1_whisper_003.wav
│   │   └── user2_normal_004.wav
│   ├── subhanallah/
│   │   ├── user1_normal_001.wav
│   │   └── ...
│   ├── alhamdulillah/
│   └── allahu_akbar/
└── background_noise/   <-- Ambient room noise, fan hum, silence
    ├── fan_noise.wav
    └── car_interior.wav
```

---

## 4. Audio Quality Standards (Non-Negotiable)

For a neural network to train properly, all audio files must conform to:
1. **Format:** Standard uncompressed `.wav` (PCM 16-bit).
2. **Sample Rate:** `16,000 Hz` (16 kHz).
3. **Channels:** `1` (Mono, not Stereo).
4. **Duration:** Clipped closely to the speech (between `0.8s` and `4.0s`).

The helper script `scripts/01_prepare_dataset.py` will automatically resample, convert to mono, and normalize any audio you place into the folder.
