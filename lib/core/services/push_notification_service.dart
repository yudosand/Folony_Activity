import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const int _checkInReminderId = 83025;
  static const int _checkOutReminderId = 170055;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tokenStreamController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String? _currentToken;

  Stream<String> get tokenStream => _tokenStreamController.stream;
  String? get currentToken => _currentToken;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidChannel = AndroidNotificationChannel(
      'approval_notifications',
      'Approval Notifications',
      description: 'Notifikasi approval cuti dan WFH/WFA.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'attendance_reminders',
            'Attendance Reminders',
            description: 'Pengingat absensi masuk dan keluar.',
            importance: Importance.high,
          ),
        );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _currentToken = await FirebaseMessaging.instance.getToken();
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      _tokenStreamController.add(_currentToken!);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _currentToken = token;
      _tokenStreamController.add(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) {
        return;
      }

      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'Approval baru',
        notification.body ?? 'Ada update approval baru.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'approval_notifications',
            'Approval Notifications',
            channelDescription: 'Notifikasi approval cuti dan WFH/WFA.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    _initialized = true;
  }

  Future<String?> ensureToken() async {
    if (!_initialized) {
      await initialize();
    }

    _currentToken ??= await FirebaseMessaging.instance.getToken();
    return _currentToken;
  }

  Future<void> scheduleStaffAttendanceReminders({
    required String checkInTime,
    required String checkOutTime,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    await cancelAttendanceReminders();
    await _scheduleDailyReminder(
      id: _checkInReminderId,
      scheduledAt: _timeMinusMinutes(checkInTime, 5),
      title: 'Pengingat absen masuk',
      body: '5 menit lagi waktunya absen masuk. Jangan lupa absen ya!',
    );
    await _scheduleDailyReminder(
      id: _checkOutReminderId,
      scheduledAt: _timeMinusMinutes(checkOutTime, 5),
      title: 'Pengingat absen keluar',
      body:
          '5 menit lagi waktunya absen keluar. Jangan lupa absen sebelum meninggalkan area kerja!',
    );
  }

  Future<void> cancelAttendanceReminders() async {
    await _localNotifications.cancel(_checkInReminderId);
    await _localNotifications.cancel(_checkOutReminderId);
  }

  Future<void> _scheduleDailyReminder({
    required int id,
    required ({int hour, int minute}) scheduledAt,
    required String title,
    required String body,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(scheduledAt.hour, scheduledAt.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_reminders',
          'Attendance Reminders',
          channelDescription: 'Pengingat absensi masuk dan keluar.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  ({int hour, int minute}) _timeMinusMinutes(String hhmm, int minutes) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final base = DateTime(2026, 1, 1, hour, minute).subtract(
      Duration(minutes: minutes),
    );

    return (hour: base.hour, minute: base.minute);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> dispose() async {
    await _tokenStreamController.close();
  }
}
