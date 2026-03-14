import 'package:flutter/material.dart';

import '../widgets/app_navigation_bar.dart';
import '../widgets/camera_feed_card.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';

class SignLanguageScreen extends StatelessWidget {
  const SignLanguageScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

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
              title: 'Sign Language Translation',
              accent: Color(0xFF9333EA),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: CameraFeedCard(
                  label: 'Show hand signs to camera',
                  accent: Color(0xFF3B82F6),
                ),
              ),
            ),
            ModuleBottomSheet(
              title: 'Translation History',
              accent: const Color(0xFFE9D5FF),
              hasData: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: const Text(
                  'Waiting for hand signs...',
                  style: TextStyle(color: Color(0xFF1F2937), fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}
