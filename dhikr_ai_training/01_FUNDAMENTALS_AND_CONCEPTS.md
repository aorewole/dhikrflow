# 01 — Speech AI Fundamentals & How It Applies to Dhikr

This document explains the core principles of Speech AI, how machine learning models process spoken audio, and why training a model specifically for Dhikr is vastly different from building a general speech-to-text system.

---

## 1. How Machine Learning Processes Speech (From Audio Wave to Prediction)

Computers cannot listen to sound; they only understand numbers. The path from a person saying *"SubhanAllah"* into a microphone to a counter incrementing is broken into four distinct stages:

```
[Spoken Voice]
       │
       ▼
1. Analog-to-Digital Conversion (Sampling)
   • Microphone captures continuous pressure waves.
   • Sampled at 16,000 times per second (16 kHz), 16-bit mono PCM.
   • Result: A 1D array of floating-point numbers: [-0.02, 0.15, 0.42, ...]
       │
       ▼
2. Time-to-Frequency Transformation (Spectrogram)
   • A raw waveform is difficult for neural networks to interpret directly.
   • We apply Short-Time Fourier Transform (STFT) with a Mel scale filter bank.
   • Result: An 80-channel **Log-Mel Spectrogram** (a 2D image where the X-axis is time, Y-axis is frequency, and pixel brightness is volume/energy).
       │
       ▼
3. Acoustic Feature Extraction (Neural Network)
   • The spectrogram is fed into neural network layers (Convolutional filters, Conformer blocks, or Transformer Encoders).
   • Layers detect phonetic characteristics: fricatives ("s"), glottal stops ("hamza"), voiced pharyngeal consonants ("'ayn"), vowel lengths.
       │
       ▼
4. Output Prediction
   • Traditional ASR: Predicts text tokens (`أ`, `س`, `ت`, `غ`, ...).
   • Keyword Spotter (KWS): Predicts phrase probability vector (`[Astaghfirullah: 0.98, SubhanAllah: 0.01, Silence: 0.01]`).
```

---

## 2. The Two Speech AI Paradigms: Seq2Seq vs. Keyword Spotting (CTC)

Understanding this distinction is the single most important breakthrough in solving your dhikr recognition issue:

### Paradigm A: Autoregressive Sequence-to-Sequence (Whisper, Moonshine)
- **How it works:** Contains an Audio Encoder AND a Text Decoder (a language model).
- **Behavior:** The language model constantly predicts "what word is grammatically likely to follow the previous word."
- **The Failure Mode for Dhikr:** 
  - If you say *"Astaghfirullah Astaghfirullah Astaghfirullah"*, the language model thinks: *"A human does not repeat the exact same word 5 times in conversational speech. It must be a different Arabic word or grammar mistake."*
  - The model applies a built-in **repetition penalty** and hallucinates colloquial Arabic or Quranic verses that sound vaguely similar.
  - This is why Whisper and Moonshine failed to count your rapid repetitions!

### Paradigm B: Keyword Spotting (KWS) / Conformer-CTC (The Siri/Alexa Approach)
- **How it works:** Pure acoustic classification. **There is no text language model.**
- **Behavior:** The network looks only at the acoustic signature of the sound. Does it match the phoneme pattern of `/as-tagh-fi-rul-lah/`? If yes, it fires a trigger.
- **Why this is perfect for Dhikr:**
  - **Zero hallucination:** It is literally impossible for it to output conversational sentences.
  - **Native repetition detection:** If the acoustic pattern appears 4 times in 3 seconds, it fires 4 times (`+4`).
  - **Ultra-fast & tiny:** Requires no 50,000-token dictionary. Model sizes are 3 MB – 10 MB instead of 100 MB+.

---

## 3. Why Dhikr is a "Closed-Domain" Problem

When Apple builds Siri, they don't transcribe your whole sentence to see if you said "Hey Siri". They have a tiny, hyper-optimized 2MB neural network that only listens for the specific acoustic signature of the words "Hey Siri".

**Dhikr is identical.** You are not asking the user to dictate their life story; you are listening for one of ~15 to 30 known liturgical formulas:
1. *SubhanAllah*
2. *Alhamdulillah*
3. *Allahu Akbar*
4. *Astaghfirullah*
5. *La ilaha illallah*
6. *La hawla wa la quwwata illa billah*
...etc.

Because the problem is **closed-domain**, you do not need billions of parameters or supercomputers to train it. A small, focused model trained on the right audio will outperform OpenAI Whisper by a massive margin.

---

## 4. Key Terminology You Need to Know

- **Epoch:** One complete pass through the entire training dataset. (Typical training is 30–60 epochs).
- **Batch Size:** Number of audio clips processed simultaneously by the GPU (e.g. 16 or 32).
- **Loss Function:** The mathematical penalty score measuring how wrong the model was. During training, backpropagation adjusts the model weights to minimize this loss toward zero.
- **CTC (Connectionist Temporal Classification):** An algorithm that aligns spoken audio of varying speeds to labels without needing frame-by-frame manual alignment.
- **Quantization (int8):** Converting 32-bit floating-point weights to 8-bit integers. Reduces model file size by 75% and speeds up mobile inference with virtually zero loss in accuracy.
- **ONNX (Open Neural Network Exchange):** The open standard format used by `sherpa-onnx` and Flutter to execute neural networks on iOS and Android devices without PyTorch.
