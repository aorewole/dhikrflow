#!/usr/bin/env python3
"""
01_prepare_dataset.py

Scans raw audio files from `dataset/raw_audio/<phrase_name>/*.wav`,
resamples to 16,000 Hz 16-bit mono, trims silence,
and splits into train (80%), validation (10%), and test (10%) manifests.
"""

import argparse
import json
import os
import random
from pathlib import Path
import soundfile as sf
import librosa
from tqdm import tqdm


def prepare_audio_file(src_path: Path, dest_path: Path, target_sr: int = 16000) -> float:
    """Load, convert to mono, resample to target_sr, trim silence, and save."""
    y, sr = librosa.load(src_path, sr=target_sr, mono=True)
    # Trim lead/tail silence (top_db=25)
    y_trimmed, _ = librosa.effects.trim(y, top_db=25)
    if len(y_trimmed) < target_sr * 0.3:  # skip clips shorter than 300ms
        return 0.0
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(dest_path, y_trimmed, target_sr, subtype="PCM_16")
    return float(len(y_trimmed) / target_sr)


def main():
    parser = argparse.ArgumentParser(description="Prepare and split Dhikr audio dataset.")
    parser.add_argument("--raw-dir", type=str, default="dataset/raw_audio", help="Path to raw audio folder.")
    parser.add_argument("--processed-dir", type=str, default="dataset/processed_audio", help="Output path for processed audio.")
    parser.add_argument("--output-dir", type=str, default="dataset", help="Output directory for manifests.")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for repeatable split.")
    args = parser.parse_args()

    random.seed(args.seed)
    raw_dir = Path(args.raw_dir)
    processed_dir = Path(args.processed_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if not raw_dir.exists():
        print(f"Error: {raw_dir} does not exist. Please place audio folders inside it.")
        print("Example structure:")
        print("  dataset/raw_audio/astaghfirullah/*.wav")
        print("  dataset/raw_audio/subhanallah/*.wav")
        return

    # Discover classes (subdirectories)
    classes = sorted([d.name for d in raw_dir.iterdir() if d.is_dir() and not d.name.startswith(".")])
    if not classes:
        print(f"No class folders found in {raw_dir}.")
        return

    print(f"Found {len(classes)} classes: {classes}")

    # Write labels mapping
    labels_file = output_dir / "labels.txt"
    with open(labels_file, "w", encoding="utf-8") as f:
        for idx, label in enumerate(classes):
            f.write(f"{idx} {label}\n")
    print(f"Saved class index mapping to {labels_file}")

    all_samples = []

    for class_idx, class_name in enumerate(classes):
        class_dir = raw_dir / class_name
        audio_files = list(class_dir.glob("*.wav")) + list(class_dir.glob("*.mp3")) + list(class_dir.glob("*.m4a"))
        print(f"Processing '{class_name}' ({len(audio_files)} files)...")

        for src_file in tqdm(audio_files):
            dest_file = processed_dir / class_name / f"{src_file.stem}.wav"
            duration = prepare_audio_file(src_file, dest_file)
            if duration > 0.0:
                all_samples.append({
                    "audio_filepath": str(dest_file),
                    "duration": duration,
                    "label": class_name,
                    "label_idx": class_idx,
                })

    print(f"Total valid audio samples processed: {len(all_samples)}")

    # Stratified Shuffle Split (80% Train, 10% Val, 10% Test)
    random.shuffle(all_samples)
    n_total = len(all_samples)
    n_train = int(n_total * 0.8)
    n_val = int(n_total * 0.1)

    train_data = all_samples[:n_train]
    val_data = all_samples[n_train:n_train + n_val]
    test_data = all_samples[n_train + n_val:]

    def write_manifest(filepath, data):
        with open(filepath, "w", encoding="utf-8") as f:
            for item in data:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

    write_manifest(output_dir / "train_manifest.jsonl", train_data)
    write_manifest(output_dir / "val_manifest.jsonl", val_data)
    write_manifest(output_dir / "test_manifest.jsonl", test_data)

    print("Manifests created:")
    print(f"  Train:      {len(train_data)} samples -> {output_dir / 'train_manifest.jsonl'}")
    print(f"  Validation: {len(val_data)} samples -> {output_dir / 'val_manifest.jsonl'}")
    print(f"  Test:       {len(test_data)} samples -> {output_dir / 'test_manifest.jsonl'}")


if __name__ == "__main__":
    main()
