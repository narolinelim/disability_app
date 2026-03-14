/*
 * Pipeline location: app/feature/obstacle_detection/services/detector.dart (Step 4 of 8)
 * General function: Runs frame inference in an isolate, decodes model outputs, and streams structured detections.
 * Return/output: Detector.start() returns Future<Detector>; resultsStream returns Stream<FrameResult>.
 */
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection_config.dart';
import '../models/detection_models.dart';
import 'tensorflow_service.dart';

class _Command {
  const _Command(this.processType, {this.args});

  final TensorflowProcessType processType;
  final List<Object?>? args;
}

enum TensorflowProcessType {
  init,
  busy,
  ready,
  detect,
  result,
}

class Detector {
  Detector._(this._isolate, this._interpreter, this._labels);

  final Isolate _isolate;
  final Interpreter _interpreter;
  final List<String> _labels;

  late final SendPort _sendPort;
  bool _isReady = false;

  final StreamController<FrameResult> _resultsStreamController =
      StreamController<FrameResult>.broadcast();

  Stream<FrameResult> get resultsStream => _resultsStreamController.stream;

  static Future<Detector> start() async {
    final service = TensorflowService.ssdMobileNet;
    final interpreter = service.interpreter;
    final labels = service.labels;

    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_DetectorServer._run, receivePort.sendPort);

    final detector = Detector._(isolate, interpreter, labels);
    receivePort.listen((message) {
      detector._handleCommand(message as _Command);
    });

