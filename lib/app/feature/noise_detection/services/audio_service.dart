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

  RecordConfig _pythonLikeCaptureConfig() {
    // Build a RecordConfig that approximates Python sounddevice InputStream behavior.
    return const RecordConfig(
      // Request raw PCM frames so Flutter receives short integer audio samples.
      encoder: AudioEncoder.pcm16bits,
      // Match Python SAMPLE_RATE=16000 for model-compatible timing/frequency content.
      sampleRate: NoiseDetectionConfig.sampleRate,
      // Match Python CHANNELS=1 to keep mono input parity.
      numChannels: 1,
      // Match Python blocksize to one full model window (15600 samples ~= 0.975s).
      streamBufferSize: NoiseDetectionConfig.modelInputSamples,
      // Disable automatic gain control so amplitude is not auto-scaled by the recorder.
      autoGain: false,
      // Disable acoustic echo cancellation to avoid capture-side DSP differences.
      echoCancel: false,
      // Disable noise suppression so captured waveform stays closer to raw microphone input.
      noiseSuppress: false,
      // Android-specific tuning to request the least processed microphone source.
      androidConfig: AndroidRecordConfig(
        // Prefer unprocessed source (closest to raw capture; may not be available on all devices).
        audioSource: AndroidAudioSource.unprocessed,
        // Keep normal audio mode to avoid voice-call processing paths.
        audioManagerMode: AudioManagerMode.modeNormal,
        // Avoid Bluetooth routing changes that can alter microphone profile/quality.
        manageBluetooth: false,
        // Keep speakerphone off to avoid route changes that can impact AEC behavior.
        speakerphone: false,
      ),
    );
  }

  RecordConfig _fallbackCaptureConfig() {
    return const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: NoiseDetectionConfig.sampleRate,
      numChannels: 1,
      streamBufferSize: NoiseDetectionConfig.modelInputSamples,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );
  }

  // Starts streaming audio
  Future<void> startRecording() async {
    if (_isDisposed || _isRecording) {
      return;
    }

    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission denied');
    }

    Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(_pythonLikeCaptureConfig());
    } catch (_) {
      // Some devices do not support unprocessed source; keep other parity settings.
      stream = await _recorder.startStream(_fallbackCaptureConfig());
    }

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
  final prediction = _classifier.classify(_peakNormalize(window));

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

  List<double> _peakNormalize(List<double> buffer) {
    double maxAbs = 0;
    for (final sample in buffer) {
      final abs = sample < 0 ? -sample : sample;
      if (abs > maxAbs) {
        maxAbs = abs;
      }
    }

    if (maxAbs <= 0) {
      return buffer;
    }

    return buffer.map((sample) => sample / maxAbs).toList(growable: false);
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