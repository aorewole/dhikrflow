# 05 — Step-by-Step Training Execution Guide

This is your practical playbook. Follow these steps in order to train your custom Dhikr AI model.

---

## Step 1: Environment Setup

Create an isolated Python environment (on your Mac Mini, Linux workstation, or Google Colab):

```bash
# 1. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate

# 2. Upgrade pip
pip install --upgrade pip

# 3. Install core machine learning and audio libraries
pip install -r requirements.txt
```

Verify your hardware acceleration:
```bash
python3 -c "
import torch
if torch.backends.mps.is_available():
    print('Apple Silicon GPU (MPS) is ACTIVE!')
elif torch.cuda.is_available():
    print(f'NVIDIA GPU ({torch.cuda.get_device_name(0)}) is ACTIVE!')
else:
    print('Running on standard CPU.')
"
```

---

## Step 2: Prepare Your Audio Data

1. Place your raw `.wav` or `.m4a` or `.mp3` recordings into subdirectories under `dataset/raw_audio/`:
   ```
   dataset/raw_audio/
   ├── astaghfirullah/
   │   ├── rec_001.wav
   │   └── rec_002.wav
   ├── subhanallah/
   │   └── rec_001.wav
   ├── alhamdulillah/
   └── allahu_akbar/
   ```
2. Run the dataset preparation script:
   ```bash
   python scripts/01_prepare_dataset.py
   ```
   **What this does automatically:**
   - Resamples every file to 16,000 Hz, 16-bit mono PCM.
   - Trims dead silence at the beginning and end.
   - Splits recordings into **80% Training**, **10% Validation**, and **10% Test**.
   - Generates `dataset/train_manifest.jsonl`, `dataset/val_manifest.jsonl`, and `dataset/test_manifest.jsonl`.

---

## Step 3: Run Audio Augmentation (Multiply Data 5x)

If you only recorded 100 samples per phrase, data augmentation will automatically turn them into 500 samples per phrase by applying realistic physical variations:

```bash
python scripts/02_augment_audio.py
```

**Augmentations applied:**
1. **Speed Perturbation:** Generates `0.85x` (slow cadence) and `1.20x` (rapid recitation).
2. **Dynamic Volume Scaling:** Multiplies amplitude between `0.4x` (whisper) and `1.3x` (loud).
3. **Additive Background Noise:** Blends soft room ambiance and fan hum at random Signal-to-Noise Ratios (SNR: 15dB to 25dB).
4. **Frequency Masking (SpecAugment):** Randomly zeroes out small frequency bands to force the model to learn phonetics rather than voice pitch.

---

## Step 4: Launch Training

Start the training run:

```bash
python scripts/03_train_dhikr_model.py \
  --epochs 40 \
  --batch-size 32 \
  --lr 1e-3 \
  --device auto
```

### What You Will See in the Console:
```
Epoch 1/40 [██████████████████] Loss: 2.312  Val Loss: 1.845  Val Acc: 68.2%
Epoch 5/40 [██████████████████] Loss: 0.812  Val Loss: 0.650  Val Acc: 89.4%
Epoch 15/40 [██████████████████] Loss: 0.142  Val Loss: 0.180  Val Acc: 96.8%
Epoch 30/40 [██████████████████] Loss: 0.035  Val Loss: 0.082  Val Acc: 99.1%
--> Best model checkpoint saved to: checkpoints/best_dhikr_model.pt
```

### How to Tell When Training is Successful:
- **Validation Loss:** Should steadily decline and flatten out below `0.10`.
- **Validation Accuracy:** Should exceed `97%–99%`.
- If Validation Loss starts increasing while Training Loss keeps dropping, the model is **overfitting** (memorizing individual voices instead of general speech). The script automatically applies **Early Stopping** to save the best generalizing checkpoint.

---

## Step 5: Test on Unseen Audio

Verify the trained model on recordings that were never seen during training:

```bash
python scripts/03_train_dhikr_model.py --eval-only --checkpoint checkpoints/best_dhikr_model.pt
```

The script will output a **Confusion Matrix** showing exact accuracy for every phrase (e.g. *Astaghfirullah: 99.2%*, *SubhanAllah: 98.7%*).
