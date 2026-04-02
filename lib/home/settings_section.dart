import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../glass_theme.dart';
import 'home_state.dart';

class SettingsSection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final int width;
  final int height;
  final ValueChanged<int> onWidthChanged;
  final ValueChanged<int> onHeightChanged;
  final TextEditingController seedCtrl;
  final bool serverOnline;
  final Uint8List? img2imgBytes;
  final String? img2imgName;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  const SettingsSection({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.width,
    required this.height,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.seedCtrl,
    required this.serverOnline,
    this.img2imgBytes,
    this.img2imgName,
    required this.onPickImage,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    final currentPreset = HomeStateMixin.resPresets
        .indexWhere((p) => p['w'] == width && p['h'] == height);

    return GlassTheme.card(
      padding: EdgeInsets.zero,
      child: Column(children: [
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
                width: 3, height: 18,
                decoration: BoxDecoration(
                  color: GlassTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Настройки',
                  style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14,
                    color: GlassTheme.textSecondary, letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: serverOnline ? const Color(0xFF30D158) : const Color(0xFFFF3B30),
                  boxShadow: [
                    BoxShadow(
                      color: (serverOnline ? const Color(0xFF30D158) : const Color(0xFFFF3B30))
                          .withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (img2imgBytes != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GlassTheme.chip('IMG2IMG', const Color(0xFF5AC8FA), icon: Icons.image_outlined),
                ),
              if (currentPreset >= 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GlassTheme.chip(
                    '${HomeStateMixin.resPresets[currentPreset]['label']}',
                    GlassTheme.textSecondary,
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
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSeedField(),
                const SizedBox(height: 16),
                _buildResolutionPresets(currentPreset),
                const SizedBox(height: 14),
                _buildCustomSliders(),
                const SizedBox(height: 14),
                _buildImg2ImgSection(),
              ],
            ),
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ]),
    );
  }

  Widget _buildSeedField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: seedCtrl,
            style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, letterSpacing: -0.2),
            keyboardType: TextInputType.number,
            decoration: GlassTheme.glassInput(
              label: 'Сид (-1 = случайный)', hint: '1234567890',
              accentColor: GlassTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => seedCtrl.text = Random().nextInt(2147483647).toString(),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD60A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD60A).withValues(alpha: 0.15), width: 0.5),
            ),
            child: const Icon(Icons.casino_rounded, size: 18, color: Color(0xFFFFD60A)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => seedCtrl.text = '-1',
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0AFFFFFF), width: 0.5),
            ),
            child: Icon(Icons.shuffle_rounded, size: 18, color: GlassTheme.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionPresets(int currentPreset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Разрешение',
                style: TextStyle(fontSize: 12, color: GlassTheme.textTertiary, letterSpacing: -0.2)),
            const Spacer(),
            Text('$width × $height',
                style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500, letterSpacing: -0.2)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: HomeStateMixin.resPresets.asMap().entries.map((e) {
            final p = e.value;
            final active = p['w'] == width && p['h'] == height;
            return GestureDetector(
              onTap: () { onWidthChanged(p['w'] as int); onHeightChanged(p['h'] as int); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? const Color(0x30FFFFFF) : const Color(0x0AFFFFFF), width: 0.5,
                  ),
                  boxShadow: active ? [BoxShadow(color: Colors.white.withValues(alpha: 0.03), blurRadius: 8)] : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p['icon'] as IconData, size: 16,
                        color: active ? const Color(0xFFF0F0F0) : GlassTheme.textTertiary),
                    const SizedBox(height: 3),
                    Text(p['label'] as String,
                        style: TextStyle(fontSize: 10,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                            color: active ? const Color(0xFFF0F0F0) : GlassTheme.textTertiary, letterSpacing: -0.2)),
                    Text('${p['w']}×${p['h']}',
                        style: TextStyle(fontSize: 8,
                            color: active ? GlassTheme.textSecondary : const Color(0xFF3A3A3E), letterSpacing: -0.2)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomSliders() {
    return GlassTheme.miniCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ручная настройка',
              style: TextStyle(fontSize: 11, color: GlassTheme.textTertiary, letterSpacing: -0.2)),
          const SizedBox(height: 8),
          _buildSliderRow('W', width, onWidthChanged),
          const SizedBox(height: 2),
          _buildSliderRow('H', height, onHeightChanged),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 14, child: Text(label, style: const TextStyle(fontSize: 10, color: GlassTheme.textTertiary))),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 2,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Color(0xFFF0F0F0),
              inactiveTrackColor: Color(0x0AFFFFFF),
              thumbColor: Color(0xFFF0F0F0),
            ),
            child: Slider(
              value: value.toDouble(), min: 256, max: 2048, divisions: 28,
              label: '$value', onChanged: (v) => onChanged((v ~/ 64) * 64),
            ),
          ),
        ),
        SizedBox(width: 38, child: Text('$value',
            style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildImg2ImgSection() {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onPickImage,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(
                    color: img2imgBytes != null ? const Color(0xFF5AC8FA).withValues(alpha: 0.3) : const Color(0x0AFFFFFF),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(img2imgBytes != null ? Icons.swap_horiz_rounded : Icons.add_photo_alternate_outlined,
                        size: 16, color: img2imgBytes != null ? const Color(0xFF5AC8FA) : GlassTheme.textTertiary),
                    const SizedBox(width: 8),
                    Text(img2imgBytes != null ? 'Заменить фото' : 'img2img: выбрать фото',
                        style: TextStyle(fontSize: 12,
                            color: img2imgBytes != null ? const Color(0xFF5AC8FA) : GlassTheme.textTertiary, letterSpacing: -0.2)),
                  ],
                ),
              ),
            ),
          ),
          if (img2imgBytes != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClearImage,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.15), width: 0.5),
                ),
                child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFFF3B30)),
              ),
            ),
          ],
        ]),
        if (img2imgBytes != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(img2imgBytes!, height: 120, width: double.infinity, fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }
}
