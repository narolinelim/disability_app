class NoiseDetectionConfig {
	const NoiseDetectionConfig._();

	static const String modelAssetPath =
			'assets/noise_detection/1.tflite';
	static const String labelsAssetPath =
			'assets/noise_detection/yamnet_class_map.csv';

	static const int sampleRate = 16000;
	static const int modelInputSamples = 15600;
	static const int modelOutputClasses = 521;
	static const int hopSamples = 7800;

	static const double confidenceThreshold = 0.25;
	static const double alertDecibelThreshold = 55.0;
	static const int predictionIntervalMs = 2000;
	static const int intraOpThreads = 2;
}
