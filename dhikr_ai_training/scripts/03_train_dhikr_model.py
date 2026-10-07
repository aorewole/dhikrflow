#!/usr/bin/env python3
"""
03_train_dhikr_model.py

Trains a lightweight Acoustic Conformer / CRNN classifier on Dhikr audio.
Features:
- 80-channel Log-Mel Spectrogram extraction.
- Automatic hardware detection: Apple Silicon MPS / Nvidia CUDA / CPU.
- AdamW optimizer with Cosine Annealing learning rate schedule.
- Checkpointing best validation accuracy to `checkpoints/best_dhikr_model.pt`.
"""

import argparse
import json
import math
import os
from pathlib import Path
import soundfile as sf
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchaudio.transforms as T
from torch.utils.data import Dataset, DataLoader
from tqdm import tqdm


# --- 1. Dataset & Feature Extractor ---

class DhikrDataset(Dataset):
    def __init__(self, manifest_path: str, max_duration: float = 4.0, target_sr: int = 16000):
        self.samples = []
        with open(manifest_path, "r", encoding="utf-8") as f:
            for line in f:
                item = json.loads(line)
                if Path(item["audio_filepath"]).exists():
                    self.samples.append(item)

        self.max_len = int(max_duration * target_sr)
        self.mel_spectrogram = T.MelSpectrogram(
            sample_rate=target_sr,
            n_fft=400,
            win_length=400,
            hop_length=160,
            n_mels=80,
            power=2.0,
        )

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        item = self.samples[idx]
        wav, sr = sf.read(item["audio_filepath"], dtype="float32")
        wav = torch.from_numpy(wav)
        if wav.ndim > 1:
            wav = wav.mean(dim=-1)

        # Pad or trim to fixed length
        if len(wav) < self.max_len:
            pad = torch.zeros(self.max_len - len(wav))
            wav = torch.cat([wav, pad], dim=0)
        else:
            wav = wav[:self.max_len]

        # Log Mel Spectrogram (80, T)
        mel = self.mel_spectrogram(wav)
        log_mel = torch.log(torch.clamp(mel, min=1e-5))
        # Normalize
        log_mel = (log_mel - log_mel.mean()) / (log_mel.std() + 1e-6)

        return log_mel, item["label_idx"]


# --- 2. Lightweight Acoustic Classifier Network (CRNN) ---

class ConvBlock(nn.Module):
    def __init__(self, in_c, out_c):
        super().__init__()
        self.conv = nn.Conv2d(in_c, out_c, kernel_size=3, padding=1, bias=False)
        self.bn = nn.BatchNorm2d(out_c)
        self.relu = nn.ReLU(inplace=True)
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2)

    def forward(self, x):
        return self.pool(self.relu(self.bn(self.conv(x))))


class DhikrAcousticModel(nn.Module):
    def __init__(self, num_classes: int = 10):
        super().__init__()
        # Input shape: (Batch, 1, 80, Time)
        self.conv1 = ConvBlock(1, 32)
        self.conv2 = ConvBlock(32, 64)
        self.conv3 = ConvBlock(64, 128)

        # Bi-directional GRU
        self.gru = nn.GRU(
            input_size=128 * 10, # 80 / 2 / 2 / 2 = 10 frequency bins
            hidden_size=128,
            num_layers=2,
            batch_first=True,
            bidirectional=True,
            dropout=0.2,
        )

        self.classifier = nn.Sequential(
            nn.Linear(256, 128),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(128, num_classes),
        )

    def forward(self, x):
        # x: (Batch, 80, Time) -> (Batch, 1, 80, Time)
        if x.ndim == 3:
            x = x.unsqueeze(1)
        x = self.conv1(x)
        x = self.conv2(x)
        x = self.conv3(x)

        # Reshape for GRU: (B, C, F, T) -> (B, T, C * F)
        b, c, f, t = x.shape
        x = x.permute(0, 3, 1, 2).contiguous().view(b, t, c * f)

        gru_out, _ = self.gru(x)  # (B, T, 256)
        # Global Average Pooling over time dimension
        pooled = gru_out.mean(dim=1)  # (B, 256)
        logits = self.classifier(pooled)
        return logits


