import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_stream_service.dart';
import '../services/yamnet_service.dart';
import '../services/label_loader.dart';
import '../utils/audio_buffer.dart';

import '../widgets/app_navigation_bar.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';

class NoiseDetectionScreen extends StatefulWidget {
  const NoiseDetectionScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<NoiseDetectionScreen> createState() =>
      _NoiseDetectionScreenState();
}

class _NoiseDetectionScreenState
    extends State<NoiseDetectionScreen> {

  bool _isListening = false;

  final AudioStreamService _audioService =
  AudioStreamService();

  final YamnetService _yamnet = YamnetService();

  final AudioBuffer _buffer = AudioBuffer();

  Map<int, String> _labels = {};

  bool _modelReady = false;

  List<String> recentResults = [];
  String detectedText = "No alarm detected";
  DateTime? _lastVibrationTime;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {

      print("Loading model...");

      await _yamnet.loadModel();

      print("Model loaded");

      _labels = await LabelLoader.loadLabels();

      print("CSV loaded");

      setState(() {
        _modelReady = true;
      });

      print("YAMNet ready");

    } catch (e) {

      print("Model loading failed: $e");

    }

  }

  void _startListening() {

    if (!_modelReady) {
      print("Model not ready");
      return;
    }

    print("Start listening");

    _audioService.start((samples) {
      // print(samples.take(10));


      _buffer.addSamples(samples);

      if (_buffer.isReady) {

        final window = _buffer.popWindow();

        final scores =
        _yamnet.runInference(window);

        final index = _yamnet.argmax(scores);

        final label =
            _labels[index] ?? "Unknown";

        final score = scores[index];

        if (score > 0.3) {

          print(
            "Detected: $label  (${score.toStringAsFixed(2)})",
          );

          final lowerLabel = label.toLowerCase();

          recentResults.add(lowerLabel);

          if (recentResults.length > 5) {
            recentResults.removeAt(0);
          }

          int alarmCount = recentResults.where((e) =>
          e.contains("alarm") || e.contains("static")).length;

          if (alarmCount >= 3) {

            setState(() {
              detectedText = "🚨 Fire Alarm Detected!";
            });

            final now = DateTime.now();

            if (_lastVibrationTime == null ||
                now.difference(_lastVibrationTime!).inSeconds > 5) {

              Vibration.vibrate(
                pattern: [0, 500, 300, 500],
              );

              _lastVibrationTime = now;
            }

          }


        }


      }

    });

  }

  void _stopListening() {

    print("Stop listening");

    _audioService.stop();

  }

  void _toggleListening() {

    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  @override
  void dispose() {

    _audioService.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [

            ModuleHeader(
              title: 'Noise Detection',
              accent: const Color(0xFFEA580C),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF7ED),
                      Colors.white
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [

                    GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedContainer(
                        duration:
                        const Duration(
                            milliseconds: 350),
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? const Color(
                              0xFFDCFCE7)
                              : const Color(
                              0xFFE5E7EB),
                        ),
                        child: Icon(
                          Icons.volume_up_outlined,
                          size: 48,
                          color: _isListening
                              ? const Color(
                              0xFF16A34A)
                              : const Color(
                              0xFF9CA3AF),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      _isListening
                          ? 'Listening for Sounds'
                          : 'Monitoring Paused',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _isListening
                          ? 'Actively monitoring environmental sounds'
                          : 'Tap center icon to resume monitoring',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                      ),
                    ),

                  ],
                ),
              ),
            ),

            ModuleBottomSheet(
              title: 'Recent Noise Alerts',
              accent: const Color(0xFFFED7AA),
              hasData: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  detectedText,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
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
        onDestinationSelected:
        widget.onDestinationSelected,
      ),
    );
  }
}