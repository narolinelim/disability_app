import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

// Main screen that opens camera, runs ONNX detection, and shows results.
class TrafficDetectorScreen extends StatefulWidget {
	final CameraDescription camera;

	const TrafficDetectorScreen({
		super.key,
		required this.camera,
	});

	@override
	State<TrafficDetectorScreen> createState() => _TrafficDetectorScreenState();
}

class _TrafficDetectorScreenState extends State<TrafficDetectorScreen> {
	// Camera + ONNX runtime objects.
	CameraController? _controller;
	OrtSession? _session;
	OrtSessionOptions? _sessionOptions;
	OrtRunOptions? _runOptions;

	// Basic app state flags.
	bool _isModelLoaded = false;
	bool _isBusy = false;
	bool _isDisposed = false;

	// Data shown on screen.
	List<Detection> _detections = [];
	double _proximityScore = 0;
	bool _alertActive = false;

	DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
	int _incomingFrameCount = 0;

	// Tuning knobs:
	// - inputSize: model input resolution (speed vs detail)
	// - confidenceThreshold/iouThreshold: detection strictness
	// - processEveryNFrames: frame skipping ratio
	// - uiUpdateIntervalMs: UI repaint rate cap (ms)
	// - maxCandidatesBeforeNms: pre-NMS cap for postprocess speed
	static const int inputSize = 320;
	static const double confidenceThreshold = 0.35;
	static const double iouThreshold = 0.45;
	static const int processEveryNFrames = 2;
	static const int uiUpdateIntervalMs = 67;
	static const int maxCandidatesBeforeNms = 120;

	static const Map<int, String> classNames = {
		0: 'person',
		1: 'bicycle',
		2: 'car',
		3: 'motorcycle',
		5: 'bus',
		7: 'truck',
	};

	@override
	void initState() {
		super.initState();
		// Start setup in the background after widget is created.
		unawaited(_initialize());
	}

	// App startup flow: camera first, model second, then begin streaming frames.
	Future<void> _initialize() async {
		await _initializeCamera();
		await _loadModel();
		_startImageStream();
	}

	// Configure camera stream settings.
	Future<void> _initializeCamera() async {
		// Low camera preset for lower bandwidth and faster preprocessing.
		_controller = CameraController(
			widget.camera,
			ResolutionPreset.low,
			enableAudio: false,
			imageFormatGroup: ImageFormatGroup.yuv420,
		);

		try {
			await _controller!.initialize();
			if (!mounted || _isDisposed) {
				return;
			}
			setState(() {});
		} catch (e) {
			debugPrint('Error initializing camera: $e');
		}
	}

	Future<void> _loadModel() async {
		try {
			// Read ONNX model from Flutter assets.
			OrtEnv.instance.init();
			final modelBytes = await rootBundle.load('assets/models/yolov8n.onnx');

			// Build runtime session options.
			_sessionOptions = OrtSessionOptions();
			_sessionOptions!.setIntraOpNumThreads(2);
			_sessionOptions!.setInterOpNumThreads(1);
			_sessionOptions!.setSessionGraphOptimizationLevel(
				GraphOptimizationLevel.ortEnableAll,
			);
			try {
				// Try XNNPACK first; fallback to default CPU provider on failure.
				_sessionOptions!.appendXnnpackProvider();
			} catch (_) {
				// Fallback to CPU provider when XNNPACK is unavailable.
			}

			_session = OrtSession.fromBuffer(
				modelBytes.buffer.asUint8List(),
				_sessionOptions!,
			);
			_runOptions = OrtRunOptions();

			if (!mounted || _isDisposed) {
				return;
			}
			setState(() {
				_isModelLoaded = true;
			});
		} catch (e) {
			debugPrint('Error loading model: $e');
			if (!mounted || _isDisposed) {
				return;
			}
			setState(() {
				_isModelLoaded = false;
			});
		}
	}

	void _startImageStream() {
		if (_controller == null || !_controller!.value.isInitialized) {
			return;
		}

		// Every incoming camera frame comes through this callback.
		_controller!.startImageStream((CameraImage image) {
			_incomingFrameCount += 1;
			// Frame skipping: process every Nth frame to reduce compute load.
			if (_incomingFrameCount % processEveryNFrames != 0) {
				return;
			}
			if (_isBusy || _session == null || !_isModelLoaded) {
				return;
			}
			_isBusy = true;
			unawaited(_processImage(image));
		});
	}

