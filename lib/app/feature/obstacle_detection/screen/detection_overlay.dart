/*
 * Pipeline location: app/feature/obstacle_detection/screen/detection_overlay.dart (Step 7 of 8)
 * General function: Paints detection boxes and labels over camera preview using frame detection data.
 * Return/output: build() returns a widget overlay layer; painter returns rendered canvas output.
 */
import 'package:flutter/material.dart';

import '../models/detection_models.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.previewSize,
    required this.sensorOrientation,
    this.mirrorHorizontally = false,
  });

  final List<Detection> detections;
  final Size? previewSize;
  final int sensorOrientation;
  final bool mirrorHorizontally;

  @override
  Widget build(BuildContext context) {
    if (previewSize == null || detections.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: DetectionOverlayPainter(
          detections: detections,
          previewSize: previewSize!,
          sensorOrientation: sensorOrientation,
          mirrorHorizontally: mirrorHorizontally,
        ),
      ),
    );
  }
}

class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter({
    required this.detections,
    required this.previewSize,
    required this.sensorOrientation,
    required this.mirrorHorizontally,
  });

  final List<Detection> detections;
  final Size previewSize;
  final int sensorOrientation;
  final bool mirrorHorizontally;

  @override
  void paint(Canvas canvas, Size size) {
    final quarterTurns = _normalizedQuarterTurns(sensorOrientation);
    final orientedSource = _sourceAfterRotation(previewSize, quarterTurns);
    final transform = _computeCoverTransform(orientedSource, size);

    final boxPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final detection in detections) {
      final orientedRect = _orientedRect(
        detection.bbox,
        previewSize,
        quarterTurns,
      );
      final displayRect = mirrorHorizontally
          ? _mirrorRectHorizontally(orientedRect, orientedSource.width)
          : orientedRect;

      final rect = Rect.fromLTWH(
        displayRect.left * transform.scale + transform.dx,
        displayRect.top * transform.scale + transform.dy,
        displayRect.width * transform.scale,
        displayRect.height * transform.scale,
      );

      canvas.drawRect(rect, boxPaint);

        final label =
          '${detection.className} (#${detection.classId}) ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.7);

      const labelPadding = 4.0;
      final labelLeft = rect.left.clamp(
        0.0,
        (size.width - (textPainter.width + (labelPadding * 2))).clamp(0.0, size.width),
      );

      final labelRect = Rect.fromLTWH(
        labelLeft,
        (rect.top - textPainter.height - (labelPadding * 2)).clamp(
          0,
          size.height - textPainter.height - (labelPadding * 2),
        ),
        textPainter.width + (labelPadding * 2),
        textPainter.height + (labelPadding * 2),
      );

      final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        bgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(labelRect.left + labelPadding, labelRect.top + labelPadding),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.sensorOrientation != sensorOrientation ||
        oldDelegate.mirrorHorizontally != mirrorHorizontally;
  }

  int _normalizedQuarterTurns(int orientationDegrees) {
    final turns = (orientationDegrees ~/ 90) % 4;
    return turns < 0 ? turns + 4 : turns;
  }

  Size _sourceAfterRotation(Size source, int quarterTurns) {
    if (quarterTurns.isOdd) {
      return Size(source.height, source.width);
    }
    return source;
  }

  Rect _orientedRect(Rect rect, Size source, int quarterTurns) {
    switch (quarterTurns) {
      case 1:
        // Rotate 90deg clockwise.
        return Rect.fromLTWH(
          source.height - rect.bottom,
          rect.left,
          rect.height,
          rect.width,
        );
      case 2:
        // Rotate 180deg.
        return Rect.fromLTWH(
          source.width - rect.right,
          source.height - rect.bottom,
          rect.width,
          rect.height,
        );
      case 3:
        // Rotate 270deg clockwise.
        return Rect.fromLTWH(
          rect.top,
          source.width - rect.right,
          rect.height,
          rect.width,
        );
      case 0:
      default:
        return rect;
    }
  }

  Rect _mirrorRectHorizontally(Rect rect, double sourceWidth) {
    return Rect.fromLTWH(
      sourceWidth - rect.right,
      rect.top,
      rect.width,
      rect.height,
    );
  }

  _CoverTransform _computeCoverTransform(Size source, Size target) {
    final scale =
        (target.width / source.width).compareTo(target.height / source.height) >
                0
            ? target.width / source.width
            : target.height / source.height;

    final scaledWidth = source.width * scale;
    final scaledHeight = source.height * scale;
    final dx = (target.width - scaledWidth) / 2;
    final dy = (target.height - scaledHeight) / 2;

    return _CoverTransform(scale: scale, dx: dx, dy: dy);
  }
}

class _CoverTransform {
  const _CoverTransform({
    required this.scale,
    required this.dx,
    required this.dy,
  });

  final double scale;
  final double dx;
  final double dy;
}
