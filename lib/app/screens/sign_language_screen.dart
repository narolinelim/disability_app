import 'package:flutter/material.dart';

import '../widgets/app_navigation_bar.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';
import '../feature/auslan_scripts/sign_language_camera_card.dart';

class SignLanguageScreen extends StatefulWidget {
  const SignLanguageScreen({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<SignLanguageScreen> createState() => _SignLanguageScreenState();
}

class _SignLanguageScreenState extends State<SignLanguageScreen> {
  String _allLetters = '';
  String _rawLabel = '';
  double _confidence = 0;

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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SignLanguageCameraCard(
                  label: 'Show hand signs to camera',
                  accent: const Color(0xFF3B82F6),
                  onPrediction: (rawLabel, confidence, allLetters) {
                    setState(() {
                      _rawLabel = rawLabel;
                      _confidence = confidence;
                      _allLetters = allLetters;
                    });
                    debugPrint(
                      'RAW: $rawLabel ${confidence.toStringAsFixed(1)}% | RESULT: $allLetters',
                    );
                  },
                ),
              ),
            ),
            ModuleBottomSheet(
              title: 'Translation History',
              accent: const Color(0xFFE9D5FF),
              hasData: _allLetters.isNotEmpty,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Text(
                  _allLetters.isEmpty
                      ? 'Waiting for hand signs...'
                      : '$_allLetters\nRaw: $_rawLabel ${_confidence.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                  ),
                ),
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