	Future<void> _processImage(CameraImage cameraImage) async {
		try {
			// Run model and decode detections for one frame.
			final detections = await _runInference(cameraImage);

			if (!mounted || _isDisposed) {
				return;
			}
			final now = DateTime.now();
			// UI throttle: cap repaint frequency to avoid jank from frequent setState.
			if (now.difference(_lastUiUpdate).inMilliseconds < uiUpdateIntervalMs) {
				return;
			}
			_lastUiUpdate = now;
			setState(() {
				_detections = detections;
				_updateProximityAndAlert();
			});
		} catch (e) {
			debugPrint('Error processing frame: $e');
		} finally {
			_isBusy = false;
		}
	}

	Future<List<Detection>> _runInference(CameraImage cameraImage) async {
		// Direct YUV420 -> normalized tensor preprocessing (no RGB frame object allocation).
		final input = _cameraImageToInputTensor(cameraImage);

		final inputTensor = OrtValueTensor.createTensorWithDataList(
			input,
			[1, 3, inputSize, inputSize],
		);

		// Outputs is always released in finally block.
		List<OrtValue?> outputs = const [];
		try {
			final inputName = _session!.inputNames.first;
			try {
				// Async ONNX run first; fallback to sync run if async path is unavailable.
				final asyncOutputs = await _session!.runAsync(
					_runOptions!,
					{inputName: inputTensor},
				);
				outputs = asyncOutputs ??
						_session!.run(
							_runOptions!,
							{inputName: inputTensor},
						);
			} catch (_) {
				outputs = _session!.run(
					_runOptions!,
					{inputName: inputTensor},
				);
			}

			final outputTensor = outputs.isNotEmpty ? outputs.first : null;
			// If no tensor came back, return empty detections.
			if (outputTensor == null || outputTensor is! OrtValueTensor) {
				return [];
			}

			final decoded = _decodeYoloOutput(
				outputTensor.value,
				cameraImage.width,
				cameraImage.height,
			);

			// Top-K before NMS: keep highest confidence candidates for faster suppression.
			decoded.sort((a, b) => b.confidence.compareTo(a.confidence));
			final limited = decoded.length > maxCandidatesBeforeNms
					? decoded.sublist(0, maxCandidatesBeforeNms)
					: decoded;

			return _applyNms(limited, iouThreshold);
		} finally {
			inputTensor.release();
			for (final out in outputs) {
				out?.release();
			}
		}
	}

	List<Detection> _decodeYoloOutput(
		dynamic tensorValue,
		int originalWidth,
		int originalHeight,
	) {
		// Expected shapes are [1, 84, N] or [1, N, 84].
		if (tensorValue is! List || tensorValue.isEmpty || tensorValue[0] is! List) {
			return [];
		}

		final detections = <Detection>[];

		final batch = tensorValue[0];
		if (batch is! List || batch.isEmpty || batch[0] is! List) {
			return [];
		}

		final secondDim = batch.length;
		final thirdDim = (batch[0] as List).length;

		if (secondDim == 84) {
			for (int i = 0; i < thirdDim; i++) {
				final cx = _asDouble(batch[0][i]);
				final cy = _asDouble(batch[1][i]);
				final w = _asDouble(batch[2][i]);
				final h = _asDouble(batch[3][i]);

				int bestClass = -1;
				double bestScore = 0;
				for (int c = 4; c < 84; c++) {
					final score = _asDouble(batch[c][i]);
					if (score > bestScore) {
						bestScore = score;
						bestClass = c - 4;
					}
				}

				_appendDetectionIfValid(
					detections: detections,
					bestClass: bestClass,
					score: bestScore,
					cx: cx,
					cy: cy,
					w: w,
					h: h,
					originalWidth: originalWidth,
					originalHeight: originalHeight,
				);
			}
		} else if (thirdDim == 84) {
			for (int i = 0; i < secondDim; i++) {
				final row = batch[i] as List;
				final cx = _asDouble(row[0]);
				final cy = _asDouble(row[1]);
				final w = _asDouble(row[2]);
				final h = _asDouble(row[3]);

				int bestClass = -1;
				double bestScore = 0;
				for (int c = 4; c < 84; c++) {
					final score = _asDouble(row[c]);
					if (score > bestScore) {
						bestScore = score;
						bestClass = c - 4;
					}
				}

				_appendDetectionIfValid(
					detections: detections,
					bestClass: bestClass,
					score: bestScore,
					cx: cx,
					cy: cy,
					w: w,
					h: h,
					originalWidth: originalWidth,
					originalHeight: originalHeight,
				);
			}
		}

		return detections;
	}

