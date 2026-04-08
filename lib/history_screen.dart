import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gallery_screen.dart';
import 'glass_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class HistoryEntry {
  final List<String> imagePaths;
  final int seed;
  final String date;
  final String time;
  final String generationTime;
  final String promptPreview;
  bool isFavorite;

  HistoryEntry({
    required this.imagePaths,
    required this.seed,
    required this.date,
    required this.time,
    required this.generationTime,
    required this.promptPreview,
    this.isFavorite = false,
  });

  Future<List<Uint8List>> loadImages() async {
    final List<Uint8List> result = [];
    for (final path in imagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          result.add(await file.readAsBytes());
        }
      } catch (_) {}
    }
    return result;
  }

  Future<Uint8List?> loadThumbnail() async {
    if (imagePaths.isEmpty) return null;
    try {
      final file = File(imagePaths.first);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toJson() => {
    'imagePaths': imagePaths,
    'seed': seed,
    'date': date,
    'time': time,
    'genTime': generationTime,
    'prompt': promptPreview,
    'fav': isFavorite,
  };

  static HistoryEntry fromJson(Map<String, dynamic> j) => HistoryEntry(
    imagePaths:
    (j['imagePaths'] as List?)?.map((e) => e.toString()).toList() ?? [],
    seed: j['seed'] ?? 0,
    date: j['date'] ?? '',
    time: j['time'] ?? '',
    generationTime: j['genTime'] ?? '',
    promptPreview: j['prompt'] ?? '',
    isFavorite: j['fav'] == true,
  );

  static Future<HistoryEntry?> fromLegacyJson(Map<String, dynamic> j) async {
    final imagesBase64 = j['images'] as List?;
    if (imagesBase64 == null || imagesBase64.isEmpty) return null;

    final paths = <String>[];
    final dir = await _getHistoryImageDir();

    for (int i = 0; i < imagesBase64.length; i++) {
      try {
        final bytes = base64Decode(imagesBase64[i].toString());
        final ts = DateTime.now().microsecondsSinceEpoch;
        final file = File('${dir.path}/migrated_${ts}_$i.png');
        await file.writeAsBytes(bytes);
        paths.add(file.path);
      } catch (_) {}
    }

    if (paths.isEmpty) return null;

    return HistoryEntry(
      imagePaths: paths,
      seed: j['seed'] ?? 0,
      date: j['date'] ?? '',
      time: j['time'] ?? '',
      generationTime: j['genTime'] ?? '',
      promptPreview: j['prompt'] ?? '',
    );
  }

  static Future<Directory> _getHistoryImageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/history_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

class HistoryStorage {
  static const _key = 'generation_history_v2';
  static const _legacyKey = 'generation_history';
  static const int maxEntries = 50;

  static Future<Directory> getHistoryImageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/history_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<String>> saveImages(List<Uint8List> images) async {
    final dir = await getHistoryImageDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final paths = <String>[];

    for (int i = 0; i < images.length; i++) {
      final file = File('${dir.path}/gen_${ts}_$i.png');
      await file.writeAsBytes(images[i]);
      paths.add(file.path);
    }

    return paths;
  }

  static Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        final entries = <HistoryEntry>[];
        for (var e in list) {
          final entry = HistoryEntry.fromJson(e);
          bool hasFiles = false;
          for (final path in entry.imagePaths) {
            if (await File(path).exists()) {
              hasFiles = true;
              break;
            }
          }
          if (hasFiles) entries.add(entry);
        }
        return entries;
      } catch (_) {}
    }

    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        final list = jsonDecode(legacy) as List;
        final entries = <HistoryEntry>[];
        for (var e in list) {
          final migrated = await HistoryEntry.fromLegacyJson(e);
          if (migrated != null) entries.add(migrated);
        }
        await _saveList(entries);
        await prefs.remove(_legacyKey);
        return entries;
      } catch (_) {}
    }

    return [];
  }

  static Future<void> _saveList(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<void> save(List<HistoryEntry> entries) => _saveList(entries);

  static Future<void> add(HistoryEntry entry) async {
    final list = await load();
    list.insert(0, entry);

    while (list.length > maxEntries) {
      final idx = list.lastIndexWhere((e) => !e.isFavorite);
      if (idx < 0) break; // все избранные — не удаляем
      final old = list.removeAt(idx);
      for (final path in old.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }

    await _saveList(list);
  }

  static Future<void> remove(int index) async {
    final list = await load();
    if (index >= 0 && index < list.length) {
      final entry = list.removeAt(index);
      for (final path in entry.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await _saveList(list);
    }
  }

  static Future<void> clear() async {
    final list = await load();
    for (final entry in list) {
      for (final path in entry.imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
  }
}

// ===================== ЭКРАН ИСТОРИИ =====================

class HistoryScreen extends StatefulWidget {
  final void Function()? onRepeat;

  const HistoryScreen({super.key, this.onRepeat});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  List<HistoryEntry> _entries = [];
  bool _loading = true;
  bool _showFavOnly = false;
  bool _compareMode = false;
  final List<int> _compareSelection = [];
  late AnimationController _animCtrl;

  /// Публичный метод для внешнего обновления
  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await HistoryStorage.load();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  List<HistoryEntry> get _filtered =>
      _showFavOnly ? _entries.where((e) => e.isFavorite).toList() : _entries;

  Future<void> _toggleFavorite(int realIndex) async {
    HapticFeedback.selectionClick();
    setState(() {
      _entries[realIndex].isFavorite = !_entries[realIndex].isFavorite;
    });
    await HistoryStorage.save(_entries);
  }

  Future<void> _deleteEntry(int realIndex) async {
    await HistoryStorage.remove(realIndex);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Очистить всё?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Все записи истории будут удалены.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      HapticFeedback.heavyImpact();
      await HistoryStorage.clear();
      await _load();
    }
  }

  void _toggleCompareMode() {
    setState(() {
      _compareMode = !_compareMode;
      _compareSelection.clear();
    });
  }

  Future<void> _openCompare() async {
    if (_compareSelection.length != 2) return;
    final filtered = _filtered;
    final a = filtered[_compareSelection[0]];
    final b = filtered[_compareSelection[1]];

    final imagesA = await a.loadImages();
    final imagesB = await b.loadImages();

    if (imagesA.isEmpty || imagesB.isEmpty || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CompareScreen(
          imageA: imagesA.first,
          imageB: imagesB.first,
          infoA: '${a.date} ${a.time} • Seed: ${a.seed}',
          infoB: '${b.date} ${b.time} • Seed: ${b.seed}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final favCount = _entries.where((e) => e.isFavorite).length;

    return Container(
      decoration: GlassTheme.scaffoldDecoration,
      child: Column(
        children: [
          GlassTheme.card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderColor: Colors.purple.withValues(alpha: 0.2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history,
                      color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('История',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(width: 8),
                GlassTheme.chip('${_entries.length}', Colors.purple),
                const Spacer(),
                if (favCount > 0)
                  GestureDetector(
                    onTap: () => setState(() => _showFavOnly = !_showFavOnly),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _showFavOnly
                            ? const Color(0xFFFFD60A).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _showFavOnly
                              ? const Color(0xFFFFD60A).withValues(alpha: 0.3)
                              : const Color(0x0AFFFFFF),
                        ),
                      ),
                      child: Icon(
                        _showFavOnly
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: _showFavOnly
                            ? const Color(0xFFFFD60A)
                            : GlassTheme.textTertiary,
                      ),
                    ),
                  ),
                if (_entries.length >= 2)
                  GestureDetector(
                    onTap: _toggleCompareMode,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _compareMode
                            ? const Color(0xFF5AC8FA).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _compareMode
                              ? const Color(0xFF5AC8FA).withValues(alpha: 0.3)
                              : const Color(0x0AFFFFFF),
                        ),
                      ),
                      child: Icon(Icons.compare_rounded,
                          size: 18,
                          color: _compareMode
                              ? const Color(0xFF5AC8FA)
                              : GlassTheme.textTertiary),
                    ),
                  ),
                if (_entries.isNotEmpty && !_compareMode)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.delete_sweep,
                          size: 18, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          if (_compareMode)
            GlassTheme.card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderColor: const Color(0xFF5AC8FA).withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.compare_rounded,
                      size: 16, color: Color(0xFF5AC8FA)),
                  const SizedBox(width: 8),
                  Text(
                    _compareSelection.isEmpty
                        ? 'Выберите 2 генерации для сравнения'
                        : 'Выбрано: ${_compareSelection.length}/2',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5AC8FA),
                        letterSpacing: -0.2),
                  ),
                  const Spacer(),
                  if (_compareSelection.length == 2)
                    GestureDetector(
                      onTap: _openCompare,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFF5AC8FA).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF5AC8FA)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Text('Сравнить',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5AC8FA),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleCompareMode,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF5AC8FA)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: Colors.amber))
                : filtered.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _showFavOnly
                          ? Icons.star_outline_rounded
                          : Icons.photo_library,
                      size: 56,
                      color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  Text(
                      _showFavOnly
                          ? 'Нет избранных'
                          : 'Пусто',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                      _showFavOnly
                          ? 'Добавьте генерации в избранное'
                          : 'Генерации появятся здесь',
                      style: TextStyle(
                          color: Colors.grey[700], fontSize: 12)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _load,
              color: Colors.amber,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 4, 12, 80),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final realIndex = _entries.indexOf(entry);
                  final isSelected =
                  _compareSelection.contains(index);

                  return GlassTheme.fadeSlideIn(
                    index: index,
                    controller: _animCtrl,
                    child: _HistoryCard(
                      entry: entry,
                      index: realIndex,
                      compareMode: _compareMode,
                      isSelected: isSelected,
                      onTapCompare: () {
                        setState(() {
                          if (isSelected) {
                            _compareSelection.remove(index);
                          } else if (_compareSelection.length < 2) {
                            _compareSelection.add(index);
                          }
                        });
                      },
                      onDelete: () => _deleteEntry(realIndex),
                      onRepeat: widget.onRepeat,
                      onToggleFav: () =>
                          _toggleFavorite(realIndex),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== КАРТОЧКА ИСТОРИИ =====================

class _HistoryCard extends StatefulWidget {
  final HistoryEntry entry;
  final int index;
  final bool compareMode;
  final bool isSelected;
  final VoidCallback onTapCompare;
  final VoidCallback onDelete;
  final VoidCallback? onRepeat;
  final VoidCallback onToggleFav;

  const _HistoryCard({
    required this.entry,
    required this.index,
    required this.compareMode,
    required this.isSelected,
    required this.onTapCompare,
    required this.onDelete,
    this.onRepeat,
    required this.onToggleFav,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  Uint8List? _thumbnail;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final thumb = await widget.entry.loadThumbnail();
    if (mounted) {
      setState(() {
        _thumbnail = thumb;
        _loaded = true;
      });
    }
  }

  Future<void> _shareFirstImage() async {
    final images = await widget.entry.loadImages();
    if (images.isEmpty || !mounted) return;
    HapticFeedback.lightImpact();
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/comfyui_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(images.first);
      await Share.shareXFiles([XFile(file.path)], text: 'ComfyGo');
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
    final entry = widget.entry;

    return GlassTheme.card(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      borderColor: widget.isSelected
          ? const Color(0xFF5AC8FA).withValues(alpha: 0.4)
          : entry.isFavorite
          ? const Color(0xFFFFD60A).withValues(alpha: 0.15)
          : Colors.purple.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.compareMode
            ? widget.onTapCompare
            : () async {
          final images = await entry.loadImages();
          if (images.isNotEmpty && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GalleryScreen(
                  images: images,
                  generationTime: entry.generationTime,
                  onRepeat: widget.onRepeat,
                  info: GenerationInfo(
                    seed: entry.seed,
                    time: entry.time,
                    date: entry.date,
                  ),
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (widget.compareMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isSelected
                          ? const Color(0xFF5AC8FA)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF5AC8FA)
                            : const Color(0x20FFFFFF),
                      ),
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              Hero(
                tag: 'history_thumb_${widget.index}',
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _thumbnail != null
                        ? Image.memory(_thumbnail!,
                        width: 72, height: 72, fit: BoxFit.cover)
                        : Container(
                      color: const Color(0xFF1A1A1A),
                      child: _loaded
                          ? const Icon(Icons.broken_image,
                          color: Color(0x33FFFFFF), size: 28)
                          : const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0x33FFFFFF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tag,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${entry.seed}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (entry.imagePaths.length > 1)
                          GlassTheme.chip(
                            '${entry.imagePaths.length} фото',
                            Colors.blue,
                            icon: Icons.photo_library,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 11, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text('${entry.date}  ${entry.time}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500])),
                        const SizedBox(width: 10),
                        Icon(Icons.timer,
                            size: 11, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        Text(entry.generationTime,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.promptPreview,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!widget.compareMode)
                Column(
                  children: [
                    GestureDetector(
                      onTap: widget.onToggleFav,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: entry.isFavorite
                              ? const Color(0xFFFFD60A)
                              .withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          entry.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 16,
                          color: entry.isFavorite
                              ? const Color(0xFFFFD60A)
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _shareFirstImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.share_rounded,
                            size: 14,
                            color: Colors.blue.withValues(alpha: 0.6)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close,
                            size: 14,
                            color: Colors.red.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== ЭКРАН СРАВНЕНИЯ =====================

class _CompareScreen extends StatelessWidget {
  final Uint8List imageA;
  final Uint8List imageB;
  final String infoA;
  final String infoB;

  const _CompareScreen({
    required this.imageA,
    required this.imageB,
    required this.infoA,
    required this.infoB,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Сравнение',
            style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme:
        const IconThemeData(color: GlassTheme.textSecondary),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Column(
                children: [
                  Text(infoA,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.memory(imageA, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Column(
                children: [
                  Text(infoB,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.memory(imageB, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
