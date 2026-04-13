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
      _addLog('info', 'Ожидание адреса сервера...', const Color(0xFFFFD60A),
          Icons.hourglass_empty);
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
            String symbol;

            switch (type) {
              case 'status':
                final q = payload['status']?['exec_info']
                ?['queue_remaining'] ??
                    0;
                text = 'Очередь: $q задач';
                color = GlassTheme.accentCyan;
                icon = Icons.queue;
                symbol = '◆';
                break;
              case 'execution_start':
                text =
                '▶ Старт: ${payload['prompt_id']?.toString().substring(0, 8) ?? '?'}';
                color = GlassTheme.accentGreen;
                icon = Icons.play_arrow_rounded;
                symbol = '▶';
                break;
              case 'execution_cached':
                final nodes = payload['nodes'] as List? ?? [];
                text = '◇ Кэш: ${nodes.length} нод';
                color = const Color(0xFF8E8E93);
                icon = Icons.cached;
                symbol = '◇';
                break;
              case 'executing':
                final node = payload['node'];
                if (node == null) {
                  text = '◉ Генерация завершена';
                  color = GlassTheme.accentGreen;
                  icon = Icons.check_circle_rounded;
                  symbol = '◉';
                } else {
                  text = '⚙ Нода: $node';
                  color = GlassTheme.accentCyan;
                  icon = Icons.settings_rounded;
                  symbol = '⚙';
                }
                break;
              case 'progress':
                final val = payload['value'] ?? 0;
                final max = payload['max'] ?? 1;
                text = '▦ Прогресс: $val / $max';
                color = GlassTheme.accentYellow;
                icon = Icons.linear_scale_rounded;
                symbol = '▦';
                break;
              case 'executed':
                text = '◉ Нода ${payload['node']} выполнена';
                color = GlassTheme.accentCyan;
                icon = Icons.done_rounded;
                symbol = '◉';
                break;
              case 'execution_error':
                text =
                '✕ ОШИБКА: ${payload['exception_message'] ?? 'unknown'}';
                color = GlassTheme.accentRed;
                icon = Icons.error_rounded;
                symbol = '✕';
                break;
              default:
                text =
                '$type: ${jsonEncode(payload).substring(0, (jsonEncode(payload).length).clamp(0, 100))}';
                color = const Color(0xFF8E8E93);
                icon = Icons.info_outline_rounded;
                symbol = '•';
            }

            _addLog(type, text, color, icon, symbol: symbol);
          } catch (e) {
            _addLog('raw', data.toString(), const Color(0xFF8E8E93),
                Icons.code, symbol: '•');
          }
        },
        onError: (e) {
          _addLog('error', '✕ Ошибка WebSocket: $e', GlassTheme.accentRed,
              Icons.error_rounded, symbol: '✕');
          setState(() => _connected = false);
        },
        onDone: () {
          _addLog('info', '◇ WebSocket отключён', const Color(0xFFFFD60A),
              Icons.link_off, symbol: '◇');
          setState(() => _connected = false);
        },
      );
    } catch (e) {
      _addLog('error', '✕ Не удалось подключиться: $e', GlassTheme.accentRed,
          Icons.error_rounded, symbol: '✕');
    }
  }

  void _addLog(String type, String text, Color color, IconData icon,
      {String symbol = '•'}) {
    if (!mounted) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.add(LogEntry(
        time: time,
        type: type,
        text: text,
        color: color,
        icon: icon,
        symbol: symbol,
      ));
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
          .where(
              (l) => l.type == 'error' || l.type == 'execution_error')
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
          // ── Connection status bar ──
          FadeTransition(
            opacity: _headerAnim,
            child: GlassTheme.card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderColor: _connected
                  ? GlassTheme.accentGreen.withValues(alpha: 0.2)
                  : GlassTheme.accentRed.withValues(alpha: 0.2),
              child: Row(
                children: [
                  _PulsingDot(
                      color: _connected
                          ? GlassTheme.accentGreen
                          : GlassTheme.accentRed),
                  const SizedBox(width: 10),
                  Text(
                    _connected ? 'CONNECTED' : 'DISCONNECTED',
                    style: TextStyle(
                      color: _connected
                          ? GlassTheme.accentGreen
                          : GlassTheme.accentRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  // Entry count badge
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentCyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                          GlassTheme.accentCyan.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      '${_logs.length} ENTRIES',
                      style: const TextStyle(
                        color: GlassTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action buttons row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _terminalActionBtn(
                  icon: _autoScroll
                      ? Icons.vertical_align_bottom_rounded
                      : Icons.vertical_align_top_rounded,
                  label: 'AUTO-SCROLL',
                  isActive: _autoScroll,
                  onTap: () => setState(() => _autoScroll = !_autoScroll),
                ),
                const SizedBox(width: 8),
                _terminalActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'CLEAR',
                  onTap: () => setState(() => _logs.clear()),
                ),
                const SizedBox(width: 8),
                if (!_connected)
                  _terminalActionBtn(
                    icon: Icons.refresh_rounded,
                    label: 'RECONNECT',
                    isActive: true,
                    activeColor: GlassTheme.accentYellow,
                    onTap: _connect,
                  ),
                const Spacer(),
                // Terminal icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: GlassTheme.accentCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                        GlassTheme.accentCyan.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.terminal_rounded,
                      size: 18, color: GlassTheme.accentCyan),
                ),
              ],
            ),
          ),

          // ── Filter chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _filterChip('ALL', 'all'),
                const SizedBox(width: 8),
                _filterChip('PROGRESS', 'progress'),
                const SizedBox(width: 8),
                _filterChip('ERRORS', 'errors'),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Terminal window ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Terminal title bar with dots
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // macOS-style dots
                          _terminalDot(const Color(0xFFFF5F57)),
                          const SizedBox(width: 6),
                          _terminalDot(const Color(0xFFFFBD2E)),
                          const SizedBox(width: 6),
                          _terminalDot(const Color(0xFF27C93F)),
                          const Spacer(),
                          Text(
                            'STREAM_V1.0.4',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.15),
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Log entries
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.terminal_rounded,
                                size: 48,
                                color: Colors.white
                                    .withValues(alpha: 0.06)),
                            const SizedBox(height: 8),
                            Text(
                              'Нет записей',
                              style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  fontSize: 13,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        controller: _scrollCtrl,
                        padding:
                        const EdgeInsets.fromLTRB(14, 8, 14, 80),
                        itemCount: filtered.length + 1,
                        itemBuilder: (_, i) {
                          if (i == filtered.length) {
                            return _buildCursorLine();
                          }
                          return _buildTerminalLogEntry(filtered[i]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _terminalDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildTerminalLogEntry(LogEntry log) {
    final isError =
        log.type == 'error' || log.type == 'execution_error';

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: isError
          ? BoxDecoration(
        color: GlassTheme.accentRed.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 62,
            child: Text(
              log.time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.18),
                fontSize: 11,
                fontFamily: 'monospace',
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Icon
          SizedBox(
            width: 20,
            child: Icon(log.icon,
                size: 13, color: log.color.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 4),
          // Message
          Expanded(
            child: Text(
              log.text,
              style: TextStyle(
                color: log.color,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCursorLine() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.18),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          _BlinkingCursor(color: GlassTheme.accentCyan),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? GlassTheme.textPrimary
                    : GlassTheme.textTertiary,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _terminalActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = GlassTheme.accentCyan,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive
                    ? activeColor
                    : GlassTheme.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: isActive
                    ? activeColor
                    : GlassTheme.textTertiary,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blinking cursor ──
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
      builder: (context, child) {
        return Opacity(
          opacity: _ctrl.value,
          child: Container(
            width: 8,
            height: 16,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}

// ── Pulsing connection dot ──
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
      builder: (context, child) {
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
  final String symbol;
  const LogEntry({
    required this.time,
    required this.type,
    required this.text,
    required this.color,
    required this.icon,
    this.symbol = '•',
  });
}