	void _appendDetectionIfValid({
		required List<Detection> detections,
		required int bestClass,
		required double score,
		required double cx,
		required double cy,
		required double w,
		required double h,
		required int originalWidth,
		required int originalHeight,
	}) {
		// Filter by confidence first.
		if (bestClass < 0 || score < confidenceThreshold) {
			return;
		}
		// Convert model-space boxes back to original camera-frame coordinates.
		final scaleX = originalWidth / inputSize;
		final scaleY = originalHeight / inputSize;

		final left = (cx - w / 2) * scaleX;
		final top = (cy - h / 2) * scaleY;
		final width = w * scaleX;
		final height = h * scaleY;

		final rect = Rect.fromLTWH(
			left.clamp(0, originalWidth.toDouble() - 1),
			top.clamp(0, originalHeight.toDouble() - 1),
			width.clamp(1, originalWidth.toDouble()),
			height.clamp(1, originalHeight.toDouble()),
		);

		final proximity = _calculateProximity(rect, originalWidth, originalHeight);

		detections.add(
			Detection(
				classId: bestClass,
				className: classNames[bestClass] ?? 'obj',
				confidence: score,
				bbox: rect,
				proximityScore: proximity,
			),
		);
	}

	Float32List _cameraImageToInputTensor(CameraImage image) {
		// Convert camera YUV image into normalized float tensor in CHW format.
		final width = image.width;
		final height = image.height;

		final yPlane = image.planes[0];
		final uPlane = image.planes[1];
		final vPlane = image.planes[2];

		final input = Float32List(1 * 3 * inputSize * inputSize);
		const channelSize = inputSize * inputSize;
		final xRatio = width / inputSize;
		final yRatio = height / inputSize;
		final uBytesPerPixel = uPlane.bytesPerPixel ?? 1;
		final vBytesPerPixel = vPlane.bytesPerPixel ?? 1;

		// Sample YUV planes directly and normalize to [0, 1] in CHW layout.
		for (int y = 0; y < inputSize; y++) {
			final srcY = math.min((y * yRatio).floor(), height - 1);
			for (int x = 0; x < inputSize; x++) {
				final srcX = math.min((x * xRatio).floor(), width - 1);

				final yIndex = srcY * yPlane.bytesPerRow + srcX;
				final uvX = srcX ~/ 2;
				final uvY = srcY ~/ 2;
				final uIndex = uvY * uPlane.bytesPerRow + uvX * uBytesPerPixel;
				final vIndex = uvY * vPlane.bytesPerRow + uvX * vBytesPerPixel;

				final yValue = yPlane.bytes[yIndex].toDouble();
				final uValue = uPlane.bytes[uIndex].toDouble() - 128.0;
				final vValue = vPlane.bytes[vIndex].toDouble() - 128.0;

				final r = (yValue + 1.402 * vValue).clamp(0.0, 255.0);
				final g = (yValue - 0.344136 * uValue - 0.714136 * vValue)
						.clamp(0.0, 255.0);
				final b = (yValue + 1.772 * uValue).clamp(0.0, 255.0);

				final index = y * inputSize + x;
				input[index] = r / 255.0;
				input[channelSize + index] = g / 255.0;
				input[(2 * channelSize) + index] = b / 255.0;
			}
		}

		return input;
	}

	List<Detection> _applyNms(List<Detection> detections, double iouThreshold) {
		// Non-maximum suppression removes overlapping duplicates.
		if (detections.isEmpty) {
			return [];
		}

		final sorted = [...detections]
			..sort((a, b) => b.confidence.compareTo(a.confidence));
		final selected = <Detection>[];

		while (sorted.isNotEmpty) {
			final current = sorted.removeAt(0);
			selected.add(current);

			sorted.removeWhere(
				(candidate) =>
						candidate.classId == current.classId &&
						_iou(candidate.bbox, current.bbox) > iouThreshold,
			);
		}

		return selected;
	}

