import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../auslan_scripts/auslan_predict.dart';

class _ServerPrediction {
  const _ServerPrediction({
    required this.label,
    required this.confidence,
    this.hasHand = true,
  });

  final String label;
  final double confidence;
  final bool hasHand;
}

class SignLanguageCameraCard extends StatefulWidget {
  const SignLanguageCameraCard({
    super.key,
    required this.label,
    required this.accent,
    this.onPrediction,
    this.onFinalized,
  });

  final String label;
  final Color accent;
  final Function(String rawLabel, double confidence, String allLetters)?
  onPrediction;
  final Function(String capturedLetters, String? guessedText, String trigger)?
  onFinalized;

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
  bool _hasLoggedServerConfigWarning = false;
  bool _hasLoggedConnectionWarning = false;
  bool _hasLoggedFrameFormatWarning = false;
  DateTime? _lastHandDetectedAt;
  bool _isFinalizing = false;

  AuslanPredictor? _predictor;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initPredictor();
  }

  void _initPredictor() {
    _predictor = AuslanPredictor();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
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
        const Duration(milliseconds: 350),
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
      final serverUrl = dotenv.env['AUSLAN_SERVER_URL']?.trim() ?? '';
      if (serverUrl.isEmpty) {
        if (!_hasLoggedServerConfigWarning) {
          debugPrint(
            'Set AUSLAN_SERVER_URL in .env (example: http://127.0.0.1:8000/predict_auslan)',
          );
          _hasLoggedServerConfigWarning = true;
        }
        return;
      }
      final candidateUris = _buildCandidateUris(serverUrl);
      if (candidateUris.isEmpty) {
        debugPrint('Invalid AUSLAN_SERVER_URL: $serverUrl');
        return;
      }

      final frameBytes = await _encodeFrameToPng(_latestFrame!);
      if (frameBytes == null) {
        if (!_hasLoggedFrameFormatWarning) {
          debugPrint('Unsupported frame format for silent capture.');
          _hasLoggedFrameFormatWarning = true;
        }
        return;
      }
      final serverPrediction = await _predictFromServer(
        candidateUris: candidateUris,
        imageBytes: frameBytes,
      );
      if (serverPrediction == null) return;

      final now = DateTime.now();
      if (!serverPrediction.hasHand) {
        if (_lastHandDetectedAt != null &&
            now.difference(_lastHandDetectedAt!) >=
                const Duration(seconds: 5)) {
          await _finalizeCapture(trigger: 'no-hand-5s');
          _lastHandDetectedAt = null;
        }
        return;
      }

      _lastHandDetectedAt = now;

      final predictor = _predictor!;
      final prediction = predictor.processRawPrediction(
        rawLabel: serverPrediction.label,
        confidencePercent: serverPrediction.confidence,
      );

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

  Future<void> _finalizeCapture({required String trigger}) async {
    if (_isFinalizing || _predictor == null) {
      return;
    }

    final predictor = _predictor!;
    if (!predictor.hasCapturedLetters) {
      return;
    }

    _isFinalizing = true;
    final capturedLetters = predictor.allLetters;
    String? guessedText;
    try {
      guessedText = await predictor.guessWordPhrase();
      widget.onFinalized?.call(capturedLetters, guessedText, trigger);
    } catch (e) {
      debugPrint('Finalize Error: $e');
      widget.onFinalized?.call(capturedLetters, null, trigger);
    } finally {
      predictor.resetCaptureState();
      if (mounted) {
        setState(() {
          _allLetters = '';
        });
      }
      _isFinalizing = false;
    }
  }

  Future<_ServerPrediction?> _predictFromServer({
    required List<Uri> candidateUris,
    required Uint8List imageBytes,
  }) async {
    for (final uri in candidateUris) {
      try {
        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'frame.png',
          ),
        );

        final response = await request.send().timeout(
          const Duration(seconds: 20),
        );
        final body = await response.stream.bytesToString();
        if (response.statusCode != 200) {
          debugPrint(
            'Auslan server failed: status=${response.statusCode}, url=$uri, body=$body',
          );
          continue;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final label = (decoded['label'] ?? '').toString().trim();
        final confidenceRaw = decoded['confidence'];
        final confidence = switch (confidenceRaw) {
          num() => confidenceRaw.toDouble(),
          String() => double.tryParse(confidenceRaw) ?? 0.0,
          _ => 0.0,
        };

        if (label.isEmpty || label == 'null') {
          return const _ServerPrediction(
            label: '',
            confidence: 0,
            hasHand: false,
          );
        }

        return _ServerPrediction(label: label, confidence: confidence);
      } on TimeoutException catch (e) {
        if (!_hasLoggedConnectionWarning) {
          debugPrint('Auslan server timeout: $e');
          debugPrint('Tried: ${candidateUris.join(', ')}');
          _hasLoggedConnectionWarning = true;
        }
        continue;
      } catch (e) {
        if (!_hasLoggedConnectionWarning) {
          debugPrint('Auslan server request error: $e');
          debugPrint('Tried: ${candidateUris.join(', ')}');
          _hasLoggedConnectionWarning = true;
        }
        continue;
      }
    }

    return null;
  }

  Future<Uint8List?> _encodeFrameToPng(CameraImage frame) async {
    if (frame.format.group != ImageFormatGroup.bgra8888 ||
        frame.planes.isEmpty) {
      return null;
    }

    final bytes = frame.planes.first.bytes;
    final rowBytes = frame.planes.first.bytesPerRow;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      frame.width,
      frame.height,
      ui.PixelFormat.bgra8888,
      completer.complete,
      rowBytes: rowBytes,
    );
    final image = await completer.future;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  List<Uri> _buildCandidateUris(String rawServerUrl) {
    final normalized =
        rawServerUrl.startsWith('http://') ||
            rawServerUrl.startsWith('https://')
        ? rawServerUrl
        : 'http://$rawServerUrl';

    Uri? primary;
    try {
      primary = Uri.parse(normalized);
    } catch (_) {
      return const [];
    }

    final uris = <Uri>[primary];
    final host = primary.host;
    final isLoopback = host == '127.0.0.1' || host == 'localhost';

    // Android emulator cannot reach host machine via 127.0.0.1.
    if (isLoopback && defaultTargetPlatform == TargetPlatform.android) {
      uris.add(primary.replace(host: '10.0.2.2'));
    }

    final unique = <String>{};
    final deduped = <Uri>[];
    for (final uri in uris) {
      final key = uri.toString();
      if (unique.add(key)) {
        deduped.add(uri);
      }
    }
    return deduped;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => _finalizeCapture(trigger: 'double-tap'),
      child: Container(
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
      ),
    );
  }
}
