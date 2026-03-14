import 'package:flutter/material.dart';

import '../feature/noise_detection/noise_detection.dart';
import '../widgets/app_navigation_bar.dart';

class NoiseDetectionScreen extends StatefulWidget {
  const NoiseDetectionScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<NoiseDetectionScreen> createState() => _NoiseDetectionScreenState();
}

class _NoiseDetectionScreenState extends State<NoiseDetectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const SafeArea(
        top: false,
        bottom: false,
        // The actual live noise result UI is hosted inside NoiseDetectionHost.
        child: NoiseDetectionHost(),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
      ),
    );
  }
}
