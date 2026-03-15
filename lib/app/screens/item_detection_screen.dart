import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_announcer.dart';
import '../services/audio_recorder_service.dart';
import '../services/cloud_image_describer.dart';
import '../services/openai_conversation_service.dart';
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

class _ItemDetectionScreenState extends State<ItemDetectionScreen>
    with WidgetsBindingObserver {
  static const _screenIndex = 1;
  static const _initialCountdownSeconds = 3;
  static const _capturingInstruction = 'Capturing image now.';
  static const _waitingForAnalysisText = 'Captured. Analyzing image...';
  static const _noItemDetectedText = 'No item detected yet';
  static const _keyMissingText =
      'OpenAI key is missing. Set OPENAI_API_KEY and rebuild.';
  static const _cameraNotReadyText = 'Camera is not ready yet.';

  final CloudImageDescriber _cloudImageDescriber = CloudImageDescriber();
  final AudioRecorderService _audioRecorder = AudioRecorderService.instance;
  final OpenAIConversationService _conversationService =
      OpenAIConversationService();


  Timer? _countdownTimer;
  Timer? _recordingTimer;

  CameraController? _cameraController;
  bool _isInitializingCamera = false;
  bool _isCameraReady = false;


  bool _isCountingDown = false;
  bool _isCapturing = false;
  bool _isAnnouncingResult = false;
  bool _isRecording = false;
  bool _isProcessingAudio = false;
  bool _hasAutoCaptured = false;
  int _secondsRemaining = _initialCountdownSeconds;
  int _recordingSeconds = 0;
  String _detectedItemText = _noItemDetectedText;
  String _conversationText = '';
  List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _audioRecorder.initialize();
  }

  @override
  void didUpdateWidget(covariant ItemDetectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive =
        oldWidget.selectedIndex != _screenIndex && _isCurrentScreenActive;
    final becameInactive =
        oldWidget.selectedIndex == _screenIndex && !_isCurrentScreenActive;
    if (becameActive) {
      _initializeCamera();
    }
    if (becameInactive) {
      _stopDetectionFlowOnExit();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _disposeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _disposeCamera();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) {
      return;
    }
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (!_isCameraReady && mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
      return;
    }

    _isInitializingCamera = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraReady = false;
            _detectedItemText = 'No camera available on this device.';
          });
        }
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Flash control is not available on some devices.
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {
        _isCameraReady = true;
      });
      // Start 3-second countdown immediately after camera is ready
      if (!_hasAutoCaptured && _isCurrentScreenActive) {
        _startDirectCountdown();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _detectedItemText = 'Camera unavailable: $error';
        });
      }
    } finally {
      _isInitializingCamera = false;
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _isCameraReady = false;
    if (controller != null) {
      await controller.dispose();
    }
  }

  bool get _isCurrentScreenActive => widget.selectedIndex == _screenIndex;

  void _startDirectCountdown() {
    if (_isCountingDown || _isCapturing || _isAnnouncingResult || _hasAutoCaptured) {
      return;
    }
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = true;
      _secondsRemaining = _initialCountdownSeconds;
    });
    AppAnnouncer.instance.announceCountdownNumber(_secondsRemaining);
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
      _captureAndDescribeImage();
    });
  }

  void _stopDetectionFlowOnExit() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _isCapturing = false;
      _isAnnouncingResult = false;
      _hasAutoCaptured = false;
      _secondsRemaining = _initialCountdownSeconds;
    });
  }


  Future<void> _captureAndDescribeImage() async {
    if (_isCapturing || !_isCurrentScreenActive) {
      return;
    }

    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _isCapturing = true;
      _hasAutoCaptured = true;
      _detectedItemText = _waitingForAnalysisText;
    });

    if (!_cloudImageDescriber.isConfigured) {
      await _finishCaptureWithText(_keyMissingText);
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _finishCaptureWithText(_cameraNotReadyText);
      return;
    }

    try {
      debugPrint('[SB_GENAI] capture flow started');
      await AppAnnouncer.instance.speak(_capturingInstruction);
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      final description = await _cloudImageDescriber.describe(bytes);
      final normalized = description.trim().isEmpty
          ? 'No clear item detected.'
          : description.trim();
      await _finishCaptureWithText(normalized);
    } catch (error) {
      await _finishCaptureWithText('Image analysis failed. $error');
    }
  }

  Future<void> _finishCaptureWithText(String text) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _detectedItemText = text;
      _isCapturing = false;
      _isAnnouncingResult = true;
    });
    await AppAnnouncer.instance.speak(text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isAnnouncingResult = false;
    });
  }

  void _onScreenTap() {
    debugPrint('[SB_GENAI] Screen tapped - stopping TTS');
    AppAnnouncer.instance.stop();
  }

  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    if (_detectedItemText == _noItemDetectedText) {
      AppAnnouncer.instance.speak('No item detected yet. Detect an item first.');
      return;
    }

    debugPrint('[SB_GENAI] Long press start detected - stopping TTS and starting recording');
    // Immediately stop any TTS
    await AppAnnouncer.instance.stop();

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _conversationText = 'Recording...';
    });
    
    // Play a low-latency click to indicate recording started
    await SystemSound.play(SystemSoundType.click);

    final recordingPath = await _audioRecorder.startRecording();
    if (recordingPath == null) {
      setState(() {
        _isRecording = false;
        _conversationText = 'Failed to start recording. Check permissions.';
      });
      AppAnnouncer.instance.speak(_conversationText);
      return;
    }

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds += 1;
        });
      }
    });
  }

  Future<void> _onLongPressEnd(LongPressEndDetails details) async {
    if (!_isRecording) return;
    await _stopRecording();
  }

  Future<void> _stopRecording() async {
    debugPrint('[SB_GENAI] Stopping recording');
    _recordingTimer?.cancel();
    
    setState(() {
      _isRecording = false;
      _isProcessingAudio = true;
      _conversationText = 'Processing your question...';
    });

    AppAnnouncer.instance.speak('Processing your question.');

    try {
      // Get the path to the recorded audio file
      final audioPath = await _audioRecorder.stopRecording();
      if (audioPath == null || audioPath.isEmpty) {
        setState(() {
          _isProcessingAudio = false;
          _conversationText = 'No audio detected. Try again.';
        });
        AppAnnouncer.instance.speak(_conversationText);
        return;
      }

      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
         setState(() {
          _isProcessingAudio = false;
          _conversationText = 'Failed to read audio file.';
        });
        AppAnnouncer.instance.speak(_conversationText);
        return;
      }

      final audioBytes = await audioFile.readAsBytes();

      // Transcribe the audio using OpenAI Whisper
      final userMessage = await _conversationService.transcribeAudio(audioBytes);
      
      // Clean up the temporary file
      try {
        await audioFile.delete();
      } catch (_) {}

      if (userMessage == null || userMessage.trim().isEmpty) {
        setState(() {
          _isProcessingAudio = false;
          _conversationText = 'Could not understand what you said. Please try again.';
        });
        AppAnnouncer.instance.speak(_conversationText);
        return;
      }

      debugPrint('[SB_GENAI] User said: $userMessage');

      // Send conversation to OpenAI
      final response = await _conversationService.chat(
        userMessage: userMessage,
        detectedItem: _detectedItemText,
        conversationHistory: _conversationHistory,
      );

      if (response == null || response.isEmpty) {
        setState(() {
          _isProcessingAudio = false;
          _conversationText = 'No response from AI. Try again.';
        });
        AppAnnouncer.instance.speak(_conversationText);
        return;
      }

      // Update conversation and read response
      _conversationHistory.add({'role': 'user', 'content': userMessage});
      _conversationHistory.add({'role': 'assistant', 'content': response});

      setState(() {
        _isProcessingAudio = false;
        _conversationText = 'Q: $userMessage\nA: $response';
      });

      AppAnnouncer.instance.speak(response);
    } catch (error) {
      debugPrint('[SB_GENAI] Error: $error');
      setState(() {
        _isProcessingAudio = false;
        _conversationText = 'Error: ${error.toString()}';
      });
      AppAnnouncer.instance.speak('An error occurred. ${error.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCountdown = _isCountingDown && !_isCapturing;
    final statusText = !_isCameraReady
        ? 'Starting camera...'
        : _isAnnouncingResult
        ? 'Reading result...'
        : _hasAutoCaptured
        ? 'Scan complete.'
        : showCountdown
        ? 'Capturing in $_secondsRemaining s...\''
        : 'Initializing...';

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
                child: GestureDetector(
                  onTap: _onScreenTap,
                  onLongPressStart: _onLongPressStart,
                  onLongPressEnd: _onLongPressEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraFeedCard(
                        label: 'Point camera at item',
                        accent: const Color(0xFF3B82F6),
                        showPlaceholder: !_isCameraReady,
                        liveFeed: _isCameraReady && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : null,
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
                                      'Analyzing...',
                                      style: TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_isRecording)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Recording ${_recordingSeconds}s',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_isProcessingAudio)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
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
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        color: Colors.white,
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
                            if (_detectedItemText != _noItemDetectedText)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A)
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Long press to ask about this item',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
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
            ),
            if (_conversationText.isNotEmpty)
              Container(
                height: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _conversationText,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 13,
                    ),
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
