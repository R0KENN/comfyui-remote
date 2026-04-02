import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai_prompt_service.dart';
import '../glass_theme.dart';

class AiPromptDialog {
  static const _historyKey = 'ai_prompt_history';
  static const _modelKey = 'ai_model';
  static const int _maxHistory = 20;

  // ── Цвета диалога (единое место) ──
  static const _bgColor = Color(0xFF0A0A0C);
  static const _cardColor = Color(0xFF111114);
  static const _borderColor = Color(0x10FFFFFF);
  static const _accent = Color(0xFFFFD60A);

  static final List<Map<String, String>> _availableModels = [
    {'id': 'google/gemini-2.5-flash', 'name': 'Gemini 2.5 Flash'},
    {'id': 'google/gemini-2.0-flash-001', 'name': 'Gemini 2.0 Flash'},
    {'id': 'google/gemini-2.5-pro', 'name': 'Gemini 2.5 Pro'},
    {'id': 'anthropic/claude-sonnet-4', 'name': 'Claude Sonnet 4'},
    {'id': 'openai/gpt-4o-mini', 'name': 'GPT-4o Mini'},
    {'id': 'openai/gpt-4o', 'name': 'GPT-4o'},
  ];

  static Future<List<String>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  static Future<void> _addToHistory(String request) async {
    if (request.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(request);
    history.insert(0, request);
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setStringList(_historyKey, history);
  }

  static Future<String> _loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? 'google/gemini-2.5-flash';
  }

