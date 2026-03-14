class DetectionConfig {
  const DetectionConfig._();

  static const String modelAssetPath = 'assets/obstacle/models/best_float32.tflite';
  static const String labelsAssetPath = 'assets/obstacle/labels/best_float32_labels.txt';

  static const int inputSize = 300;
  static const double confidenceThreshold = 0.50;
  static const double iouThreshold = 0.45;

  static const int processEveryNFrames = 1;

  static const int intraOpThreads = 2;
}
