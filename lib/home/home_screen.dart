import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services.dart';
import '../history_screen.dart';
import '../monitor_screen.dart';
import '../logs_screen.dart';
import '../glass_theme.dart';
import '../workflow_manager.dart';
import '../fullscreen_editor.dart';
import '../background_service.dart';
import 'home_state.dart';
import 'generation_controller.dart';
import 'settings_section.dart';
import 'prompt_section.dart';
import 'loras_section.dart';
import 'bottom_bar.dart';
import 'bottom_nav.dart';
import 'ai_prompt_dialog.dart';
import '../server_gallery_screen.dart';
import '../model_picker_screen.dart';

class _SectionConfig {
  final String key;
  final String title;
  final Color color;
  final TextEditingController Function(_HomeScreenState s) posCtrl;
  final TextEditingController Function(_HomeScreenState s) negCtrl;
  final int posLines;
  final int negLines;
  final String posHint;

  const _SectionConfig({
    required this.key,
    required this.title,
    required this.color,
    required this.posCtrl,
    required this.negCtrl,
    this.posLines = 5,
    this.negLines = 3,
    this.posHint = '',
  });
}

final List<_SectionConfig> _sectionConfigs = [
  _SectionConfig(
    key: 'zimage',
    title: 'Z-Image Base',
    color: const Color(0xFF5AC8FA),
    posCtrl: (s) => s.zimageBaseCtrl,
    negCtrl: (s) => s.zimageNegCtrl,
    posLines: 6,
    negLines: 3,
    posHint: 'Основной промпт сцены',
  ),
  _SectionConfig(
    key: 'pony',
    title: 'Pony',
    color: const Color(0xFFFF6482),
    posCtrl: (s) => s.ponyPosCtrl,
    negCtrl: (s) => s.ponyNegCtrl,
    posHint: 'Стилистика Pony',
  ),
  _SectionConfig(
    key: 'handfix',
    title: 'HandFix',
    color: const Color(0xFFFF9F0A),
    posCtrl: (s) => s.handFixPosCtrl,
    negCtrl: (s) => s.handFixNegCtrl,
    posHint: 'Промпт для фикса рук',
  ),
  _SectionConfig(
    key: 'refiner',
    title: 'Refiner',
    color: const Color(0xFF64D2FF),
    posCtrl: (s) => s.refinerCtrl,
    negCtrl: (s) => s.refinerNegCtrl,
    posHint: 'Промпт рефайнера',
  ),
  _SectionConfig(
    key: 'face',
    title: 'FaceDetailer',
    color: const Color(0xFFBF5AF2),
    posCtrl: (s) => s.facePosCtrl,
    negCtrl: (s) => s.faceNegCtrl,
    posHint: 'Промпт для лица',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver,
        HomeStateMixin<HomeScreen>, GenerationControllerMixin<HomeScreen> {

  StreamSubscription? _bgSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    serverCtrl.text = prefs.getString('server_url') ?? '';
    macCtrl.text = prefs.getString('mac_address') ?? '';

    setState(() {
      width = prefs.getInt('gen_width') ?? 1024;
      height = prefs.getInt('gen_height') ?? 1024;
      seedCtrl.text = prefs.getString('seed') ?? '-1';
      geminiApiKey = prefs.getString('gemini_api_key') ?? '';
    });

    zimageBaseCtrl.text = prefs.getString('zimage_base') ?? '';
    zimageNegCtrl.text = prefs.getString('zimage_neg') ?? '';
    ponyPosCtrl.text = prefs.getString('pony_pos') ?? '';
    ponyNegCtrl.text = prefs.getString('pony_neg') ?? '';
    handFixPosCtrl.text = prefs.getString('handfix_pos') ?? '';
    handFixNegCtrl.text = prefs.getString('handfix_neg') ?? '';
    refinerCtrl.text = prefs.getString('refiner') ?? '';
    refinerNegCtrl.text = prefs.getString('refiner_neg') ?? '';
    facePosCtrl.text = prefs.getString('face_pos') ?? '';
    faceNegCtrl.text = prefs.getString('face_neg') ?? '';

    for (final section in ['zimage', 'pony', 'handfix', 'refiner', 'face']) {
      pinnedNegTags[section] = prefs.getStringList('pinned_neg_$section') ?? [];
    }

    final savedOrder = prefs.getStringList('section_order');
    if (savedOrder != null && savedOrder.length == sectionOrder.length) {
      sectionOrder = savedOrder;
    }

    templates = await TemplateStorage.load();

    final activeWf = await WorkflowManager.getActiveWorkflowPath();
    if (activeWf == 'built_in_2') {
      await service.loadWorkflow2();
      setState(() => activeWorkflowName = 'Z-Image + Pony');
    } else if (activeWf != null) {
      try {
        await service.loadWorkflowFromFile(activeWf);
        setState(() {
          activeWorkflowName = activeWf.split('/').last.replaceAll('.json', '');
        });
      } catch (_) {
        await service.loadWorkflow();
        setState(() => activeWorkflowName = 'Z-Image');
      }
    } else {
      await service.loadWorkflow();
    }


    setState(() {
      loraGroups = service.extractLoraGroups();
      nodeGroups = service.extractNodeGroups();
    });

    if (serverCtrl.text.isNotEmpty) {
      await checkServer();
    }

    // Автосохранение при изменении полей
    _setupAutoSave();


    await _checkPendingBackgroundGeneration();
    _bgSub = BackgroundGenerationService.onComplete.listen((_) {
      _handleBackgroundComplete();
    });
  }

  // ===================== ФОНОВАЯ ГЕНЕРАЦИЯ =====================

  Future<void> _checkPendingBackgroundGeneration() async {
    final pending = await BackgroundGenerationService.getPendingResult();
    if (pending == null) return;
    await _handlePendingGeneration(pending['serverUrl']!, pending['promptId']!);
  }

  Future<void> _handleBackgroundComplete() async {
    final pending = await BackgroundGenerationService.getPendingResult();
    if (pending == null) return;
    await _handlePendingGeneration(pending['serverUrl']!, pending['promptId']!);
  }

  Future<void> _handlePendingGeneration(String serverUrl, String promptId) async {
    try {
      service.serverUrl = serverUrl;
      final images = await service.fetchResults(promptId);
      if (images.isNotEmpty) {
        final imagePaths = await HistoryStorage.saveImages(images);
        final now = DateTime.now();
        final entry = HistoryEntry(
          imagePaths: imagePaths,
          seed: int.tryParse(seedCtrl.text) ?? -1,
          date: '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
          time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          generationTime: 'фон',
          promptPreview: zimageBaseCtrl.text.length > 80
              ? zimageBaseCtrl.text.substring(0, 80)
              : zimageBaseCtrl.text,
        );
        await HistoryStorage.add(entry);

        if (!mounted) return;
        setState(() => currentTab = 3);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фоновая генерация завершена!'), backgroundColor: Color(0xFF30D158)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка фоновой генерации: $e'), backgroundColor: const Color(0xFFFF3B30)),
      );
    }

    if (!mounted) return;  // <── ДОБАВЬ
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_prompt_id');
    await prefs.remove('pending_server_url');
  }

  // ===================== LIFECYCLE =====================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isGenerating) reconnectIfGenerating();
      _checkPendingBackgroundGeneration();
    }
  }

  // ===================== ДЕЙСТВИЯ =====================

  void _copyZimageToRefiner() {
    refinerCtrl.text = zimageBaseCtrl.text;
    refinerNegCtrl.text = zimageNegCtrl.text;
  }

  Future<void> _pickImg2Img() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      img2imgBytes = bytes;
      img2imgName = picked.name;
    });
  }

  // ===================== АВТОСОХРАНЕНИЕ =====================

  final List<TextEditingController> _autoSaveControllers = [];

  void _setupAutoSave() {
    _autoSaveControllers.addAll([
      serverCtrl, macCtrl, seedCtrl,
      zimageBaseCtrl, zimageNegCtrl,
      ponyPosCtrl, ponyNegCtrl,
      handFixPosCtrl, handFixNegCtrl,
      refinerCtrl, refinerNegCtrl,
      facePosCtrl, faceNegCtrl,
    ]);
    for (final ctrl in _autoSaveControllers) {
      ctrl.addListener(_debouncedSave);
    }
  }

  void _removeAutoSaveListeners() {
    for (final ctrl in _autoSaveControllers) {
      ctrl.removeListener(_debouncedSave);
    }
  }

  Timer? _saveTimer;

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      saveAll();
    });
  }

  Future<void> _sendWol() async {
    if (macCtrl.text.isEmpty) return;
    try {
      await ComfyUIService.sendWakeOnLan(macCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WoL пакет отправлен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка WoL: $e'), backgroundColor: const Color(0xFFFF3B30)),
      );
    }
  }

  // ===================== ШАБЛОНЫ =====================

  Future<void> _saveTemplate(String name) async {
    final prompt = getPromptData();
    final template = PromptTemplate(name: name, data: prompt);
    templates.add(template);
    await TemplateStorage.save(templates);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Шаблон "$name" сохранён')),
    );
  }

  void _loadTemplate(PromptTemplate template) {
    loadFromTemplate(template);
    setState(() {});
  }

  void _showTemplates() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E12),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Шаблоны',
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Нет сохранённых шаблонов',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13)),
              )
            else
              ...templates.asMap().entries.map((e) {
                final idx = e.key;
                final tpl = e.value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x08FFFFFF)),
                  ),
                  child: ListTile(
                    title: Text(tpl.name,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, letterSpacing: -0.2)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.6), size: 18),
                      onPressed: () async {
                        templates.removeAt(idx);
                        await TemplateStorage.save(templates);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showTemplates();
                      },
                    ),
                    onTap: () {
                      _loadTemplate(tpl);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ===================== WORKFLOW =====================

  Future<void> _selectWorkflow() async {
    final workflows = await WorkflowManager.getWorkflows();
    final activePath = await WorkflowManager.getActiveWorkflowPath();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E12),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Выбор Workflow',
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),
            ...workflows.map((wf) {
              final bool isActive;
              if (wf.filePath == 'built_in') {
                isActive = activePath == null;
              } else if (wf.filePath == 'built_in_2') {
                isActive = activePath == 'built_in_2';
              } else {
                isActive = wf.filePath == activePath;
              }
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? const Color(0x25FFFFFF) : const Color(0x08FFFFFF),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    wf.isBuiltIn ? Icons.star_rounded : Icons.description_outlined,
                    color: isActive ? const Color(0xFFFFD60A) : GlassTheme.textTertiary,
                    size: 20,
                  ),
                  title: Text(wf.name,
                    style: TextStyle(
                      color: isActive ? const Color(0xFFF0F0F0) : GlassTheme.textSecondary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                  trailing: !wf.isBuiltIn
                      ? IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.6), size: 18),
                    onPressed: () async {
                      await WorkflowManager.deleteWorkflow(wf);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _selectWorkflow();
                    },
                  )
                      : null,
                  onTap: () async {
                    if (wf.isBuiltIn) {
                      if (wf.filePath == 'built_in_2') {
                        await WorkflowManager.setActiveWorkflow('built_in_2');
                        await service.loadWorkflow2();
                        setState(() => activeWorkflowName = 'Z-Image + Pony');
                      } else {
                        await WorkflowManager.setActiveWorkflow(null);
                        await service.loadWorkflow();
                        setState(() => activeWorkflowName = 'Z-Image');
                      }
                    } else {
                      await WorkflowManager.setActiveWorkflow(wf.filePath);
                      await service.loadWorkflowFromFile(wf.filePath);
                      setState(() => activeWorkflowName = wf.name);
                    }
                    setState(() {
                      loraGroups = service.extractLoraGroups();
                      nodeGroups = service.extractNodeGroups();
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x08FFFFFF)),
              ),
              child: ListTile(
                leading: const Icon(Icons.add_rounded, color: Color(0xFF5AC8FA), size: 20),
                title: const Text('Импортировать workflow',
                    style: TextStyle(color: Color(0xFF5AC8FA), fontSize: 14, letterSpacing: -0.2)),
                onTap: () async {
                  final imported = await WorkflowManager.importWorkflow();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (imported != null) _selectWorkflow();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ===================== ТЕГИ =====================

  void _handlePinTags(String sectionKey, TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    final tags = text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    setState(() {
      pinnedNegTags[sectionKey] = [...(pinnedNegTags[sectionKey] ?? []), ...tags];
    });
    _savePinnedTags(sectionKey);
  }

  Future<void> _savePinnedTags(String section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_neg_$section', pinnedNegTags[section] ?? []);
  }

  // ===================== ПОЛНОЭКРАННЫЙ РЕДАКТОР =====================

  Future<void> _handleOpenFullscreen(String sectionKey, String title, Color color, TextEditingController ctrl) async {
    final pinned = pinnedNegTags[sectionKey] ?? [];

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenEditor(
          title: title,
          text: ctrl.text,
          accentColor: color,
          initialPinned: pinned,
        ),
      ),
    );

    if (result == null) return;
    ctrl.text = result['text'] ?? '';
    if (result['pinned'] != null) {
      setState(() {
        pinnedNegTags[sectionKey] = List<String>.from(result['pinned']);
      });
      _savePinnedTags(sectionKey);
    }
  }

  // ===================== AI ДИАЛОГ =====================

  void _showAiPromptDialog() {
    AiPromptDialog.show(
      context: context,
      geminiApiKey: geminiApiKey,
      onSaveKey: (key) async {
        geminiApiKey = key;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gemini_api_key', key);
      },
      onResult: (result) {
        setState(() {
          zimageBaseCtrl.text = result.zimageBase;
          ponyPosCtrl.text = result.ponyPositive;
          ponyNegCtrl.text = result.ponyNegativeAdd;
          facePosCtrl.text = result.faceDetailer;
          faceNegCtrl.text = result.faceDetailerNegAdd;
          // HandFix: дополняем стандартный промпт, не заменяем
          if (result.handFixAdd.isNotEmpty) {
            final base = handFixPosCtrl.text.trim();
            if (base.isNotEmpty && !base.contains(result.handFixAdd)) {
              handFixPosCtrl.text = '$base\n${result.handFixAdd}';
            } else if (base.isEmpty) {
              handFixPosCtrl.text = result.handFixAdd;
            }
          }
          // Refiner: копия Z-Image базы по умолчанию
          if (result.refinerNote.contains('копия') || result.refinerNote.isEmpty) {
            refinerCtrl.text = result.zimageBase;
          } else {
            refinerCtrl.text = result.refinerNote;
          }
          // Refiner негатив = копия Z-Image негатива
          if (refinerNegCtrl.text.isEmpty) {
            refinerNegCtrl.text = zimageNegCtrl.text;
          }
        });
      },
      onStateChanged: (generating, elapsedTime) {
        setState(() {
          aiGenerating = generating;
          aiElapsed = elapsedTime;
        });
      },
    );
  }

  // ===================== СБОРКА СЕКЦИЙ =====================

  _SectionConfig? _getConfig(String key) {
    try {
      return _sectionConfigs.firstWhere((c) => c.key == key);
    } catch (_) {
      return null;
    }
  }

  Widget _buildSection(String key) {
    switch (key) {
      case 'settings':
        return SettingsSection(
          seedCtrl: seedCtrl,
          serverCtrl: serverCtrl,
          macCtrl: macCtrl,
          serverOnline: serverOnline,
          onCheckServer: () => checkServer().then((_) => setState(() {})),
          width: width,
          height: height,
          img2imgBytes: img2imgBytes,
          img2imgName: img2imgName,
          isExpanded: expanded['settings'] ?? false,
          onToggle: () => setState(() => expanded['settings'] = !(expanded['settings'] ?? false)),
          onWidthChanged: (v) => setState(() => width = v),
          onHeightChanged: (v) => setState(() => height = v),
          onPickImage: _pickImg2Img,
          onClearImage: () => setState(() { img2imgBytes = null; img2imgName = null; }),
        );
      case 'loras':
        return LorasSection(
          loraGroups: loraGroups,
          loraGroupOpen: loraGroupOpen,
          isExpanded: expanded['loras'] ?? false,
          onToggle: () => setState(() => expanded['loras'] = !(expanded['loras'] ?? false)),
          onToggleGroup: (nodeId) => setState(() {
            loraGroupOpen[nodeId] = !(loraGroupOpen[nodeId] ?? false);
          }),
          onChanged: () => setState(() {}),
        );
      default:
        final cfg = _getConfig(key);
        if (cfg == null) return const SizedBox.shrink();
        // Двойная страховка: если секции нет в воркфлоу — пустой виджет
        if (!service.isSectionAvailable(key)) return const SizedBox.shrink();
        final isEnabled = service.nodeEnabled[key] ?? true;
        return PromptSection(
          sectionKey: cfg.key,
          title: cfg.title,
          color: cfg.color,
          posCtrl: cfg.posCtrl(this),
          negCtrl: cfg.negCtrl(this),
          posLines: cfg.posLines,
          negLines: cfg.negLines,
          posHint: cfg.posHint,
          pinnedNegTags: pinnedNegTags[cfg.key] ?? [],
          isExpanded: expanded[cfg.key] ?? false,
          negVisible: negOpen[cfg.key] ?? false,
          isEnabled: isEnabled,
          hasToggle: true,
          onToggleExpand: () => setState(() => expanded[cfg.key] = !(expanded[cfg.key] ?? false)),
          onToggleNeg: () => setState(() => negOpen[cfg.key] = !(negOpen[cfg.key] ?? false)),
          onToggleEnabled: () => setState(() {
            service.nodeEnabled[cfg.key] = !isEnabled;
          }),
          onPinTags: _handlePinTags,
          onOpenFullscreen: _handleOpenFullscreen,
          onPinnedChanged: (pinned) {
            setState(() => pinnedNegTags[cfg.key] = pinned);
            _savePinnedTags(cfg.key);
          },
        );
    }
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: GlassTheme.scaffoldDecoration,
        child: SafeArea(child: _buildBody()),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentTab == 0)
            GenerationBottomBar(
              isGenerating: isGenerating,
              serverOnline: serverOnline,
              progress: progress,
              status: status,
              currentNode: currentNode,
              elapsed: elapsed,
              fmtTime: fmtTime,
              onGenerate: () => generate(),
              onStop: () => stopGeneration(),
              previewImage: previewImage,
            ),
          BottomNav(
            currentTab: currentTab,
            onTabChanged: (t) => setState(() => currentTab = t),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          const Text('ComfyGo',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: GlassTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _selectWorkflow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x0AFFFFFF), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_tree_outlined,
                      size: 12, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 5),
                  Text(activeWorkflowName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: GlassTheme.textTertiary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: serverOnline ? const Color(0xFF30D158) : const Color(0xFFFF3B30),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (serverOnline ? const Color(0xFF30D158) : const Color(0xFFFF3B30))
                      .withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (aiGenerating)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD60A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD60A).withValues(alpha: 0.15), width: 0.5),
                ),
                child: Text('AI ${fmtTime(aiElapsed)}',
                    style: const TextStyle(color: Color(0xFFFFD60A), fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        if (isGenerating)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        IconButton(
          icon: Icon(Icons.auto_awesome_rounded,
              size: 19, color: Colors.white.withValues(alpha: 0.5)),
          onPressed: _showAiPromptDialog,
          tooltip: 'AI промпт',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz_rounded,
              size: 20, color: Colors.white.withValues(alpha: 0.5)),
          color: const Color(0xFF1A1A1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (val) async {
            switch (val) {
              case 'save_template':
                final nameCtrl = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Сохранить шаблон',
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    content: TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14),
                      decoration: GlassTheme.glassInput(hint: 'Название шаблона'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Отмена', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, nameCtrl.text),
                        child: const Text('Сохранить', style: TextStyle(color: Color(0xFFFFD60A))),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) await _saveTemplate(name);
              case 'load_template':
                _showTemplates();
              case 'copy_to_refiner':
                _copyZimageToRefiner();
              case 'models':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ModelPickerScreen(service: service),
                  ),
                );
              case 'wol':
                await _sendWol();
            }
          },
          itemBuilder: (_) => [
            _menuItem(Icons.save_outlined, 'Сохранить шаблон', 'save_template'),
            _menuItem(Icons.folder_open_outlined, 'Загрузить шаблон', 'load_template'),
            _menuItem(Icons.content_copy_rounded, 'Скопировать в Refiner', 'copy_to_refiner'),
            _menuItem(Icons.power_settings_new_rounded, 'Wake-on-LAN', 'wol'),
            _menuItem(Icons.model_training, 'Модели сервера', 'models'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(IconData icon, String text, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Text(text,
            style: const TextStyle(
              color: GlassTheme.textPrimary,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (currentTab) {
      case 0:
        return _buildGenerateTab();
      case 1:
        return MonitorScreen(service: service);
      case 2:
        return LogsScreen(serverAddress: serverCtrl.text);
      case 3:
        return HistoryScreen(
          onRepeat: () {
            setState(() => currentTab = 0);
            generate();
          },
        );
      case 4:
        return ServerGalleryScreen(service: service);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGenerateTab() {
    // Фильтруем секции: settings и loras показываем всегда,
    // промпт-секции — только если есть в воркфлоу
    final visibleSections = sectionOrder.where((key) {
      if (key == 'settings' || key == 'loras') return true;
      return service.isSectionAvailable(key);
    }).toList();

    return ReorderableListView(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      onReorder: (oldIdx, newIdx) {
        if (visibleSections.length < 2) return;
        setState(() {
          if (newIdx > oldIdx) newIdx--;
          // Работаем с visibleSections для получения ключей,
          // но переставляем в оригинальном sectionOrder
          final movedKey = visibleSections[oldIdx];
          final targetKey = visibleSections[newIdx.clamp(0, visibleSections.length - 1)];
          final realOld = sectionOrder.indexOf(movedKey);
          final realNew = sectionOrder.indexOf(targetKey);
          if (realOld >= 0 && realNew >= 0) {
            final item = sectionOrder.removeAt(realOld);
            sectionOrder.insert(realNew, item);
          }
        });
        SharedPreferences.getInstance()
            .then((p) => p.setStringList('section_order', sectionOrder));
      },
      children: visibleSections.asMap().entries.map((entry) {
        final idx = entry.key;
        final key = entry.value;
        return Container(
          key: ValueKey(key),
          child: _AnimatedSection(
            delay: Duration(milliseconds: 80 * idx),
            child: _buildSection(key),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _bgSub?.cancel();
    _saveTimer?.cancel();
    _removeAutoSaveListeners();
    disposeGeneration();
    disposeControllers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _AnimatedSection extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedSection({
    required this.child,
    required this.delay,
  });

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

