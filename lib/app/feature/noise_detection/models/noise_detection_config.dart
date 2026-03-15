/*
 * Pipeline location: app/feature/noise_detection/models/noise_detection_config.dart (Step 1 of 8)
 * General function: Central constants for model assets, audio framing, thresholds, and runtime tuning.
 * Return/output: Static configuration values consumed by services, controller, and UI.
 */
class NoiseDetectionConfig {
	const NoiseDetectionConfig._();

	static const String modelAssetPath =
			'assets/noise_detection/1.tflite';
	static const String labelsAssetPath =
			'assets/noise_detection/yamnet_class_map.csv';

	static const int sampleRate = 16000;
	static const int modelInputSamples = 15600;
	static const int modelOutputClasses = 521;
	static const int hopSamples = 15600;

	static const double confidenceThreshold = 0.25;
	static const double alertDecibelThreshold = -12.0;
	static const int predictionIntervalMs = 1000;
	static const int intraOpThreads = 2;
}
