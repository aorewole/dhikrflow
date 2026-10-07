# 06 — Exporting to ONNX & Integrating into the Flutter App

Once your PyTorch training is complete and your model achieves 98%+ validation accuracy, you need to convert it into a format that runs offline on iOS and Android without Python or PyTorch.

This guide details the export process, quantization, and dropping the new model directly into the Dhikr Counter Flutter app.

---

## 1. Exporting PyTorch to ONNX (int8 Quantized)

Run the automated export script:

```bash
python scripts/04_export_to_onnx.py \
  --checkpoint checkpoints/best_dhikr_model.pt \
  --output-dir ../assets/models/custom_dhikr
```

### What This Generates:
Inside `assets/models/custom_dhikr/`:
1. `encoder.int8.onnx` (~4 MB to 10 MB): Quantized acoustic encoder.
2. `tokens.txt` (or `labels.txt`): Mapping of phrase IDs to Arabic text labels.

### Why int8 Quantization is Mandatory:
- **Reduces size by 75%** (e.g. from 40MB down to 10MB).
- **Uses 8-bit integer CPU instructions** (ARM NEON on Apple Silicon and Snapdragon), speeding up inference by 2x–3x.
- **Zero cloud calls:** Runs 100% locally on the device with zero Internet access.

---

## 2. Integrating into the Flutter Project

Our Flutter codebase is already engineered with clean modularity to consume `sherpa-onnx` models. Integrating your custom model takes just 3 quick steps:

### Step A: Declare Assets in `pubspec.yaml`
Ensure the custom model directory is registered under `flutter.assets`:

```yaml
flutter:
  assets:
    - assets/models/custom_dhikr/
    - assets/models/tarteel_tiny_quran/
    - assets/models/moonshine_arabic/
```

### Step B: Register Model in `ModelAssetExtractor`
Open `lib/recognition/asr/model_asset_extractor.dart` and add:

```dart
static const List<String> customDhikrFiles = [
  'encoder.int8.onnx',
  'tokens.txt',
];

static Future<Directory> getCustomDhikrModelDirectory() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final modelDir = Directory('${docsDir.path}/models/custom_dhikr');
  if (!modelDir.existsSync()) {
    await modelDir.create(recursive: true);
  }
  return modelDir;
}
```

### Step C: Prioritize the Model in `app_scope.dart`
Open `lib/app/app_scope.dart` and point `asrEngine` to your new model directory:

```dart
final customModelDir = '${docsDir.path}/models/custom_dhikr';
final customEngine = SherpaOnnxAsrEngine.kws( // or .conformer()
  modelPath: '$customModelDir/encoder.int8.onnx',
  tokensPath: '$customModelDir/tokens.txt',
);

if (customEngine.areModelFilesPresent) {
  asrEngine = customEngine;
  debugPrint('[AppDependencies] Using CUSTOM trained Dhikr model!');
}
```

---

## 3. Verification & Testing

1. Run the test suite:
   ```bash
   flutter test
   ```
2. Launch on the iOS simulator or physical device:
   ```bash
   flutter run -d <device_id>
   ```
3. Test your recitation:
   - Select your dhikr (e.g. *Astaghfirullah*).
   - Recite rapidly in your natural regional cadence.
   - Watch the counter track `+1, +2, +3...` in real-time with zero lag!