    return detector;
  }

  void processFrame(CameraImage cameraImage) {
    if (_isReady) {
      _sendPort.send(
        _Command(TensorflowProcessType.detect, args: [cameraImage]),
      );
    }
  }

  void _handleCommand(_Command command) {
    switch (command.processType) {
      case TensorflowProcessType.init:
        _sendPort = command.args?[0] as SendPort;
        final rootIsolateToken = RootIsolateToken.instance!;
        _sendPort.send(
          _Command(
            TensorflowProcessType.init,
            args: [
              rootIsolateToken,
              _interpreter.address,
              _labels,
            ],
          ),
        );
        break;
      case TensorflowProcessType.ready:
        _isReady = true;
        break;
      case TensorflowProcessType.busy:
        _isReady = false;
        break;
      case TensorflowProcessType.result:
        _isReady = true;
        if (_resultsStreamController.isClosed) {
          return;
        }
        final payload = command.args?[0] as Map<Object?, Object?>;
        _resultsStreamController.add(_frameResultFromPayload(payload));
        break;
      case TensorflowProcessType.detect:
        break;
    }
  }

  FrameResult _frameResultFromPayload(Map<Object?, Object?> payload) {
    final detectionMaps = (payload['detections'] as List<Object?>? ?? const []);
    final detections = detectionMaps
        .whereType<Map<Object?, Object?>>()
        .map((m) {
          final bbox = (m['bbox'] as Map<Object?, Object?>?) ?? const {};
          return Detection(
            classId: ((m['classId'] as num?) ?? 0).toInt(),
            className: (m['className'] as String?) ?? 'obj',
            confidence: ((m['confidence'] as num?) ?? 0.0).toDouble(),
            bbox: Rect.fromLTWH(
              ((bbox['left'] as num?) ?? 0.0).toDouble(),
              ((bbox['top'] as num?) ?? 0.0).toDouble(),
              ((bbox['width'] as num?) ?? 1.0).toDouble(),
              ((bbox['height'] as num?) ?? 1.0).toDouble(),
            ),
            proximityScore: ((m['proximityScore'] as num?) ?? 0.0).toDouble(),
          );
        })
        .toList();

    final objectLabels = (payload['objectLabels'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList();

    return FrameResult(
      rawOutput: payload['rawOutput'],
      detections: detections,
      objectLabels: objectLabels,
      proximityScore: ((payload['proximityScore'] as num?) ?? 0.0).toDouble(),
    );
  }

  void stop() {
    _resultsStreamController.close();
    _isolate.kill();
    _interpreter.close();
  }
}

class _DetectorServer {
  _DetectorServer(this._sendPort);

  final SendPort _sendPort;
  Interpreter? _interpreter;
  List<String> _labels = const [];

  static void _run(SendPort sendPort) {
    final receivePort = ReceivePort();
    final server = _DetectorServer(sendPort);

    receivePort.listen((message) async {
      final command = message as _Command;
      await server._handleCommand(command);
    });

    sendPort.send(_Command(TensorflowProcessType.init, args: [receivePort.sendPort]));
  }

  Future<void> _handleCommand(_Command command) async {
    switch (command.processType) {
      case TensorflowProcessType.init:
        final rootIsolateToken = command.args?[0] as RootIsolateToken;
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        _interpreter = Interpreter.fromAddress(command.args?[1] as int);
        final labels = command.args?[2] as List<Object?>?;
        _labels = labels?.map((e) => e?.toString() ?? '').toList() ?? const [];
        _sendPort.send(const _Command(TensorflowProcessType.ready));
        break;
      case TensorflowProcessType.detect:
        _sendPort.send(const _Command(TensorflowProcessType.busy));
        final payload = _runInference(command.args?[0] as CameraImage);
        _sendPort.send(_Command(TensorflowProcessType.result, args: [payload]));
        break;
      case TensorflowProcessType.busy:
      case TensorflowProcessType.ready:
      case TensorflowProcessType.result:
        break;
    }
  }

  Map<String, Object?> _runInference(CameraImage cameraImage) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      return const {
        'rawOutput': null,
        'detections': <Map<String, Object?>>[],
        'objectLabels': <String>[],
        'proximityScore': 0.0,
      };
    }

    final inputTensor = interpreter.getInputTensor(0);
    final isFloatInput = inputTensor.type == TensorType.float32;

    final input = isFloatInput
        ? _cameraImageToFloatInputTensor(cameraImage)
        : _cameraImageToUint8InputTensor(cameraImage);

    final boxes = List.generate(
      1,
      (_) => List.generate(10, (_) => List<double>.filled(4, 0.0)),
    );
    final classes = List.generate(1, (_) => List<double>.filled(10, 0.0));
    final scores = List.generate(1, (_) => List<double>.filled(10, 0.0));
    final count = List<double>.filled(1, 0.0);

    final outputs = <int, Object>{
      0: boxes,
      1: classes,
      2: scores,
      3: count,
    };

    interpreter.runForMultipleInputs([input], outputs);

    final decoded = _decodeSsdOutputs(
      boxes: boxes,
      classes: classes,
      scores: scores,
      count: count,
      originalWidth: cameraImage.width,
      originalHeight: cameraImage.height,
    );

    final finalDetections = _applyNms(decoded, DetectionConfig.iouThreshold);
    final proximity = finalDetections.isEmpty
        ? 0.0
        : finalDetections
            .map((d) => d.proximityScore)
            .fold<double>(0.0, (a, b) => math.max(a, b));

    final labels = finalDetections
        .map((d) => '${d.className} ${(d.confidence * 100).toStringAsFixed(0)}%')
        .toList();

    return {
      'rawOutput': {
        'boxes': boxes,
        'classes': classes,
        'scores': scores,
        'count': count,
      },
      'detections': finalDetections.map(_serializeDetection).toList(),
      'objectLabels': labels,
      'proximityScore': proximity,
    };
  }

  List<Detection> _decodeSsdOutputs({
    required List<List<List<double>>> boxes,
    required List<List<double>> classes,
    required List<List<double>> scores,
    required List<double> count,
    required int originalWidth,
    required int originalHeight,
  }) {
    final detections = <Detection>[];

    final detectionsCount = count.isEmpty
        ? 0
        : count.first.toInt().clamp(0, boxes.first.length);

    for (int i = 0; i < detectionsCount; i++) {
      final score = scores.first[i];
      if (score < DetectionConfig.confidenceThreshold) {
        continue;
      }

      final classId = classes.first[i].toInt();
      final rectNormalized = boxes.first[i];

      final yMin = rectNormalized[0].clamp(0.0, 1.0);
      final xMin = rectNormalized[1].clamp(0.0, 1.0);
      final yMax = rectNormalized[2].clamp(0.0, 1.0);
      final xMax = rectNormalized[3].clamp(0.0, 1.0);

      final left = xMin * originalWidth;
      final top = yMin * originalHeight;
      final width = (xMax - xMin) * originalWidth;
      final height = (yMax - yMin) * originalHeight;

      if (width <= 1 || height <= 1) {
        continue;
      }

      final rect = Rect.fromLTWH(
        left.clamp(0, originalWidth.toDouble() - 1),
        top.clamp(0, originalHeight.toDouble() - 1),
        width.clamp(1, originalWidth.toDouble()),
        height.clamp(1, originalHeight.toDouble()),
      );

      final proximity = _calculateProximity(rect, originalWidth, originalHeight);

      detections.add(
        Detection(
          classId: classId,
          className: _labelForClassId(classId),
          confidence: score,
          bbox: rect,
          proximityScore: proximity,
        ),
      );
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections;
  }

  List<List<List<List<double>>>> _cameraImageToFloatInputTensor(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final input = List.generate(
      1,
      (_) => List.generate(
        DetectionConfig.inputSize,
        (_) => List.generate(DetectionConfig.inputSize, (_) => List<double>.filled(3, 0.0)),
      ),
    );

    final xRatio = width / DetectionConfig.inputSize;
    final yRatio = height / DetectionConfig.inputSize;
    final uBytesPerPixel = uPlane.bytesPerPixel ?? 1;
    final vBytesPerPixel = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < DetectionConfig.inputSize; y++) {
      final srcY = math.min((y * yRatio).floor(), height - 1);
      for (int x = 0; x < DetectionConfig.inputSize; x++) {
        final srcX = math.min((x * xRatio).floor(), width - 1);

        final yIndex = srcY * yPlane.bytesPerRow + srcX;
        final uvX = srcX ~/ 2;
        final uvY = srcY ~/ 2;
        final uIndex = uvY * uPlane.bytesPerRow + uvX * uBytesPerPixel;
        final vIndex = uvY * vPlane.bytesPerRow + uvX * vBytesPerPixel;

        final yValue = yPlane.bytes[yIndex].toDouble();
        final uValue = uPlane.bytes[uIndex].toDouble() - 128.0;
        final vValue = vPlane.bytes[vIndex].toDouble() - 128.0;

        final r = (yValue + 1.402 * vValue).clamp(0.0, 255.0) / 255.0;
        final g =
            (yValue - 0.344136 * uValue - 0.714136 * vValue).clamp(0.0, 255.0) /
                255.0;
        final b = (yValue + 1.772 * uValue).clamp(0.0, 255.0) / 255.0;

        input[0][y][x][0] = r;
        input[0][y][x][1] = g;
        input[0][y][x][2] = b;
      }
    }

    return input;
  }

  List<List<List<List<int>>>> _cameraImageToUint8InputTensor(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final input = List.generate(
      1,
      (_) => List.generate(
        DetectionConfig.inputSize,
        (_) => List.generate(DetectionConfig.inputSize, (_) => List<int>.filled(3, 0)),
      ),
    );

    final xRatio = width / DetectionConfig.inputSize;
    final yRatio = height / DetectionConfig.inputSize;
    final uBytesPerPixel = uPlane.bytesPerPixel ?? 1;
    final vBytesPerPixel = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < DetectionConfig.inputSize; y++) {
      final srcY = math.min((y * yRatio).floor(), height - 1);
      for (int x = 0; x < DetectionConfig.inputSize; x++) {
        final srcX = math.min((x * xRatio).floor(), width - 1);

        final yIndex = srcY * yPlane.bytesPerRow + srcX;
        final uvX = srcX ~/ 2;
        final uvY = srcY ~/ 2;
        final uIndex = uvY * uPlane.bytesPerRow + uvX * uBytesPerPixel;
        final vIndex = uvY * vPlane.bytesPerRow + uvX * vBytesPerPixel;

        final yValue = yPlane.bytes[yIndex].toDouble();
        final uValue = uPlane.bytes[uIndex].toDouble() - 128.0;
        final vValue = vPlane.bytes[vIndex].toDouble() - 128.0;

        final r = (yValue + 1.402 * vValue).clamp(0.0, 255.0).toInt();
        final g = (yValue - 0.344136 * uValue - 0.714136 * vValue)
            .clamp(0.0, 255.0)
            .toInt();
        final b = (yValue + 1.772 * uValue).clamp(0.0, 255.0).toInt();

        input[0][y][x][0] = r;
        input[0][y][x][1] = g;
        input[0][y][x][2] = b;
      }
    }

    return input;
  }

  List<Detection> _applyNms(List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) {
      return [];
    }

    final sorted = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <Detection>[];

    while (sorted.isNotEmpty) {
      final current = sorted.removeAt(0);
      selected.add(current);

      sorted.removeWhere(
        (candidate) =>
            candidate.classId == current.classId &&
            _iou(candidate.bbox, current.bbox) > iouThreshold,
      );
    }

    return selected;
  }

  double _iou(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);

    final overlapWidth = math.max(0.0, right - left);
    final overlapHeight = math.max(0.0, bottom - top);
    final intersection = overlapWidth * overlapHeight;

    final union = a.width * a.height + b.width * b.height - intersection;
    if (union <= 0) {
      return 0;
    }
    return intersection / union;
  }

  double _calculateProximity(Rect bbox, int frameWidth, int frameHeight) {
    final heightRatio = bbox.height / frameHeight;
    final verticalPosition = (bbox.bottom / frameHeight).clamp(0.0, 1.0);
    final areaRatio = (bbox.width * bbox.height) / (frameWidth * frameHeight);

    final score =
        (heightRatio * 0.50 + verticalPosition * 0.30 + areaRatio * 20.0) * 100;
    return score.clamp(0.0, 100.0);
  }

  Map<String, Object?> _serializeDetection(Detection d) {
    return {
      'classId': d.classId,
      'className': d.className,
      'confidence': d.confidence,
      'proximityScore': d.proximityScore,
      'bbox': {
        'left': d.bbox.left,
        'top': d.bbox.top,
        'width': d.bbox.width,
        'height': d.bbox.height,
      },
    };
  }

  String _labelForClassId(int classId) {
    final actualLabelLength = _labels.length - 1;
    if (classId < 0 || classId > actualLabelLength) {
      return '???';
    }

    final label = _labels[classId].trim();
    if (label.isEmpty) {
      return '???';
    }
    return label;
  }
}
