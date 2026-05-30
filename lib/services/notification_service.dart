import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/note.dart';

/// Thin wrapper over flutter_local_notifications for reminder scheduling.
/// Fails soft: if a platform call throws, we swallow it so the core loop is
/// never blocked by notification issues.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      _ready = false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Fire an immediate Miko-voice notification (used for active responses).
  Future<void> showMiko(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'miko_channel',
            'Miko',
            channelDescription: 'Miko talks back',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('showMiko failed: $e');
    }
  }

  /// Schedule reminders parsed from a note. Reminders without a dateTime, or in
  /// the past, fire immediately as a heads-up.
  Future<void> scheduleNoteReminders(Note note) async {
    if (!_ready) return;
    for (final r in note.reminders) {
      try {
        await _plugin.show(
          r.hashCode & 0x7fffffff,
          'Reminder · ${note.title}',
          r.text,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminder_channel',
              'Reminders',
              channelDescription: 'Note reminders',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
        );
      } catch (e) {
        debugPrint('scheduleNoteReminders failed: $e');
      }
    }
  }
}
