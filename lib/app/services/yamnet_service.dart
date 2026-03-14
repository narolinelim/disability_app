import 'package:tflite_flutter/tflite_flutter.dart';

class YamnetService {

  late Interpreter _interpreter;

  Future<void> loadModel() async {

    _interpreter = await Interpreter.fromAsset("assets/models/1.tflite");
    // Interpreter.fromAsset(
    //   "1.tflite",
    //   options: InterpreterOptions()..threads = 2,
    // );

  }

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