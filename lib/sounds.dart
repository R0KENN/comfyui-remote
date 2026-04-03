// lib/sounds.dart

import 'package:flutter/services.dart';

class AppSounds {
  static Future<void> playGenerationComplete() async {
    await SystemSound.play(SystemSoundType.alert);
  }

  static void dispose() {}
}
