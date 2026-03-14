import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class SoundClassifier {

  late Interpreter interpreter;

  List<String> labels = [];

  // --------------------------
  // 加载模型和标签
  // --------------------------
  Future<void> loadModel() async {

    // 加载 tflite
    interpreter = await Interpreter.fromAsset('1.tflite');

    // 加载 csv
    final csv = await rootBundle.loadString('assets/yamnet_class_map.csv');

    List<String> lines = csv.split('\n');

    labels = lines.skip(1).map((line) {
      final parts = line.split(',');
      return parts[2];
    }).toList();

    print("Model loaded");
    print("Labels loaded: ${labels.length}");
  }

  // --------------------------
  // 声音分类
  // --------------------------
  String classify(List<double> buffer) {

    // 输入 shape: [1, 15600]
    var input = [buffer];

    // 输出 shape: [1, 521]
    var output = List.generate(
      1,
          (_) => List.filled(521, 0.0),
    );

    interpreter.run(input, output);

    // 找最大概率
    double maxScore = -1;
    int index = 0;

    for (int i = 0; i < output[0].length; i++) {

      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        index = i;
      }

    }

    return labels[index];
  }

}