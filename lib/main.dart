import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'obstacle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final backCamera = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );
  runApp(MyApp(camera: backCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;

  const MyApp({super.key, this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: camera == null
          ? const Scaffold(
              body: Center(child: Text('Camera not initialized')),
            )
          : TrafficDetectorScreen(
              camera: camera!,
              frameResultStream: (result) {
                for (final d in result.detections) {
                  debugPrint(
                    '${d.className} conf=${(d.confidence * 100).toStringAsFixed(1)}% '
                    'proximity=${d.proximityScore.toStringAsFixed(1)} '
                    'bbox=${d.bbox.left.toStringAsFixed(1)},${d.bbox.top.toStringAsFixed(1)},'
                    '${d.bbox.width.toStringAsFixed(1)},${d.bbox.height.toStringAsFixed(1)}',
                  );
                }
              },
            ),
    );
  }
}
