/*
 * Pipeline location: app/feature/noise_detection/models/noise_detection_models.dart (Step 2 of 8)
 * General function: Defines immutable data contracts for predictions, frame results, and UI state.
 * Return/output: Model objects passed between services, controller, and widgets.
 */
class NoisePrediction {
	const NoisePrediction({
		required this.mid,
		required this.displayName,
		required this.confidence,
		required this.index,
	});

	final String mid;
	final String displayName;
	final double confidence;
	final int index;

	// Backward-compatible alias used by existing UI strings.
	String get label => displayName;
}

class NoiseClassInfo {
	const NoiseClassInfo({
		required this.index,
		required this.mid,
		required this.displayName,
	});

	final int index;
	final String mid;
	final String displayName;
}

class NoiseFrameResult {
	const NoiseFrameResult({
		required this.decibel,
		required this.isDanger,
		required this.prediction,
		required this.timestamp,
	});

	final double decibel;
	final bool isDanger;
	final NoisePrediction? prediction;
	final DateTime timestamp;
}

class NoiseUiState {
	const NoiseUiState({
		required this.isListening,
		required this.isModelReady,
		this.error,
		this.lastLabel,
		this.lastDecibel,
	});

	const NoiseUiState.initial()
			: isListening = false,
				isModelReady = false,
				error = null,
				lastLabel = null,
				lastDecibel = null;

	final bool isListening;
	final bool isModelReady;
	final String? error;
	final String? lastLabel;
	final double? lastDecibel;

	NoiseUiState copyWith({
		bool? isListening,
		bool? isModelReady,
		String? error,
		String? lastLabel,
		double? lastDecibel,
		bool clearError = false,
	}) {
		return NoiseUiState(
			isListening: isListening ?? this.isListening,
			isModelReady: isModelReady ?? this.isModelReady,
			error: clearError ? null : (error ?? this.error),
			lastLabel: lastLabel ?? this.lastLabel,
			lastDecibel: lastDecibel ?? this.lastDecibel,
		);
	}
}
