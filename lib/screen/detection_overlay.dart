import 'package:flutter/material.dart';

import '../detection/models/detection_models.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.previewSize,
  });

  final List<Detection> detections;
  final Size? previewSize;

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
        ),
      ),
    );
  }
}

class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter({
    required this.detections,
    required this.previewSize,
  });

  final List<Detection> detections;
  final Size previewSize;

  @override
  void paint(Canvas canvas, Size size) {
    final source = _bestPreviewSizeForCanvas(previewSize, size);
    final transform = _computeCoverTransform(source, size);

    final boxPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final detection in detections) {
      final rect = Rect.fromLTWH(
        detection.bbox.left * transform.scale + transform.dx,
        detection.bbox.top * transform.scale + transform.dy,
        detection.bbox.width * transform.scale,
        detection.bbox.height * transform.scale,
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
      final labelRect = Rect.fromLTWH(
        rect.left,
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
        oldDelegate.previewSize != previewSize;
  }

  Size _bestPreviewSizeForCanvas(Size preview, Size canvas) {
    final optionA = preview;
    final optionB = Size(preview.height, preview.width);

    final canvasAspect = canvas.width / canvas.height;
    final aAspect = optionA.width / optionA.height;
    final bAspect = optionB.width / optionB.height;

    final aDiff = (aAspect - canvasAspect).abs();
    final bDiff = (bAspect - canvasAspect).abs();

    return aDiff <= bDiff ? optionA : optionB;
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
