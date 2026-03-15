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

  @override
  void initState() {
    super.initState();
    _pipelineFuture = _initializePipeline();
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

  Future<void> _openDetector(CameraDescription camera) async {
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
  }

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
                          onTap: () => _openDetector(camera),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const CameraFeedCard(
                                label: 'Tap to open live detection',
                                accent: Color(0xFF3B82F6),
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
                                    child: const Text(
                                      'Start Live Detection',
                                      style: TextStyle(
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
