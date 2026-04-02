import 'dart:ui';
import 'package:flutter/material.dart';

class GlassTheme {
  // ── Цвета AMOLED ──
  static const Color bgDark = Color(0xFF000000);
  static const Color bgCard = Color(0xFF0A0A0E);
  static const Color bgCardElevated = Color(0xFF111116);
  static const Color borderLight = Color(0x18FFFFFF);
  static const Color borderActive = Color(0x30FFFFFF);
  static const Color textPrimary = Color(0xFFF2F2F7);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF48484A);
  static const Color accent = Color(0xFFD1D1D6);

  // Акцентные цвета
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentYellow = Color(0xFFFFD60A);
  static const Color accentRed = Color(0xFFFF453A);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentCyan = Color(0xFF64D2FF);

  // ── Liquid Glass параметры ──
  static const double _defaultBlur = 24.0;
  static const double _defaultTintOpacity = 0.08;
  static const double _defaultBorderOpacity = 0.12;
  static const double _specularOpacity = 0.06;

  // ── Фон scaffold ──
  static BoxDecoration get scaffoldDecoration => const BoxDecoration(
    color: Color(0xFF000000),
  );

  // ── Liquid Glass карточка ──
  static Widget card({
    required Widget child,
    Color? borderColor,
    double blur = _defaultBlur,
    EdgeInsetsGeometry margin =
    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double borderRadius = 22,
    double tintOpacity = _defaultTintOpacity,
    bool highlight = false,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (highlight
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: _defaultBorderOpacity)),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (highlight && borderColor != null)
            BoxShadow(
              color: borderColor.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: -2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: tintOpacity + 0.04),
                  Colors.white.withValues(alpha: tintOpacity * 0.3),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Specular highlight — блик сверху
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(borderRadius)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: _specularOpacity),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Маленькая стеклянная карточка ──
  static Widget miniCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 14,
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
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
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
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
                          color: color.withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
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
      begin: const Offset(0, 0.08),
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
  static Widget progressBar(double percent,
      {Color? color, double height = 4}) {
    final barColor = color ??
        (percent > 90
            ? accentRed
            : percent > 70
            ? const Color(0xFFFF9F0A)
            : accentGreen);
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.white.withValues(alpha: 0.06),
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
          child: Text(
            '${percent.toStringAsFixed(1)}%',
            style: const TextStyle(
                color: textTertiary, fontSize: 10, letterSpacing: -0.2),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
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
  static AppBar appBar(String title,
      {List<Widget>? actions, Widget? leading}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
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
    Color accentColor = accentBlue,
    Widget? suffixIcon,
    bool isDense = true,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          fontSize: 12, color: textTertiary, letterSpacing: -0.2),
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 11, color: Colors.white.withValues(alpha: 0.12)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide:
        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accentColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      isDense: isDense,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      suffixIcon: suffixIcon,
    );
  }

  // ── Стеклянная кнопка ──
  static Widget glassButton({
    required String text,
    required VoidCallback? onTap,
    Color color = accentBlue,
    IconData? icon,
    bool expanded = true,
    double height = 48,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isEnabled
                  ? LinearGradient(colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.1),
              ])
                  : null,
              color:
              isEnabled ? null : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isEnabled
                    ? color.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 18,
                      color: isEnabled ? color : textTertiary),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
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
        ),
      ),
    );
  }
}
