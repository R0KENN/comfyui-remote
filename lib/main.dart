import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'background_service.dart';

final FlutterLocalNotificationsPlugin notifications =
FlutterLocalNotificationsPlugin();

/// ID уведомлений
const int _progressNotifId = 1;
const int _resultNotifId = 0;

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
      _resultNotifId, title, body, const NotificationDetails(android: details));
}

/// Уведомление с превью-картинкой (BigPicture)
Future<void> showImageNotification(
    String title, String body, Uint8List imageBytes) async {
  // Убираем прогресс-уведомление
  await dismissProgressNotification();
  try {
    final dir = await getTemporaryDirectory();
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
        _resultNotifId, title, body, NotificationDetails(android: details));
  } catch (_) {
    await showNotification(title, body);
  }
}

/// Уведомление с прогресс-баром (ongoing)
Future<void> showProgressNotification({
  required String title,
  required String body,
  required int progress,
  required int maxProgress,
}) async {
  final details = AndroidNotificationDetails(
    'comfyui_progress_channel',
    'Прогресс генерации',
    channelDescription: 'Прогресс текущей генерации',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    showProgress: true,
    maxProgress: maxProgress,
    progress: progress,
    onlyAlertOnce: true,
    category: AndroidNotificationCategory.progress,
  );
  await notifications.show(
      _progressNotifId, title, body, NotificationDetails(android: details));
}

/// Убрать прогресс-уведомление
Future<void> dismissProgressNotification() async {
  await notifications.cancel(_progressNotifId);
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
