/*
 * Pipeline location: app/feature/obstacle_detection/models/detection_config.dart (Step 1 of 8)
 * General function: Centralizes model, labels, threshold, and threading constants used by detection.
 * Return/output: Exposes static configuration values consumed by services and controllers.
 */
class DetectionConfig {
  const DetectionConfig._();

  static const String modelAssetPath = 'assets/obstacle/models/ssd_mobilenet_v1.tflite';
  static const String labelsAssetPath = 'assets/obstacle/label/labels.txt';

  static const int inputSize = 300;
  static const double confidenceThreshold = 0.50;
  static const double iouThreshold = 0.45;

  static const int processEveryNFrames = 1;

  static const int intraOpThreads = 2;
}
