# 03 — Hardware, Compute Options & Cost Analysis

A common misconception is that training an AI model requires spending thousands of dollars on enterprise cloud servers. 

Because we are training a **closed-vocabulary acoustic model** (rather than a 70-billion-parameter LLM like Llama 3), **the training can be done completely for FREE**, or for under \$3.00 on paid cloud GPUs.

Here is a full breakdown of your options.

---

## 1. Option Comparison Matrix

| Environment | Cost | Training Time | Setup Difficulty | Best For |
| :--- | :--- | :--- | :--- | :--- |
| **Google Colab (Free Tier)** | **\$0.00** | 1.5 – 3 hours | ⭐ Very Easy | First experiments, zero financial commitment |
| **Kaggle Notebooks** | **\$0.00** | 1.5 – 3 hours | ⭐ Very Easy | 30 hours/week free GPU (2x Nvidia T4) |
| **Your Mac Mini (Local Apple Silicon)** | **\$0.00** | 2 – 5 hours | ⭐⭐ Easy | Training offline with complete data privacy |
| **RunPod / Vast.ai (RTX 4090)** | **~\$0.35 / hr** (~**\$1.50** total) | 30 – 45 mins | ⭐⭐⭐ Moderate | Fast production iterations |
| **Lambda Labs (A10 / A100)** | **~\$0.75 / hr** (~**\$3.00** total) | 20 – 30 mins | ⭐⭐⭐ Moderate | Heavy data augmentation & massive datasets |

---

## 2. Can You Train on Your Mac Mini?

**YES, absolutely.**

Modern Mac Minis (M1, M2, M3, M4) feature **Apple Silicon Unified Memory** and high-speed neural accelerators. PyTorch natively supports Apple Silicon via the **MPS (`torch.device("mps")`)** backend.

### Advantages of your Mac Mini:
- **100% Free:** Zero subscription or hourly compute charges.
- **Zero Privacy Leak:** Audio files never leave your physical desk.
- **Unified Memory:** 16GB or 24GB of RAM is shared directly with the GPU cores, easily handling batch sizes of 32 or 64 for acoustic models.

### Expected Performance:
- For a **Conformer-CTC or Keyword Spotting (KWS)** model: ~15 to 30 minutes on Apple Silicon.
- For fine-tuning **Whisper-Tiny**: ~1.5 to 3 hours on Apple Silicon.

---

## 3. How to Train 100% for Free in the Cloud

If you don't want your Mac Mini fans spinning or running hot for 2 hours, you can use free cloud GPUs:

### A. Google Colab (Free T4 GPU)
1. Go to [colab.research.google.com](https://colab.research.google.com).
2. Click **Runtime** → **Change runtime type** → Select **T4 GPU** (Free).
3. Upload your dataset (zipped) or clone your GitHub repository.
4. Run the training script. A standard 50-epoch training run finishes in ~1.5 hours within Colab's free 12-hour session limit.

### B. Kaggle Notebooks (Free 30 Hours/Week)
1. Go to [kaggle.com/code](https://www.kaggle.com/code).
2. Create a new notebook and enable **GPU T4 x2** in the right-hand settings panel.
3. Kaggle gives you **30 hours per week of completely free Nvidia GPU compute** with zero auto-disconnect surprises.

---

## 4. Paid Cloud GPUs (When You Need Speed: ~\$1.00 – \$3.00)

If you have a large dataset (e.g. 5,000+ audio clips) and want your model trained in 20 minutes:

### RunPod.io / Vast.ai
- **GPU:** NVIDIA RTX 4090 (24GB VRAM) or RTX 3090.
- **Cost:** **\$0.25 to \$0.40 per hour**.
- **Total Cost:** A 2-hour training run will cost you roughly **\$0.60 to \$1.00**.
- **How it works:** You launch a pre-configured PyTorch Docker container, upload your data via SCP/JupyterLab, run the script, and download the finished `.onnx` model weights.

---

## 5. Summary Recommendation

1. **Start with your Mac Mini or Google Colab (Free).** You do not need to spend a single penny to train, evaluate, and export your first custom Dhikr AI model.
2. Only consider renting an RTX 4090 on RunPod if your dataset exceeds 10,000 audio files and you want faster turnaround time.
