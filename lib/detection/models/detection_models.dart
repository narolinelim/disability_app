import 'package:flutter/material.dart';

class FrameResult {
  final dynamic rawOutput;
  final List<Detection> detections;
  final List<String> objectLabels;
  final double proximityScore;

  const FrameResult({
    required this.rawOutput,
    required this.detections,
    required this.objectLabels,
    required this.proximityScore,
  });
}

class Detection {
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

class DetectorUiState {
  final bool isCameraReady;
  final bool isModelReady;
  final String? error;

  const DetectorUiState({
    required this.isCameraReady,
    required this.isModelReady,
    this.error,
  });

  const DetectorUiState.initial()
      : isCameraReady = false,
        isModelReady = false,
        error = null;

  DetectorUiState copyWith({
    bool? isCameraReady,
    bool? isModelReady,
    String? error,
    bool clearError = false,
  }) {
    return DetectorUiState(
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isModelReady: isModelReady ?? this.isModelReady,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
