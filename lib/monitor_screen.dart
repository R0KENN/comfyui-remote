import 'dart:async';
import 'package:flutter/material.dart';
import 'services.dart';
import 'glass_theme.dart';

class MonitorScreen extends StatefulWidget {
  final ComfyUIService service;
  const MonitorScreen({super.key, required this.service});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _queue = {};
  Map<String, dynamic> _history = {};
  bool _loading = true;
  int _pingMs = -1;

  // GPU статистика (история для графиков)
  final List<double> _vramHistory = [];
  final List<double> _tempHistory = [];
  static const int _maxHistoryPoints = 30;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final sw = Stopwatch()..start();
      final stats = await widget.service.getSystemStats();
      sw.stop();
      final ping = sw.elapsedMilliseconds;

      final queue = await widget.service.getQueue();
      final history = await widget.service.getHistory();

      // Собираем VRAM историю
      final devices = stats['devices'] as List? ?? [];
      if (devices.isNotEmpty) {
        final d = devices.first;
        final vramTotal = (d['vram_total'] ?? 0) / 1024 / 1024 / 1024;
        final vramFree = (d['vram_free'] ?? 0) / 1024 / 1024 / 1024;
        final vramUsed = vramTotal > 0 ? vramTotal - vramFree : 0.0;
        final vramPercent = vramTotal > 0 ? (vramUsed / vramTotal * 100) : 0.0;

        _vramHistory.add(vramPercent);
        if (_vramHistory.length > _maxHistoryPoints) {
          _vramHistory.removeAt(0);
        }

        // GPU температура (если доступна)
        final temp = d['gpu_temperature'] as num?;
        if (temp != null) {
          _tempHistory.add(temp.toDouble());
          if (_tempHistory.length > _maxHistoryPoints) {
            _tempHistory.removeAt(0);
          }
        }
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _queue = queue;
          _history = history;
          _pingMs = ping;
          _loading = false;
        });
        if (_animCtrl.status == AnimationStatus.dismissed) {
          _animCtrl.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _pingMs = -1;
        });
      }
    }
  }

  Color _pingColor(int ms) {
    if (ms < 0) return Colors.red;
    if (ms < 100) return Colors.green;
    if (ms < 300) return Colors.orange;
    return Colors.red;
  }

  String _pingText(int ms) {
    if (ms < 0) return 'N/A';
    return '${ms}ms';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GlassTheme.scaffoldDecoration,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.amber,
        child: _loading
            ? const Center(
            child: CircularProgressIndicator(color: Colors.amber))
            : ListView(
          padding: const EdgeInsets.all(12),
          children: [
            GlassTheme.fadeSlideIn(
              index: 0,
              controller: _animCtrl,
              child: _buildPingBar(),
            ),
            GlassTheme.fadeSlideIn(
              index: 1,
              controller: _animCtrl,
              child: _buildGpuCard(),
            ),
            GlassTheme.fadeSlideIn(
              index: 2,
              controller: _animCtrl,
              child: _buildSystemCard(),
            ),
            GlassTheme.fadeSlideIn(
              index: 3,
              controller: _animCtrl,
              child: _buildQueueCard(),
            ),
            GlassTheme.fadeSlideIn(
              index: 4,
              controller: _animCtrl,
              child: _buildHistoryCard(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Ping ──
  Widget _buildPingBar() {
    return GlassTheme.card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderColor: _pingColor(_pingMs).withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.speed, color: _pingColor(_pingMs), size: 20),
          const SizedBox(width: 10),
          Text('Ping: ',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _pingText(_pingMs),
              key: ValueKey(_pingMs),
              style: TextStyle(
                color: _pingColor(_pingMs),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          GlassTheme.statusBadge(
            _pingMs >= 0 ? 'Online' : 'Offline',
            _pingMs >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  // ── GPU card (расширенный) ──
  Widget _buildGpuCard() {
    final devices = _stats['devices'] as List? ?? [];
    if (devices.isEmpty) {
      return GlassTheme.card(
        borderColor: Colors.red.withValues(alpha: 0.3),
        child: GlassTheme.sectionTitle(
            Icons.memory, Colors.red, 'GPU не обнаружен'),
      );
    }

    return GlassTheme.card(
      borderColor: Colors.green.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassTheme.sectionTitle(Icons.memory, Colors.green, 'GPU'),
          const SizedBox(height: 12),
          ...devices.map((d) {
            final vramTotal = (d['vram_total'] ?? 0) / 1024 / 1024 / 1024;
            final vramFree = (d['vram_free'] ?? 0) / 1024 / 1024 / 1024;
            final vramUsed = vramTotal - vramFree;
            final vramPercent =
            vramTotal > 0 ? (vramUsed / vramTotal * 100) : 0.0;

            final torchVramTotal =
                (d['torch_vram_total'] ?? 0) / 1024 / 1024 / 1024;
            final torchVramFree =
                (d['torch_vram_free'] ?? 0) / 1024 / 1024 / 1024;
            final torchUsed = torchVramTotal - torchVramFree;

            final gpuTemp = d['gpu_temperature'] as num?;
            final gpuLoad = d['gpu_utilization'] as num?;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название GPU
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${d['name'] ?? 'Unknown'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                    if (gpuTemp != null)
                      _gpuStatChip(
                        Icons.thermostat_rounded,
                        '${gpuTemp.toInt()}°C',
                        _tempColor(gpuTemp.toDouble()),
                      ),
                    if (gpuLoad != null) ...[
                      const SizedBox(width: 6),
                      _gpuStatChip(
                        Icons.speed_rounded,
                        '${gpuLoad.toInt()}%',
                        _loadColor(gpuLoad.toDouble()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('Тип: ${d['type'] ?? '?'}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 12),

                // VRAM
                Row(
                  children: [
                    Icon(Icons.storage,
                        size: 14,
                        color: Colors.green.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'VRAM: ${vramUsed.toStringAsFixed(1)} / ${vramTotal.toStringAsFixed(1)} ГБ',
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '${vramPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: _vramColor(vramPercent),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                GlassTheme.progressBar(vramPercent,
                    color: _vramColor(vramPercent)),

                // Torch VRAM (если отличается)
                if (torchVramTotal > 0 && torchUsed > 0.01) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 14,
                          color: Colors.orange.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        'PyTorch: ${torchUsed.toStringAsFixed(1)} / ${torchVramTotal.toStringAsFixed(1)} ГБ',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  GlassTheme.progressBar(
                    torchVramTotal > 0
                        ? (torchUsed / torchVramTotal * 100)
                        : 0,
                    color: Colors.orange,
                  ),
                ],

                // Мини-график VRAM
                if (_vramHistory.length > 2) ...[
                  const SizedBox(height: 12),
                  _buildMiniChart(
                    'VRAM',
                    _vramHistory,
                    Colors.green,
                  ),
                ],

                // Мини-график температуры
                if (_tempHistory.length > 2) ...[
                  const SizedBox(height: 8),
                  _buildMiniChart(
                    'Температура',
                    _tempHistory,
                    Colors.orange,
                    suffix: '°C',
                    maxVal: 100,
                  ),
                ],

                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _gpuStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _tempColor(double temp) {
    if (temp < 60) return Colors.green;
    if (temp < 75) return Colors.orange;
    return Colors.red;
  }

  Color _loadColor(double load) {
    if (load < 50) return Colors.green;
    if (load < 80) return Colors.orange;
    return Colors.red;
  }

  Color _vramColor(double percent) {
    if (percent < 60) return Colors.green;
    if (percent < 85) return Colors.orange;
    return Colors.red;
  }

  /// Мини-график (sparkline)
  Widget _buildMiniChart(
      String label,
      List<double> data,
      Color color, {
        String suffix = '%',
        double? maxVal,
      }) {
    final currentVal = data.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 10)),
            const Spacer(),
            Text(
              '${currentVal.toStringAsFixed(0)}$suffix',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(
              data: data,
              color: color,
              maxValue: maxVal ?? 100,
            ),
          ),
        ),
      ],
    );
  }

  // ── System card ──
  Widget _buildSystemCard() {
    final sys = _stats['system'] as Map<String, dynamic>? ?? {};
    final ramTotal = (sys['ram_total'] ?? 0) / 1024 / 1024 / 1024;
    final ramFree = (sys['ram_free'] ?? 0) / 1024 / 1024 / 1024;
    final ramUsed = ramTotal - ramFree;
    final ramPercent = ramTotal > 0 ? (ramUsed / ramTotal * 100) : 0.0;

    return GlassTheme.card(
      borderColor: Colors.amber.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassTheme.sectionTitle(Icons.computer, Colors.amber, 'Система'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _versionChip('ComfyUI', sys['comfyui_version'] ?? '?'),
              _versionChip('Python', sys['python_version'] ?? '?'),
              _versionChip('PyTorch', sys['pytorch_version'] ?? '?'),
              if (sys['embedded_python'] == true)
                _versionChip('Mode', 'Embedded'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.memory,
                  size: 14, color: Colors.amber.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                'RAM: ${ramUsed.toStringAsFixed(1)} / ${ramTotal.toStringAsFixed(1)} ГБ',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${ramPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: ramPercent > 85 ? Colors.red : Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          GlassTheme.progressBar(ramPercent, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _versionChip(String label, String version) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          Text(version,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Queue card ──
  Widget _buildQueueCard() {
    final running = _queue['queue_running'] as List? ?? [];
    final pending = _queue['queue_pending'] as List? ?? [];
    final isActive = running.isNotEmpty;

    return GlassTheme.card(
      borderColor: isActive
          ? Colors.green.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassTheme.sectionTitle(
            Icons.queue,
            isActive ? Colors.green : Colors.grey,
            'Очередь',
            trailing: GlassTheme.statusBadge(
              isActive ? 'Активно' : 'Свободно',
              isActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _statChip('Выполняется', '${running.length}',
                      running.isNotEmpty ? Colors.green : Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statChip('В ожидании', '${pending.length}',
                      pending.isNotEmpty ? Colors.orange : Colors.grey)),
            ],
          ),
          if (running.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...running.map((item) {
              final id = item is List && item.length > 1
                  ? item[1].toString().substring(0, 8)
                  : '?';
              return Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: Colors.green.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Text('$id...',
                        style: TextStyle(
                            color: Colors.green[300],
                            fontSize: 12,
                            fontFamily: 'monospace')),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style:
              TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ── History card ──
  Widget _buildHistoryCard() {
    final sortedEntries = _history.entries.toList();
    sortedEntries.sort((a, b) {
      final aTime = _getTimestamp(a.value);
      final bTime = _getTimestamp(b.value);
      return bTime.compareTo(aTime);
    });
    final entries = sortedEntries.take(15).toList();

    return GlassTheme.card(
      borderColor: Colors.blue.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassTheme.sectionTitle(
            Icons.history,
            Colors.blue,
            'Последние задачи',
            trailing: GlassTheme.chip('${_history.length}', Colors.blue),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Нет задач',
                    style: TextStyle(color: Colors.grey[700])),
              ),
            )
          else
            ...entries.map((e) => _buildHistoryItem(e.key, e.value)),
        ],
      ),
    );
  }

  DateTime _getTimestamp(dynamic data) {
    final status = data['status'] as Map? ?? {};
    final msgs = status['messages'] as List? ?? [];
    for (var msg in msgs) {
      if (msg is List && msg.length > 1 && msg[0] == 'execution_start') {
        final ts = msg[1]['timestamp'];
        if (ts != null) {
          return DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
        }
      }
    }
    return DateTime(2000);
  }

  Widget _buildHistoryItem(String id, dynamic data) {
    final status = data['status'] as Map? ?? {};
    final completed = status['completed'] == true;
    final msgs = status['messages'] as List? ?? [];

    String timeStr = '';
    String dateStr = '';
    DateTime? startDt;
    DateTime? endDt;

    for (var msg in msgs) {
      if (msg is List && msg.length > 1) {
        final type = msg[0];
        final payload = msg[1] as Map? ?? {};
        final ts = payload['timestamp'];
        if (ts != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
          if (type == 'execution_start') {
            startDt = dt;
            timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
          }
          if (type == 'execution_success' || type == 'execution_error') {
            endDt = dt;
          }
        }
      }
    }

    String durationStr = '';
    if (startDt != null && endDt != null) {
      final sec = endDt.difference(startDt).inSeconds;
      durationStr = sec >= 60 ? '${sec ~/ 60}м ${sec % 60}с' : '$secс';
    }

    int imageCount = 0;
    final outputs = data['outputs'] as Map? ?? {};
    for (var nodeOut in outputs.values) {
      if (nodeOut is Map) {
        final images = nodeOut['images'] as List? ?? [];
        imageCount += images.length;
      }
    }

    final Color statusColor = completed ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.error_outline,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            id.length > 8 ? id.substring(0, 8) : id,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          if (dateStr.isNotEmpty)
            Text('$dateStr ',
                style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          if (timeStr.isNotEmpty)
            Text(timeStr,
                style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          const Spacer(),
          if (durationStr.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(durationStr,
                  style: TextStyle(color: Colors.grey[400], fontSize: 10)),
            ),
          if (imageCount > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image, size: 12, color: Colors.blue[300]),
                const SizedBox(width: 2),
                Text('$imageCount',
                    style: TextStyle(color: Colors.blue[300], fontSize: 10)),
                const SizedBox(width: 6),
              ],
            ),
          Text(
            completed ? 'OK' : 'Ошибка',
            style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Sparkline painter ──

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;

  _SparklinePainter({
    required this.data,
    required this.color,
    this.maxValue = 100,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue * size.height).clamp(0, size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data.length != data.length ||
          (data.isNotEmpty && old.data.isNotEmpty && old.data.last != data.last);
}
