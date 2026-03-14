import 'package:flutter/material.dart';

class ModuleBottomSheet extends StatelessWidget {
  const ModuleBottomSheet({
    super.key,
    required this.title,
    required this.accent,
    required this.child,
    this.hasData = false,
  });

  final String title;
  final Color accent;
  final Widget child;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final ratio = hasData ? 0.32 : 0.20;
    final minHeight = hasData ? 280.0 : 180.0;
    final maxHeight = hasData ? 460.0 : 260.0;
    final sheetHeight = (screenHeight * ratio).clamp(minHeight, maxHeight);

    return BottomSheet(
      onClosing: () {},
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: accent.withValues(alpha: 0.25), width: 1.2),
      ),
      builder: (context) {
        return SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        );
      },
    );
  }
}
