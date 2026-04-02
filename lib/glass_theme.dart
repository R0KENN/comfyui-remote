import 'package:flutter/material.dart';

class GlassTheme {
  // ── Цвета ──
  static const Color bgDark = Color(0xFF050507);
  static const Color bgCard = Color(0xFF0E0E12);
  static const Color borderLight = Color(0x12FFFFFF);
  static const Color borderActive = Color(0x25FFFFFF);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF8A8A8E);
  static const Color textTertiary = Color(0xFF5A5A5E);
  static const Color accent = Color(0xFFD4D4D4);

  // ── Фон scaffold ──
  static BoxDecoration get scaffoldDecoration => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF08080C),
        Color(0xFF050507),
        Color(0xFF030304),
      ],
    ),
  );

  // ── Стеклянная карточка ──
  static Widget card({
    required Widget child,
    Color? borderColor,
    double blur = 18,
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double borderRadius = 20,
    double opacity = 0.04,
    bool highlight = false,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? (highlight ? borderActive : borderLight),
          width: 0.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: opacity * 0.2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (highlight)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              blurRadius: 1,
              spreadRadius: 0,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  // ── Маленькая стеклянная карточка (для вложенных элементов) ──
  static Widget miniCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 14,
    Color? borderColor,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: borderColor ?? const Color(0x0AFFFFFF),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }

  // ── Заголовок секции ──
  static Widget sectionTitle(
      IconData icon,
      Color iconColor,
      String title, {
        Widget? trailing,
        double iconSize = 18,
      }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  // ── Статус-бейдж ──
  static Widget statusBadge(String text, Color color, {bool dot = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Анимация появления ──
  static Widget fadeSlideIn({
    required Widget child,
    required int index,
    required AnimationController controller,
  }) {
    final delay = (index * 0.08).clamp(0.0, 0.5);
    final animation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    ));
    final opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut),
    ));

    return SlideTransition(
      position: animation,
      child: FadeTransition(opacity: opacity, child: child),
    );
  }

  // ── Прогресс-бар ──
  static Widget progressBar(double percent, {Color? color, double height = 4}) {
    final barColor = color ??
        (percent > 90
            ? const Color(0xFFFF4444)
            : percent > 70
            ? const Color(0xFFFF9500)
            : const Color(0xFF30D158));
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${percent.toStringAsFixed(1)}%',
            style: const TextStyle(color: textTertiary, fontSize: 10, letterSpacing: -0.2),
          ),
        ),
      ],
    );
  }

  // ── Чип / тег ──
  static Widget chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Glass AppBar ──
  static AppBar appBar(String title, {List<Widget>? actions, Widget? leading}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(title,
        style: const TextStyle(
          fontSize: 16,
          color: textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      leading: leading,
      actions: actions,
    );
  }

  // ── Стеклянное текстовое поле ──
  static InputDecoration glassInput({
    String? label,
    String? hint,
    Color accentColor = const Color(0xFF8A8AFF),
    Widget? suffixIcon,
    bool isDense = true,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: textTertiary, letterSpacing: -0.2),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Color(0x22FFFFFF)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accentColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.02),
      isDense: isDense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      suffixIcon: suffixIcon,
    );
  }

  // ── Стеклянная кнопка ──
  static Widget glassButton({
    required String text,
    required VoidCallback? onTap,
    Color color = const Color(0xFF8A8AFF),
    IconData? icon,
    bool expanded = true,
    double height = 48,
  }) {
    final isEnabled = onTap != null;
    final button = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isEnabled
              ? LinearGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.1),
            ],
          )
              : null,
          color: isEnabled ? null : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 0.3) : const Color(0x0AFFFFFF),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isEnabled ? color : textTertiary),
              const SizedBox(width: 8),
            ],
            Text(text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isEnabled ? Colors.white : textTertiary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
    return expanded ? button : button;
  }
}
