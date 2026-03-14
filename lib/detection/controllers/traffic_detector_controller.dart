import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/detection_models.dart';
import '../services/camera_stream_coordinator.dart';
import '../services/detector.dart';

class TrafficDetectorController with WidgetsBindingObserver {
  TrafficDetectorController({
    Detector? detector,
    CameraStreamCoordinator? cameraCoordinator,
  })  : _detector = detector,
        _cameraCoordinator = cameraCoordinator ?? CameraStreamCoordinator() {
    WidgetsBinding.instance.addObserver(this);
  }

  Detector? _detector;
  final CameraStreamCoordinator _cameraCoordinator;
  StreamSubscription<FrameResult>? _detectorSubscription;

  final StreamController<FrameResult> _resultsController =
      StreamController<FrameResult>.broadcast();

  final ValueNotifier<DetectorUiState> uiState =
      ValueNotifier<DetectorUiState>(const DetectorUiState.initial());

  CameraDescription? _camera;
  bool _isDisposed = false;

  Stream<FrameResult> get resultsStream => _resultsController.stream;

  CameraController? get cameraController => _cameraCoordinator.controller;

  Future<void> start(CameraDescription camera) async {
    if (_isDisposed) {
      return;
    }

    _camera = camera;

    try {
      await _cameraCoordinator.initialize(camera);
      _setUiState(uiState.value.copyWith(isCameraReady: true, clearError: true));

      await _initializeDetector();
      _setUiState(uiState.value.copyWith(isModelReady: true, clearError: true));

      await _cameraCoordinator.startStream(_handleFrame);
    } catch (e) {
      _setUiState(
        uiState.value.copyWith(
          error: 'Initialization failed: $e',
        ),
      );
    }
  }

  Future<void> _initializeDetector() async {
    final detector = _detector ?? await Detector.start();
    _detector = detector;
    await _detectorSubscription?.cancel();
    _detectorSubscription = detector.resultsStream.listen((result) {
      if (_isDisposed || _resultsController.isClosed) {
        return;
      }
      _resultsController.add(result);
    });
  }

  Future<void> _handleFrame(CameraImage image) async {
    final detector = _detector;
    if (_isDisposed || detector == null) {
      return;
    }

    try {
      detector.processFrame(image);
    } catch (e) {
      _setUiState(uiState.value.copyWith(error: 'Frame processing failed: $e'));
    }
  }

  Future<void> pauseStream() async {
    await _cameraCoordinator.stopStream();
  }

  Future<void> resumeStream() async {
    if (_isDisposed || _camera == null || _detector == null) {
      return;
    }
    await _cameraCoordinator.startStream(_handleFrame);
  }

  void _setUiState(DetectorUiState state) {
    if (_isDisposed) {
      return;
    }
    uiState.value = state;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(resumeStream());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(pauseStream());
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    await _cameraCoordinator.dispose();
    await _detectorSubscription?.cancel();
    _detector?.stop();

    await _resultsController.close();
    uiState.dispose();
  }
}
