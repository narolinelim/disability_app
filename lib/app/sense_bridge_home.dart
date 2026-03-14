import 'package:flutter/material.dart';

import 'services/app_announcer.dart';
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
  static const _pageAnimationDuration = Duration(milliseconds: 240);
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentScreen();
    });
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
    _setSelectedIndex(index);
    _pageController.animateToPage(
      index,
      duration: _pageAnimationDuration,
      curve: Curves.easeOutCubic,
    );
    _announceCurrentScreen(force: true);
  }

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _announceCurrentScreen({bool force = false}) {
    AppAnnouncer.instance.announceScreenByIndex(_selectedIndex, force: force);
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        if (index == _selectedIndex) {
          return;
        }
        _setSelectedIndex(index);
        _announceCurrentScreen(force: true);
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
