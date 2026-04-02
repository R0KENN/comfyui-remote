import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'background_service.dart';

final FlutterLocalNotificationsPlugin notifications =
FlutterLocalNotificationsPlugin();

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
