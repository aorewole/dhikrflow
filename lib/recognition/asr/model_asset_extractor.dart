import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Helper to ensure offline ONNX models bundled in Flutter assets
/// are extracted into the application's local documents directory for native C++ loading.
class ModelAssetExtractor {
  static const List<String> moonshineArabicFiles = [
    'encoder_model.ort',
    'decoder_model_merged.ort',
    'tokens.txt',
  ];

  static const List<String> whisperBaseFiles = [
    'base-encoder.int8.onnx',
    'base-decoder.int8.onnx',
    'base-tokens.txt',
  ];

  static const List<String> whisperTinyFiles = [
    'tiny-encoder.int8.onnx',
    'tiny-decoder.int8.onnx',
    'tiny-tokens.txt',
  ];

  /// Returns the target directory for the Moonshine Arabic ONNX model.
  static Future<Directory> getMoonshineModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/models/moonshine_arabic');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Returns the target directory for the Whisper Base ONNX model.
  static Future<Directory> getBaseModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/models/whisper_base');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Returns the target directory for the Whisper Tiny ONNX model.
  static Future<Directory> getTinyModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/models/whisper_tiny');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Extracts the model files from assets if they are missing or incomplete.
  /// Prioritizes purpose-built Moonshine Arabic, then Whisper Base, then Whisper Tiny.
  static Future<bool> ensureModelsExtracted() async {
    // 1. Try extracting purpose-built Moonshine Arabic model
    final moonshineDir = await getMoonshineModelDirectory();
    bool moonshineSuccess = true;
    for (final filename in moonshineArabicFiles) {
      final destFile = File('${moonshineDir.path}/$filename');
      if (destFile.existsSync() && destFile.lengthSync() > 0) continue;

      try {
        final assetPath = 'assets/models/moonshine_arabic/$filename';
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        await destFile.writeAsBytes(bytes, flush: true);
        debugPrint('[ModelAssetExtractor] Extracted Moonshine Arabic: $filename (${bytes.length} bytes)');
      } catch (_) {
        final localFile = File('assets/models/moonshine_arabic/$filename');
        if (localFile.existsSync() && localFile.lengthSync() > 0) {
          await localFile.copy(destFile.path);
          debugPrint('[ModelAssetExtractor] Copied $filename from local filesystem fallback.');
        } else {
          moonshineSuccess = false;
        }
      }
    }

    if (moonshineSuccess) {
      debugPrint('[ModelAssetExtractor] Dedicated Moonshine Arabic model ready on device.');
      return true;
    }

    // 2. Fallback to Whisper Base
    final baseDir = await getBaseModelDirectory();
    bool baseSuccess = true;
    for (final filename in whisperBaseFiles) {
      final destFile = File('${baseDir.path}/$filename');
      if (destFile.existsSync() && destFile.lengthSync() > 0) continue;

      try {
        final assetPath = 'assets/models/whisper_base/$filename';
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        await destFile.writeAsBytes(bytes, flush: true);
        debugPrint('[ModelAssetExtractor] Extracted Whisper Base: $filename (${bytes.length} bytes)');
      } catch (_) {
        final localFile = File('assets/models/whisper_base/$filename');
        if (localFile.existsSync() && localFile.lengthSync() > 0) {
          await localFile.copy(destFile.path);
          debugPrint('[ModelAssetExtractor] Copied $filename from local filesystem fallback.');
        } else {
          baseSuccess = false;
        }
      }
    }

    if (baseSuccess) {
      debugPrint('[ModelAssetExtractor] Whisper Base models ready on device.');
      return true;
    }

    // 3. Fallback to Whisper Tiny
    final tinyDir = await getTinyModelDirectory();
    bool tinySuccess = true;
    for (final filename in whisperTinyFiles) {
      final destFile = File('${tinyDir.path}/$filename');
      if (destFile.existsSync() && destFile.lengthSync() > 0) continue;

      try {
        final assetPath = 'assets/models/whisper_tiny/$filename';
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        await destFile.writeAsBytes(bytes, flush: true);
        debugPrint('[ModelAssetExtractor] Extracted Whisper Tiny: $filename (${bytes.length} bytes)');
      } catch (_) {
        final localFile = File('assets/models/whisper_tiny/$filename');
        if (localFile.existsSync() && localFile.lengthSync() > 0) {
          await localFile.copy(destFile.path);
          debugPrint('[ModelAssetExtractor] Copied $filename from local filesystem fallback.');
        } else {
          tinySuccess = false;
        }
      }
    }

    return tinySuccess;
  }
}
