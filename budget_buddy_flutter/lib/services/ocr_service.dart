import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final _recognizer = TextRecognizer();

  Future<String> extractText(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  void dispose() {
    _recognizer.close();
  }
}
