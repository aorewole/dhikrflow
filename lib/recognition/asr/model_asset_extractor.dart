import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Helper to ensure offline Whisper ONNX models bundled in Flutter assets
/// are extracted into the application's local documents directory for native C++ loading.
class ModelAssetExtractor {
  static const List<String> requiredModelFiles = [
    'tiny-encoder.int8.onnx',
    'tiny-decoder.int8.onnx',
    'tiny-tokens.txt',
  ];

  /// Returns the target directory for the Whisper Tiny ONNX model.
  static Future<Directory> getModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/models/whisper_tiny');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Checks if all required model files are present and non-empty.
  static Future<bool> areModelsExtracted() async {
    final dir = await getModelDirectory();
    for (final filename in requiredModelFiles) {
      final file = File('${dir.path}/$filename');
      if (!file.existsSync() || file.lengthSync() == 0) {
        return false;
      }
    }
    return true;
  }

  /// Extracts the model files from assets if they are missing or incomplete.
  static Future<bool> ensureModelsExtracted() async {
    final dir = await getModelDirectory();

    // Check if already extracted
    bool allPresent = true;
    for (final filename in requiredModelFiles) {
      final file = File('${dir.path}/$filename');
      if (!file.existsSync() || file.lengthSync() == 0) {
        allPresent = false;
        break;
      }
    }

    if (allPresent) {
      debugPrint('[ModelAssetExtractor] All model files are already extracted.');
      return true;
    }

    debugPrint('[ModelAssetExtractor] Extracting offline Whisper model files from assets...');
    for (final filename in requiredModelFiles) {
      final destinationFile = File('${dir.path}/$filename');
      if (destinationFile.existsSync() && destinationFile.lengthSync() > 0) {
        continue;
      }

      try {
        final assetPath = 'assets/models/whisper_tiny/$filename';
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        await destinationFile.writeAsBytes(bytes, flush: true);
        debugPrint('[ModelAssetExtractor] Extracted $filename (${bytes.length} bytes)');
      } catch (e) {
        debugPrint('[ModelAssetExtractor] Could not load asset $filename: $e');
        // Fallback for local desktop / test runs
        final localFile = File('assets/models/whisper_tiny/$filename');
        if (localFile.existsSync() && localFile.lengthSync() > 0) {
          await localFile.copy(destinationFile.path);
          debugPrint('[ModelAssetExtractor] Copied $filename from local filesystem fallback.');
        } else {
          return false;
        }
      }
    }

    return true;
  }
}
