/*
 * Pipeline location: app/feature/noise_detection/controllers/noise_detection_controller.dart (Step 7 of 8)
 * General function: Orchestrates model/audio lifecycle and exposes stream + ValueNotifier UI state.
 * Return/output: start/pause/resume/dispose manage runtime; resultsStream publishes frame-level results.
 */
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/noise_detection_config.dart';
import '../models/noise_detection_models.dart';
import '../services/audio_service.dart';
import '../services/sound_classifier.dart';
import '../services/tensorflow_service.dart';

class NoiseDetectionController with WidgetsBindingObserver {
	NoiseDetectionController({
		NoiseTensorflowService? tensorflowService,
	}) : _tensorflowService = tensorflowService ?? NoiseTensorflowService.yamNet {
		WidgetsBinding.instance.addObserver(this);
	}

	final NoiseTensorflowService _tensorflowService;

	AudioService? _audioService;
	StreamSubscription<NoiseFrameResult>? _audioResultsSubscription;
	bool _isDisposed = false;

	final StreamController<NoiseFrameResult> _resultsController =
			StreamController<NoiseFrameResult>.broadcast();

	final ValueNotifier<NoiseUiState> uiState =
			ValueNotifier<NoiseUiState>(const NoiseUiState.initial());

	// UI and feature host subscribe to this stream for per-frame noise results.
	Stream<NoiseFrameResult> get resultsStream => _resultsController.stream;

	Future<void> start() async {
		if (_isDisposed) {
			return;
		}

		try {
			await _tensorflowService.initialize();
			_setUiState(uiState.value.copyWith(isModelReady: true, clearError: true));

			if (_audioService == null) {
				// Build processing services once and reuse them while the screen is alive.
				final classifier = SoundClassifier(
					interpreter: _tensorflowService.interpreter,
					classMap: _tensorflowService.classMap,
					confidenceThreshold: NoiseDetectionConfig.confidenceThreshold,
				);
				_audioService = AudioService(
					classifier: classifier,
					dangerThresholdDb: NoiseDetectionConfig.alertDecibelThreshold,
				);

				_audioResultsSubscription = _audioService!.resultsStream.listen((result) {
					if (_isDisposed || _resultsController.isClosed) {
						return;
					}

					// Forward each frame result so the host can build alert cards.
					_resultsController.add(result);
					_setUiState(
						uiState.value.copyWith(
							// Keep a live reading in state for top-level status text in the UI.
							lastLabel: result.prediction?.label,
							lastDecibel: result.decibel,
							clearError: true,
						),
					);
				});
			}

			await _audioService!.startRecording();
			_setUiState(uiState.value.copyWith(isListening: true, clearError: true));
		} catch (e) {
			_setUiState(
				uiState.value.copyWith(
					isListening: false,
					error: 'Noise detection failed: $e',
				),
			);
		}
	}

	Future<void> pause() async {
		final audioService = _audioService;
		if (audioService == null || !audioService.isRecording) {
			return;
		}

		await audioService.stopRecording();
		_setUiState(uiState.value.copyWith(isListening: false, clearError: true));
	}

	Future<void> resume() async {
		if (_isDisposed) {
			return;
		}

		final audioService = _audioService;
		if (audioService == null) {
			await start();
			return;
		}

		if (!audioService.isRecording) {
			await audioService.startRecording();
			_setUiState(uiState.value.copyWith(isListening: true, clearError: true));
		}
	}

	void _setUiState(NoiseUiState state) {
		if (_isDisposed) {
			return;
		}
		uiState.value = state;
	}

	@override
	void didChangeAppLifecycleState(AppLifecycleState state) {
		if (_isDisposed) {
			return;
		}

		switch (state) {
			// Pause recording when app is not foregrounded to avoid background capture.
			case AppLifecycleState.resumed:
				unawaited(resume());
			case AppLifecycleState.inactive:
			case AppLifecycleState.hidden:
			case AppLifecycleState.paused:
			case AppLifecycleState.detached:
				unawaited(pause());
		}
	}

	Future<void> dispose() async {
		_isDisposed = true;
		WidgetsBinding.instance.removeObserver(this);

		await _audioResultsSubscription?.cancel();
		await _audioService?.dispose();

		await _resultsController.close();
		uiState.dispose();
	}
}
