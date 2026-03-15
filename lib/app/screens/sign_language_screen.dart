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
        child: Stack(
          children: [
            Column(
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
                const SizedBox(height: ModuleBottomSheet.collapsedHeight),
              ],
            ),
            ModuleBottomSheet(
              title: 'Translation History',
              accent: const Color(0xFFE9D5FF),
              hasData: false,
              child: const SizedBox.shrink(),
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
