import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/noise_detection_config.dart';
import '../models/noise_detection_models.dart';

class SoundClassifier {
  SoundClassifier({
    required this.interpreter,
    required this.labels,
    required this.confidenceThreshold,
  });

  final Interpreter interpreter;
  final List<String> labels;
  final double confidenceThreshold;

  NoisePrediction? classify(List<double> buffer) {
    if (buffer.length != NoiseDetectionConfig.modelInputSamples) {
      return null;
    }

    final input = [buffer];
    final output = List.generate(
      1,
      (_) => List<double>.filled(NoiseDetectionConfig.modelOutputClasses, 0.0),
    );

    interpreter.run(input, output);

    double maxScore = -1;
    int maxIndex = -1;
    final scores = output[0];

    for (int i = 0; i < scores.length; i++) {
      final score = scores[i];
      if (score > maxScore) {
        maxScore = score;
        maxIndex = i;
      }
    }

    if (maxIndex < 0) {
      return null;
    }

    final label = maxIndex < labels.length ? labels[maxIndex] : 'Unknown sound';
    return NoisePrediction(
      label: label,
      confidence: maxScore,
      index: maxIndex,
    );
  }
}