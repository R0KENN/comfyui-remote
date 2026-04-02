// lib/background_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class BackgroundGenerationService {
  static const _keyServerUrl = 'bg_gen_server_url';
  static const _keyPromptId = 'bg_gen_prompt_id';
  static const _keyClientId = 'bg_gen_client_id';
  static const _keyStartTime = 'bg_gen_start_time';
  static const _keyRunning = 'bg_gen_running';

  static final _completeController =
  StreamController<Map<String, dynamic>>.broadcast();

  static Timer? _pollTimer;
  static bool _isRunning = false;
  static String? _currentServerUrl;
  static String? _currentPromptId;

  // ── Инициализация ──

  static Future<void> initialize() async {
    // Проверяем, не было ли незавершённой генерации при прошлом запуске
    final prefs = await SharedPreferences.getInstance();
    _isRunning = prefs.getBool(_keyRunning) ?? false;
    _currentServerUrl = prefs.getString(_keyServerUrl);
    _currentPromptId = prefs.getString(_keyPromptId);
  }

  // ── Начать отслеживание генерации ──

  static Future<void> startTracking(
      String serverUrl, String clientId) async {
    // Этот метод вызывается из старого кода, но promptId передаётся
    // отдельно через startGeneration. Сохраняем serverUrl и clientId.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, serverUrl);
    await prefs.setString(_keyClientId, clientId);
  }

  static Future<void> startGeneration({
    required String serverUrl,
    required String workflow,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, serverUrl);
    await prefs.setBool(_keyRunning, true);
    _currentServerUrl = serverUrl;
    _isRunning = true;
  }

  // ── Сохранить promptId после отправки ──

  static Future<void> savePromptId(String promptId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPromptId, promptId);
    await prefs.setInt(_keyStartTime, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_keyRunning, true);
    _currentPromptId = promptId;
    _isRunning = true;

    // Запускаем polling — если приложение ещё в foreground,
    // completion придёт через основной WebSocket;
    // если приложение вернулось из фона — polling подхватит.
    _startPolling();
  }

  // ── Polling: проверяем готовность на сервере ──

  static void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkCompletion();
    });
  }

  static Future<void> _checkCompletion() async {
    if (_currentServerUrl == null || _currentPromptId == null) return;

    try {
      final resp = await http
          .get(Uri.parse('$_currentServerUrl/history/$_currentPromptId'))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final history = jsonDecode(resp.body) as Map<String, dynamic>;
        if (history.containsKey(_currentPromptId)) {
          // Генерация завершена — результат есть в history
          _completeController.add({
            'serverUrl': _currentServerUrl!,
            'promptId': _currentPromptId!,
          });
          await stop();
        }
      }
    } catch (_) {
      // Сервер недоступен — продолжаем polling
    }
  }

  // ── Получить незавершённый результат (при возврате из фона) ──

  static Future<Map<String, dynamic>?> getPendingResult() async {
    final prefs = await SharedPreferences.getInstance();
    final running = prefs.getBool(_keyRunning) ?? false;
    if (!running) return null;

    final serverUrl = prefs.getString(_keyServerUrl);
    final promptId = prefs.getString(_keyPromptId);
    if (serverUrl == null || promptId == null) return null;

    // Проверяем, завершилась ли генерация
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/history/$promptId'))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final history = jsonDecode(resp.body) as Map<String, dynamic>;
        if (history.containsKey(promptId)) {
          // Генерация завершена пока приложение было в фоне
          return {
            'serverUrl': serverUrl,
            'promptId': promptId,
          };
        }
      }
    } catch (_) {}

    // Ещё не завершена — запускаем polling
    _currentServerUrl = serverUrl;
    _currentPromptId = promptId;
    _isRunning = true;
    _startPolling();

    return null;
  }

  // ── Получить завершённый результат ──

  static Future<Map<String, dynamic>?> getCompletedResult() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_keyServerUrl);
    final promptId = prefs.getString(_keyPromptId);
    final running = prefs.getBool(_keyRunning) ?? false;

    if (!running || serverUrl == null || promptId == null) return null;

    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/history/$promptId'))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final history = jsonDecode(resp.body) as Map<String, dynamic>;
        if (history.containsKey(promptId)) {
          await stop();
          return {
            'serverUrl': serverUrl,
            'promptId': promptId,
          };
        }
      }
    } catch (_) {}

    return null;
  }

  // ── Статус ──

  static bool isRunning() => _isRunning;

  // ── Подписка на завершение ──

  static void listen(Function(Map<String, dynamic>) callback) {
    _completeController.stream.listen(callback);
  }

  static Stream<Map<String, dynamic>> get onComplete =>
      _completeController.stream;

  // ── Остановка ──

  static Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isRunning = false;
    _currentServerUrl = null;
    _currentPromptId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRunning, false);
    await prefs.remove(_keyPromptId);
    await prefs.remove(_keyStartTime);
  }
}

Future<void> initBackgroundService() async {
  await BackgroundGenerationService.initialize();
}
