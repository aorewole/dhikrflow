#!/usr/bin/env python3
"""
02_augment_audio.py

Multiplies training data by applying physical variations:
1. Speed Perturbation (0.85x slow, 1.18x fast recitation)
2. Pitch Shift (simulating male/female vocal tract differences)
3. Volume Scaling (whisper to loud recitation)
4. Additive Noise (ambient room hum, background fan)

Appends all generated variations to `dataset/train_manifest.jsonl`.
"""

import argparse
import json
import os
import random
from pathlib import Path
import numpy as np
import soundfile as sf
import librosa
from tqdm import tqdm


def augment_sample(audio: np.ndarray, sr: int, aug_type: str) -> np.ndarray:
    if aug_type == "speed_slow":
        return librosa.effects.time_stretch(audio, rate=0.88)
    elif aug_type == "speed_fast":
        return librosa.effects.time_stretch(audio, rate=1.18)
    elif aug_type == "pitch_up":
        return librosa.effects.pitch_shift(audio, sr=sr, n_steps=1.5)
    elif aug_type == "pitch_down":
        return librosa.effects.pitch_shift(audio, sr=sr, n_steps=-1.5)
    elif aug_type == "whisper":
        return audio * 0.35
    elif aug_type == "noise":
        noise = np.random.randn(len(audio))
        snr = 20.0  # 20 dB SNR
        audio_power = np.mean(audio ** 2)
        noise_power = np.mean(noise ** 2)
        if noise_power > 0 and audio_power > 0:
            scale = np.sqrt(audio_power / (noise_power * (10 ** (snr / 10))))
            return audio + (noise * scale)
        return audio
    return audio


def main():
    parser = argparse.ArgumentParser(description="Augment training audio data.")
    parser.add_argument("--manifest", type=str, default="dataset/train_manifest.jsonl", help="Train manifest to augment.")
    parser.add_argument("--output-dir", type=str, default="dataset/augmented_audio", help="Folder to save augmented wavs.")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.exists():
        print(f"Error: {manifest_path} not found. Run 01_prepare_dataset.py first.")
        return

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(manifest_path, "r", encoding="utf-8") as f:
        train_samples = [json.loads(line) for line in f]

    print(f"Loaded {len(train_samples)} training samples for augmentation.")

    augmentations = ["speed_slow", "speed_fast", "pitch_up", "whisper", "noise"]
    new_samples = []

    for item in tqdm(train_samples, desc="Augmenting"):
        src_path = Path(item["audio_filepath"])
        if not src_path.exists():
            continue

        y, sr = librosa.load(src_path, sr=16000, mono=True)

        for aug in augmentations:
            aug_y = augment_sample(y, sr, aug)
            aug_filename = f"{src_path.stem}_{aug}.wav"
            class_folder = output_dir / item["label"]
            class_folder.mkdir(parents=True, exist_ok=True)
            aug_path = class_folder / aug_filename

            sf.write(aug_path, aug_y, sr, subtype="PCM_16")

            new_samples.append({
                "audio_filepath": str(aug_path),
                "duration": float(len(aug_y) / sr),
                "label": item["label"],
                "label_idx": item["label_idx"],
            })

    # Append to train manifest
    print(f"Adding {len(new_samples)} augmented samples to {manifest_path}...")
    with open(manifest_path, "a", encoding="utf-8") as f:
        for sample in new_samples:
            f.write(json.dumps(sample, ensure_ascii=False) + "\n")

    total_train = len(train_samples) + len(new_samples)
    print(f"Augmentation complete! Total training samples is now: {total_train} (multiplied by {total_train/len(train_samples):.1f}x)")


if __name__ == "__main__":
    main()
