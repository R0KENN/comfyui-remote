// lib/home/generation_controller.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../gallery_screen.dart';
import '../history_screen.dart';
import '../background_service.dart';
import '../seed_storage.dart';
import '../sounds.dart';
import 'home_state.dart';
import 'dart:io';
import '../main.dart'
    show
    showNotification,
    showImageNotification,
    showProgressNotification,
    dismissProgressNotification;

mixin GenerationControllerMixin<T extends StatefulWidget>
on State<T>, HomeStateMixin<T> {
  Timer? _reconnectTimer;
  Timer? _timeoutTimer;
  static const _timeoutMinutes = 10;

  Completer<String?>? _generationCompleter;

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
        if (!serverOnline) setState(() => serverOnline = true);
      } else {
        _handleServerLost();
      }
    } catch (_) {
      _handleServerLost();
    }
  }

  void _handleServerLost() {
    if (serverOnline) setState(() => serverOnline = false);
    if (isGenerating) reconnectIfGenerating();
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
            style: TextStyle(
                color: Color(0xFFF0F0F0),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
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

  // ===================== WEBSOCKET =====================

  void _handleWsMessage(dynamic msg) {
    if (msg is String) {
      try {
        final data = jsonDecode(msg);
        final type = data['type'];

        if (type == 'progress') {
          final v = data['data']['value'];
          final m = data['data']['max'];
          setState(() {
            progress = v / m;
            status = 'Шаг $v / $m';
          });
          showProgressNotification(
            title: 'Генерация...',
            body: 'Шаг $v / $m  •  ${fmtTime(elapsed)}',
            progress: v is int ? v : (v as num).toInt(),
            maxProgress: m is int ? m : (m as num).toInt(),
          );
        } else if (type == 'executing') {
          final node = data['data']['node'];
          if (node != null) {
            setState(() {
              currentNode = service.getNodeDisplayName(node.toString());
            });
          } else {
            final promptId = data['data']['prompt_id']?.toString();
            if (_generationCompleter != null &&
                !_generationCompleter!.isCompleted) {
              _generationCompleter!.complete(promptId);
            }
          }
        } else if (type == 'execution_error') {
          final errorMsg =
              data['data']?['exception_message'] ?? 'Неизвестная ошибка';
          if (_generationCompleter != null &&
              !_generationCompleter!.isCompleted) {
            _generationCompleter!.completeError(Exception(errorMsg));
          }
        }
      } catch (_) {}
    } else if (msg is List<int>) {
      if (msg.length > 8) {
        final imageData = Uint8List.fromList(msg.sublist(8));
        if (imageData.length > 100) {
          setState(() => previewImage = imageData);
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
    if (online) _startAutoReconnect();
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

  // ===================== ОБРАБОТКА ЗАВЕРШЕНИЯ =====================

  Future<void> _onSuccess({
    required List<Uint8List> images,
    required int usedSeed,
    required String time,
    required String dateStr,
    required String timeStr,
  }) async {
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
      await SeedStorage.add(SavedSeed(
        seed: usedSeed,
        date: dateStr,
        time: timeStr,
        promptPreview: zimageBaseCtrl.text.isNotEmpty
            ? zimageBaseCtrl.text.substring(
            0,
            zimageBaseCtrl.text.length > 60
                ? 60
                : zimageBaseCtrl.text.length)
            : '',
        generationTime: time,
      ));
    }

    final genInfo =
    GenerationInfo(seed: usedSeed, time: timeStr, date: dateStr);
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
    await AppSounds.playGenerationComplete();

    if (images.isNotEmpty) {
      await showImageNotification(
          'Генерация завершена',
          'Готово за $time (сид: $usedSeed)',
          images.first);
    } else {
      await showNotification('Генерация завершена', 'Нет результата');
    }

    // Открываем галерею результатов вместо переключения на вкладку истории
    if (images.isNotEmpty && mounted) {
      _showResultGallery(images, genInfo);
    }
  }

  // ===================== ГАЛЕРЕЯ РЕЗУЛЬТАТОВ =====================

  // ===================== ГАЛЕРЕЯ РЕЗУЛЬТАТОВ =====================

  void _showResultGallery(List<Uint8List> images, GenerationInfo info) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return GalleryScreen(
            images: images,
            generationTime: lastTime,
            info: info,
            onRepeat: () {
              Navigator.of(context).pop();
              generate();
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ===================== ГЕНЕРАЦИЯ =====================

  Future<void> generate() async {
    HapticFeedback.mediumImpact();

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

      _generationCompleter = Completer<String?>();

      ws = service.connectWebSocket();
      ws!.stream.listen(
        _handleWsMessage,
        onError: (e) {
          if (_generationCompleter != null &&
              !_generationCompleter!.isCompleted) {
            _generationCompleter!
                .completeError(Exception('WebSocket ошибка: $e'));
          }
        },
        onDone: () {
          if (_generationCompleter != null &&
              !_generationCompleter!.isCompleted) {
            _generationCompleter!.complete(null);
          }
        },
      );

      int? customSeed;
      if (seedCtrl.text.isNotEmpty) customSeed = int.tryParse(seedCtrl.text);

      final workflow = service.buildWorkflow(
        getPromptData(),
        width: width,
        height: height,
        customSeed: customSeed,
        loraGroups: loraGroups,
      );
      final usedSeed = service.lastSeed;
      final promptId = await service.submitPrompt(workflow);

      await BackgroundGenerationService.savePromptId(promptId);
      await BackgroundGenerationService.startTracking(
          serverCtrl.text, promptId);

      setState(() => status = 'Ожидание...');

      String? completedPromptId;
      try {
        completedPromptId = await _generationCompleter!.future
            .timeout(Duration(minutes: _timeoutMinutes));
      } on TimeoutException {
        completedPromptId = null;
      }

      final fetchId = completedPromptId ?? promptId;
      final images = await service.fetchResults(fetchId);

      stopTimer();
      _stopTimeout();
      await dismissProgressNotification();

      final time = fmtTime(elapsed);
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      await _onSuccess(
          images: images,
          usedSeed: usedSeed,
          time: time,
          dateStr: dateStr,
          timeStr: timeStr);
    } catch (e) {
      stopTimer();
      _stopTimeout();
      await dismissProgressNotification();

      String errorMsg;
      if (e is SocketException) {
        errorMsg = 'Нет подключения к серверу';
      } else if (e is TimeoutException) {
        errorMsg = 'Таймаут подключения';
      } else if (e is HttpException) {
        errorMsg = 'HTTP ошибка сервера';
      } else {
        errorMsg = '$e';
      }

      setState(() {
        status = 'Ошибка: $errorMsg';
        isGenerating = false;
        currentNode = '';
        previewImage = null;
      });
      HapticFeedback.heavyImpact();
      await showNotification('Ошибка генерации', errorMsg);
    } finally {
      _generationCompleter = null;
      ws?.sink.close();
      await BackgroundGenerationService.stop();
    }
  }

  Future<void> stopGeneration() async {
    HapticFeedback.lightImpact();
    _stopTimeout();

    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.completeError(Exception('Остановлено пользователем'));
    }

    try {
      final ok = await service.cancelGeneration();
      await BackgroundGenerationService.stop();
      stopTimer();
      await dismissProgressNotification();
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
          _generationCompleter = Completer<String?>();

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
            _handleWsMessage,
            onError: (_) {
              if (_generationCompleter != null &&
                  !_generationCompleter!.isCompleted) {
                _generationCompleter!
                    .completeError(Exception('WebSocket потерян'));
              }
              setState(() {
                isGenerating = false;
                status = 'Соединение потеряно';
                previewImage = null;
              });
              stopTimer();
              _stopTimeout();
            },
            onDone: () {
              if (_generationCompleter != null &&
                  !_generationCompleter!.isCompleted) {
                _generationCompleter!.complete(promptId);
              }
            },
          );

          try {
            await _generationCompleter!.future
                .timeout(Duration(minutes: _timeoutMinutes));
          } catch (_) {}

          await onGenerationComplete(promptId);
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
    if (!mounted) return;
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
          await _onSuccess(
              images: images,
              usedSeed: service.lastSeed,
              time: time,
              dateStr: dateStr,
              timeStr: timeStr);
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
    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.completeError(Exception('disposed'));
    }
  }
}
