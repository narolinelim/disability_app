/*
 * Pipeline location: app/feature/obstacle_detection/services/camera_stream_coordinator.dart (Step 5 of 8)
 * General function: Owns camera controller lifecycle and throttled frame streaming into the detector callback.
 * Return/output: initialize()/startStream()/stopStream()/dispose() return Future<void>; controller getter returns CameraController?.
 */
import 'dart:async';

import 'package:camera/camera.dart';

import '../models/detection_config.dart';

class CameraStreamCoordinator {
  CameraController? _controller;
  bool _isBusy = false;
  bool _isDisposed = false;
  int _incomingFrameCount = 0;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize(CameraDescription camera) async {
    if (_isDisposed) {
      return;
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  Future<void> startStream(Future<void> Function(CameraImage image) onFrame) async {
    if (_isDisposed || !isInitialized) {
      return;
    }

    final controller = _controller!;
    if (controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((CameraImage image) {
      _incomingFrameCount += 1;
      if (_incomingFrameCount % DetectionConfig.processEveryNFrames != 0) {
        return;
      }
      if (_isBusy || _isDisposed) {
        return;
      }

      _isBusy = true;
      unawaited(() async {
        try {
          await onFrame(image);
        } finally {
          _isBusy = false;
        }
      }());
    });
  }

  Future<void> stopStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }

    await controller.stopImageStream();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    final controller = _controller;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    _controller = null;
  }
}
