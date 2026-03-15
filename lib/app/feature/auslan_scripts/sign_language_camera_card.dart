import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import '../auslan_scripts/auslan_predict.dart';

class SignLanguageCameraCard extends StatefulWidget {
  const SignLanguageCameraCard({
    super.key,
    required this.label,
    required this.accent,
    this.onPrediction,
  });

  final String label;
  final Color accent;
  final Function(String rawLabel, double confidence, String allLetters)?
  onPrediction;

  @override
  State<SignLanguageCameraCard> createState() => _SignLanguageCameraCardState();
}

class _SignLanguageCameraCardState extends State<SignLanguageCameraCard> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isPredicting = false;
  String _prediction = '';
  double _confidence = 0;
  Timer? _timer;
  CameraImage? _latestFrame;
  String _allLetters = '';

  AuslanPredictor? _predictor;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initPredictor();
  }

  Future<void> _initPredictor() async {
    try {
      final predictor = AuslanPredictor();
      await predictor.loadModel();
      _predictor = predictor;
    } catch (e) {
      debugPrint('Predictor Init Error: $e');
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    await _controller!.startImageStream((frame) {
      _latestFrame = frame;
    });

    if (mounted) {
      setState(() => _isInitialized = true);
      _timer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => _sendFrame(),
      );
    }
  }

  Future<void> _sendFrame() async {
    if (_isPredicting ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _predictor == null ||
        _latestFrame == null) {
      return;
    }
    _isPredicting = true;

    try {
      final predictor = _predictor!;
      final frame = _latestFrame!;
      final modelInput = extractModelInputFromFrame(
        frame,
        predictor.inputLength,
      );
      final prediction = predictor.predictAuslan(modelInput);

      if (!mounted) return;
      setState(() {
        _prediction = prediction.rawLabel;
        _confidence = prediction.confidence;
        _allLetters = prediction.allLetters;
      });

      if (prediction.acceptedLetter.isNotEmpty) {
        widget.onPrediction?.call(
          prediction.rawLabel,
          prediction.confidence,
          prediction.allLetters,
        );
      }
    } catch (e) {
      debugPrint('Prediction Error: $e');
    } finally {
      _isPredicting = false;
    }
  }

  List<double> extractModelInputFromFrame(CameraImage frame, int inputLength) {
    if (inputLength <= 0 || frame.planes.isEmpty) {
      return const [];
    }

    final bytes = frame.planes.first.bytes;
    if (bytes.isEmpty) {
      return List<double>.filled(inputLength, 0.0);
    }

    final pixelStride = frame.format.group == ImageFormatGroup.bgra8888 ? 4 : 1;
    final sourceLength = bytes.length ~/ pixelStride;
    if (sourceLength <= 0) {
      return List<double>.filled(inputLength, 0.0);
    }

    final step = sourceLength / inputLength;
    final values = List<double>.filled(inputLength, 0.0);
    for (var i = 0; i < inputLength; i++) {
      final sourceIndex = (i * step).floor().clamp(0, sourceLength - 1);
      final byteIndex = sourceIndex * pixelStride;
      values[i] = bytes[byteIndex] / 255.0;
    }
    return values;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_controller?.value.isStreamingImages ?? false) {
      unawaited(_controller!.stopImageStream());
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      child: Stack(
        children: [
          if (_isInitialized && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1F2937).withValues(alpha: 0.8),
                      const Color(0xFF111827).withValues(alpha: 0.8),
                      const Color(0xFF000000).withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 2, color: widget.accent),
          ),

          if (!_isInitialized)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    size: 68,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (_prediction.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_prediction ${_confidence.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _confidence >= 80
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          if (_allLetters.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _allLetters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
