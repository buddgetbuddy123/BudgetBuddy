import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'cloud_ocr_service.dart';
import 'image_preprocessor.dart';
import 'ocr_cleanup_service.dart';
import 'ocr_config.dart';

/// Which engine actually produced a given OCR result.
enum OcrEngine { cloud, onDevice }

/// Result of an OCR pass, including which engine ran — so the UI can be
/// honest with the user about whether handwriting was actually read.
class OcrResult {
  final String text;
  final OcrEngine engine;

  /// True only when [engine] is [OcrEngine.cloud] — the on-device
  /// recognizer never reads handwriting, no matter how the image is
  /// preprocessed.
  final bool supportsHandwriting;

  const OcrResult({
    required this.text,
    required this.engine,
    required this.supportsHandwriting,
  });
}

/// Hybrid OCR pipeline:
///   1. If cloud OCR is configured (API key set), try it first — it's the
///      only engine here that can read handwriting. Network dependent.
///   2. If that's unavailable (no key, no internet, timeout, request
///      failure, or it just didn't find any text) fall back to the
///      on-device ML Kit recognizer — offline-safe, but printed text only.
///
/// This means the app always works offline (like before), and
/// transparently gets better (including handwriting) whenever the device
/// has a connection and a Cloud Vision key is configured.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();
  final ImagePreprocessor _preprocessor = ImagePreprocessor();
  final OcrCleanupService _cleanup = OcrCleanupService();
  final CloudOcrService _cloudOcr = CloudOcrService();

  /// Engine used by the most recent [extractText] / [extractDetailed]
  /// call. Handy for callers still using the legacy String-only API that
  /// want to show "read online" vs "read offline" without switching over.
  OcrEngine? lastEngineUsed;

  /// Backward-compatible entry point — returns cleaned text only.
  /// Prefer [extractDetailed] in new code so you can tell the user
  /// whether handwriting was actually supported for this scan.
  Future<String> extractText(String imagePath) async {
    final result = await extractDetailed(imagePath);
    return result.text;
  }

  /// Runs the hybrid pipeline described above and returns which engine
  /// produced the result along with the cleaned text.
  Future<OcrResult> extractDetailed(String imagePath) async {
    // ── 1. Try cloud OCR first — the only engine that reads handwriting ──
    if (OcrConfig.isCloudOcrConfigured) {
      try {
        final uploadPath = await _preprocessor.prepareForCloudUpload(imagePath);
        final cloudText = await _cloudOcr.extractText(uploadPath);
        final cleaned = _cleanup.clean(cloudText);

        if (cleaned.isNotEmpty) {
          lastEngineUsed = OcrEngine.cloud;
          return OcrResult(
            text: cleaned,
            engine: OcrEngine.cloud,
            supportsHandwriting: true,
          );
        }
        // Cloud call succeeded but found nothing usable — fall through
        // to on-device rather than returning empty text.
        debugPrint('CLOUD OCR: succeeded but returned no usable text.');
      } catch (e) {
        // TEMPORARY: log the real reason cloud OCR failed instead of
        // swallowing it, so we can diagnose setup issues (billing not
        // enabled, API not enabled, bad key restriction, network error,
        // etc). Safe to revert to a silent `catch (_) {}` once cloud OCR
        // is confirmed working end-to-end.
        debugPrint('CLOUD OCR FAILED: $e');
      }
    } else {
      debugPrint('CLOUD OCR: not configured (no API key at build time).');
    }

    // ── 2. On-device fallback — offline-safe, printed text only ─────────
    final text = await _extractOnDevice(imagePath);
    lastEngineUsed = OcrEngine.onDevice;
    return OcrResult(
      text: text,
      engine: OcrEngine.onDevice,
      supportsHandwriting: false,
    );
  }

  Future<String> _extractOnDevice(String imagePath) async {
    try {
      String finalText = '';

      // Process original image
      final processedPath = await _preprocessor.process(imagePath);

      final candidates = <String>[
        imagePath, // Original image
        processedPath, // Enhanced image
      ];

      for (final path in candidates) {
        final file = File(path);

        if (!await file.exists()) continue;

        final inputImage = InputImage.fromFilePath(path);
        final recognizedText = await _recognizer.processImage(inputImage);

        final buffer = StringBuffer();

        // Keep receipt formatting line-by-line
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final text = line.text.trim();

            if (text.isNotEmpty) {
              buffer.writeln(text);
            }
          }
        }

        final extracted = buffer.toString().trim();

        // Keep whichever OCR pass produced more text
        if (extracted.length > finalText.length) {
          finalText = extracted;
        }
      }

      // Fallback if blocks were empty
      if (finalText.isEmpty) {
        final inputImage = InputImage.fromFilePath(processedPath);
        final recognizedText = await _recognizer.processImage(inputImage);

        finalText = recognizedText.text.trim();
      }

      // Fix common OCR mistakes
      finalText = _cleanup.clean(finalText);

      return finalText;
    } catch (e) {
      throw Exception('OCR failed: $e');
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
  