import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ocr_config.dart';

/// Thrown whenever cloud OCR can't be used right now for any reason
/// (no key configured, no internet, timeout, bad response, no text
/// found, etc). OcrService catches this and falls back to the
/// on-device recognizer, so callers of OcrService never see it directly.
class CloudOcrUnavailableException implements Exception {
  final String message;
  CloudOcrUnavailableException(this.message);

  @override
  String toString() => 'CloudOcrUnavailableException: $message';
}

/// Calls Google Cloud Vision's DOCUMENT_TEXT_DETECTION feature.
///
/// Unlike the on-device ML Kit recognizer, Cloud Vision can read
/// handwriting reasonably well — but it requires a network connection,
/// a configured API key, and a billing account on the project (see
/// OcrConfig). This service is meant to be used as an *optional
/// enhancement* — always call it from somewhere that can fall back to
/// on-device OCR on failure.
class CloudOcrService {
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate';
  static const _timeout = Duration(seconds: 15);

  Future<String> extractText(String imagePath) async {
    if (!OcrConfig.isCloudOcrConfigured) {
      throw CloudOcrUnavailableException('No Cloud Vision API key configured.');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw CloudOcrUnavailableException('Image not found.');
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('$_endpoint?key=${OcrConfig.cloudVisionApiKey}');

    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Image},
          'features': [
            {'type': 'DOCUMENT_TEXT_DETECTION'},
          ],
          // English + Filipino, since receipts in this app are PH-based.
          // Cloud Vision ignores hints it doesn't recognize, so this is
          // safe even for receipts in other languages.
          'imageContext': {
            'languageHints': ['en', 'fil'],
          },
        },
      ],
    });

    http.Response response;
    try {
      response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);
    } on SocketException {
      // No network route at all — the offline case we need to handle.
      throw CloudOcrUnavailableException('No internet connection.');
    } on HttpException catch (e) {
      throw CloudOcrUnavailableException('Could not reach Cloud Vision: $e');
    } catch (e) {
      // Covers TimeoutException and anything else (DNS failure, TLS, etc).
      throw CloudOcrUnavailableException('Cloud OCR request failed: $e');
    }

    if (response.statusCode != 200) {
      throw CloudOcrUnavailableException(
        'Cloud Vision returned ${response.statusCode}: ${response.body}',
      );
    }

    late final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw CloudOcrUnavailableException('Bad response from Cloud Vision.');
    }

    final responses = decoded['responses'] as List<dynamic>?;
    if (responses == null || responses.isEmpty) {
      throw CloudOcrUnavailableException('Empty response from Cloud Vision.');
    }

    final result = responses.first as Map<String, dynamic>;

    if (result.containsKey('error')) {
      throw CloudOcrUnavailableException(
        'Cloud Vision error: ${result['error']}',
      );
    }

    final fullText =
        (result['fullTextAnnotation'] as Map<String, dynamic>?)?['text']
            as String?;

    if (fullText == null || fullText.trim().isEmpty) {
      throw CloudOcrUnavailableException('No text detected.');
    }

    return fullText.trim();
  }
}