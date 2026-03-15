/*
 * Pipeline location: app/feature/noise_detection/services/sound_classifier.dart (Step 4 of 8)
 * General function: Runs model inference over a fixed audio window and maps output scores to a top label.
 * Return/output: classify() returns the strongest NoisePrediction for each valid window.
 */
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/noise_detection_config.dart';
import '../models/noise_detection_models.dart';

class SoundClassifier {
  SoundClassifier({
    required this.interpreter,
    required this.classMap,
    required this.confidenceThreshold,
  });

  final Interpreter interpreter;
  final List<NoiseClassInfo> classMap;
  final double confidenceThreshold;

  NoisePrediction? classify(List<double> buffer) {
    if (buffer.length != NoiseDetectionConfig.modelInputSamples) {
      return null;
    }

    final inputTensor = interpreter.getInputTensor(0);
    final shape = inputTensor.shape;
    final Object input =
        shape.length == 1 && shape[0] == NoiseDetectionConfig.modelInputSamples
            ? buffer
            : <List<double>>[buffer];
    final output = List.generate(
      1,
      (_) => List<double>.filled(NoiseDetectionConfig.modelOutputClasses, 0.0),
    );

    interpreter.run(input, output);

    double maxScore = -1;
    int maxIndex = -1;
    final scores = output[0];

    // Select top-1 class from model logits/probabilities for lightweight real-time UI updates.
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

    final classInfo = maxIndex < classMap.length
        ? classMap[maxIndex]
        : NoiseClassInfo(
            index: maxIndex,
            mid: '/m/unknown_$maxIndex',
            displayName: 'Unknown sound',
          );

    return NoisePrediction(
      mid: classInfo.mid,
      displayName: classInfo.displayName,
      confidence: maxScore,
      index: maxIndex,
    );
  }
}