# --- 3. Training & Evaluation Loops ---

def train_epoch(model, dataloader, optimizer, criterion, device):
    model.train()
    total_loss, correct, total = 0.0, 0, 0
    for mels, labels in dataloader:
        mels, labels = mels.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(mels)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * len(labels)
        preds = outputs.argmax(dim=-1)
        correct += (preds == labels).sum().item()
        total += len(labels)

    return total_loss / total, (correct / total) * 100.0


@torch.no_grad()
def evaluate(model, dataloader, criterion, device):
    model.eval()
    total_loss, correct, total = 0.0, 0, 0
    for mels, labels in dataloader:
        mels, labels = mels.to(device), labels.to(device)
        outputs = model(mels)
        loss = criterion(outputs, labels)

        total_loss += loss.item() * len(labels)
        preds = outputs.argmax(dim=-1)
        correct += (preds == labels).sum().item()
        total += len(labels)

    return total_loss / total, (correct / total) * 100.0


def main():
    parser = argparse.ArgumentParser(description="Train Dhikr Acoustic Classifier.")
    parser.add_argument("--epochs", type=int, default=40)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--train-manifest", type=str, default="dataset/train_manifest.jsonl")
    parser.add_argument("--val-manifest", type=str, default="dataset/val_manifest.jsonl")
    parser.add_argument("--checkpoint-dir", type=str, default="checkpoints")
    parser.add_argument("--eval-only", action="store_true")
    parser.add_argument("--checkpoint", type=str, default=None)
    args = parser.parse_args()

    # Device selection
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print("Using Apple Silicon GPU (MPS) acceleration.")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print(f"Using NVIDIA GPU ({torch.cuda.get_device_name(0)}) acceleration.")
    else:
        device = torch.device("cpu")
        print("Using standard CPU.")

    checkpoint_dir = Path(args.checkpoint_dir)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    # Read class count from labels.txt
    labels_path = Path("dataset/labels.txt")
    if labels_path.exists():
        with open(labels_path, "r", encoding="utf-8") as f:
            classes = [line.strip().split()[-1] for line in f if line.strip()]
        num_classes = len(classes)
    else:
        num_classes = 10

    print(f"Configuring model for {num_classes} dhikr classes.")
    model = DhikrAcousticModel(num_classes=num_classes).to(device)

    criterion = nn.CrossEntropyLoss(label_smoothing=0.05)

    if args.eval_only:
        ckpt_path = args.checkpoint or str(checkpoint_dir / "best_dhikr_model.pt")
        print(f"Loading checkpoint {ckpt_path} for evaluation...")
        model.load_state_dict(torch.load(ckpt_path, map_location=device))
        val_dataset = DhikrDataset(args.val_manifest)
        val_loader = DataLoader(val_dataset, batch_size=args.batch_size, shuffle=False)
        val_loss, val_acc = evaluate(model, val_loader, criterion, device)
        print(f"Evaluation Results -> Loss: {val_loss:.4f} | Accuracy: {val_acc:.2f}%")
        return

    train_dataset = DhikrDataset(args.train_manifest)
    val_dataset = DhikrDataset(args.val_manifest)
    train_loader = DataLoader(train_dataset, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=args.batch_size, shuffle=False)

    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)

    best_acc = 0.0

    print(f"Starting training for {args.epochs} epochs...")
    for epoch in range(1, args.epochs + 1):
        train_loss, train_acc = train_epoch(model, train_loader, optimizer, criterion, device)
        val_loss, val_acc = evaluate(model, val_loader, criterion, device)
        scheduler.step()

        print(f"Epoch {epoch:02d}/{args.epochs:02d} | Train Loss: {train_loss:.4f} Acc: {train_acc:.1f}% | Val Loss: {val_loss:.4f} Acc: {val_acc:.1f}%")

        if val_acc > best_acc:
            best_acc = val_acc
            save_path = checkpoint_dir / "best_dhikr_model.pt"
            torch.save(model.state_dict(), save_path)
            print(f"  --> Saved new best checkpoint to {save_path} (Acc: {best_acc:.2f}%)")

    print(f"Training finished! Best Validation Accuracy: {best_acc:.2f}%")


if __name__ == "__main__":
    main()
