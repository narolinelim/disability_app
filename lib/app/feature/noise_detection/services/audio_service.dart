/*
 * Pipeline location: app/feature/noise_detection/services/audio_service.dart (Step 6 of 8)
 * General function: Streams microphone PCM audio, builds model windows, computes dB, and emits predictions.
 * Return/output: resultsStream emits NoiseFrameResult events for controller/UI consumption.
 */
import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../models/noise_detection_config.dart';
import '../models/noise_detection_models.dart';
import 'decibel_detector.dart';
import 'sound_classifier.dart';

class AudioService {
  AudioService({
    required SoundClassifier classifier,
    required this.dangerThresholdDb,
  }) : _classifier = classifier;

  final AudioRecorder _recorder = AudioRecorder();
  final SoundClassifier _classifier;
  final double dangerThresholdDb;

  final StreamController<NoiseFrameResult> _resultsController =
      StreamController<NoiseFrameResult>.broadcast();
  final List<double> _sampleBuffer = <double>[];

  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isDisposed = false;
  bool _isRecording = false;
  DateTime? _lastPredictionAt;

  Stream<NoiseFrameResult> get resultsStream => _resultsController.stream;
  bool get isRecording => _isRecording;

  // Starts streaming audio
  Future<void> startRecording() async {
    if (_isDisposed || _isRecording) {
      return;
    }

    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission denied');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: NoiseDetectionConfig.sampleRate,
        numChannels: 1,
      ),
    );

    _isRecording = true;

    await _audioSubscription?.cancel();
    _audioSubscription = stream.listen(_onAudioChunk);
  }

  // Handles incoming audio chunks, builds model windows, computes dB, and emits results.
  void _onAudioChunk(Uint8List data) {
    if (_isDisposed || !_isRecording) {
      return;
    }

    // Convert byte to float 
    // The audio stream is PCM 16-bit, so we interpret the byte data as signed 16-bit integers and normalize to [-1.0, 1.0].
    final int16Buffer =
        data.buffer.asInt16List(data.offsetInBytes ~/ 2, data.lengthInBytes ~/ 2);
    _sampleBuffer.addAll(int16Buffer.map((sample) => sample / 32768.0));

    while (_sampleBuffer.length >= NoiseDetectionConfig.modelInputSamples) {
      // Build a fixed-size model window and then advance by hopSamples (overlap windowing).
      // So this run inference every hopSamples (in config). The sliding window move forward by hopSamples amount
      final window = _sampleBuffer
          .take(NoiseDetectionConfig.modelInputSamples)
          .toList(growable: false);
      _sampleBuffer.removeRange(
        0,
        NoiseDetectionConfig.hopSamples.clamp(1, _sampleBuffer.length),
      );

      final db = DecibelDetector.calculateDb(window);
      final isDanger =
          DecibelDetector.isDanger(db, thresholdDb: dangerThresholdDb);

      final now = DateTime.now();
        // Throttle inference to one prediction every configured interval to reduce UI churn.
      if (_lastPredictionAt != null &&
          now.difference(_lastPredictionAt!).inMilliseconds <
              NoiseDetectionConfig.predictionIntervalMs) {
        continue;
      }

      _lastPredictionAt = now;
      final prediction = _classifier.classify(window);

      if (!_resultsController.isClosed) {
        _resultsController.add(
          NoiseFrameResult(
            decibel: db,
            isDanger: isDanger,
            prediction: prediction,
            timestamp: DateTime.now(),
          ),
        );
      }
    }

  }

  Future<void> stopRecording() async {
    if (!_isRecording) {
      return;
    }

    await _recorder.stop();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _sampleBuffer.clear();
    _lastPredictionAt = null;

    _isRecording = false;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    if (_isRecording) {
      await stopRecording();
    }
    await _audioSubscription?.cancel();
    await _resultsController.close();
    _sampleBuffer.clear();
    _lastPredictionAt = null;
  }

}