	double _iou(Rect a, Rect b) {
		final left = math.max(a.left, b.left);
		final top = math.max(a.top, b.top);
		final right = math.min(a.right, b.right);
		final bottom = math.min(a.bottom, b.bottom);

		final overlapWidth = math.max(0.0, right - left);
		final overlapHeight = math.max(0.0, bottom - top);
		final intersection = overlapWidth * overlapHeight;

		final union = a.width * a.height + b.width * b.height - intersection;
		if (union <= 0) {
			return 0;
		}
		return intersection / union;
	}

	double _calculateProximity(Rect bbox, int frameWidth, int frameHeight) {
		// Heuristic proximity score from object size and vertical position.
		final heightRatio = bbox.height / frameHeight;
		final verticalPosition = (bbox.bottom / frameHeight).clamp(0.0, 1.0);
		final areaRatio = (bbox.width * bbox.height) / (frameWidth * frameHeight);

		final score =
				(heightRatio * 0.50 + verticalPosition * 0.30 + areaRatio * 20.0) * 100;
		return score.clamp(0.0, 100.0);
	}

	double _asDouble(dynamic value) {
		if (value is num) {
			return value.toDouble();
		}
		return 0;
	}

	void _updateProximityAndAlert() {
		// Pick strongest proximity score and trigger red alert threshold.
		if (_detections.isEmpty) {
			_proximityScore = 0;
			_alertActive = false;
			return;
		}

		_proximityScore = _detections
				.map((d) => d.proximityScore)
				.fold<double>(0, (prev, next) => math.max(prev, next));
		_alertActive = _proximityScore >= 60;
	}

	@override
	void dispose() {
		// Stop camera and release ONNX resources safely.
		_isDisposed = true;

		final controller = _controller;
		if (controller != null) {
			if (controller.value.isStreamingImages) {
				controller.stopImageStream();
			}
			controller.dispose();
		}

		_runOptions?.release();
		_session?.release();
		_sessionOptions?.release();
		OrtEnv.instance.release();

		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		// Show loading spinner until camera is ready.
		if (_controller == null || !_controller!.value.isInitialized) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}

		// Main UI: camera, boxes, warning banner, model status, proximity meter.
		return Scaffold(
			backgroundColor: Colors.black,
			body: Stack(
				fit: StackFit.expand,
				children: [
					CameraPreview(_controller!),
					CustomPaint(
						painter: DetectionPainter(
							detections: _detections,
							previewSize: _controller!.value.previewSize!,
							screenSize: MediaQuery.of(context).size,
						),
					),
					if (_alertActive)
						Container(
							decoration: BoxDecoration(
								border: Border.all(color: Colors.red, width: 4),
							),
						),
					Positioned(
						top: 0,
						left: 0,
						right: 0,
						child: Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								gradient: LinearGradient(
									begin: Alignment.topCenter,
									end: Alignment.bottomCenter,
									colors: [
										Colors.black.withValues(alpha: 0.75),
										Colors.transparent,
									],
								),
							),
							child: SafeArea(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												IconButton(
													onPressed: () => Navigator.pop(context),
													icon: const Icon(Icons.arrow_back, color: Colors.white),
												),
												const SizedBox.shrink(),
											],
										),
										if (_alertActive)
											Container(
												margin: const EdgeInsets.only(top: 8),
												padding: const EdgeInsets.symmetric(
													horizontal: 14,
													vertical: 8,
												),
												decoration: BoxDecoration(
													color: Colors.red,
													borderRadius: BorderRadius.circular(8),
												),
												child: const Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(Icons.warning, color: Colors.white),
														SizedBox(width: 8),
														Text(
															'ALERT: VEHICLE CLOSE!',
															style: TextStyle(
																color: Colors.white,
																fontWeight: FontWeight.bold,
																fontSize: 16,
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
					Positioned(
						top: MediaQuery.of(context).padding.top + 64,
						right: 16,
						child: Container(
							padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
							decoration: BoxDecoration(
								color: _isModelLoaded ? Colors.green : Colors.orange,
								borderRadius: BorderRadius.circular(999),
							),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(
										_isModelLoaded ? Icons.check_circle : Icons.warning_amber,
										size: 16,
										color: Colors.white,
									),
									const SizedBox(width: 6),
									Text(
										_isModelLoaded ? 'Model Ready' : 'Loading Model',
										style: const TextStyle(
											color: Colors.white,
											fontSize: 12,
											fontWeight: FontWeight.w700,
										),
									),
								],
							),
						),
					),
					Positioned(
						bottom: 16,
						left: 16,
						right: 16,
						child: SafeArea(
							child: ProximityMeter(score: _proximityScore),
						),
					),
				],
			),
		);
	}
}

