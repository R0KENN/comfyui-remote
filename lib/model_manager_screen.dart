// lib/model_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services.dart';
import 'glass_theme.dart';

class ModelManagerScreen extends StatefulWidget {
  final ComfyUIService service;
  const ModelManagerScreen({super.key, required this.service});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String _search = '';

  List<String> _checkpoints = [];
  List<String> _loras = [];
  List<String> _vaes = [];
  List<String> _samplers = [];
  List<String> _schedulers = [];

  static const _tabs = ['Checkpoints', 'LoRA', 'VAE', 'Samplers', 'Schedulers'];
  static const _icons = [
    Icons.memory, Icons.extension, Icons.palette,
    Icons.tune, Icons.schedule,
  ];
  static const _colors = [
    Color(0xFF0A84FF), Color(0xFFFFD60A), Color(0xFFBF5AF2),
    Color(0xFF30D158), Color(0xFFFF9F0A),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.service.getCheckpoints(),
        widget.service.getLoras(),
        widget.service.getVAEs(),
        widget.service.getSamplers(),
        widget.service.getSchedulers(),
      ]);
      setState(() {
        _checkpoints = results[0];
        _loras = results[1];
        _vaes = results[2];
        _samplers = results[3];
        _schedulers = results[4];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    widget.service.clearObjectInfoCache();
    await _loadAll();
  }

  List<String> get _currentList {
    switch (_tabController.index) {
      case 0: return _checkpoints;
      case 1: return _loras;
      case 2: return _vaes;
      case 3: return _samplers;
      case 4: return _schedulers;
      default: return [];
    }
  }

  List<String> get _filteredList {
    if (_search.isEmpty) return _currentList;
    final q = _search.toLowerCase();
    return _currentList.where((m) => m.toLowerCase().contains(q)).toList();
  }

  List<int> get _counts => [
    _checkpoints.length, _loras.length, _vaes.length,
    _samplers.length, _schedulers.length,
  ];

  String _shortName(String full) {
    final parts = full.replaceAll('\\', '/').split('/');
    return parts.last;
  }

  String? _folderPath(String full) {
    final parts = full.replaceAll('\\', '/').split('/');
    if (parts.length <= 1) return null;
    return parts.sublist(0, parts.length - 1).join('/');
  }

  void _onItemTap(String name, int tabIndex) {
    if (tabIndex == 0) {
      // Checkpoint → apply to workflow
      widget.service.setCheckpoint(name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkpoint: ${_shortName(name)}')),
      );
    } else if (tabIndex == 2) {
      // VAE → apply to workflow
      widget.service.setVAE(name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VAE: ${_shortName(name)}')),
      );
    } else {
      // Others → copy to clipboard
      Clipboard.setData(ClipboardData(text: name));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Скопировано: ${_shortName(name)}')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassTheme.appBar('Модели', actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: GlassTheme.textSecondary),
          onPressed: _refresh,
        ),
      ]),
      body: Container(
        decoration: GlassTheme.scaffoldGradient,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Tab bar
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _tabs.length,
                  itemBuilder: (ctx, i) {
                    final active = _tabController.index == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _tabController.index = i;
                          _search = '';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active
                                ? _colors[i].withOpacity(0.2)
                                : GlassTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? _colors[i].withOpacity(0.5)
                                  : GlassTheme.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_icons[i], size: 16,
                                  color: active ? _colors[i] : GlassTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '${_tabs[i]} ${_loading ? '' : '(${_counts[i]})'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: active ? _colors[i] : GlassTheme.textSecondary,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14),
                  decoration: GlassTheme.glassInput('Поиск...', icon: Icons.search),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 8),
              // List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredList.isEmpty
                    ? Center(
                  child: Text('Ничего не найдено',
                      style: TextStyle(color: GlassTheme.textSecondary)),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (ctx, i) {
                    final name = _filteredList[i];
                    final folder = _folderPath(name);
                    final tabIdx = _tabController.index;
                    return GestureDetector(
                      onTap: () => _onItemTap(name, tabIdx),
                      child: GlassTheme.miniCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: _colors[tabIdx].withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          color: _colors[tabIdx], fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_shortName(name),
                                      style: const TextStyle(
                                          color: GlassTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (folder != null)
                                      Text(folder,
                                        style: TextStyle(
                                            color: GlassTheme.textSecondary,
                                            fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                tabIdx == 0 || tabIdx == 2
                                    ? Icons.check_circle_outline
                                    : Icons.copy,
                                size: 18,
                                color: GlassTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
