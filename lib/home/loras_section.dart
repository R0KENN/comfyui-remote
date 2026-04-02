import 'package:flutter/material.dart';
import '../glass_theme.dart';
import '../services.dart';

class LorasSection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<LoraGroup> loraGroups;
  final Map<String, bool> loraGroupOpen;
  final void Function(String nodeId) onToggleGroup;
  final VoidCallback onChanged;

  const LorasSection({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.loraGroups,
    required this.loraGroupOpen,
    required this.onToggleGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    int totalEnabled = 0;
    for (var g in loraGroups) {
      totalEnabled += g.loras.where((l) => l.enabled).length;
    }

    return GlassTheme.card(
      padding: EdgeInsets.zero,
      child: Column(children: [
        // ── Заголовок ──
        GestureDetector(
          onTap: onToggle,
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
                  color: const Color(0xFFFFD60A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Лоры',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFFFFD60A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (totalEnabled > 0)
                GlassTheme.chip('$totalEnabled вкл', const Color(0xFFFFD60A)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.expand_more_rounded,
                    color: Colors.white.withValues(alpha: 0.2), size: 20),
              ),
            ]),
          ),
        ),

        // ── Содержимое ──
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: loraGroups.isEmpty
                  ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_clear_outlined,
                          size: 16, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(width: 8),
                      Text('Нет лор в воркфлоу',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.2),
                              letterSpacing: -0.2)),
                    ],
                  ),
                ),
              ]
                  : loraGroups
                  .map((group) => _LoraGroupCard(
                group: group,
                isOpen: loraGroupOpen[group.nodeId] ?? false,
                onToggle: () => onToggleGroup(group.nodeId),
                onChanged: onChanged,
              ))
                  .toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ]),
    );
  }
}

class _LoraGroupCard extends StatelessWidget {
  final LoraGroup group;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  const _LoraGroupCard({
    required this.group,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabledCount = group.loras.where((l) => l.enabled).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x08FFFFFF)),
      ),
      child: Column(children: [
        // ── Заголовок группы ──
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Text(group.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xCCFFFFFF),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: enabledCount > 0
                      ? const Color(0xFFFFD60A).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: enabledCount > 0
                        ? const Color(0xFFFFD60A).withValues(alpha: 0.15)
                        : const Color(0x08FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '$enabledCount / ${group.loras.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: enabledCount > 0
                        ? const Color(0xFFFFD60A)
                        : GlassTheme.textTertiary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.expand_more_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.2)),
              ),
            ]),
          ),
        ),

        // ── Лоры внутри группы ──
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: group.loras.map((lora) {
                final shortName = lora.name.split('\\').last.split('/').last;
                return _LoraItem(
                    lora: lora, shortName: shortName, onChanged: onChanged);
              }).toList(),
            ),
          ),
          crossFadeState: isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ]),
    );
  }
}

class _LoraItem extends StatelessWidget {
  final LoraInfo lora;
  final String shortName;
  final VoidCallback onChanged;

  const _LoraItem({
    required this.lora,
    required this.shortName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        // ── Переключатель ──
        GestureDetector(
          onTap: () {
            lora.enabled = !lora.enabled;
            onChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: lora.enabled
                  ? const Color(0xFFFFD60A).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: lora.enabled
                    ? const Color(0xFFFFD60A).withValues(alpha: 0.4)
                    : const Color(0x15FFFFFF),
                width: 0.5,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: lora.enabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lora.enabled
                      ? const Color(0xFFFFD60A)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Название + слайдер ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shortName,
                style: TextStyle(
                  fontSize: 11,
                  color: lora.enabled
                      ? const Color(0xDDFFFFFF)
                      : Colors.white.withValues(alpha: 0.2),
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(
                height: 24,
                child: Row(children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      lora.strength.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 9,
                        color: lora.enabled
                            ? GlassTheme.textSecondary
                            : Colors.white.withValues(alpha: 0.15),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: lora.enabled
                            ? const Color(0xFFFFD60A)
                            : Colors.white.withValues(alpha: 0.08),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.04),
                        thumbColor: lora.enabled
                            ? const Color(0xFFFFD60A)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: lora.strength,
                        min: -2,
                        max: 2,
                        divisions: 80,
                        onChanged: lora.enabled
                            ? (v) {
                          lora.strength = v;
                          onChanged();
                        }
                            : null,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
