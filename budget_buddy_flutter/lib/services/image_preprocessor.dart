import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  /// Prepares an image for the ON-DEVICE ML Kit recognizer. ML Kit does
  /// best on high-contrast, sharpened, grayscale input, so this pass is
  /// deliberately aggressive.
  Future<String> process(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Image not found.');
    }

    final bytes = await file.readAsBytes();

    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    // ----------------------------------------------------
    // Resize
    // ----------------------------------------------------

    const targetWidth = 1800;

    if (image.width > targetWidth) {
      image = img.copyResize(
        image,
        width: targetWidth,
        interpolation: img.Interpolation.cubic,
      );
    } else if (image.width < 1200) {
      image = img.copyResize(
        image,
        width: 1200,
        interpolation: img.Interpolation.cubic,
      );
    }

    // ----------------------------------------------------
    // Grayscale
    // ----------------------------------------------------

    image = img.grayscale(image);

    // ----------------------------------------------------
    // Brightness
    // ----------------------------------------------------

    image = img.adjustColor(
      image,
      brightness: 0.12,
    );

    // ----------------------------------------------------
    // Contrast
    // ----------------------------------------------------

    image = img.adjustColor(
      image,
      contrast: 1.6,
    );
    // ----------------------------------------------------
    // Sharpen
    // ----------------------------------------------------

    image = img.convolution(
      image,
      filter: const [
        0, -1, 0,
       -1,  5, -1,
        0, -1, 0,
      ],
    );

    // ----------------------------------------------------
    // Save
    // ----------------------------------------------------

    return _save(image, prefix: 'processed');
  }

  /// Prepares an image for CLOUD upload (Cloud Vision handwriting path).
  ///
  /// Deliberately much lighter than [process]: Cloud Vision's models are
  /// trained on natural photos, and aggressive grayscale/contrast/sharpen
  /// filtering tends to destroy the subtle stroke-width and gradient
  /// information handwriting recognition relies on. We only resize (to
  /// keep upload size/time reasonable) and re-encode at a slightly lower
  /// quality — no grayscale, no sharpen filter, no contrast push.
  ///
  /// Cloud Vision's size limits are generous (well into the tens of MB),
  /// so unlike a tight-quota free API we can afford to keep more detail —
  /// more resolution generally helps handwriting recognition accuracy.
  Future<String> prepareForCloudUpload(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Image not found.');
    }

    final bytes = await file.readAsBytes();

    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Unable to decode image.');
    }

    // Cap the largest dimension — plenty of resolution for text/handwriting
    // while keeping upload payloads reasonable.
    const maxDimension = 2400;

    if (image.width > maxDimension || image.height > maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: maxDimension,
              interpolation: img.Interpolation.cubic,
            )
          : img.copyResize(
              image,
              height: maxDimension,
              interpolation: img.Interpolation.cubic,
            );
    }

    return _save(image, prefix: 'cloud_upload', quality: 92);
  }

  Future<String> _save(
    img.Image image, {
    required String prefix,
    int quality = 100,
  }) async {
    final tempDir = await getTemporaryDirectory();

    final savedPath = path.join(
      tempDir.path,
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final savedFile = File(savedPath);

    await savedFile.writeAsBytes(
      img.encodeJpg(image, quality: quality),
    );

    return savedPath;
  }
}