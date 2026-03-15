/*
 * Pipeline location: app/feature/obstacle_detection/obstacle.dart (Step 8 of 8)
 * General function: Hosts the live detection screen, binds controller state to UI, and forwards frame results.
 * Return/output: build() returns the live camera + overlay UI; emits FrameResult through frameResultStream callback.
 */
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/app_announcer.dart';
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
  static const _holdDurationSeconds = 3;
  static const _featureOnInstruction =
      'Obstacle detection is on. Hold screen for 3 seconds to stop.';
  static const _holdInstruction =
      'Keep holding for 3 seconds to stop obstacle detection.';
  static const _featureOffInstruction = 'Obstacle detection is off.';

  late final TrafficDetectorController _controller;
  StreamSubscription<FrameResult>? _resultSubscription;
  Timer? _holdStopTimer;
  Timer? _holdCountdownTimer;
  bool _isHoldingToStop = false;
  bool _isStopping = false;
  int _holdSecondsRemaining = _holdDurationSeconds;
  bool _didAnnounceHoldInstruction = false;
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
    unawaited(AppAnnouncer.instance.speak(_featureOnInstruction));
  }

  @override
  void dispose() {
    _cancelHoldToStop();
    unawaited(_resultSubscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }


  // Hold on the screen for 3 seconds to stop the detector and go back.
  void _startHoldToStop() {
    if (_isStopping) {
      return;
    }

    _cancelHoldToStop();
    setState(() {
      _isHoldingToStop = true;
      _holdSecondsRemaining = _holdDurationSeconds;
    });

    if (!_didAnnounceHoldInstruction) {
      _didAnnounceHoldInstruction = true;
      unawaited(
        AppAnnouncer.instance.speak(
          _holdInstruction,
          interrupt: true,
        ),
      );
    }

    _holdCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _holdSecondsRemaining =
            (_holdSecondsRemaining - 1).clamp(0, _holdDurationSeconds);
      });

      if (_holdSecondsRemaining == 0) {
        timer.cancel();
      }
    });

    _holdStopTimer = Timer(const Duration(seconds: 3), _stopAndClose);
  }

  void _cancelHoldToStop() {
    _holdStopTimer?.cancel();
    _holdCountdownTimer?.cancel();
    _holdStopTimer = null;
    _holdCountdownTimer = null;

    if (!mounted || _isStopping) {
      return;
    }

    setState(() {
      _isHoldingToStop = false;
      _holdSecondsRemaining = _holdDurationSeconds;
    });
    _didAnnounceHoldInstruction = false;
  }

  void _stopAndClose() {
    if (!mounted || _isStopping) {
      return;
    }

    _cancelHoldToStop();
    setState(() {
      _isStopping = true;
    });

    unawaited(AppAnnouncer.instance.speak(_featureOffInstruction));
    Navigator.of(context).maybePop();
  }
  // 
  
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
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _startHoldToStop(),
            onTapUp: (_) => _cancelHoldToStop(),
            onTapCancel: _cancelHoldToStop,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Positioned.fill(
                  child: DetectionOverlay(
                    detections: _latestResult.detections,
                    previewSize: controller.value.previewSize,
                    sensorOrientation: widget.camera.sensorOrientation,
                    mirrorHorizontally:
                        widget.camera.lensDirection == CameraLensDirection.front,
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
                            onPressed: _stopAndClose,
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
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isHoldingToStop
                              ? 'Hold $_holdSecondsRemaining s to stop'
                              : 'Hold screen for $_holdDurationSeconds s to stop detection',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


