import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'glass_theme.dart';

class LogsScreen extends StatefulWidget {
  final String serverAddress;
  const LogsScreen({super.key, required this.serverAddress});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen>
    with SingleTickerProviderStateMixin {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollCtrl = ScrollController();
  WebSocketChannel? _ws;
  bool _autoScroll = true;
  bool _connected = false;
  String _filter = 'all';

  late AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _connect();
    _headerAnim.forward();
  }

  void _connect() {
    if (widget.serverAddress.trim().isEmpty) {
      _addLog('info', 'Ожидание адреса сервера...', Colors.orange, Icons.hourglass_empty);
      return;
    }
    try {
      final wsUrl = widget.serverAddress
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      _ws = WebSocketChannel.connect(
          Uri.parse('$wsUrl/ws?clientId=comfygo_logs'));
      setState(() => _connected = true);

      _ws!.stream.listen(
            (data) {
          try {
            final msg = jsonDecode(data);
            final type = msg['type'] ?? 'unknown';
            final payload = msg['data'] ?? {};

            String text;
            Color color;
            IconData icon;

            switch (type) {
              case 'status':
                final q = payload['status']?['exec_info']
                ?['queue_remaining'] ??
                    0;
                text = 'Очередь: $q задач';
                color = Colors.cyan;
                icon = Icons.queue;
                break;
              case 'execution_start':
                text =
                'Старт: ${payload['prompt_id']?.toString().substring(0, 8) ?? '?'}';
                color = Colors.green;
                icon = Icons.play_circle;
                break;
              case 'execution_cached':
                final nodes = payload['nodes'] as List? ?? [];
                text = 'Кэш: ${nodes.length} нод';
                color = Colors.grey;
                icon = Icons.cached;
                break;
              case 'executing':
                final node = payload['node'];
                if (node == null) {
                  text = 'Генерация завершена';
                  color = Colors.green;
                  icon = Icons.check_circle;
                } else {
                  text = 'Нода: $node';
                  color = Colors.white70;
                  icon = Icons.settings;
                }
                break;
              case 'progress':
                final val = payload['value'] ?? 0;
                final max = payload['max'] ?? 1;
                text = 'Прогресс: $val / $max';
                color = Colors.amber;
                icon = Icons.trending_up;
                break;
              case 'executed':
                text = 'Нода ${payload['node']} выполнена';
                color = Colors.lightGreen;
                icon = Icons.done;
                break;
              case 'execution_error':
                text =
                'ОШИБКА: ${payload['exception_message'] ?? 'unknown'}';
                color = Colors.red;
                icon = Icons.error;
                break;
              default:
                text =
                '$type: ${jsonEncode(payload).substring(0, (jsonEncode(payload).length).clamp(0, 100))}';
                color = Colors.grey;
                icon = Icons.info_outline;
            }

            _addLog(type, text, color, icon);
          } catch (e) {
            _addLog('raw', data.toString(), Colors.grey, Icons.code);
          }
        },
        onError: (e) {
          _addLog('error', 'Ошибка WebSocket: $e', Colors.red, Icons.error);
          setState(() => _connected = false);
        },
        onDone: () {
          _addLog(
              'info', 'WebSocket отключён', Colors.orange, Icons.link_off);
          setState(() => _connected = false);
        },
      );
    } catch (e) {
      _addLog('error', 'Не удалось подключиться: $e', Colors.red,
          Icons.error);
    }
  }

  void _addLog(String type, String text, Color color, IconData icon) {
    if (!mounted) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.add(LogEntry(
          time: time, type: type, text: text, color: color, icon: icon));
      if (_logs.length > 500) _logs.removeAt(0);
    });
    if (_autoScroll) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  List<LogEntry> get _filteredLogs {
    if (_filter == 'all') return _logs;
    if (_filter == 'errors') {
      return _logs
          .where((l) =>
      l.type == 'error' || l.type == 'execution_error')
          .toList();
    }
    if (_filter == 'progress') {
      return _logs
          .where((l) =>
      l.type == 'progress' ||
          l.type == 'executing' ||
          l.type == 'execution_start')
          .toList();
    }
    return _logs;
  }

  @override
  void didUpdateWidget(covariant LogsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverAddress != widget.serverAddress) {
      _ws?.sink.close();
      setState(() {
        _connected = false;
        _logs.clear();
      });
      _connect();
    }
  }

    @override
  void dispose() {
    _ws?.sink.close();
    _scrollCtrl.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Container(
      decoration: GlassTheme.scaffoldDecoration,
      child: Column(
        children: [
          // ── Status bar ──
          FadeTransition(
            opacity: _headerAnim,
            child: GlassTheme.card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderColor: _connected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              child: Row(
                children: [
                  _pulsingDot(_connected ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    _connected ? 'Подключено' : 'Отключено',
                    style: TextStyle(
                        color: _connected ? Colors.green : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text('${_logs.length}',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(width: 12),
                  _iconBtn(
                    icon: _autoScroll
                        ? Icons.vertical_align_bottom
                        : Icons.vertical_align_top,
                    color: _autoScroll ? Colors.amber : Colors.grey,
                    onTap: () =>
                        setState(() => _autoScroll = !_autoScroll),
                    tooltip: 'Автопрокрутка',
                  ),
                  _iconBtn(
                    icon: Icons.delete_outline,
                    color: Colors.grey,
                    onTap: () => setState(() => _logs.clear()),
                    tooltip: 'Очистить',
                  ),
                  if (!_connected)
                    _iconBtn(
                      icon: Icons.refresh,
                      color: Colors.amber,
                      onTap: _connect,
                      tooltip: 'Переподключить',
                    ),
                ],
              ),
            ),
          ),

          // ── Filter chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _filterChip('Все', 'all'),
                const SizedBox(width: 6),
                _filterChip('Прогресс', 'progress'),
                const SizedBox(width: 6),
                _filterChip('Ошибки', 'errors'),
              ],
            ),
          ),

          // ── Log list ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal,
                      size: 48,
                      color: Colors.grey[800]),
                  const SizedBox(height: 8),
                  Text('Нет записей',
                      style: TextStyle(
                          color: Colors.grey[700], fontSize: 14)),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final log = filtered[i];
                return _buildLogEntry(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: log.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: log.color.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(log.icon, size: 14, color: log.color.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            log.time,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.text,
              style: TextStyle(color: log.color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.amber.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.amber.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.amber : Colors.grey[500],
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _pulsingDot(Color color) {
    return _PulsingDot(color: color);
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String tooltip = '',
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.4,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, ___) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _ctrl.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _ctrl.value * 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class LogEntry {
  final String time;
  final String type;
  final String text;
  final Color color;
  final IconData icon;
  const LogEntry({
    required this.time,
    required this.type,
    required this.text,
    required this.color,
    required this.icon,
  });
}
