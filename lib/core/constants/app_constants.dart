class AppConstants {
  AppConstants._();

  // Notification channel IDs
  static const String zoneEntryChannelId = 'zone_entry';
  static const String zoneEntryChannelName = 'Zone Entry Alerts';
  static const String paymentReminderChannelId = 'payment_reminder';
  static const String paymentReminderChannelName = 'Payment Reminders';
  static const String backgroundChannelId = 'background_service';
  static const String backgroundChannelName = 'Background Tracking';
  static const String motTaxChannelId = 'mot_tax_reminder';
  static const String motTaxChannelName = 'MOT & Tax Reminders';

  // Notification IDs
  static const int backgroundNotificationId = 1;
  static const int zoneEntryNotificationId = 100;
  static const int paymentReminderBaseId = 200;

  // Background service
  static const String bgServicePortName = 'location_service';
  static const int locationUpdateIntervalMs = 15000; // 15 seconds
  static const int locationDistanceFilterM = 50;    // 50 metres

  // Subscription product IDs (Google Play)
  static const String premiumMonthlyId = 'chargeshield_premium_monthly';
  static const String premiumAnnualId = 'chargeshield_premium_annual';

  // Zones that free tier users receive entry alert notifications for.
  // All zones are still detected and logged to history — alerts only.
  static const Set<String> freeAlertZoneIds = {'ulez', 'dartford'};

  // Free tier limits
  static const int freeVehicleLimit = 1;
  static const int freeHistoryDays = 7;
  static const int freeMonthlyAlertLimit = 15;

  // Pro tier limits
  static const int proVehicleLimit = 10;
  static const int proHistoryDays = 365;

  // Payment deadlines (minutes after midnight on next day)
  static const Map<String, int> paymentDeadlines = {
    'ccz': 23 * 60,    // Midnight (23:59) same day or next day
    'ulez': 23 * 60,   // midnight
    'lez': 23 * 60,
  };

  // CCZ operating hours (Mon-Fri 7am-6pm, Sat 12pm-6pm)
  static const Map<String, dynamic> cczOperatingHours = {
    'weekday': {'start': 7, 'end': 18},
    'saturday': {'start': 12, 'end': 18},
    'sunday': null, // free
  };

  // Hive box names
  static const String vehiclesBox = 'vehicles';
  static const String settingsBox = 'settings';

  // Settings keys
  static const String keyTrackingEnabled = 'tracking_enabled';
  static const String keySelectedVehicleId = 'selected_vehicle_id';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyPaymentRemindersEnabled = 'payment_reminders_enabled';
  static const String keyReminderMinutesBefore = 'reminder_minutes_before';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyPremiumActive = 'premium_active';
  static const String keyPremiumPurchaseToken = 'premium_purchase_token';
  static const String keyLicenceKey = 'licence_key';

  // SharedPreferences cache of selected vehicle (readable from background isolate)
  static const String keySelectedVehicleReg = 'selected_vehicle_reg';
  static const String keySelectedVehicleType = 'selected_vehicle_type';
  static const String keySelectedVehicleFuelType = 'selected_vehicle_fuel_type';

  // Debug: when true the location stream uses the legacy LocationManager so that
  // mock GPS apps (Fake Route, etc.) are accepted. Should be OFF for real testing.
  static const String keyMockGpsMode = 'mock_gps_mode';

  // Per-zone notification preferences (SharedPreferences, readable from bg isolate).
  static const String keyNotifyZonePrefix = 'notify_zone_';

  // Per-zone display preferences (controls status card visibility).
  static const String keyDisplayZonePrefix = 'display_zone_';

  // Pro: record exact GPS route through charge zones (stored as JSON in DB).
  static const String keyRecordExactRoute = 'record_exact_route';
}
