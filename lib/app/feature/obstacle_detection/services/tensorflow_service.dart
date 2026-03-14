/*
 * Pipeline location: app/feature/obstacle_detection/services/tensorflow_service.dart (Step 3 of 8)
 * General function: Loads the TFLite model and labels from bundled assets and holds interpreter state.
 * Return/output: initialize() returns Future<void> and prepares interpreter/labels for downstream inference.
 */
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection_config.dart';

class TensorflowService {
  const TensorflowService._();

  static const ssdMobileNet = TensorflowService._();

  static Interpreter? _interpreter;
  static List<String>? _labels;
  static Future<void>? _initializing;

  Interpreter get interpreter {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('TensorflowService is not initialized. Call initialize() first.');
    }
    return interpreter;
  }

  List<String> get labels {
    final labels = _labels;
    if (labels == null) {
      throw StateError('TensorflowService labels are not initialized. Call initialize() first.');
    }
    return labels;
  }

  Future<void> initialize() async {
    if (_interpreter != null && _labels != null) {
      return;
    }

    final inFlight = _initializing;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final initFuture = _initializeInternal();
    _initializing = initFuture;
    try {
      await initFuture;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    final options = InterpreterOptions()..threads = DetectionConfig.intraOpThreads;
    final interpreter = await Interpreter.fromAsset(
      DetectionConfig.modelAssetPath,
      options: options,
    );

    final labelsRaw = await rootBundle.loadString(DetectionConfig.labelsAssetPath);

    _interpreter = interpreter;
    _labels = labelsRaw.split(RegExp(r'\r?\n'));
  }
}