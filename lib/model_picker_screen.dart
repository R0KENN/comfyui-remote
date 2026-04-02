import 'package:flutter/material.dart';
import 'services.dart';
import 'glass_theme.dart';

class ModelPickerScreen extends StatefulWidget {
  final ComfyUIService service;
  const ModelPickerScreen({super.key, required this.service});

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<String> _checkpoints = [];
  List<String> _loras = [];
  List<String> _vaes = [];
  List<String> _samplers = [];
  List<String> _schedulers = [];

  String _searchQuery = '';
  int _selectedTab = 0;

  late AnimationController _animCtrl;
  final _searchCtrl = TextEditingController();

  static const _tabs = ['Checkpoints', 'LoRA', 'VAE', 'Samplers', 'Schedulers'];
  static const _tabIcons = [
    Icons.model_training,
    Icons.layers_rounded,
    Icons.color_lens_rounded,
    Icons.tune_rounded,
    Icons.schedule_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.service.getCheckpoints(),
        widget.service.getServerLoras(),
        widget.service.getVaeModels(),
        widget.service.getSamplers(),
        widget.service.getSchedulers(),
      ]);
      if (mounted) {
        setState(() {
          _checkpoints = results[0];
          _loras = results[1];
          _vaes = results[2];
          _samplers = results[3];
          _schedulers = results[4];
          _loading = false;
        });
        _animCtrl.forward(from: 0);
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

  List<String> get _currentList {
    switch (_selectedTab) {
      case 0: return _checkpoints;
      case 1: return _loras;
      case 2: return _vaes;
      case 3: return _samplers;
      case 4: return _schedulers;
      default: return [];
    }
  }

  List<String> get _filteredList {
    final list = _currentList;
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((s) => s.toLowerCase().contains(q)).toList();
  }

  Color _tabColor(int index) {
    const colors = [
      Color(0xFFFFD60A),
      Color(0xFF5AC8FA),
      Color(0xFFBF5AF2),
      Color(0xFF30D158),
      Color(0xFFFF9F0A),
    ];
    return colors[index % colors.length];
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.model_training,
                        color: Color(0xFFFFD60A), size: 20),
                    const SizedBox(width: 10),
                    const Text('Модели сервера',
                      style: TextStyle(
                        color: GlassTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        widget.service.clearObjectInfoCache();
                        _loadAll();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x0AFFFFFF)),
                        ),
                        child: Icon(Icons.refresh_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              ),

              // Табы
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _tabs.length,
                  itemBuilder: (_, i) {
                    final isActive = i == _selectedTab;
                    final color = _tabColor(i);
                    final count = [
                      _checkpoints.length,
                      _loras.length,
                      _vaes.length,
                      _samplers.length,
                      _schedulers.length,
                    ][i];
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedTab = i;
                        _searchQuery = '';
                        _searchCtrl.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? color.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? color.withValues(alpha: 0.3)
                                : const Color(0x08FFFFFF),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_tabIcons[i],
                                size: 14,
                                color: isActive
                                    ? color
                                    : GlassTheme.textTertiary),
                            const SizedBox(width: 6),
                            Text(_tabs[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? color
                                    : GlassTheme.textTertiary,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? color.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('$count',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isActive
                                        ? color
                                        : GlassTheme.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Поиск
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111114),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x10FFFFFF)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 13,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Поиск...',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.15),
                          fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.2)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close_rounded,
                            size: 16,
                            color:
                            Colors.white.withValues(alpha: 0.2)),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Список
              Expanded(
                child: _loading
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFFD60A)))
                    : _filteredList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48,
                          color: Colors.white
                              .withValues(alpha: 0.1)),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Ничего не найдено'
                            : 'Нет данных',
                        style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.2),
                            fontSize: 13),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      12, 4, 12, 80),
                  itemCount: _filteredList.length,
                  itemBuilder: (_, i) {
                    final name = _filteredList[i];
                    final color = _tabColor(_selectedTab);
                    return _buildModelItem(name, color, i);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelItem(String name, Color color, int index) {
    // Извлекаем короткое имя (без пути)
    final shortName = name.contains('/') || name.contains('\\')
        ? name.split(RegExp(r'[/\\]')).last
        : name;
    final folder = name.contains('/') || name.contains('\\')
        ? name.substring(0, name.length - shortName.length)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x08FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shortName,
                  style: const TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (folder.isNotEmpty)
                  Text(folder,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.15),
                      fontSize: 10,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text('${index + 1}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.1),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
