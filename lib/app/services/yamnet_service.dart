import 'package:tflite_flutter/tflite_flutter.dart';

class YamnetService {

  late Interpreter _interpreter;

  // load yamnet model
  Future<void> loadModel() async {

    _interpreter = await Interpreter.fromAsset("assets/models/1.tflite");

  }

  // run model with input data, for example, output would be [0.21,0.42,0.63...], they are possibilities of each sound
  List<double> runInference(List<double> input) {

    var inputTensor = [input];

    var output =
    List.generate(1, (_) => List.filled(521, 0.0));
    final start = DateTime.now();
    _interpreter.run(inputTensor, output);
    final end = DateTime.now();
    // print("Inference time: ${end.difference(start).inMilliseconds} ms");
    return output[0];

  }

  // choose the maximum one within scores
  int argmax(List<double> scores) {

    double max = scores[0];
    int index = 0;

    for (int i = 1; i < scores.length; i++) {

      if (scores[i] > max) {

        max = scores[i];
        index = i;

      }

    }

    return index;

  }

}