class Detection {
	// One model prediction after decoding.
	final int classId;
	final String className;
	final double confidence;
	final Rect bbox;
	final double proximityScore;

	const Detection({
		required this.classId,
		required this.className,
		required this.confidence,
		required this.bbox,
		required this.proximityScore,
	});
}

class DetectionPainter extends CustomPainter {
	// Draws bounding boxes and labels on top of camera preview.
	final List<Detection> detections;
	final Size previewSize;
	final Size screenSize;

	DetectionPainter({
		required this.detections,
		required this.previewSize,
		required this.screenSize,
	});

	@override
	void paint(Canvas canvas, Size size) {
		final boxPaint = Paint()
			..style = PaintingStyle.stroke
			..strokeWidth = 2.5;

		for (final detection in detections) {
			final color = detection.proximityScore > 60
					? Colors.red
					: detection.proximityScore > 30
							? Colors.yellow
							: Colors.green;
			boxPaint.color = color;

			final scaled = _transformRect(detection.bbox);
			canvas.drawRect(scaled, boxPaint);

			final label =
					'${detection.className} ${(detection.confidence * 100).toStringAsFixed(0)}%';
			final tp = TextPainter(
				text: TextSpan(
					text: label,
					style: const TextStyle(
						color: Colors.white,
						fontSize: 12,
						fontWeight: FontWeight.bold,
					),
				),
				textDirection: TextDirection.ltr,
			)..layout();

			final bgPaint = Paint()..color = color;
			canvas.drawRect(
				Rect.fromLTWH(
					scaled.left,
					math.max(0, scaled.top - tp.height - 6),
					tp.width + 8,
					tp.height + 4,
				),
				bgPaint,
			);
			tp.paint(canvas, Offset(scaled.left + 4, math.max(0, scaled.top - tp.height - 4)));
		}
	}

	Rect _transformRect(Rect raw) {
		// Convert camera-space rect to screen-space rect.
		final previewRatio = previewSize.height / previewSize.width;
		final screenRatio = screenSize.width / screenSize.height;

		double scale;
		double dx = 0;
		double dy = 0;

		if (previewRatio > screenRatio) {
			scale = screenSize.width / previewSize.height;
			final fittedHeight = previewSize.width * scale;
			dy = (screenSize.height - fittedHeight) / 2;
		} else {
			scale = screenSize.height / previewSize.width;
			final fittedWidth = previewSize.height * scale;
			dx = (screenSize.width - fittedWidth) / 2;
		}

		return Rect.fromLTWH(
			raw.left * scale + dx,
			raw.top * scale + dy,
			raw.width * scale,
			raw.height * scale,
		);
	}

	@override
	bool shouldRepaint(covariant DetectionPainter oldDelegate) {
		return oldDelegate.detections != detections;
	}
}

class ProximityMeter extends StatelessWidget {
	// Bottom progress bar showing current proximity score.
	final double score;

	const ProximityMeter({
		super.key,
		required this.score,
	});

	@override
	Widget build(BuildContext context) {
		final meterColor = score < 30
				? Colors.green
				: score < 60
						? Colors.yellow
						: Colors.red;

		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				const Text(
					'Proximity',
					style: TextStyle(
						color: Colors.white,
						fontSize: 16,
						fontWeight: FontWeight.bold,
					),
				),
				const SizedBox(height: 8),
				Container(
					height: 24,
					decoration: BoxDecoration(
						color: Colors.grey.shade800,
						borderRadius: BorderRadius.circular(999),
						border: Border.all(color: Colors.white, width: 2),
					),
					child: ClipRRect(
						borderRadius: BorderRadius.circular(999),
						child: Stack(
							children: [
								FractionallySizedBox(
									widthFactor: (score / 100).clamp(0.0, 1.0),
									child: Container(color: meterColor),
								),
								Center(
									child: Text(
										'${score.toStringAsFixed(0)}%',
										style: const TextStyle(
											color: Colors.white,
											fontSize: 12,
											fontWeight: FontWeight.bold,
										),
									),
								),
							],
						),
					),
				),
			],
		);
	}
}
