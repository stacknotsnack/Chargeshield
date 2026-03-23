import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'data/database/database_helper.dart';
import 'data/models/vehicle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each step is individually wrapped — a failure in one must never prevent
  // runApp() from being reached, otherwise the app appears to crash on launch.

  try {
    await Firebase.initializeApp();
  } catch (_) {}

  try {
    await Hive.initFlutter();
    Hive.registerAdapter(VehicleAdapter());
    await Hive.openBox<Vehicle>('vehicles');
    await Hive.openBox('settings');
  } catch (_) {}

  try {
    await DatabaseHelper.instance.database;
  } catch (_) {}

  // Notification channels — POST_NOTIFICATIONS permission is requested later
  // in the onboarding screen (after runApp) to avoid an activity-restart crash
  // on Android 13+ when the system dialog fires before Flutter renders.
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  try {
    await BackgroundLocationService.initialize();
  } catch (_) {}

  runApp(const ProviderScope(child: ChargeShieldApp()));
}
