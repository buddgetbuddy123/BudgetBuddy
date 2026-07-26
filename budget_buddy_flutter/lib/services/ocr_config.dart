/// Configuration for the optional cloud OCR path (used for handwriting).
///
/// The API key is intentionally NOT hardcoded here — never commit a real
/// key to source control. Instead, pass it at build/run time:
///
///   flutter run --dart-define=CLOUD_VISION_API_KEY=your_key_here
///   flutter build apk --dart-define=CLOUD_VISION_API_KEY=your_key_here
///
/// Get a key from Google Cloud Console (enable the "Cloud Vision API" on a
/// project, then create an API key — restrict it to the Vision API and to
/// your app's package name / bundle id). Requires a billing account
/// attached to the project, but personal/testing use should stay well
/// within the free 1,000 units/month quota — verify current pricing at
/// https://cloud.google.com/vision/pricing since it can change.
///
/// If no key is provided, [isCloudOcrConfigured] is false and OcrService
/// automatically skips straight to the on-device (offline, printed-text-
/// only) recognizer — the app keeps working with zero setup.
class OcrConfig {
  static const String cloudVisionApiKey = String.fromEnvironment(
    'CLOUD_VISION_API_KEY',
  );

  static bool get isCloudOcrConfigured => cloudVisionApiKey.isNotEmpty;
}