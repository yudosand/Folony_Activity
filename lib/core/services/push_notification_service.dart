import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

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

  Future<void> dispose() async {
    await _tokenStreamController.close();
  }
}
