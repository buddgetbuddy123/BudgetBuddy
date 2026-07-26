import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class _ProcessArgs {
  final Uint8List bytes;
  final String outputDir;
  const _ProcessArgs(this.bytes, this.outputDir);
}

class _CloudArgs {
  final Uint8List bytes;
  final String outputDir;
  const _CloudArgs(this.bytes, this.outputDir);
}

/// Runs entirely on a background isolate via [compute] — decode, resize,
/// grayscale, contrast, and the sharpen convolution are all CPU-bound pixel
/// operations that are heavy enough on a full-resolution photo to visibly
/// freeze the UI thread if run inline. Doing this on the calling isolate
/// was the actual cause of the reported lag while scanning.
String _processOnDeviceIsolate(_ProcessArgs args) {
  img.Image? image = img.decodeImage(args.bytes);
  if (image == null) {
    throw Exception('Unable to decode image.');
  }

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

  image = img.grayscale(image);
  image = img.adjustColor(image, brightness: 0.12);
  image = img.adjustColor(image, contrast: 1.6);
  image = img.convolution(image, filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0]);

  final savedPath = path.join(
    args.outputDir,
    'processed_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  File(savedPath).writeAsBytesSync(img.encodeJpg(image, quality: 100));
  return savedPath;
}

String _processCloudIsolate(_CloudArgs args) {
  img.Image? image = img.decodeImage(args.bytes);
  if (image == null) {
    throw Exception('Unable to decode image.');
  }

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

  final savedPath = path.join(
    args.outputDir,
    'cloud_upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  File(savedPath).writeAsBytesSync(img.encodeJpg(image, quality: 92));
  return savedPath;
}

class ImagePreprocessor {
  /// Prepares an image for the ON-DEVICE ML Kit recognizer. ML Kit does
  /// best on high-contrast, sharpened, grayscale input, so this pass is
  /// deliberately aggressive.
  ///
  /// The actual pixel work runs on a background isolate (see
  /// [_processOnDeviceIsolate]) so a large photo doesn't freeze the UI
  /// while scanning.
  Future<String> process(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Image not found.');
    }

    final bytes = await file.readAsBytes();
    final tempDir = await getTemporaryDirectory();

    return compute(_processOnDeviceIsolate, _ProcessArgs(bytes, tempDir.path));
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
  ///
  /// Also runs on a background isolate for the same reason as [process].
  Future<String> prepareForCloudUpload(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Image not found.');
    }

    final bytes = await file.readAsBytes();
    final tempDir = await getTemporaryDirectory();

    return compute(_processCloudIsolate, _CloudArgs(bytes, tempDir.path));
  }
}
