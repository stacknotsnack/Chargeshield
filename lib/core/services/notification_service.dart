import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../constants/zone_polygons.dart';

/// Handles "Pay now →" taps from notification action buttons.
/// Must be a top-level function so it can run in the background isolate.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  _openPayUrl(response.payload);
}

void _openPayUrl(String? url) {
  if (url != null && url.isNotEmpty) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Handles both local (zone entry, payment reminders) and FCM push notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/London'));

    // Android init settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    await _createChannels();
    await _setupFCM();
  }

  Future<void> _createChannels() async {
    const AndroidNotificationChannel zoneChannel = AndroidNotificationChannel(
      AppConstants.zoneEntryChannelId,
      AppConstants.zoneEntryChannelName,
      description: 'Alerts when you enter a London charge zone.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      AppConstants.paymentReminderChannelId,
      AppConstants.paymentReminderChannelName,
      description: 'Reminds you to pay before the deadline.',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel bgChannel = AndroidNotificationChannel(
      AppConstants.backgroundChannelId,
      AppConstants.backgroundChannelName,
      description: 'Persistent notification while ChargeShield tracks your location.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    const AndroidNotificationChannel motTaxChannel = AndroidNotificationChannel(
      AppConstants.motTaxChannelId,
      AppConstants.motTaxChannelName,
      description: 'Reminders for upcoming MOT and road tax renewals.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final plugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(zoneChannel);
    await plugin?.createNotificationChannel(reminderChannel);
    await plugin?.createNotificationChannel(bgChannel);
    await plugin?.createNotificationChannel(motTaxChannel);
  }

  Future<void> _setupFCM() async {
    try {
      // Handle foreground FCM messages (main isolate only — no-op in background)
      // Permission is requested in the onboarding screen after runApp().
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showZoneEntry(
            title: notification.title ?? 'ChargeShield',
            body: notification.body ?? '',
          );
        }
      });
    } catch (e) {
      // FCM setup may fail in background isolate if Firebase state differs —
      // local notifications still work without it.
      debugPrint('NotificationService: FCM setup skipped: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    _openPayUrl(response.payload);
  }

  // ---------------------------------------------------------------------------
  // Zone entry notification
  // ---------------------------------------------------------------------------
  Future<void> showZoneEntry({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConstants.zoneEntryChannelId,
      AppConstants.zoneEntryChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    await _local.show(
      AppConstants.zoneEntryNotificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> notifyZoneEntries(
    List<ZoneInfo> zones,
    String vehicleReg, {
    String vehicleType = 'car',
  }) async {
    if (zones.isEmpty) return;

    for (final zone in zones) {
      final double charge = zone.chargeFor(vehicleType);
      final bool isFree = charge == 0.0;

      final String chargeText = isFree
          ? 'No charge for your vehicle.'
          : '£${charge.toStringAsFixed(2)} per ${zone.isCrossing ? 'crossing' : 'day'}.';

      final String deadline = _paymentDeadline(zone);

      final String title = '${zone.shortName} – $vehicleReg';
      final String body = isFree
          ? '${zone.name} detected. $chargeText'
          : '${zone.name} detected. $chargeText $deadline';

      // Use a stable per-zone notification ID so entering multiple zones
      // simultaneously shows separate notifications.
      final int notifId = AppConstants.zoneEntryNotificationId +
          (zone.id.hashCode.abs() % 900);

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        AppConstants.zoneEntryChannelId,
        AppConstants.zoneEntryChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        styleInformation: BigTextStyleInformation(body),
        actions: isFree || zone.payUrl.isEmpty
            ? const []
            : const [
                AndroidNotificationAction(
                  'pay',
                  'Pay now →',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ],
      );

      await _local.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: zone.payUrl,
      );
    }
  }

  String _paymentDeadline(ZoneInfo zone) {
    switch (zone.id) {
      case 'dartford':
      case 'silvertown':
      case 'blackwall':
        return 'Pay by midnight tomorrow.';
      case 'ccz':
        return 'Pay by midnight tonight.';
      case 'ulez':
        return 'Pay by midnight tonight.';
      case 'lez':
        return 'Pay by midnight tonight.';
      default:
        // CAZ zones and tolls
        return 'Pay by midnight today.';
    }
  }

  // ---------------------------------------------------------------------------
  // Payment reminder (scheduled)
  // ---------------------------------------------------------------------------
  Future<void> schedulePaymentReminder({
    required int id,
    required ZoneInfo zone,
    required DateTime deadline,
    required int minutesBefore,
  }) async {
    final reminderTime = deadline.subtract(Duration(minutes: minutesBefore));
    if (reminderTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConstants.paymentReminderChannelId,
      AppConstants.paymentReminderChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    await _local.zonedSchedule(
      AppConstants.paymentReminderBaseId + id,
      '${zone.shortName} Payment Reminder',
      'Pay your ${zone.name} charge before ${_formatTime(deadline)}. £${zone.dailyCharge.toStringAsFixed(2)}',
      tz.TZDateTime.from(reminderTime, tz.getLocation('Europe/London')),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: zone.payUrl,
    );
  }

  Future<void> cancelPaymentReminder(int id) async {
    await _local.cancel(AppConstants.paymentReminderBaseId + id);
  }

  Future<void> cancelAll() async {
    await _local.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Persistent background notification (foreground service)
  // ---------------------------------------------------------------------------
  static const AndroidNotificationDetails backgroundDetails =
      AndroidNotificationDetails(
    AppConstants.backgroundChannelId,
    AppConstants.backgroundChannelName,
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    icon: '@drawable/ic_notification',
  );

  static const NotificationDetails backgroundNotification =
      NotificationDetails(android: backgroundDetails);

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // MOT & Tax reminder notifications (Pro feature)
  // ---------------------------------------------------------------------------

  /// Schedules all six MOT+Tax reminders (30d/7d/1d before each).
  /// Safe to call multiple times — cancels previous before re-scheduling.
  Future<void> scheduleMotTaxReminders({
    required String registration,
    required String nickname,
    required DateTime? motExpiry,
    required DateTime? taxDue,
  }) async {
    await cancelMotTaxReminders(registration);

    final reg = registration.replaceAll(' ', '').toUpperCase();
    final base = reg.hashCode.abs() & 0xFFFF;

    if (motExpiry != null) {
      final reminders = [
        (30, base + 1000, 'MOT Reminder — $registration',
            'Your MOT on $registration expires in 30 days — book now to avoid a fine'),
        (7,  base + 2000, '⚠ MOT on $registration expires in 7 days!',
            'Book your MOT now before it expires'),
        (1,  base + 3000, '🚨 MOT on $registration expires TOMORROW',
            'Your MOT expires tomorrow — book immediately'),
      ];
      for (final (days, id, title, body) in reminders) {
        await _scheduleMotTax(
          id: id,
          title: title,
          body: body,
          triggerDate: motExpiry.subtract(Duration(days: days)),
        );
      }
    }

    if (taxDue != null) {
      final reminders = [
        (30, base + 4000, 'Road Tax Reminder — $registration',
            'Road tax on $registration is due in 30 days'),
        (7,  base + 5000, '⚠ Road tax on $registration due in 7 days',
            'Renew your road tax to avoid a fine'),
        (1,  base + 6000, '🚨 Road tax on $registration due TOMORROW',
            'Renew your road tax immediately'),
      ];
      for (final (days, id, title, body) in reminders) {
        await _scheduleMotTax(
          id: id,
          title: title,
          body: body,
          triggerDate: taxDue.subtract(Duration(days: days)),
        );
      }
    }
  }

  Future<void> _scheduleMotTax({
    required int id,
    required String title,
    required String body,
    required DateTime triggerDate,
  }) async {
    if (triggerDate.isBefore(DateTime.now())) return;
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        AppConstants.motTaxChannelId,
        AppConstants.motTaxChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
      );
      await _local.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(triggerDate, tz.getLocation('Europe/London')),
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'nav://vehicles',
      );
    } catch (e) {
      debugPrint('NotificationService: MOT/tax schedule failed id=$id: $e');
    }
  }

  Future<void> cancelMotTaxReminders(String registration) async {
    final reg = registration.replaceAll(' ', '').toUpperCase();
    final base = reg.hashCode.abs() & 0xFFFF;
    for (final offset in [1000, 2000, 3000, 4000, 5000, 6000]) {
      await _local.cancel(base + offset);
    }
  }
}