  static Future<void> _saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  static Future<void> show({
    required BuildContext context,
    required String geminiApiKey,
    required Future<void> Function(String key) onSaveKey,
    required void Function(AiPromptResult result) onResult,
    required void Function(bool generating, int elapsed) onStateChanged,
  }) async {
    String apiKey = geminiApiKey;

    // ── Запрос API ключа ──
    if (apiKey.isEmpty) {
      final keyController = TextEditingController();
      final key = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accent.withValues(alpha: 0.12),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(Icons.key_rounded,
                          color: _accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('OpenRouter API Key',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: GlassTheme.textTertiary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Получите ключ на openrouter.ai/keys',
                          style: TextStyle(
                            color: GlassTheme.textSecondary,
                            fontSize: 12,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyController,
                  style: const TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                  decoration: _darkInput(
                    label: 'API Key',
                    hint: 'sk-or-...',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _darkButton(
                        text: 'Отмена',
                        isAccent: false,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _darkButton(
                        text: 'Сохранить',
                        icon: Icons.check_rounded,
                        isAccent: true,
                        onTap: () => Navigator.pop(ctx, keyController.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (key == null || key.isEmpty) return;
      await onSaveKey(key);
      apiKey = key;
    }

    if (!context.mounted) return;

    // ── Основной диалог ──
    final requestController = TextEditingController();
    Uint8List? aiImageBytes;
    String selectedModel = await _loadModel();
    final history = await _loadHistory();
    bool useMethodichka = true;

    final request = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accent.withValues(alpha: 0.12),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(Icons.auto_awesome_rounded,
                            color: _accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('AI Промпт',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlassTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      // История
                      if (history.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _showHistory(ctx, history, (selected) {
                              setDialogState(() {
                                requestController.text = selected;
                              });
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderColor),
                            ),
                            child: const Icon(Icons.history_rounded,
                                color: GlassTheme.textTertiary, size: 16),
                          ),
                        ),
                      // Сброс ключа
                      GestureDetector(
                        onTap: () async {
                          await onSaveKey('');
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('API ключ сброшен')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _borderColor),
                          ),
                          child: const Icon(Icons.key_off_rounded,
                              color: GlassTheme.textTertiary, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор модели
                  GestureDetector(
                    onTap: () {
                      _showModelPicker(ctx, selectedModel, (model) {
                        setDialogState(() => selectedModel = model);
                        _saveModel(model);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy_outlined,
                              size: 14, color: _accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _availableModels.firstWhere(
                                    (m) => m['id'] == selectedModel,
                                orElse: () => {'name': selectedModel},
                              )['name']!,
                              style: const TextStyle(
                                color: GlassTheme.textSecondary,
                                fontSize: 12,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Icon(Icons.expand_more_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.15)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Переключатель методички
                  GestureDetector(
                    onTap: () {
                      setDialogState(() => useMethodichka = !useMethodichka);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: useMethodichka
                            ? _accent.withValues(alpha: 0.05)
                            : _cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: useMethodichka
                              ? _accent.withValues(alpha: 0.15)
                              : _borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            useMethodichka
                                ? Icons.menu_book_rounded
                                : Icons.edit_note_rounded,
                            size: 14,
                            color: useMethodichka
                                ? _accent
                                : GlassTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  useMethodichka ? 'По методичке' : 'Свободный режим',
                                  style: TextStyle(
                                    color: useMethodichka
                                        ? _accent
                                        : GlassTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  useMethodichka
                                      ? 'Промпты строго по методичке персонажа'
                                      : 'Свободное описание любой сцены',
                                  style: const TextStyle(
                                    color: GlassTheme.textTertiary,
                                    fontSize: 10,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 20,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: useMethodichka
                                  ? _accent.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.06),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              alignment: useMethodichka
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: useMethodichka
                                      ? _accent
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Загрузка фото
                  _buildGlassImagePicker(ctx, aiImageBytes, (bytes) {
                    setDialogState(() => aiImageBytes = bytes);
                  }),
                  const SizedBox(height: 14),

                  // Поле ввода
                  TextField(
                    controller: requestController,
                    style: const TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 4,
                    decoration: _darkInput(
                      label: aiImageBytes != null
                          ? 'Дополнительные пожелания'
                          : 'Описание сцены',
                      hint: aiImageBytes != null
                          ? 'Опционально...'
                          : 'Сидит на кухне, пьёт кофе, сонная...',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Кнопки
                  Row(
                    children: [
                      Expanded(
                        child: _darkButton(
                          text: 'Отмена',
                          isAccent: false,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _darkButton(
                          text: 'Сгенерировать',
                          icon: Icons.auto_awesome_rounded,
                          isAccent: true,
                          onTap: () {
                            if (requestController.text.trim().isEmpty &&
                                aiImageBytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Введите описание или загрузите фото')),
                              );
                              return;
                            }
                            Navigator.pop(ctx, requestController.text.trim());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (request == null && aiImageBytes == null) return;
    if (!context.mounted) return;

    // Сохраняем в историю
    final requestText = request ?? '';
    if (requestText.isNotEmpty) {
      await _addToHistory(requestText);
    }

    int aiElapsed = 0;
    onStateChanged(true, 0);
    final aiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      aiElapsed++;
      onStateChanged(true, aiElapsed);
    });

    try {
      final ai = AiPromptService(
          apiKey: apiKey, model: selectedModel, useMethodichka: useMethodichka);
      AiPromptResult? result;

      if (aiImageBytes != null) {
        result = await ai.generatePromptsFromImage(requestText, aiImageBytes!);
      } else {
        result = await ai.generatePrompts(requestText);
      }

      if (result != null && context.mounted) {
        onResult(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI промпты заполнены! ${result.refinerNote}'),
            backgroundColor: const Color(0xFF30D158),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка AI: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    } finally {
      aiTimer.cancel();
      onStateChanged(false, 0);
    }
  }

  // ── Тёмный InputDecoration ──
  static InputDecoration _darkInput({
    String? label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.25),
        fontSize: 12,
        letterSpacing: -0.2,
      ),
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.12),
        fontSize: 13,
        letterSpacing: -0.2,
      ),
      filled: true,
      fillColor: _cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accent.withValues(alpha: 0.3)),
      ),
    );
  }

  // ── Тёмная кнопка ──
  static Widget _darkButton({
    required String text,
    IconData? icon,
    required bool isAccent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isAccent
              ? _accent.withValues(alpha: 0.12)
              : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAccent
                ? _accent.withValues(alpha: 0.25)
                : _borderColor,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: isAccent ? _accent : GlassTheme.textTertiary),
              const SizedBox(width: 6),
            ],
            Text(text,
              style: TextStyle(
                color: isAccent ? _accent : GlassTheme.textTertiary,
                fontSize: 13,
                fontWeight: isAccent ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── История запросов ──
  static void _showHistory(
      BuildContext ctx, List<String> history, ValueChanged<String> onSelect) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('История запросов',
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: history.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    onSelect(history[i]);
                    Navigator.pop(sheetCtx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      history[i],
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Выбор модели ──
  static void _showModelPicker(
      BuildContext ctx, String current, ValueChanged<String> onSelect) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Выбор модели',
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            ..._availableModels.map((m) {
              final isActive = m['id'] == current;
              return GestureDetector(
                onTap: () {
                  onSelect(m['id']!);
                  Navigator.pop(sheetCtx);
                },
                child: Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _accent.withValues(alpha: 0.06)
                        : _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? _accent.withValues(alpha: 0.15)
                          : _borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.smart_toy_outlined,
                          size: 16,
                          color: isActive
                              ? _accent
                              : GlassTheme.textTertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['name']!,
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFFF0F0F0)
                                    : GlassTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(m['id']!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.1),
                                fontSize: 10,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Icon(Icons.check_rounded,
                            size: 16, color: _accent),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Загрузка фото ──
  static Widget _buildGlassImagePicker(
      BuildContext ctx, Uint8List? imageBytes, ValueChanged<Uint8List?> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          onChanged(bytes);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: imageBytes != null ? null : 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: imageBytes != null
              ? _accent.withValues(alpha: 0.03)
              : _cardColor,
          border: Border.all(
            color: imageBytes != null
                ? _accent.withValues(alpha: 0.15)
                : _borderColor,
            width: 0.5,
          ),
        ),
        child: imageBytes != null
            ? Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.memory(imageBytes,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover),
            ),
            // Затемнение поверх картинки
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => onChanged(null),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFF3B30)
                            .withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Color(0xFFFF3B30)),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_rounded,
                        size: 11, color: _accent),
                    const SizedBox(width: 4),
                    Text('Референс загружен',
                      style: TextStyle(
                        fontSize: 10,
                        color: _accent,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: Colors.white.withValues(alpha: 0.12), size: 22),
            const SizedBox(width: 8),
            Text('Загрузить референс',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
