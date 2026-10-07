/// Core application constants and configuration.
class AppConstants {
  static const String appName = 'DhikrFlow';
  static const String appTagline = 'Rhythmic, hands-free offline remembrance';

  // Session limits and defaults
  static const int defaultTarget33 = 33;
  static const int defaultTarget100 = 100;

  // Confidence defaults
  static const double minAcceptConfidence = 0.70;
  static const double highConfidence = 0.85;

  // Private by design copy
  static const String privacyPromise =
      'Your recitation stays on your device. '
      'The app processes speech locally for counting and does not upload or store your recitation audio.';
}
