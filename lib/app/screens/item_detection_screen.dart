import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../widgets/app_navigation_bar.dart';
import '../widgets/camera_feed_card.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';

class ItemDetectionScreen extends StatefulWidget {
  const ItemDetectionScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<ItemDetectionScreen> createState() => _ItemDetectionScreenState();
}

class _ItemDetectionScreenState extends State<ItemDetectionScreen> {
  static const _gravity = 9.81;
  static const _movementThreshold = 1.05;
  static const _jerkThreshold = 0.95;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _countdownTimer;
  Timer? _captureTimer;

  DateTime? _steadySince;
  double? _lastMagnitude;

  bool _isMoving = true;
  bool _isCountingDown = false;
  bool _isCapturing = false;
  int _secondsRemaining = 3;
  String _detectedItemText = 'No item detected yet';

  @override
  void initState() {
    super.initState();
    _accelerometerSubscription = accelerometerEventStream().listen(_onMotion);
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _countdownTimer?.cancel();
    _captureTimer?.cancel();
    super.dispose();
  }

  void _onMotion(AccelerometerEvent event) {
    if (!mounted || _isCapturing) {
      return;
    }

    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final gravityDelta = (magnitude - _gravity).abs();
    final jerk = _lastMagnitude == null
        ? 0.0
        : (magnitude - _lastMagnitude!).abs();
    _lastMagnitude = magnitude;

    final moving = gravityDelta > _movementThreshold || jerk > _jerkThreshold;

    if (moving) {
      _steadySince = null;
      if (!_isMoving || _isCountingDown) {
        _resetCountdown();
        setState(() {
          _isMoving = true;
        });
      }
      return;
    }

    _steadySince ??= DateTime.now();

    if (_isMoving && !_isCountingDown) {
      setState(() {
        _isMoving = false;
      });
    }

    final steadyDuration = DateTime.now().difference(_steadySince!);
    if (!_isCountingDown &&
        steadyDuration >= const Duration(milliseconds: 450)) {
      _startAutoCaptureCountdown();
    }
  }

  void _startAutoCaptureCountdown() {
    _countdownTimer?.cancel();

    setState(() {
      _isCountingDown = true;
      _secondsRemaining = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining -= 1;
        });
        return;
      }

      timer.cancel();
      _captureImage();
    });
  }

  void _captureImage() {
    _countdownTimer?.cancel();

    setState(() {
      _isCountingDown = false;
      _isCapturing = true;
      _detectedItemText = 'Captured. Waiting for analysis result...';
    });

    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCapturing = false;
        _isMoving = true;
        _steadySince = null;
      });
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _secondsRemaining = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showCountdown = _isCountingDown && !_isCapturing;
    final statusText = showCountdown
        ? 'Keep phone steady for $_secondsRemaining s'
        : (_isMoving
              ? 'Hold phone steady to start auto capture'
              : 'Keep phone steady for 3 s');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const ModuleHeader(
              title: 'Item Detection',
              accent: Color(0xFF16A34A),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraFeedCard(
                      label: 'Point camera at item',
                      accent: Color(0xFF3B82F6),
                      showPlaceholder: !_isCountingDown,
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showCountdown)
                            Container(
                              width: 92,
                              height: 92,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 12,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$_secondsRemaining',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (_isCapturing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Capturing...',
                                    style: TextStyle(
                                      color: Color(0xFF1F2937),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ModuleBottomSheet(
              title: 'Detected Item',
              accent: const Color(0xFFBBF7D0),
              hasData: _detectedItemText != 'No item detected yet',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  _detectedItemText,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                  ),
                ),
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
