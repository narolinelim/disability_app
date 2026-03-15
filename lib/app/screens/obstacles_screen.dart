import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../feature/obstacle_detection/obstacle.dart';
import '../feature/obstacle_detection/services/tensorflow_service.dart';
import '../services/app_announcer.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/camera_feed_card.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';

class ObstaclesScreen extends StatefulWidget {
  const ObstaclesScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<ObstaclesScreen> createState() => _ObstaclesScreenState();
}

class _ObstaclesScreenState extends State<ObstaclesScreen> {
  final List<String> _detectedObjects = [];
  late final Future<CameraDescription?> _pipelineFuture;
  Timer? _holdStartTimer;
  Timer? _holdCountdownTimer;
  int _holdSecondsRemaining = 3;
  bool _isHoldingToStart = false;
  bool _isLaunchingDetector = false;

  @override
  void initState() {
    super.initState();
    _pipelineFuture = _initializePipeline();
  }

  @override
  void dispose() {
    _cancelHoldActivation();
    super.dispose();
  }

  Future<CameraDescription?> _initializePipeline() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      return null;
    }

    await TensorflowService.ssdMobileNet.initialize();

    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  // Opens the live obstacle detector screen with the given camera feed.
  Future<void> _openDetector(CameraDescription camera) async {
    if (_isLaunchingDetector) {
      return;
    }

    _cancelHoldActivation();
    if (mounted) {
      setState(() {
        _isLaunchingDetector = true;
      });
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrafficDetectorScreen(
            camera: camera,
            frameResultStream: (result) {
              if (!mounted) {
                return;
              }
              setState(() {
                _detectedObjects
                  ..clear()
                  ..addAll(result.objectLabels);
              });

              unawaited(
                AppAnnouncer.instance.announceDetectedObjects(
                  result.objectLabels,
                  proximityScore: result.proximityScore,
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingDetector = false;
        });
      }
    }
  }

  void _startHoldActivation(CameraDescription camera) {
    if (_isLaunchingDetector) {
      return;
    }

    _cancelHoldActivation();
    setState(() {
      _isHoldingToStart = true;
      _holdSecondsRemaining = 3;
    });

    _holdCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _holdSecondsRemaining = (_holdSecondsRemaining - 1).clamp(0, 3);
      });

      if (_holdSecondsRemaining == 0) {
        timer.cancel();
      }
    });

    _holdStartTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _openDetector(camera);
    });
  }

  void _cancelHoldActivation() {
    _holdStartTimer?.cancel();
    _holdCountdownTimer?.cancel();
    _holdStartTimer = null;
    _holdCountdownTimer = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _isHoldingToStart = false;
      _holdSecondsRemaining = 3;
    });
  }


  // Widget building 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const ModuleHeader(
                  title: 'Obstacles Detection',
                  accent: Color(0xFF2563EB),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FutureBuilder<CameraDescription?>(
                      future: _pipelineFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const CameraFeedCard(
                            label: 'Preparing obstacle pipeline...',
                            accent: Color(0xFF3B82F6),
                          );
                        }

                        if (snapshot.hasError) {
                          return CameraFeedCard(
                            label: 'Pipeline failed: ${snapshot.error}',
                            accent: const Color(0xFFEF4444),
                          );
                        }

                        final camera = snapshot.data;
                        if (camera == null) {
                          return const CameraFeedCard(
                            label: 'No camera available',
                            accent: Color(0xFFEF4444),
                          );
                        }

                        return GestureDetector(
                          onTapDown: (_) => _startHoldActivation(camera),
                          onTapCancel: _cancelHoldActivation,
                          onTapUp: (_) => _cancelHoldActivation(),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraFeedCard(
                                label: _isLaunchingDetector
                                    ? 'Opening live detection...'
                                    : _isHoldingToStart
                                        ? 'Keep holding...'
                                        : 'Press and hold for 3 seconds to start',
                                accent: const Color(0xFF3B82F6),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _isLaunchingDetector
                                          ? 'Opening...'
                                          : _isHoldingToStart
                                              ? 'Hold $_holdSecondsRemaining s'
                                              : 'Hold to Start',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: ModuleBottomSheet.collapsedHeight),
              ],
            ),
            ModuleBottomSheet(
              title: 'Detected Obstacles',
              accent: const Color(0xFF93C5FD),
              hasData: _detectedObjects.isNotEmpty,
              child: _detectedObjects.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      children: _detectedObjects
                          .map(
                            (object) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                object,
                                style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
      ),
    );
  }
}
