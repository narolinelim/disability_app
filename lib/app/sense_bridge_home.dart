import 'package:flutter/material.dart';

import 'screens/item_detection_screen.dart';
import 'screens/noise_detection_screen.dart';
import 'screens/obstacles_screen.dart';
import 'screens/sign_language_screen.dart';

class SenseBridgeHome extends StatefulWidget {
  const SenseBridgeHome({super.key});

  @override
  State<SenseBridgeHome> createState() => _SenseBridgeHomeState();
}

class _SenseBridgeHomeState extends State<SenseBridgeHome> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        if (index == _selectedIndex) {
          return;
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      children: [
        ObstaclesScreen(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
        ItemDetectionScreen(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
        SignLanguageScreen(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
        NoiseDetectionScreen(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ],
    );
  }
}
