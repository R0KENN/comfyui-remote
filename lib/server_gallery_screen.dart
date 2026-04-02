import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'glass_theme.dart';
import 'services.dart';

class ServerGalleryScreen extends StatefulWidget {
  final ComfyUIService service;
  const ServerGalleryScreen({super.key, required this.service});

  @override
  State<ServerGalleryScreen> createState() => _ServerGalleryScreenState();
}

class _ServerGalleryScreenState extends State<ServerGalleryScreen> {
  List<Map<String, dynamic>> _images = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    try {

      // Получаем список файлов через history
      final histResp = await http
          .get(Uri.parse('${widget.service.serverUrl}/history'))
          .timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> allImages = [];

      if (histResp.statusCode == 200) {
        final history = jsonDecode(histResp.body) as Map<String, dynamic>;

        // Собираем все картинки из истории
        final sorted = history.entries.toList();
        sorted.sort((a, b) {
          final aStatus = a.value['status'] as Map? ?? {};
          final bStatus = b.value['status'] as Map? ?? {};
          final aMsgs = aStatus['messages'] as List? ?? [];
          final bMsgs = bStatus['messages'] as List? ?? [];
          double aTs = 0, bTs = 0;
          for (var m in aMsgs) {
            if (m is List && m.length > 1 && m[0] == 'execution_start') {
              aTs = (m[1]['timestamp'] ?? 0).toDouble();
            }
          }
          for (var m in bMsgs) {
            if (m is List && m.length > 1 && m[0] == 'execution_start') {
              bTs = (m[1]['timestamp'] ?? 0).toDouble();
            }
          }
          return bTs.compareTo(aTs);
        });

        for (final entry in sorted.take(50)) {
          final outputs = entry.value['outputs'] as Map? ?? {};
          for (final nodeOut in outputs.values) {
            if (nodeOut is Map && nodeOut['images'] != null) {
              for (final img in nodeOut['images'] as List) {
                final type = img['type'] ?? 'output';
                if (type == 'temp') continue;
                allImages.add({
                  'filename': img['filename'],
                  'subfolder': img['subfolder'] ?? '',
                  'type': type,
                  'promptId': entry.key,
                });
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _images = allImages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  String _imageUrl(Map<String, dynamic> img) {
    final fn = img['filename'];
    final sub = img['subfolder'] ?? '';
    final type = img['type'] ?? 'output';
    return '${widget.service.serverUrl}/view?filename=$fn&subfolder=$sub&type=$type';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: GlassTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // Заголовок
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_outlined,
                        color: Color(0xFF5AC8FA), size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Галерея сервера',
                      style: TextStyle(
                        color: GlassTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    GlassTheme.chip('${_images.length}', const Color(0xFF5AC8FA)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loadImages,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border:
                          Border.all(color: const Color(0x0AFFFFFF)),
                        ),
                        child: Icon(Icons.refresh_rounded,
                            size: 16,
                            color:
                            Colors.white.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              ),

              // Сетка
              Expanded(
                child: _loading
                    ? const Center(
                    child:
                    CircularProgressIndicator(color: Color(0xFF5AC8FA)))
                    : _images.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 48,
                          color:
                          Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 12),
                      Text('Нет изображений на сервере',
                          style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.2),
                              fontSize: 13)),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _loadImages,
                  color: const Color(0xFF5AC8FA),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (ctx, i) =>
                        _buildThumbnail(_images[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Map<String, dynamic> img) {
    final url = _imageUrl(img);
    return GestureDetector(
      onTap: () => _showFullImage(img),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x10FFFFFF)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            headers: const {},
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.white.withValues(alpha: 0.02),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Color(0xFF5AC8FA)),
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              color: Colors.white.withValues(alpha: 0.02),
              child: Icon(Icons.broken_image_outlined,
                  size: 20, color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(Map<String, dynamic> img) {
    final url = _imageUrl(img);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Картинка
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF5AC8FA)),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Имя файла
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111114),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x10FFFFFF)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      img['filename'] ?? '',
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded,
                        color: GlassTheme.textTertiary, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
