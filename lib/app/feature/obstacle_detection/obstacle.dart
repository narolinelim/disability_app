/*
 * Pipeline location: app/feature/obstacle_detection/obstacle.dart (Step 8 of 8)
 * General function: Hosts the live detection screen, binds controller state to UI, and forwards frame results.
 * Return/output: build() returns the live camera + overlay UI; emits FrameResult through frameResultStream callback.
 */
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'controllers/traffic_detector_controller.dart';
import 'models/detection_models.dart';
import 'screen/detection_overlay.dart';

class TrafficDetectorScreen extends StatefulWidget {
  final CameraDescription camera;
  final ValueChanged<FrameResult>? frameResultStream;

  const TrafficDetectorScreen({
    super.key,
    required this.camera,
    this.frameResultStream,
  });

  @override
  State<TrafficDetectorScreen> createState() => _TrafficDetectorScreenState();
}

class _TrafficDetectorScreenState extends State<TrafficDetectorScreen> {
  late final TrafficDetectorController _controller;
  StreamSubscription<FrameResult>? _resultSubscription;
  FrameResult _latestResult = const FrameResult(
    rawOutput: null,
    detections: [],
    objectLabels: [],
    proximityScore: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = TrafficDetectorController();

    _resultSubscription = _controller.resultsStream.listen((result) {
      if (mounted) {
        setState(() {
          _latestResult = result;
        });
      }
      widget.frameResultStream?.call(result);
    });

    unawaited(_controller.start(widget.camera));
  }

  @override
  void dispose() {
    unawaited(_resultSubscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DetectorUiState>(
      valueListenable: _controller.uiState,
      builder: (context, state, _) {
        final controller = _controller.cameraController;
        if (controller == null || !controller.value.isInitialized) {
          return Scaffold(
            body: Center(
              child: state.error == null
                  ? const CircularProgressIndicator()
                  : Text(state.error!),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              Positioned.fill(
                child: DetectionOverlay(
                  detections: _latestResult.detections,
                  previewSize: controller.value.previewSize,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: state.isModelReady ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                state.isModelReady
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                state.isModelReady ? 'Model Ready' : 'Loading Model',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


