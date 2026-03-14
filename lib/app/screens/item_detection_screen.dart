import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/app_announcer.dart';
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
  static const _screenIndex = 1;
  static const _initialCountdownSeconds = 3;
  static const _gravity = 9.81;
  static const _movementThreshold = 1.05;
  static const _jerkThreshold = 0.95;
  static const _steadyBeforeCountdown = Duration(milliseconds: 450);
  static const _screenAnnounceBuffer = Duration(milliseconds: 2400);
  static const _captureProcessingDelay = Duration(milliseconds: 1200);
  static const _steadyInstruction = 'Keep camera steady for 3 seconds.';
  static const _movingInstruction = 'Phone is moving. Hold camera steady.';
  static const _capturingInstruction = 'Capturing image now.';
  static const _captureDoneInstruction =
      'Capture complete. Waiting for analysis.';
  static const _waitingForAnalysisText =
      'Captured. Waiting for analysis result...';
  static const _noItemDetectedText = 'No item detected yet';

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _countdownTimer;
  Timer? _captureTimer;

  DateTime? _steadySince;
  double? _lastMagnitude;

  bool _isMoving = true;
  bool _isPreparingCountdown = false;
  bool _isCountingDown = false;
  bool _isCapturing = false;
  int _secondsRemaining = _initialCountdownSeconds;
  String _detectedItemText = _noItemDetectedText;
  DateTime _countdownAllowedAfter = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _accelerometerSubscription = accelerometerEventStream().listen(_onMotion);
    if (_isCurrentScreenActive) {
      _armCountdownAfterScreenAnnouncement();
    }
  }

  @override
  void didUpdateWidget(covariant ItemDetectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive =
        oldWidget.selectedIndex != _screenIndex && _isCurrentScreenActive;
    final becameInactive =
        oldWidget.selectedIndex == _screenIndex && !_isCurrentScreenActive;
    if (becameActive) {
      _armCountdownAfterScreenAnnouncement();
    }
    if (becameInactive) {
      _stopDetectionFlowOnExit();
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _countdownTimer?.cancel();
    _captureTimer?.cancel();
    super.dispose();
  }

  void _onMotion(AccelerometerEvent event) {
    if (!mounted || _isCapturing || !_isCurrentScreenActive) {
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
      if (!_isMoving || _isCountingDown || _isPreparingCountdown) {
        _resetCountdown();
        setState(() {
          _isMoving = true;
        });
        AppAnnouncer.instance.speak(_movingInstruction, interrupt: false);
      }
      return;
    }

    _steadySince ??= DateTime.now();

    if (_isMoving && !_isCountingDown) {
      setState(() {
        _isMoving = false;
      });
    }

    if (_isCountdownBlockedByAnnouncement) {
      return;
    }

    final steadyDuration = DateTime.now().difference(_steadySince!);
    if (!_isCountingDown &&
        !_isPreparingCountdown &&
        steadyDuration >= _steadyBeforeCountdown) {
      _startAutoCaptureCountdown();
    }
  }

  bool get _isCurrentScreenActive => widget.selectedIndex == _screenIndex;

  bool get _isCountdownBlockedByAnnouncement =>
      DateTime.now().isBefore(_countdownAllowedAfter);

  void _armCountdownAfterScreenAnnouncement() {
    _countdownAllowedAfter = DateTime.now().add(_screenAnnounceBuffer);
    _steadySince = null;
    _countdownTimer?.cancel();
    setState(() {
      _isMoving = true;
      _isCountingDown = false;
      _secondsRemaining = _initialCountdownSeconds;
    });
  }

  void _stopDetectionFlowOnExit() {
    _countdownTimer?.cancel();
    _captureTimer?.cancel();
    _steadySince = null;
    setState(() {
      _isMoving = true;
      _isPreparingCountdown = false;
      _isCountingDown = false;
      _isCapturing = false;
      _secondsRemaining = _initialCountdownSeconds;
    });
  }

  Future<void> _startAutoCaptureCountdown() async {
    if (_isCountingDown || _isPreparingCountdown || _isCapturing) {
      return;
    }

    _countdownTimer?.cancel();

    setState(() {
      _isPreparingCountdown = true;
      _isCountingDown = false;
      _secondsRemaining = _initialCountdownSeconds;
    });
    await AppAnnouncer.instance.speak(_steadyInstruction);

    if (!mounted || _isMoving || _isCapturing) {
      setState(() {
        _isPreparingCountdown = false;
        _isCountingDown = false;
        _secondsRemaining = _initialCountdownSeconds;
      });
      return;
    }

    setState(() {
      _isPreparingCountdown = false;
      _isCountingDown = true;
      _secondsRemaining = _initialCountdownSeconds;
    });
    await AppAnnouncer.instance.announceCountdownNumber(_secondsRemaining);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining -= 1;
        });
        AppAnnouncer.instance.announceCountdownNumber(_secondsRemaining);
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
      _detectedItemText = _waitingForAnalysisText;
    });
    AppAnnouncer.instance.speak(_capturingInstruction);

    _captureTimer?.cancel();
    _captureTimer = Timer(_captureProcessingDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCapturing = false;
        _isMoving = true;
        _steadySince = null;
      });
      AppAnnouncer.instance.speak(_captureDoneInstruction);
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isPreparingCountdown = false;
      _isCountingDown = false;
      _secondsRemaining = _initialCountdownSeconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showCountdown = _isCountingDown && !_isCapturing;
    final statusText = _isCountdownBlockedByAnnouncement
        ? 'Item detection ready. Listen for instructions.'
        : _isPreparingCountdown
        ? 'Keep phone steady. Countdown starts soon.'
        : showCountdown
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
              hasData: _detectedItemText != _noItemDetectedText,
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
