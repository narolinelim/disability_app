import 'package:flutter/material.dart';

import '../services/app_announcer.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/module_bottom_sheet.dart';
import '../widgets/module_header.dart';

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
  bool _isListening = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ModuleHeader(
              title: 'Noise Detection',
              accent: const Color(0xFFEA580C),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF7ED), Colors.white],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isListening = !_isListening;
                        });
                        AppAnnouncer.instance.speak(
                          _isListening
                              ? 'Noise monitoring on.'
                              : 'Noise monitoring paused.',
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFE5E7EB),
                        ),
                        child: Icon(
                          Icons.volume_up_outlined,
                          size: 48,
                          color: _isListening
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _isListening
                          ? 'Listening for Sounds'
                          : 'Monitoring Paused',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isListening
                          ? 'Actively monitoring environmental sounds'
                          : 'Tap center icon to resume monitoring',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const ModuleBottomSheet(
              title: 'Recent Noise Alerts',
              accent: Color(0xFFFED7AA),
              hasData: false,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'No noise detected yet',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
