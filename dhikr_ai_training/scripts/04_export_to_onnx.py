#!/usr/bin/env python3
"""
04_export_to_onnx.py

Loads the trained PyTorch checkpoint, exports to ONNX with dynamic axes,
quantizes the weights using ONNX Runtime int8 dynamic quantization,
and generates `tokens.txt` for sherpa-onnx / Flutter integration.
"""

import argparse
import os
import shutil
from pathlib import Path
import torch
from onnxruntime.quantization import QuantType, quantize_dynamic

from _model_def import DhikrAcousticModel


def main():
    parser = argparse.ArgumentParser(description="Export trained PyTorch Dhikr model to int8 ONNX.")
    parser.add_argument("--checkpoint", type=str, default="checkpoints/best_dhikr_model.pt", help="Path to .pt checkpoint.")
    parser.add_argument("--labels", type=str, default="dataset/labels.txt", help="Path to labels.txt.")
    parser.add_argument("--output-dir", type=str, default="../assets/models/custom_dhikr", help="Target output folder.")
    args = parser.parse_args()

    ckpt_path = Path(args.checkpoint)
    if not ckpt_path.exists():
        print(f"Error: Checkpoint {ckpt_path} does not exist. Train the model first using 03_train_dhikr_model.py.")
        return

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Read class count
    labels_file = Path(args.labels)
    if labels_file.exists():
        with open(labels_file, "r", encoding="utf-8") as f:
            classes = [line.strip().split()[-1] for line in f if line.strip()]
        num_classes = len(classes)
    else:
        num_classes = 10
        classes = [f"class_{i}" for i in range(num_classes)]

    print(f"Loading checkpoint {ckpt_path} with {num_classes} classes...")
    model = DhikrAcousticModel(num_classes=num_classes)
    model.load_state_dict(torch.load(ckpt_path, map_location="cpu"))
    model.eval()

    # Create dummy Mel spectrogram input: (Batch=1, Mel=80, Time=200)
    dummy_input = torch.randn(1, 80, 200, dtype=torch.float32)

    raw_onnx_path = output_dir / "encoder.onnx"
    quantized_onnx_path = output_dir / "encoder.int8.onnx"

    print("Exporting PyTorch model to ONNX...")
    torch.onnx.export(
        model,
        dummy_input,
        str(raw_onnx_path),
        opset_version=17,
        input_names=["mel"],
        output_names=["logits"],
        dynamic_axes={
            "mel": {0: "batch_size", 2: "time_frames"},
            "logits": {0: "batch_size"},
        },
    )
    print(f"Exported raw ONNX model: {raw_onnx_path.stat().st_size / (1024*1024):.2f} MB")

    print("Applying dynamic int8 quantization...")
    quantize_dynamic(
        model_input=str(raw_onnx_path),
        model_output=str(quantized_onnx_path),
        op_types_to_quantize=["MatMul", "Gemm"],
        weight_type=QuantType.QInt8,
    )
    print(f"Quantized int8 ONNX model: {quantized_onnx_path.stat().st_size / (1024*1024):.2f} MB")

    # Generate tokens.txt for sherpa-onnx
    tokens_path = output_dir / "tokens.txt"
    with open(tokens_path, "w", encoding="utf-8") as f:
        for idx, name in enumerate(classes):
            f.write(f"{name} {idx}\n")
    print(f"Saved token mapping to {tokens_path}")

    # Remove unquantized file to save space
    if raw_onnx_path.exists():
        raw_onnx_path.unlink()

    print("\nSUCCESS! Ready for Flutter integration:")
    print(f"  Model:  {quantized_onnx_path}")
    print(f"  Tokens: {tokens_path}")


if __name__ == "__main__":
    main()
