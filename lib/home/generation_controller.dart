import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../gallery_screen.dart';
import '../history_screen.dart';
import '../main.dart' show showNotification;
import '../background_service.dart';
import 'home_state.dart';

mixin GenerationControllerMixin<T extends StatefulWidget> on State<T>, HomeStateMixin<T> {
  Timer? _reconnectTimer;
  Timer? _timeoutTimer;
  static const _timeoutMinutes = 10;

  void startTimer() {
    elapsed = 0;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsed++);
    });
  }

  void stopTimer() => timer?.cancel();

  // ===================== АВТОПЕРЕПОДКЛЮЧЕНИЕ =====================

  void _startAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkServerAlive();
    });
  }

  void _stopAutoReconnect() => _reconnectTimer?.cancel();

  Future<void> _checkServerAlive() async {
    final base = serverCtrl.text.trim();
    if (base.isEmpty) return;

    try {
      final resp = await http
          .get(Uri.parse('$base/system_stats'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        if (!serverOnline) {
          setState(() => serverOnline = true);
        }
      } else {
        _handleServerLost();
      }
    } catch (_) {
      _handleServerLost();
    }
  }

  void _handleServerLost() {
    if (serverOnline) {
      setState(() => serverOnline = false);
    }
    if (isGenerating) {
      reconnectIfGenerating();
    }
  }

  // ===================== ТАЙМАУТ ГЕНЕРАЦИИ =====================

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      if (!isGenerating || !mounted) return;
      _showTimeoutDialog();
    });
  }

  void _stopTimeout() => _timeoutTimer?.cancel();

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Сервер не отвечает',
            style: TextStyle(color: Color(0xFFF0F0F0), fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
            'Генерация длится уже ${fmtTime(elapsed)}. Сервер может быть завис.',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startTimeout();
            },
            child: const Text('Подождать ещё',
                style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              stopGeneration();
            },
            child: const Text('Отменить',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  // ===================== WEBSOCKET С ПРЕВЬЮ =====================

  /// Обработка сообщений WebSocket — текст (JSON) и бинарные (preview)
  void _handleWsMessage(dynamic msg) {
    if (msg is String) {
      // JSON-сообщение
      try {
        final data = jsonDecode(msg);
        if (data['type'] == 'progress') {
          final v = data['data']['value'];
          final m = data['data']['max'];
          setState(() {
            progress = v / m;
            status = 'Шаг $v / $m';
          });
        } else if (data['type'] == 'executing' &&
            data['data']['node'] != null) {
          setState(() {
            currentNode =
                service.getNodeDisplayName(data['data']['node'].toString());
          });
        }
      } catch (_) {}
    } else if (msg is List<int>) {
      // Бинарное сообщение — preview image
      // ComfyUI шлёт: первые 8 байт — заголовок (тип + формат),
      // остальное — JPEG/PNG данные
      if (msg.length > 8) {
        final imageData = Uint8List.fromList(msg.sublist(8));
        if (imageData.length > 100) {
          setState(() {
            previewImage = imageData;
          });
        }
      }
    }
  }

  // ===================== СЕРВЕР =====================

  Future<void> checkServer() async {
    service.serverUrl = serverCtrl.text;
    service.clearObjectInfoCache();
    final online = await service.checkServer();
    setState(() => serverOnline = online);
    if (online) {
      _startAutoReconnect();
    }
  }

  Future<void> saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', serverCtrl.text);
    await prefs.setString('mac_address', macCtrl.text);
    await prefs.setInt('gen_width', width);
    await prefs.setInt('gen_height', height);
    await prefs.setString('seed', seedCtrl.text);
    await prefs.setStringList('section_order', sectionOrder);
    await prefs.setString('zimage_base', zimageBaseCtrl.text);
    await prefs.setString('zimage_neg', zimageNegCtrl.text);
    await prefs.setString('pony_pos', ponyPosCtrl.text);
    await prefs.setString('pony_neg', ponyNegCtrl.text);
    await prefs.setString('handfix_pos', handFixPosCtrl.text);
    await prefs.setString('handfix_neg', handFixNegCtrl.text);
    await prefs.setString('refiner', refinerCtrl.text);
    await prefs.setString('refiner_neg', refinerNegCtrl.text);
    await prefs.setString('face_pos', facePosCtrl.text);
    await prefs.setString('face_neg', faceNegCtrl.text);
    for (var key in pinnedNegTags.keys) {
      await prefs.setStringList('pinned_neg_$key', pinnedNegTags[key]!);
    }
  }

  // ===================== ГЕНЕРАЦИЯ =====================

  Future<void> generate() async {
    setState(() {
      isGenerating = true;
      progress = 0;
      status = 'Отправка...';
      currentNode = '';
      lastImages = [];
      lastTime = '';
      previewImage = null;
    });

    startTimer();
    _startTimeout();
    await saveAll();
    service.serverUrl = serverCtrl.text;

    try {
      if (img2imgBytes != null) {
        setState(() => status = 'Загрузка изображения...');
        await service.uploadImage(img2imgBytes!, img2imgName ?? 'input.png');
      }

      ws = service.connectWebSocket();
      ws!.stream.listen(
        _handleWsMessage,
        onError: (_) {},
      );

      int? customSeed;
      if (seedCtrl.text.isNotEmpty) {
        customSeed = int.tryParse(seedCtrl.text);
      }

      final workflow = service.buildWorkflow(
        getPromptData(),
        width: width,
        height: height,
        customSeed: customSeed,
        loraGroups: loraGroups,
      );
      final usedSeed = service.lastSeed;
      final promptId = await service.submitPrompt(workflow);

      await BackgroundGenerationService.startTracking(
          serverCtrl.text, promptId);

      final images = await service.fetchResults(promptId);

      stopTimer();
      _stopTimeout();
      final time = fmtTime(elapsed);
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final genInfo =
      GenerationInfo(seed: usedSeed, time: timeStr, date: dateStr);

      if (images.isNotEmpty) {
        final imagePaths = await HistoryStorage.saveImages(images);
        final historyEntry = HistoryEntry(
          imagePaths: imagePaths,
          seed: usedSeed,
          date: dateStr,
          time: timeStr,
          generationTime: time,
          promptPreview: zimageBaseCtrl.text.isNotEmpty
              ? zimageBaseCtrl.text.substring(
              0,
              zimageBaseCtrl.text.length > 100
                  ? 100
                  : zimageBaseCtrl.text.length)
              : 'Без промпта',
        );
        await HistoryStorage.add(historyEntry);
      }

      setState(() {
        lastImages = images;
        lastTime = time;
        lastInfo = genInfo;
        status = images.isNotEmpty
            ? 'Готово за $time! Сид: $usedSeed'
            : 'Нет результата';
        isGenerating = false;
        progress = 1.0;
        currentNode = '';
        previewImage = null;
      });

      HapticFeedback.heavyImpact();
      await showNotification(
        'Генерация завершена',
        images.isNotEmpty
            ? 'Готово за $time (сид: $usedSeed)'
            : 'Нет результата',
      );

      if (images.isNotEmpty && mounted) {
        setState(() => currentTab = 3);
      }
    } catch (e) {
      stopTimer();
      _stopTimeout();
      setState(() {
        status = 'Ошибка: $e';
        isGenerating = false;
        currentNode = '';
        previewImage = null;
      });
      HapticFeedback.heavyImpact();
      await showNotification('Ошибка генерации', '$e');
    } finally {
      ws?.sink.close();
      await BackgroundGenerationService.stop();
    }
  }

  Future<void> stopGeneration() async {
    _stopTimeout();
    try {
      final ok = await service.cancelGeneration();
      await BackgroundGenerationService.stop();
      stopTimer();
      setState(() {
        isGenerating = false;
        status = ok ? 'Остановлено' : 'Не удалось остановить';
        currentNode = '';
        previewImage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  ok ? 'Генерация остановлена' : 'Не удалось остановить')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> reconnectIfGenerating() async {
    final base = serverCtrl.text.trim();
    if (base.isEmpty) return;

    try {
      final resp = await http
          .get(Uri.parse('$base/queue'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body);
      final running = data['queue_running'] as List? ?? [];
      final pending = data['queue_pending'] as List? ?? [];

      if (running.isNotEmpty) {
        final runningItem = running.first;
        final promptId = runningItem[1] as String?;

        if (!isGenerating) {
          setState(() {
            isGenerating = true;
            status = 'Восстановление...';
            currentNode = '';
            previewImage = null;
          });
          startTimer();
          _startTimeout();

          ws?.sink.close();
          ws = service.connectWebSocket();
          ws!.stream.listen(
                (msg) {
              // Обработка JSON
              if (msg is String) {
                final wsData = jsonDecode(msg);
                if (wsData['type'] == 'progress') {
                  final v = wsData['data']['value'];
                  final m = wsData['data']['max'];
                  setState(() {
                    progress = v / m;
                    status = 'Шаг $v / $m';
                  });
                } else if (wsData['type'] == 'executing') {
                  final node = wsData['data']['node'];
                  if (node != null) {
                    setState(() {
                      currentNode =
                          service.getNodeDisplayName(node.toString());
                    });
                  } else {
                    onGenerationComplete(promptId);
                  }
                }
              } else if (msg is List<int>) {
                // Preview
                if (msg.length > 8) {
                  final imageData = Uint8List.fromList(msg.sublist(8));
                  if (imageData.length > 100) {
                    setState(() => previewImage = imageData);
                  }
                }
              }
            },
            onError: (_) {
              setState(() {
                isGenerating = false;
                status = 'Соединение потеряно';
                previewImage = null;
              });
              stopTimer();
              _stopTimeout();
            },
            onDone: () {
              if (isGenerating) {
                onGenerationComplete(promptId);
              }
            },
          );
        }
      } else if (pending.isEmpty && isGenerating) {
        setState(() {
          isGenerating = false;
          status = 'Генерация завершена (в фоне)';
          progress = 1.0;
          currentNode = '';
          previewImage = null;
        });
        stopTimer();
        _stopTimeout();
      }

      setState(() => serverOnline = true);
    } catch (e) {
      if (isGenerating) {
        setState(() {
          isGenerating = false;
          status = 'Потеряно соединение';
          previewImage = null;
        });
        stopTimer();
        _stopTimeout();
      }
    }
  }

  Future<void> onGenerationComplete(String? promptId) async {
    stopTimer();
    _stopTimeout();
    final time = fmtTime(elapsed);

    try {
      if (promptId != null) {
        final images = await service.fetchResults(promptId);
        final now = DateTime.now();
        final dateStr =
            '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        if (images.isNotEmpty) {
          final imagePaths = await HistoryStorage.saveImages(images);
          final historyEntry = HistoryEntry(
            imagePaths: imagePaths,
            seed: service.lastSeed,
            date: dateStr,
            time: timeStr,
            generationTime: time,
            promptPreview: zimageBaseCtrl.text.isNotEmpty
                ? zimageBaseCtrl.text.substring(
                0,
                zimageBaseCtrl.text.length > 100
                    ? 100
                    : zimageBaseCtrl.text.length)
                : 'Без промпта',
          );
          await HistoryStorage.add(historyEntry);

          setState(() {
            lastImages = images;
            lastTime = time;
            lastInfo = GenerationInfo(
              seed: service.lastSeed,
              time: timeStr,
              date: dateStr,
            );
            status = 'Готово за $time!';
            isGenerating = false;
            progress = 1.0;
            currentNode = '';
            previewImage = null;
          });

          HapticFeedback.heavyImpact();
          await showNotification('Генерация завершена', 'Готово за $time');
          if (mounted) {
            setState(() => currentTab = 3);
          }
          return;
        }
      }
    } catch (_) {}

    setState(() {
      isGenerating = false;
      status = 'Генерация завершена';
      progress = 1.0;
      currentNode = '';
      previewImage = null;
    });
  }

  void disposeGeneration() {
    _stopAutoReconnect();
    _stopTimeout();
  }
}
