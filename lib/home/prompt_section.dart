// lib/home/prompt_section.dart
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
          if (hasToggle)
            GestureDetector(
              onTap: onToggleEnabled,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isEnabled
                      ? const Color(0xFF30D158).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: isEnabled
                        ? const Color(0xFF30D158).withValues(alpha: 0.4)
                        : const Color(0x15FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: isEnabled
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEnabled
                          ? const Color(0xFF30D158)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Позитивный промпт — label + actions row ──
        Row(
          children: [
            Text(
              'ПОЗИТИВНЫЙ ПРОМПТ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => onOpenFullscreen(
                sectionKey,
                '$title — Позитивный',
                color,
                posCtrl,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.open_in_full_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => posCtrl.clear(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 12, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 3),
                    Text('Очистить',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.3),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Поле позитивного промпта
        TextField(
          controller: posCtrl,
          maxLines: posLines,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xDDFFFFFF),
            letterSpacing: -0.2,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: posHint,
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
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.02),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        if (extraWidget != null) ...[
          extraWidget!,
          const SizedBox(height: 8),
        ],

        // ── Негативный промпт — label с toggle ──
        Row(
          children: [
            Text(
              'НЕГАТИВНЫЙ ПРОМПТ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF453A).withValues(alpha: 0.7),
                letterSpacing: 1.0,
              ),
            ),
            if (pinnedNegTags.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD60A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Text('${pinnedNegTags.length}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFFFFD60A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // Круглый переключатель — как в макете
            GestureDetector(
              onTap: onToggleNeg,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: negVisible
                      ? const Color(0xFFFF453A).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: negVisible
                        ? const Color(0xFFFF453A).withValues(alpha: 0.4)
                        : const Color(0x15FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  negVisible
                      ? Icons.remove_rounded
                      : Icons.add_rounded,
                  size: 16,
                  color: negVisible
                      ? const Color(0xFFFF453A)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Негативный промпт (раскрывающийся)
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Закреплённые теги — тёмные чипы (как в макете)
              if (pinnedNegTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pinnedNegTags.asMap().entries.map((e) {
                      final idx = e.key;
                      final tag = e.value;
                      return GestureDetector(
                        onTap: () {
                          final updated = List<String>.from(pinnedNegTags);
                          updated.removeAt(idx);
                          onPinnedChanged(updated);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.push_pin_rounded,
                                  size: 11, color: Color(0xFFFFD60A)),
                              const SizedBox(width: 5),
                              Text(tag.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xDDFFFFFF),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Негативное поле
              TextField(
                controller: negCtrl,
                maxLines: negLines,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xDDFFFFFF),
                  letterSpacing: -0.2,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: negHint,
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0x0AFFFFFF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.02),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.open_in_full_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.2)),
                    onPressed: () => onOpenFullscreen(
                      sectionKey,
                      '$title — Негативный',
                      const Color(0xFFFF3B30),
                      negCtrl,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Кнопка "ЗАКРЕПИТЬ ТЕГИ" — полная ширина, яркая
              GestureDetector(
                onTap: () => onPinTags(sectionKey, negCtrl),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        const Color(0xFFBF5AF2).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.push_pin_rounded,
                          size: 14, color: color),
                      const SizedBox(width: 6),
                      Text('ЗАКРЕПИТЬ ТЕГИ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
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
}
