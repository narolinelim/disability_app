import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
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
  final Function(String label, double confidence)? onPrediction;

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

  late AuslanPredictor _predictor;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initPredictor();
  }

  Future<void> _initPredictor() async {
    _predictor = AuslanPredictor();
    await _predictor.loadModel();
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
        imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();

    if (mounted) {
      setState(() => _isInitialized = true);
      _timer = Timer.periodic(
          const Duration(milliseconds: 300),
              (_) => _sendFrame(),
      );
    }
  }

  Future<void> _sendFrame() async {
    if (_isPredicting || _controller == null || !_controller!.value.isInitialized) return;
    _isPredicting = true;

    try {
      List<double> coords = await extractCoordinatesFromFrame();
      String predictedLetter = _predictor.predictAuslan(coords);

      setState(() {
        _prediction = predictedLetter;
        _confidence = 100.0;
      });

      widget.onPrediction?.call(_prediction, _confidence);

    } catch (e) {
      debugPrint('Prediction Error: $e');
    }

    _isPredicting = false;
  }

  Future<List<double>> extractCoordinatesFromFrame() async {
    return List.filled(126, 0.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
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
              top: 0, left: 0, right: 0,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_prediction $_confidence%',
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
        ],
      ),
    );
  }
}