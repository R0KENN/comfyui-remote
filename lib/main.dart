import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'background_service.dart';

final FlutterLocalNotificationsPlugin notifications =
FlutterLocalNotificationsPlugin();

/// Обычное уведомление (текст)
Future<void> showNotification(String title, String body) async {
  const details = AndroidNotificationDetails(
    'comfyui_channel',
    'Генерация',
    channelDescription: 'Уведомления о генерации',
    importance: Importance.high,
    priority: Priority.high,
  );
  await notifications.show(
      0, title, body, const NotificationDetails(android: details));
}

/// Уведомление с превью-картинкой (BigPicture)
Future<void> showImageNotification(
    String title, String body, Uint8List imageBytes) async {
  try {
    final dir = await getTemporaryDirectory();
    // Фиксированное имя — всегда перезаписывается
    final file = File('${dir.path}/notif_preview.png');
    await file.writeAsBytes(imageBytes);

    final details = AndroidNotificationDetails(
      'comfyui_channel',
      'Генерация',
      channelDescription: 'Уведомления о генерации',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigPictureStyleInformation(
        FilePathAndroidBitmap(file.path),
        contentTitle: title,
        summaryText: body,
        hideExpandedLargeIcon: false,
      ),
      largeIcon: FilePathAndroidBitmap(file.path),
    );
    await notifications.show(
        0, title, body, NotificationDetails(android: details));
  } catch (_) {
    await showNotification(title, body);
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidSettings),
  );
  await initBackgroundService();
  runApp(const ComfyRemoteApp());
}
