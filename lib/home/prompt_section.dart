import 'package:flutter/material.dart';
import '../glass_theme.dart';

class PromptSection extends StatelessWidget {
  final String sectionKey;
  final String title;
  final Color color;
  final TextEditingController posCtrl;
  final TextEditingController negCtrl;
  final int posLines;
  final int negLines;
  final String posHint;
  final String negHint;
  final Widget? extraWidget;
  final bool isExpanded;
  final bool negVisible;
  final bool isEnabled;
  final bool hasToggle;
  final List<String> pinnedNegTags;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleNeg;
  final VoidCallback? onToggleEnabled;
  final void Function(String key, TextEditingController ctrl) onPinTags;
  final void Function(String key, String title, Color color,
      TextEditingController ctrl) onOpenFullscreen;
  final void Function(List<String> pinned) onPinnedChanged;

  const PromptSection({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.color,
    required this.posCtrl,
    required this.negCtrl,
    this.posLines = 5,
    this.negLines = 3,
    this.posHint = '',
    this.negHint = 'Пусто = из воркфлоу',
    this.extraWidget,
    required this.isExpanded,
    required this.negVisible,
    required this.isEnabled,
    this.hasToggle = false,
    required this.pinnedNegTags,
    required this.onToggleExpand,
    required this.onToggleNeg,
    this.onToggleEnabled,
    required this.onPinTags,
    required this.onOpenFullscreen,
    required this.onPinnedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassTheme.card(
      padding: EdgeInsets.zero,
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 250),
        child: Column(children: [
          _buildHeader(),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildBody(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: onToggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.drag_handle_rounded,
              size: 14, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: isEnabled ? color : GlassTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isEnabled ? color : GlassTheme.textTertiary,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // NEG индикатор
          if (negCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: const Text('NEG',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF3B30),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Переключатель ВКЛ/ВЫКЛ
          if (hasToggle)
            GestureDetector(
              onTap: onToggleEnabled,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? const Color(0xFF30D158).withValues(alpha: 0.08)
                      : const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEnabled
                        ? const Color(0xFF30D158).withValues(alpha: 0.2)
                        : const Color(0xFFFF3B30).withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  isEnabled ? 'ВКЛ' : 'ВЫКЛ',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF3B30),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Icon(Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(children: [
        // Позитивный промпт
        _buildField(
          label: 'Позитивный промпт',
          ctrl: posCtrl,
          lines: posLines,
          hint: posHint,
          showClear: true,
          accentColor: color,
          fullscreenTitle: '$title — Позитивный',
          fullscreenColor: color,
          context: context,
        ),

        ?extraWidget,

        // Кнопка негатива
        _buildNegButton(),

        // Негативный промпт
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            children: [
              _buildField(
                label: 'Негативный промпт',
                ctrl: negCtrl,
                lines: negLines,
                hint: negHint,
                accentColor: const Color(0xFFFF3B30),
                fullscreenTitle: '$title — Негативный',
                fullscreenColor: const Color(0xFFFF3B30),
                context: context,
              ),

              // Закреплённые теги
              if (pinnedNegTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: pinnedNegTags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD60A).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.push_pin_rounded,
                              size: 10, color: Color(0xFFFFD60A)),
                          const SizedBox(width: 4),
                          Text(tag,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFFD60A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),

              // Кнопка закрепить
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => onPinTags(sectionKey, negCtrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD60A).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD60A).withValues(alpha: 0.12),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_outlined,
                            size: 12, color: Color(0xFFFFD60A)),
                        SizedBox(width: 4),
                        Text('Закрепить теги',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFD60A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          crossFadeState: negVisible
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ]),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController ctrl,
    required int lines,
    required BuildContext context,
    String hint = '',
    bool showClear = false,
    Color accentColor = const Color(0xFF8A8AFF),
    String? fullscreenTitle,
    Color? fullscreenColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        TextField(
          controller: ctrl,
          maxLines: lines,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xDDFFFFFF),
            letterSpacing: -0.2,
            height: 1.5,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontSize: 12,
              color: GlassTheme.textTertiary,
              letterSpacing: -0.2,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0x0AFFFFFF)),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            suffixIcon: fullscreenTitle != null
                ? IconButton(
              icon: Icon(Icons.fullscreen_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.2)),
              onPressed: () => onOpenFullscreen(
                sectionKey,
                fullscreenTitle,
                fullscreenColor ?? Colors.white,
                ctrl,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
                : null,
          ),
        ),
        if (showClear && ctrl.text.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => ctrl.clear(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_rounded,
                        size: 12, color: Colors.white.withValues(alpha: 0.25)),
                    const SizedBox(width: 4),
                    Text('Очистить',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildNegButton() {
    final pinnedCount = pinnedNegTags.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleNeg,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    negVisible
                        ? Icons.remove_circle_outline_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 14,
                    color: const Color(0xFFFF453A),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    negVisible ? 'Скрыть негативный' : 'Негативный промпт',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF453A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pinnedCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD60A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.push_pin_rounded,
                      size: 9, color: Color(0xFFFFD60A)),
                  const SizedBox(width: 3),
                  Text('$pinnedCount',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFFFFD60A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
