import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'services.dart';
import 'glass_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animCtrl.forward();
  }

  void _copySeed() {
    if (widget.info != null) {
      Clipboard.setData(ClipboardData(text: widget.info!.seed.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сид ${widget.info!.seed} скопирован'),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareImage(Uint8List imageBytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/comfyui_share_${DateTime.now().millisecondsSinceEpoch}.png');
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
                        style: const TextStyle(fontSize: 12))),
              ],
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
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
      return _buildCompareView();
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  borderColor: Colors.purple.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),

                      // Page indicator dots
                      if (widget.images.length > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(widget.images.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: i == _currentPage ? 16 : 6,
                              height: 6,
                              margin:
                              const EdgeInsets.symmetric(horizontal: 2),
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
                        Text('1 / 1',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),

                      const Spacer(),

                      // Action buttons
                      if (widget.images.length > 1)
                        _actionBtn(Icons.compare, 'Сравнить', () {
                          setState(() {
                            _compareMode = true;
                            _compareIndex = _currentPage == 0 ? 1 : 0;
                          });
                        }),
                      if (widget.onRepeat != null)
                        _actionBtn(Icons.replay, 'Повторить', () {
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    borderColor: Colors.amber.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        // Seed
                        GestureDetector(
                          onTap: _copySeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                  Colors.amber.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.info!.seed}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy,
                                    size: 12,
                                    color:
                                    Colors.amber.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Time
                        Icon(Icons.timer,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(widget.generationTime,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[400])),
                        const SizedBox(width: 12),
                        // Date
                        Icon(Icons.calendar_today,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.info!.date}  ${widget.info!.time}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
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
                              pageBuilder: (_, anim, secondaryAnimation) => FadeTransition(
                                opacity: anim,
                                child: _FullScreenImage(
                                    image: widget.images[index]),
                              ),
                              transitionDuration:
                              const Duration(milliseconds: 300),
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
                                child: Image.memory(
                                  widget.images[index],
                                  fit: BoxFit.contain,
                                ),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                          setState(() {
                            _compareMode = true;
                            _compareIndex = _currentPage == 0 ? 1 : 0;
                          });
                        }),
                      ],
                      if (widget.onRepeat != null) ...[
                        _divider(),
                        _bottomAction(Icons.replay, 'Ещё раз', () {
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
          Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 10)),
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

  // ── Compare view ──
  Widget _buildCompareView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: GlassTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              GlassTheme.card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                borderColor: Colors.purple.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () =>
                          setState(() => _compareMode = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Text('Сравнение',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    _compareSelector('Л:', _currentPage, (v) {
                      if (v != null) setState(() => _currentPage = v);
                    }),
                    const SizedBox(width: 8),
                    _compareSelector('П:', _compareIndex!, (v) {
                      if (v != null) setState(() => _compareIndex = v);
                    }),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.memory(
                                widget.images[_currentPage],
                                fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.memory(
                                widget.images[_compareIndex!],
                                fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compareSelector(
      String label, int value, ValueChanged<int?> onChanged) {
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
          Text(label,
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          DropdownButton<int>(
            value: value,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(fontSize: 12, color: Colors.white),
            underline: const SizedBox(),
            isDense: true,
            items: List.generate(
              widget.images.length,
                  (i) => DropdownMenuItem(
                  value: i, child: Text('${i + 1}')),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }
}

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
          child: Center(
            child: Image.memory(image, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
