// lib/sounds.dart

import 'package:audioplayers/audioplayers.dart';

class AppSounds {
  static final AudioPlayer _player = AudioPlayer();

  /// Короткий звук завершения генерации
  static Future<void> playGenerationComplete() async {
    try {
      await _player.setVolume(0.7);
      // Системный звук уведомления
      await _player.play(
        AssetSource('sounds/complete.mp3'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Если файла нет — молча игнорируем
    }
  }

  static void dispose() {
    _player.dispose();
  }
}
