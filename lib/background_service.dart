class BackgroundGenerationService {
  static Future<void> initialize() async {}

  static Future<void> startGeneration({
    required String serverUrl,
    required String workflow,
  }) async {}

  static Future<Map<String, dynamic>?> getCompletedResult() async => null;

  static Future<Map<String, dynamic>?> getPendingResult() async => null;

  static bool isRunning() => false;

  static void listen(Function(Map<String, dynamic>) callback) {}

  static Future<void> startTracking(String serverUrl, String clientId) async {}

  static Future<void> stop() async {}

  static Stream<Map<String, dynamic>> get onComplete => const Stream.empty();
}

Future<void> initBackgroundService() async {}
