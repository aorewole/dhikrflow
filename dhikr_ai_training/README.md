# Dhikr AI Model Training — Master Blueprint & Project Guide

Welcome to the **Dhikr AI Model Training** project. This directory is a completely self-contained, end-to-end engineering guide and codebase designed to train a dedicated, lightweight, on-device AI model specifically tuned for Islamic liturgical recitation (*Adhkar*).

---

## 📌 Why This Project Exists

General speech recognition models (like OpenAI Whisper or Moonshine) fail on repetitive dhikr because:
1. **They expect conversational grammar**, causing repetition penalties and hallucinations when repeating phrases like *Astaghfirullah* rapidly.
2. **Quranic models (like Tarteel AI) are trained on formal Quran recitation**, expecting full verses with extended *Tajweed* vowels rather than rhythmic, continuous dhikr cadences.
3. **Dhikr is a closed set of 15–30 phrases**, not a 50,000-word open vocabulary. Running a massive 40M–100M parameter language model on a phone for a 20-word vocabulary is overkill, drains battery, and invites mistakes.

By training a **dedicated acoustic classifier or fine-tuned model**, we achieve:
- **Zero hallucinations**: It only recognizes the target phrases.
- **10x–20x faster inference**: ~10ms to 25ms per segment on mobile CPU.
- **Tiny footprint**: 3MB to 10MB (compared to 40MB–150MB).
- **Dialect & accent robustness**: Easily adapts to regional pronunciations, speed cadences, and whispers.

---

## 📚 Document Index & Curriculum

Navigate through the numbered guides below in order:

| File | Topic | What You Will Learn |
| :--- | :--- | :--- |
| [**01_FUNDAMENTALS_AND_CONCEPTS.md**](./01_FUNDAMENTALS_AND_CONCEPTS.md) | **Speech AI from A to Z** | Audio signals, spectrograms, acoustic models, CTC loss, Keyword Spotting (KWS), and why dhikr requires unique modeling. |
| [**02_DATA_COLLECTION_STRATEGY.md**](./02_DATA_COLLECTION_STRATEGY.md) | **How to Get Audio** | Free sources, community collection portals, synthetic data (TTS), and audio augmentation secrets. |
| [**03_HARDWARE_COSTS_AND_OPTIONS.md**](./03_HARDWARE_COSTS_AND_OPTIONS.md) | **Costs & Compute** | Can you use your Mac Mini? How to train 100% for free on Google Colab/Kaggle vs cloud GPU costs ($0.20–$0.50/hr). |
| [**04_MODEL_ARCHITECTURE_CHOICE.md**](./04_MODEL_ARCHITECTURE_CHOICE.md) | **Selecting Architecture** | Conformer-CTC vs Keyword Spotter (KWS) vs Whisper-Tiny LoRA fine-tuning. |
| [**05_STEP_BY_STEP_TRAINING_GUIDE.md**](./05_STEP_BY_STEP_TRAINING_GUIDE.md) | **Execution Walkthrough** | Data manifests, train/val/test splits, running the training script, tracking loss, and evaluation. |
| [**06_EXPORT_AND_FLUTTER_INTEGRATION.md**](./06_EXPORT_AND_FLUTTER_INTEGRATION.md) | **Deploy to Flutter** | ONNX int8 quantization, deploying to `assets/models/`, and wiring up with `sherpa-onnx` in the Flutter app. |

---

## 🛠️ Ready-to-Run Starter Scripts

Located in the [`scripts/`](./scripts/) folder:

- [`scripts/01_prepare_dataset.py`](./scripts/01_prepare_dataset.py) — Validates audio sample rates (16kHz mono), organizes folders, and generates train/validation/test manifests.
- [`scripts/02_augment_audio.py`](./scripts/02_augment_audio.py) — Multiplies your audio dataset 5x using background noise, speed perturbations (0.85x–1.25x), and volume shifts.
- [`scripts/03_train_dhikr_model.py`](./scripts/03_train_dhikr_model.py) — Complete PyTorch training pipeline with CTC/Cross-Entropy loss.
- [`scripts/04_export_to_onnx.py`](./scripts/04_export_to_onnx.py) — Exports trained PyTorch checkpoints to int8 quantized ONNX files ready for `sherpa-onnx`.

---

## 🚀 Quick Start Summary

1. **Install dependencies:**
   ```bash
   python3 -m venv venv && source venv/bin/activate
   pip install -r requirements.txt
   ```
2. **Collect ~50–100 recordings per phrase** (or use the data augmentation script to generate them).
3. **Train in Google Colab (Free T4 GPU)** or locally on your Mac Mini.
4. **Export ONNX files** and copy them to the Flutter app's `assets/models/custom_dhikr/` folder.
