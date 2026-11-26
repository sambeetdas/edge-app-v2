import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';

const String _dailySummaryTaskName = 'edged_daily_summary';
const String _reminderTaskPrefix = 'edged_reminder_';

@pragma('vm:entry-point')
void edgedWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    final title = (inputData?['title'] as String?) ?? 'Edged Daily Briefing';
    final body = (inputData?['body'] as String?) ??
        'Open Edged to review your offline chats, knowledge docs, and reminders.';
    final payload = inputData?['payload'] as String?;

    await plugin.show(
      id: task.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'edged_proactive',
          'Edged Proactive Assistant',
          channelDescription: 'Offline reminders, scheduled agents, and briefings',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
    return true;
  });
}

class ProactiveReminderEntity {
  final String id;
  final String title;
  final DateTime triggerAt;
  final bool isCompleted;
  final DateTime createdAt;

  const ProactiveReminderEntity({
    required this.id,
    required this.title,
    required this.triggerAt,
    required this.isCompleted,
    required this.createdAt,
  });

  factory ProactiveReminderEntity.fromMap(Map<String, Object?> map) {
    return ProactiveReminderEntity(
      id: map['Id'] as String,
      title: map['Title'] as String,
      triggerAt: DateTime.parse(map['TriggerAt'] as String),
      isCompleted: (map['IsCompleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
    );
  }
}

/// 100% offline Proactive Assistant: local reminders, daily briefing, and Workmanager tasks.
class ProactiveService {
  final AppDatabase _db;
  static const _uuid = Uuid();
  static bool _initialized = false;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  ProactiveService(this._db);

  static Future<void> initializeBackground() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    _initialized = true;
    await Workmanager().initialize(edgedWorkmanagerDispatcher);
  }

  Future<void> ensureNotificationsReady() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final uri = Uri.tryParse(payload);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  /// Schedules a local notification that opens [actionUrl] (e.g. mailto: or wa.me) on tap.
  Future<void> scheduleActionNotification({
    required String title,
    required String body,
    required Duration delay,
    required String actionUrl,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final id = _uuid.v4();
    await initializeBackground();
    await ensureNotificationsReady();
    await Workmanager().registerOneOffTask(
      '$_reminderTaskPrefix$id',
      '$_reminderTaskPrefix$id',
      initialDelay: delay,
      inputData: {
        'title': title,
        'body': body,
        'payload': actionUrl,
      },
    );
  }

  Future<List<ProactiveReminderEntity>> getReminders() async {
    final db = await _db.database;
    final rows = await db.query(
      'ProactiveReminderEntity',
      orderBy: 'TriggerAt ASC',
    );
    return rows.map(ProactiveReminderEntity.fromMap).toList();
  }

  Future<ProactiveReminderEntity> addReminder({
    required String title,
    required Duration delay,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc();
    final triggerAt = now.add(delay);
    final id = _uuid.v4();

    await db.insert('ProactiveReminderEntity', {
      'Id': id,
      'Title': title,
      'TriggerAt': triggerAt.toIso8601String(),
      'IsCompleted': 0,
      'CreatedAt': now.toIso8601String(),
    });

    if (!kIsWeb && Platform.isAndroid) {
      await initializeBackground();
      await ensureNotificationsReady();
      await Workmanager().registerOneOffTask(
        '$_reminderTaskPrefix$id',
        '$_reminderTaskPrefix$id',
        initialDelay: delay,
        inputData: {
          'title': 'Edged Reminder',
          'body': title,
        },
      );
    }

    return ProactiveReminderEntity(
      id: id,
      title: title,
      triggerAt: triggerAt,
      isCompleted: false,
      createdAt: now,
    );
  }

  Future<void> toggleCompleted(String id, bool completed) async {
    final db = await _db.database;
    await db.update(
      'ProactiveReminderEntity',
      {'IsCompleted': completed ? 1 : 0},
      where: 'Id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteReminder(String id) async {
    final db = await _db.database;
    await db.delete(
      'ProactiveReminderEntity',
      where: 'Id = ?',
      whereArgs: [id],
    );
    if (!kIsWeb && Platform.isAndroid) {
      await Workmanager().cancelByUniqueName('$_reminderTaskPrefix$id');
    }
  }

  Future<void> setDailyBriefingEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await initializeBackground();
    await ensureNotificationsReady();
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        _dailySummaryTaskName,
        _dailySummaryTaskName,
        frequency: const Duration(hours: 24),
        inputData: const {
          'title': 'Edged Daily Summary',
          'body': 'Tap to view your offline activity & pending reminders.',
        },
      );
    } else {
      await Workmanager().cancelByUniqueName(_dailySummaryTaskName);
    }
  }

  Future<void> sendInstantTestNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await ensureNotificationsReady();
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'edged_proactive',
          'Edged Proactive Assistant',
          channelDescription: 'Offline reminders and daily summaries',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
