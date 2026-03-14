import 'package:flutter/material.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          color: Colors.white,
          elevation: 14,
          shadowColor: Colors.black26,
          surfaceTintColor: Colors.white,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFEFF6FF),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF4B5563),
                  size: 24,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF4B5563),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: Colors.white,
              height: 82,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.photo_camera_outlined),
                  selectedIcon: Icon(Icons.photo_camera_outlined),
                  label: 'Obstacles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_outlined),
                  label: 'Items',
                ),
                NavigationDestination(
                  icon: Icon(Icons.front_hand_outlined),
                  selectedIcon: Icon(Icons.front_hand_outlined),
                  label: 'Sign',
                ),
                NavigationDestination(
                  icon: Icon(Icons.volume_up_outlined),
                  selectedIcon: Icon(Icons.volume_up_outlined),
                  label: 'Noise',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
