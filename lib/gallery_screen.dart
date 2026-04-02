// lib/gallery_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'services.dart';
import 'glass_theme.dart';
import 'seed_storage.dart';

class GenerationInfo {
  final int seed;
  final String time;
  final String date;

  GenerationInfo({
    required this.seed,
    required this.time,
    required this.date,
  });
}

class GalleryScreen extends StatefulWidget {
  final List<Uint8List> images;
  final String generationTime;
  final VoidCallback? onRepeat;
  final GenerationInfo? info;

  const GalleryScreen({
    super.key,
    required this.images,
    required this.generationTime,
    this.onRepeat,
    this.info,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  int _currentPage = 0;
  bool _compareMode = false;
  int? _compareIndex;
  late AnimationController _animCtrl;
  bool _seedSaved = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animCtrl.forward();
    _checkSeedSaved();
  }

  Future<void> _checkSeedSaved() async {
    if (widget.info == null) return;
    final seeds = await SeedStorage.load();
    if (mounted) {
      setState(() {
        _seedSaved = seeds.any((s) => s.seed == widget.info!.seed);
      });
    }
  }

  void _copySeed() {
    if (widget.info != null) {
      Clipboard.setData(ClipboardData(text: widget.info!.seed.toString()));
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сид ${widget.info!.seed} скопирован'),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _saveSeed() async {
    if (widget.info == null) return;
    HapticFeedback.mediumImpact();
    await SeedStorage.add(SavedSeed(
      seed: widget.info!.seed,
      date: widget.info!.date,
      time: widget.info!.time,
      promptPreview: '',
      generationTime: widget.generationTime,
    ));
    setState(() => _seedSaved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFD60A), size: 16),
              const SizedBox(width: 8),
              Text('Сид ${widget.info!.seed} сохранён в избранное'),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareImage(Uint8List imageBytes) async {
    HapticFeedback.lightImpact();
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/comfyui_share.png');
      await file.writeAsBytes(imageBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'ComfyGo');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _saveImage(Uint8List imageBytes) async {
    HapticFeedback.mediumImpact();
    try {
      final path = await ComfyUIService.saveImage(imageBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Сохранено: $path',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_compareMode && _compareIndex != null && widget.images.length > 1) {
      return _DragCompareView(
        imageA: widget.images[_currentPage],
        imageB: widget.images[_compareIndex!],
        labelA: 'Изображение ${_currentPage + 1}',
        labelB: 'Изображение ${_compareIndex! + 1}',
        onClose: () => setState(() => _compareMode = false),
        imageCount: widget.images.length,
        indexA: _currentPage,
        indexB: _compareIndex!,
        onChangeA: (v) { if (v != null) setState(() => _currentPage = v); },
        onChangeB: (v) { if (v != null) setState(() => _compareIndex = v); },
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: GlassTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ──
              FadeTransition(
                opacity: _animCtrl,
                child: GlassTheme.card(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  borderColor: Colors.purple.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      if (widget.images.length > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(widget.images.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: i == _currentPage ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i == _currentPage
                                    ? Colors.amber
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            );
                          }),
                        )
                      else
                        Text('1 / 1', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      const Spacer(),
                      if (widget.images.length > 1)
                        _actionBtn(Icons.compare, 'Сравнить', () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _compareMode = true;
                            _compareIndex = _currentPage == 0 ? 1 : 0;
                          });
                        }),
                      if (widget.onRepeat != null)
                        _actionBtn(Icons.replay, 'Повторить', () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          widget.onRepeat!();
                        }),
                      _actionBtn(Icons.share, 'Поделиться',
                              () => _shareImage(widget.images[_currentPage])),
                      _actionBtn(Icons.save_alt, 'Сохранить',
                              () => _saveImage(widget.images[_currentPage])),
                    ],
                  ),
                ),
              ),

