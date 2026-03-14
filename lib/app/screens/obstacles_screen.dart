import 'package:flutter/material.dart';

import '../widgets/app_navigation_bar.dart';
import '../widgets/camera_feed_card.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';

class ObstaclesScreen extends StatefulWidget {
  const ObstaclesScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<ObstaclesScreen> createState() => _ObstaclesScreenState();
}

class _ObstaclesScreenState extends State<ObstaclesScreen> {
  final List<String> _detectedObjects = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const ModuleHeader(
              title: 'Obstacles Detection',
              accent: Color(0xFF2563EB),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: CameraFeedCard(
                  label: 'Live Camera Feed',
                  accent: Color(0xFF3B82F6),
                ),
              ),
            ),
            ModuleBottomSheet(
              title: 'Detected Obstacles',
              accent: const Color(0xFF93C5FD),
              hasData: _detectedObjects.isNotEmpty,
              child: _detectedObjects.isEmpty
                  ? const Text(
                      'Scanning for obstacles...',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    )
                  : Column(
                      children: _detectedObjects
                          .map(
                            (object) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                object,
                                style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
      ),
    );
  }
}
