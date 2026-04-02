import 'package:flutter/material.dart';
import 'glass_theme.dart';

class FullscreenEditor extends StatefulWidget {
  final String title;
  final String text;
  final Color accentColor;
  final List<String> initialPinned;

  const FullscreenEditor({
    super.key,
    required this.title,
    required this.text,
    required this.accentColor,
    this.initialPinned = const [],
  });

  @override
  State<FullscreenEditor> createState() => _FullscreenEditorState();
}

class _FullscreenEditorState extends State<FullscreenEditor> {
  late TextEditingController _ctrl;
  List<String> _pinned = [];

  @override
  void initState() {
    super.initState();
    _pinned = List<String>.from(widget.initialPinned);

    String cleanText = widget.text;
    for (final tag in _pinned) {
      cleanText = cleanText.replaceAll(
          RegExp('(,\\s*)?${RegExp.escape(tag)}(\\s*,)?'), '');
    }
    cleanText = cleanText.replaceAll(RegExp(r',\s*,'), ',');
    cleanText = cleanText.replaceAll(RegExp(r'^\s*,\s*'), '');
    cleanText = cleanText.replaceAll(RegExp(r'\s*,\s*$'), '');
    cleanText = cleanText.trim();

    _ctrl = TextEditingController(text: cleanText);
  }

  String _buildFinalText() {
    final editableText = _ctrl.text.trim();
    if (_pinned.isEmpty) return editableText;
    final pinnedStr = _pinned.join(', ');
    if (editableText.isEmpty) return pinnedStr;
    return '$pinnedStr, $editableText';
  }

  void _pinSelectedText() {
    final sel = _ctrl.selection;
    if (!sel.isValid || sel.start == sel.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выделите текст')),
      );
      return;
    }

    final fullText = _ctrl.text;
    final selected = fullText.substring(sel.start, sel.end).trim();
    if (selected.isEmpty) return;

    if (_pinned.contains(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот фрагмент уже закреплён')),
      );
      return;
    }

    String before = fullText.substring(0, sel.start);
    String after = fullText.substring(sel.end);
    before = before.replaceAll(RegExp(r'\s*,\s*$'), '');
    after = after.replaceAll(RegExp(r'^\s*,\s*'), '');

    String newText;
    if (before.isEmpty && after.isEmpty) {
      newText = '';
    } else if (before.isEmpty) {
      newText = after.trim();
    } else if (after.isEmpty) {
      newText = before.trim();
    } else {
      newText = '${before.trim()}, ${after.trim()}';
    }

    setState(() {
      _pinned.add(selected);
      _ctrl.text = newText;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Закреплено: "$selected"'),
        backgroundColor: const Color(0xFFFFD60A).withValues(alpha: 0.8),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _unpinTag(String tag) {
    setState(() {
      _pinned.remove(tag);
      final current = _ctrl.text.trim();
      if (current.isEmpty) {
        _ctrl.text = tag;
      } else {
        _ctrl.text = '$current, $tag';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: Colors.white.withValues(alpha: 0.6), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
          style: TextStyle(
            fontSize: 15,
            color: widget.accentColor,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context, {
              'text': _buildFinalText(),
              'pinned': _pinned,
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD60A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFD60A).withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: const Text('Готово',
                style: TextStyle(
                  color: Color(0xFFFFD60A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: GlassTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // === Закреплённые фрагменты ===
              if (_pinned.isNotEmpty)
                GlassTheme.card(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  padding: const EdgeInsets.all(12),
                  borderColor: const Color(0xFFFFD60A).withValues(alpha: 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded,
                              size: 13, color: Color(0xFFFFD60A)),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Закреплено',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFFD60A),
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final current = _ctrl.text.trim();
                              final allPinned = _pinned.join(', ');
                              setState(() {
                                if (current.isEmpty) {
                                  _ctrl.text = allPinned;
                                } else {
                                  _ctrl.text = '$current, $allPinned';
                                }
                                _pinned.clear();
                              });
                            },
                            child: Text('Открепить всё',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.2),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _pinned.map((tag) => Container(
                          padding: const EdgeInsets.only(
                              left: 10, top: 5, bottom: 5, right: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD60A).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFD60A).withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_rounded,
                                  size: 10, color: Color(0xFFFFD60A)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFFD60A),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _unpinTag(tag),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD60A).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 12, color: Color(0xFFFFD60A)),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),

              // === Текстовое поле ===
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 14,
                      color: GlassTheme.textPrimary,
                      height: 1.6,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: _pinned.isNotEmpty
                          ? 'Редактируемая часть промпта...'
                          : 'Введите промпт...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.1),
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.accentColor.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: widget.accentColor.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.02),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),

              // === Кнопка закрепить ===
              GlassTheme.card(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(10),
                borderColor: const Color(0xFFFFD60A).withValues(alpha: 0.15),
                child: GestureDetector(
                  onTap: _pinSelectedText,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD60A).withValues(alpha: 0.15),
                          const Color(0xFFFFD60A).withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFD60A).withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 16, color: Color(0xFFFFD60A)),
                        SizedBox(width: 8),
                        Text('Закрепить выделенное',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFFD60A),
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
