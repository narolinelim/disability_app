import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection_config.dart';

class TensorflowService {
  const TensorflowService._();

  static const ssdMobileNet = TensorflowService._();

  static late final Interpreter _interpreter;
  static late final List<String> _labels;

  Interpreter get interpreter => _interpreter;
  List<String> get labels => _labels;

  Future<void> initialize() async {
    await Future.wait([
      _loadModel(),
      _loadLabels(),
    ]);
  }

  Future<void> _loadModel() async {
    final options = InterpreterOptions()..threads = DetectionConfig.intraOpThreads;
    _interpreter = await Interpreter.fromAsset(
      DetectionConfig.modelAssetPath,
      options: options,
    );
  }

  Future<void> _loadLabels() async {
    final labelsRaw = await rootBundle.loadString(DetectionConfig.labelsAssetPath);
    _labels = labelsRaw.split(RegExp(r'\r?\n'));
  }
}