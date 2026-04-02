import 'package:flutter/material.dart';
import 'dart:ui';

class BottomNav extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onTabChanged;

  const BottomNav({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x12FFFFFF),
          width: 0.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.015),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.brush_outlined,
                  activeIcon: Icons.brush,
                  label: 'Генерация',
                  active: currentTab == 0,
                  onTap: () => onTabChanged(0),
                ),
                _NavItem(
                  icon: Icons.monitor_heart_outlined,
                  activeIcon: Icons.monitor_heart,
                  label: 'Монитор',
                  active: currentTab == 1,
                  onTap: () => onTabChanged(1),
                ),
                _NavItem(
                  icon: Icons.terminal_outlined,
                  activeIcon: Icons.terminal,
                  label: 'Логи',
                  active: currentTab == 2,
                  onTap: () => onTabChanged(2),
                ),
                _NavItem(
                  icon: Icons.photo_library_outlined,
                  activeIcon: Icons.photo_library,
                  label: 'История',
                  active: currentTab == 3,
                  onTap: () => onTabChanged(3),
                ),
                _NavItem(
                  icon: Icons.cloud_outlined,
                  activeIcon: Icons.cloud,
                  label: 'Сервер',
                  active: currentTab == 4,
                  onTap: () => onTabChanged(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: active
              ? Border.all(color: const Color(0x15FFFFFF), width: 0.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                size: 20,
                color: active
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFF4A4A4E),
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: -0.2,
                color: active
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFF4A4A4E),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