              // ── Info card ──
              if (widget.info != null)
                GlassTheme.fadeSlideIn(
                  index: 0,
                  controller: _animCtrl,
                  child: GlassTheme.card(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    borderColor: Colors.amber.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        // Seed
                        GestureDetector(
                          onTap: _copySeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text('${widget.info!.seed}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.amber, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                Icon(Icons.copy, size: 12, color: Colors.amber.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Кнопка сохранить сид
                        GestureDetector(
                          onTap: _seedSaved ? null : _saveSeed,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _seedSaved
                                  ? const Color(0xFFFFD60A).withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _seedSaved
                                    ? const Color(0xFFFFD60A).withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Icon(
                              _seedSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 18,
                              color: _seedSaved
                                  ? const Color(0xFFFFD60A)
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.timer, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(widget.generationTime,
                            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        const SizedBox(width: 12),
                        Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('${widget.info!.date}  ${widget.info!.time}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                ),

              // ── Image viewer ──
              Expanded(
                child: GlassTheme.fadeSlideIn(
                  index: 1,
                  controller: _animCtrl,
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, anim, __) => FadeTransition(
                                opacity: anim,
                                child: _FullScreenImage(image: widget.images[index]),
                              ),
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(widget.images[index], fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Bottom actions ──
              GlassTheme.fadeSlideIn(
                index: 2,
                controller: _animCtrl,
                child: GlassTheme.card(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderColor: Colors.white.withValues(alpha: 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bottomAction(Icons.share, 'Поделиться',
                              () => _shareImage(widget.images[_currentPage])),
                      _divider(),
                      _bottomAction(Icons.save_alt, 'Сохранить',
                              () => _saveImage(widget.images[_currentPage])),
                      if (widget.images.length > 1) ...[
                        _divider(),
                        _bottomAction(Icons.compare, 'Сравнить', () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _compareMode = true;
                            _compareIndex = _currentPage == 0 ? 1 : 0;
                          });
                        }),
                      ],
                      if (widget.onRepeat != null) ...[
                        _divider(),
                        _bottomAction(Icons.replay, 'Ещё раз', () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          widget.onRepeat!();
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════
//  DRAG-TO-COMPARE — перетаскиваемый разделитель
// ══════════════════════════════════════════════════════

class _DragCompareView extends StatefulWidget {
  final Uint8List imageA;
  final Uint8List imageB;
  final String labelA;
  final String labelB;
  final VoidCallback onClose;
  final int imageCount;
  final int indexA;
  final int indexB;
  final ValueChanged<int?> onChangeA;
  final ValueChanged<int?> onChangeB;

  const _DragCompareView({
    required this.imageA,
    required this.imageB,
    required this.labelA,
    required this.labelB,
    required this.onClose,
    required this.imageCount,
    required this.indexA,
    required this.indexB,
    required this.onChangeA,
    required this.onChangeB,
  });

  @override
  State<_DragCompareView> createState() => _DragCompareViewState();
}

class _DragCompareViewState extends State<_DragCompareView> {
  double _dividerX = 0.5; // 0.0 — 1.0
  bool _vertical = true;  // true = вертикальный разделитель (лево-право)
  double _dividerY = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: GlassTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── Toolbar ──
              GlassTheme.card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                borderColor: Colors.purple.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Text('Сравнение',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    // Переключатель vert / horiz
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _vertical = !_vertical);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _vertical ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _compareSelector('Л:', widget.indexA, widget.onChangeA),
                    const SizedBox(width: 6),
                    _compareSelector('П:', widget.indexB, widget.onChangeB),
                  ],
                ),
              ),

              // ── Compare area ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;

                      return GestureDetector(
                        onHorizontalDragUpdate: _vertical
                            ? (details) {
                          setState(() {
                            _dividerX = (_dividerX + details.delta.dx / w)
                                .clamp(0.05, 0.95);
                          });
                        }
                            : null,
                        onVerticalDragUpdate: !_vertical
                            ? (details) {
                          setState(() {
                            _dividerY = (_dividerY + details.delta.dy / h)
                                .clamp(0.05, 0.95);
                          });
                        }
                            : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              // Полное изображение B (фон)
                              Positioned.fill(
                                child: Image.memory(widget.imageB, fit: BoxFit.contain),
                              ),
                              // Изображение A обрезано
                              Positioned.fill(
                                child: ClipRect(
                                  clipper: _vertical
                                      ? _VerticalClipper(_dividerX)
                                      : _HorizontalClipper(_dividerY),
                                  child: Image.memory(widget.imageA, fit: BoxFit.contain),
                                ),
                              ),
                              // Разделитель
                              if (_vertical)
                                Positioned(
                                  left: w * _dividerX - 1,
                                  top: 0,
                                  bottom: 0,
                                  child: _buildDividerLine(true),
                                )
                              else
                                Positioned(
                                  top: h * _dividerY - 1,
                                  left: 0,
                                  right: 0,
                                  child: _buildDividerLine(false),
                                ),
                              // Ручка разделителя
                              if (_vertical)
                                Positioned(
                                  left: w * _dividerX - 18,
                                  top: h / 2 - 18,
                                  child: _buildHandle(true),
                                )
                              else
                                Positioned(
                                  left: w / 2 - 18,
                                  top: h * _dividerY - 18,
                                  child: _buildHandle(false),
                                ),
                              // Лейблы
                              Positioned(
                                left: 8,
                                top: 8,
                                child: _labelBadge(widget.labelA),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: _labelBadge(widget.labelB),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDividerLine(bool vertical) {
    return Container(
      width: vertical ? 2 : double.infinity,
      height: vertical ? double.infinity : 2,
      color: Colors.white.withValues(alpha: 0.7),
    );
  }

  Widget _buildHandle(bool vertical) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        vertical ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded,
        color: Colors.black87,
        size: 20,
      ),
    );
  }

  Widget _labelBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _compareSelector(String label, int value, ValueChanged<int?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          DropdownButton<int>(
            value: value,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(fontSize: 12, color: Colors.white),
            underline: const SizedBox(),
            isDense: true,
            items: List.generate(
              widget.imageCount,
                  (i) => DropdownMenuItem(value: i, child: Text('${i + 1}')),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// Кастомные клипперы для обрезки изображений
class _VerticalClipper extends CustomClipper<Rect> {
  final double fraction;
  _VerticalClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_VerticalClipper old) => old.fraction != fraction;
}

class _HorizontalClipper extends CustomClipper<Rect> {
  final double fraction;
  _HorizontalClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width, size.height * fraction);

  @override
  bool shouldReclip(_HorizontalClipper old) => old.fraction != fraction;
}

// ══════════════════════════════════════════
//  FULLSCREEN IMAGE
// ══════════════════════════════════════════

class _FullScreenImage extends StatelessWidget {
  final Uint8List image;
  const _FullScreenImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8.0,
          child: Center(child: Image.memory(image, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
