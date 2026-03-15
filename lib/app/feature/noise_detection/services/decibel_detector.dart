/*
 * Pipeline location: app/feature/noise_detection/services/decibel_detector.dart (Step 5 of 8)
 * General function: Computes an RMS-based decibel estimate and evaluates danger threshold crossings.
 * Return/output: calculateDb() returns estimated dB; isDanger() returns threshold decision.
 */
import 'dart:math';

import '../models/noise_detection_config.dart';

class DecibelDetector {
  static double calculateDb(List<double> buffer) {
    if (buffer.isEmpty) {
      return 0;
    }

    double sum = 0;
    for (var sample in buffer) {
      sum += sample * sample;
    }

    final rms = sqrt(sum / buffer.length);
    if (rms == 0) {
      return 0;
    }

    // Estimate sound level from normalized PCM samples via RMS -> dB conversion.
    return 20 * log(rms) / ln10;
  }

  static bool isDanger(double db, {double? thresholdDb}) {
    final effectiveThreshold =
        thresholdDb ?? NoiseDetectionConfig.alertDecibelThreshold;
    return db > effectiveThreshold;
  }
}