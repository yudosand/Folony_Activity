import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.initialize();
  runApp(const HexActivityApp());
}
