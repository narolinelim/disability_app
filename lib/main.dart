import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disability Assist App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Disability Assist App'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF6366F1),
                  Color(0xFF38BDF8),
                ],
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.visibility), text: 'Obstacle'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'Product'),
              Tab(icon: Icon(Icons.sign_language), text: 'Sign Language'),
              Tab(icon: Icon(Icons.volume_up), text: 'Noise'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
            ),
          ),
          child: const SafeArea(
            child: TabBarView(
              physics: BouncingScrollPhysics(),
              children: [
                _ObstacleDetectionView(),
                _ProductDetailView(),
                _SignLanguageView(),
                _NoiseDetectionView(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: (color ?? theme.colorScheme.primary).withAlpha(38),
                      child: Icon(icon, size: 30, color: color ?? theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withAlpha(191),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObstacleDetectionView extends StatefulWidget {
  // ignore: unused_element_parameter
  const _ObstacleDetectionView({super.key});

  @override
  State<_ObstacleDetectionView> createState() => _ObstacleDetectionViewState();
}

class _ObstacleDetectionViewState extends State<_ObstacleDetectionView> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _obstacleDetected = false;
  bool _isProcessing = false;
  String _confidenceValue = '0%';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _toggleDetection() async {
    if (_isDetecting) {
      // Stop detection
      await _cameraController?.stopImageStream();
      setState(() {
        _isDetecting = false;
        _obstacleDetected = false;
        _confidenceValue = '0%';
      });
    } else {
      // Start detection
      if (_cameraController != null && _isCameraInitialized) {
        try {
          await _cameraController!.startImageStream(_analyzeFrame);
          setState(() {
            _isDetecting = true;
          });
        } catch (e) {
          debugPrint('Error starting image stream: $e');
        }
      }
    }
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    if (_isProcessing) return;

    try {
      _isProcessing = true;

      // Convert YUV420 camera image to Image for processing
      final img.Image? imageData = _convertYUV420ToImage(image);

      if (imageData != null) {
        // Analyze center region for obstacles (simplified edge detection)
        final detected = _detectObstacles(imageData);

        if (mounted) {
          setState(() {
            _obstacleDetected = detected['detected'] as bool;
            _confidenceValue = '${detected['confidence'] as int}%';
          });

          if (detected['detected'] as bool) {
            final hasVibrator = await Vibration.hasVibrator();
            if (hasVibrator == true) {
              Vibration.vibrate(duration: 100);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Frame analysis error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  img.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      final Uint8List yPlane = image.planes[0].bytes;

      // Create grayscale image from Y plane (faster and simpler)
      final img.Image result = img.Image(width: width, height: height);

      for (int i = 0; i < width * height; i++) {
        final int grayValue = yPlane[i];
        result.setPixelRgba(i % width, i ~/ width, grayValue, grayValue, grayValue, 255);
      }

      return result;
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  Map<String, dynamic> _detectObstacles(img.Image image) {
    final int width = image.width;
    final int height = image.height;

    // Focus on center region (where obstacles would directly impact)
    final int centerX = width ~/ 2;
    final int centerY = height ~/ 2;
    final int regionSize = width ~/ 4;

    // Count high-contrast edges in center region
    int edgeCount = 0;
    int samplePoints = 0;

    for (int x = (centerX - regionSize).clamp(0, width - 1);
        x < (centerX + regionSize).clamp(0, width - 1);
        x += 2) {
      for (int y = (centerY - regionSize).clamp(0, height - 1);
          y < (centerY + regionSize).clamp(0, height - 1);
          y += 2) {
        final img.Pixel pixel = image.getPixelSafe(x, y);
        final img.Pixel nextXPixel = image.getPixelSafe(x + 1, y);
        final img.Pixel nextYPixel = image.getPixelSafe(x, y + 1);

        // Extract grayscale value (R channel works as brightness for grayscale)
        final int brightness = pixel.r.toInt();
        final int nextXBrightness = nextXPixel.r.toInt();
        final int nextYBrightness = nextYPixel.r.toInt();

        // Detect edges by comparing luminance differences
        if ((brightness - nextXBrightness).abs() > 30 ||
            (brightness - nextYBrightness).abs() > 30) {
          edgeCount++;
        }

        samplePoints++;
      }
    }

    // Calculate confidence (0-100)
    final int confidence = samplePoints > 0 ? ((edgeCount / samplePoints) * 100).toInt().clamp(0, 100) : 0;

    // Threshold: if high-contrast edges occupy > 15% of sampled center region
    final bool obstacleDetected = confidence > 15;

    return {
      'detected': obstacleDetected,
      'confidence': confidence,
    };
  }

  @override
  void dispose() {
    if (_isDetecting) {
      _cameraController?.stopImageStream();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Initializing camera...', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = !_isDetecting
        ? 'Tap the button to start detection'
        : (_obstacleDetected ? 'Obstacle detected ahead! Please be careful.' : 'Scanning for obstacles...');

    final statusColor = !_isDetecting
        ? Colors.black87
        : (_obstacleDetected ? Colors.redAccent : Colors.green.shade700);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obstacle Detection'),
        centerTitle: true,
        backgroundColor: Colors.red,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildCameraPreview(),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: statusColor),
                  textAlign: TextAlign.center,
                ),
                if (_isDetecting)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Detection Confidence: $_confidenceValue',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _toggleDetection,
                    icon: Icon(_isDetecting ? Icons.stop_circle : Icons.play_circle),
                    label: Text(_isDetecting ? 'Stop Detection' : 'Start Detection'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== AI Image Recognition Service =====
/// Service for recognizing images using AI APIs
class ImageRecognitionService {
  // Configuration for AI API
  // Replace these with your actual API keys
  static const String _googleVisionApiKey = 'YOUR_GOOGLE_CLOUD_VISION_API_KEY';
  static const String _openaiApiKey = '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';
  static const String _googleVisionEndpoint =
      'https://vision.googleapis.com/v1/images:annotate';
  static const String _openaiVisionEndpoint =
      'https://api.openai.com/v1/chat/completions';

  /// Recognize image content using Google Cloud Vision API
  static Future<String> recognizeImageWithGoogle(File imageFile) async {
    try {
      if (_googleVisionApiKey == 'YOUR_GOOGLE_CLOUD_VISION_API_KEY') {
        return 'Error: Google Cloud Vision API key not configured.\n\n'
            'To use Google Cloud Vision:\n'
            '1. Create a project on Google Cloud Console\n'
            '2. Enable Vision API\n'
            '3. Create a service account and API key\n'
            '4. Replace _googleVisionApiKey in the code';
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_googleVisionEndpoint?key=$_googleVisionApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 10},
                {'type': 'TEXT_DETECTION'},
                {'type': 'OBJECT_LOCALIZATION', 'maxResults': 10},
              ],
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return _parseGoogleVisionResponse(jsonResponse);
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Recognize image content using OpenAI Vision API
  static Future<String> recognizeImageWithOpenAI(File imageFile) async {
    try {
      if (_openaiApiKey == 'YOUR_OPENAI_API_KEY') {
        return 'Error: OpenAI API key not configured.\n\n'
            'To use OpenAI Vision:\n'
            '1. Create an account on OpenAI\n'
            '2. Get your API key from https://platform.openai.com/api-keys\n'
            '3. Replace _openaiApiKey in the code';
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_openaiVisionEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openaiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Please analyze this image and describe what you see. '
                      'Include details about objects, text, colors, and any important information. '
                      'Be concise but thorough.'
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  }
                }
              ]
            }
          ],
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return _parseOpenAIResponse(jsonResponse);
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  static String _parseGoogleVisionResponse(Map<String, dynamic> response) {
    try {
      final results = response['responses'][0];
      final buffer = StringBuffer();

      // Parse label detections
      if (results.containsKey('labelAnnotations')) {
        buffer.writeln('🏷️ Detected Objects:');
        for (var label in results['labelAnnotations']) {
          final description = label['description'];
          final confidence = ((label['score'] as num) * 100).toStringAsFixed(1);
          buffer.writeln('  • $description ($confidence% confidence)');
        }
        buffer.writeln();
      }

      // Parse text detection
      if (results.containsKey('textAnnotations') &&
          results['textAnnotations'].isNotEmpty) {
        buffer.writeln('📝 Detected Text:');
        buffer.writeln(results['textAnnotations'][0]['description']);
        buffer.writeln();
      }

      // Parse object localization
      if (results.containsKey('localizedObjectAnnotations')) {
        buffer.writeln('🎯 Objects in Image:');
        for (var obj in results['localizedObjectAnnotations']) {
          final name = obj['name'];
          final score = ((obj['score'] as num) * 100).toStringAsFixed(1);
          buffer.writeln('  • $name ($score% confidence)');
        }
      }

      return buffer.toString().isNotEmpty
          ? buffer.toString()
          : 'No objects detected in the image.';
    } catch (e) {
      return 'Error parsing response: $e';
    }
  }

  static String _parseOpenAIResponse(Map<String, dynamic> response) {
    try {
      if (response.containsKey('choices') && response['choices'].isNotEmpty) {
        final content = response['choices'][0]['message']['content'];
        return content ?? 'No description available';
      }
      return 'Error: Invalid response format';
    } catch (e) {
      return 'Error parsing response: $e';
    }
  }
}

// ===== Product Detail View =====
class _ProductDetailView extends StatefulWidget {
  // ignore: unused_element_parameter
  const _ProductDetailView({super.key});

  @override
  State<_ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<_ProductDetailView> {
  File? _selectedImage;
  String _recognitionResult = '📷 Take a photo or select an image to analyze';
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick image from device gallery
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _recognitionResult = 'Image selected. Choose an AI service to analyze...';
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  /// Take a photo using device camera
  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _recognitionResult = 'Photo captured. Choose an AI service to analyze...';
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  /// Recognize image with Google Cloud Vision
  Future<void> _recognizeWithGoogle() async {
    if (_selectedImage == null) {
      _showError('Please select or take an image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _recognitionResult = '🔄 Analyzing with Google Cloud Vision...';
    });

    try {
      final result =
          await ImageRecognitionService.recognizeImageWithGoogle(_selectedImage!);
      setState(() {
        _recognitionResult = result;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Recognition failed: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Recognize image with OpenAI Vision
  Future<void> _recognizeWithOpenAI() async {
    if (_selectedImage == null) {
      _showError('Please select or take an image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _recognitionResult = '🔄 Analyzing with OpenAI Vision...';
    });

    try {
      final result =
          await ImageRecognitionService.recognizeImageWithOpenAI(_selectedImage!);
      setState(() {
        _recognitionResult = result;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Recognition failed: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _PageCard(
        icon: Icons.shopping_cart,
        title: 'Product Details',
        subtitle: 'Take a photo to see what\'s in it',
        color: Colors.green,
        children: [
          // Image Preview
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Recognition Result
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              _recognitionResult,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 20),

          // Camera and Gallery Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _takePhoto,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take Photo'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Select Image'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Service Selection
          if (_selectedImage != null) ...[
            Text(
              'Choose AI Service:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _recognizeWithGoogle,
                    icon: const Icon(Icons.cloud),
                    label: const Text('Google Vision'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _recognizeWithOpenAI,
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('OpenAI Vision'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===== Sign Language View (existing code continues) =====
class _SignLanguageView extends StatefulWidget {
  // ignore: unused_element_parameter
  const _SignLanguageView({super.key});

  @override
  State<_SignLanguageView> createState() => _SignLanguageViewState();
}

class _SignLanguageViewState extends State<_SignLanguageView> {
  bool _isRecording = false;
final String _translation = 'Sign language translation will appear here';

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    // TODO: 集成相机/手势识别模型，输出翻译结果
  }

  @override
  Widget build(BuildContext context) {
    return _PageCard(
      icon: Icons.sign_language,
      title: 'Sign Language',
      subtitle: 'Use camera to recognize gestures and translate',
      color: Colors.orange,
      children: [
        Center(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _isRecording ? Icons.videocam : Icons.videocam_off,
                  key: ValueKey(_isRecording),
                  size: 96,
                  color: _isRecording ? Colors.orangeAccent : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _translation,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                  label: Text(_isRecording ? 'Stop Recognition' : 'Start Recognition'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoiseDetectionView extends StatefulWidget {
  // ignore: unused_element_parameter
  const _NoiseDetectionView({super.key});

  @override
  State<_NoiseDetectionView> createState() => _NoiseDetectionViewState();
}

class _NoiseDetectionViewState extends State<_NoiseDetectionView> {
  bool _isMonitoring = false;
  String _noiseLevel = 'Current noise: Normal';

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
      _noiseLevel = _isMonitoring ? 'Current noise: High (please watch your surroundings)' : 'Current noise: Normal';
    });
    // TODO: 使用麦克风测量环境声音分贝并实时反馈
  }

  @override
  Widget build(BuildContext context) {
    return _PageCard(
      icon: Icons.volume_up,
      title: 'Noise Detection',
      subtitle: 'Monitor ambient noise and provide alerts',
      color: Colors.purple,
      children: [
        Center(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _isMonitoring ? Icons.hearing : Icons.hearing_disabled,
                  key: ValueKey(_isMonitoring),
                  size: 96,
                  color: _isMonitoring ? Colors.purpleAccent : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _noiseLevel,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _toggleMonitoring,
                  icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                  label: Text(_isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
