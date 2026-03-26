import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../constants/zone_polygons.dart';
import '../services/notification_service.dart';
import '../services/zone_detection_service.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/journey.dart';
import '../../data/models/vehicle.dart';

/// Background location service that runs as a foreground service on Android.
@pragma('vm:entry-point')
class BackgroundLocationService {
  BackgroundLocationService._();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConstants.backgroundChannelId,
        initialNotificationTitle: 'ChargeShield Active',
        initialNotificationContent: 'Monitoring for charge zones...',
        foregroundServiceNotificationId: AppConstants.backgroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<bool> start() async {
    final service = FlutterBackgroundService();
    return service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  static Future<bool> isRunning() => FlutterBackgroundService().isRunning();

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    debugPrint('DEBUG BG: _onStart entered');

    // Firebase must be initialised in every Dart isolate independently.
    // The background service runs in a separate isolate from main(), so
    // Firebase.initializeApp() was never called here — causing every access
    // to FirebaseMessaging.instance to throw and crash _onStart silently.
    try {
      await Firebase.initializeApp();
      debugPrint('DEBUG BG: Firebase initialised');
    } catch (e) {
      // Already initialised in this isolate (shouldn't happen) or failed — safe to continue.
      debugPrint('DEBUG BG: Firebase.initializeApp skipped/failed: $e');
    }

    // Android: switch to foreground mode
    if (service is AndroidServiceInstance) {
      service.on('stop').listen((_) => service.stopSelf());
      service.on('setForeground').listen((_) {
        service.setAsForegroundService();
      });
    }

    final prefs = await SharedPreferences.getInstance();

    // Try to open Hive in this isolate for vehicle lookups.
    // Wrapped in try-catch: if Hive fails (e.g. file contention with main isolate)
    // we fall back to SharedPreferences-cached vehicle data.
    bool hiveAvailable = false;
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(VehicleAdapter());
      await Hive.openBox<Vehicle>(AppConstants.vehiclesBox);
      await Hive.openBox(AppConstants.settingsBox);
      hiveAvailable = true;
    } catch (e) {
      debugPrint('DEBUG BG: Hive init failed: $e');
      hiveAvailable = false;
    }
    debugPrint('DEBUG BG: hiveAvailable=$hiveAvailable');

    // Check location permission before starting stream
    final locationPermission = await Permission.locationWhenInUse.status;
    debugPrint('DEBUG BG: locationPermission=$locationPermission');
    if (!locationPermission.isGranted) {
      service.invoke('permission_error', {'message': 'Location permission not granted'});
      if (service is AndroidServiceInstance) service.stopSelf();
      return;
    }

    // Check location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('DEBUG BG: locationServiceEnabled=$serviceEnabled');
    if (!serviceEnabled) {
      service.invoke('location_error', {'message': 'Location services disabled'});
      if (service is AndroidServiceInstance) service.stopSelf();
      return;
    }

    // Initialise notification service in this isolate so show() works.
    // Wrapped in try-catch: a notification failure must NOT prevent the
    // location stream from starting (journeys can still be logged to DB).
    try {
      await NotificationService.instance.initialize();
      debugPrint('DEBUG BG: NotificationService initialised');
    } catch (e) {
      debugPrint('DEBUG BG: NotificationService init failed (non-fatal): $e');
    }

    // Initialise database in this isolate
    try {
      await DatabaseHelper.instance.database;
      debugPrint('DEBUG BG: Database initialised');
    } catch (e) {
      debugPrint('DEBUG BG: Database init failed (non-fatal): $e');
    }

    // Sanity-check zone detection before starting the stream.
    // The Dartford bridge centre (51.4651, 0.2587) must return inDartford=true.
    final _dartfordTest = ZoneDetectionService.instance.detect(const LatLng(51.4651, 0.2587));
    debugPrint('DEBUG SANITY: Dartford(51.4651,0.2587) → inDartford=${_dartfordTest.inDartford} (expected true)');

    // Start with "outside all zones" so that if tracking begins while already
    // inside a zone the very first position update is treated as an entry.
    ZoneStatus previousStatus = ZoneStatus.empty(const LatLng(0, 0));

    // Read mock GPS mode flag. When true, use legacy LocationManager so mock GPS
    // apps (Fake Route) are accepted. When false (default), use Fused Location
    // Provider which is more reliable on real hardware with screen off.
    final bool mockGpsMode = prefs.getBool(AppConstants.keyMockGpsMode) ?? false;

    // In debug builds always behave as if mock GPS mode is on so that Fake Route
    // and other mock GPS apps work without needing to toggle the setting manually.
    final bool useMockSettings = !kReleaseMode || mockGpsMode;

    // Location stream settings — platform-specific.
    // Android: use AndroidSettings with foreground-service-safe config (no
    // ForegroundNotificationConfig — we're already inside flutter_background_service).
    // iOS: use AppleSettings with automotive activity type for best accuracy.
    final LocationSettings locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: useMockSettings ? 0 : 20,
            intervalDuration: Duration(seconds: useMockSettings ? 3 : 10),
            forceLocationManager: useMockSettings,
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: useMockSettings ? 0 : 20,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );

    debugPrint('DEBUG BG: Starting position stream (mockGpsMode=$mockGpsMode useMockSettings=$useMockSettings kReleaseMode=$kReleaseMode)');

    // Broadcast an immediate one-shot fix so the UI shows a position straight
    // away, without waiting for the first distance-filtered stream event.
    try {
      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (kReleaseMode && !mockGpsMode && initial.isMocked) {
        debugPrint('DEBUG BG: Initial position is mocked — skipping (release mode only)');
      } else {
        final initPoint = LatLng(initial.latitude, initial.longitude);
        final initStatus = ZoneDetectionService.instance.detect(initPoint);
        service.invoke('location', {
          'lat': initial.latitude,
          'lng': initial.longitude,
          'zones': initStatus.activeZoneIds.toList(),
          'timestamp': initStatus.timestamp.toIso8601String(),
        });
        debugPrint('DEBUG BG: Initial position broadcast: ${initial.latitude}, ${initial.longitude}');
      }
    } catch (e) {
      debugPrint('DEBUG BG: Initial position failed (non-fatal): $e');
    }

    // Whether to record GPS route points while inside a zone (Pro feature).
    final bool recordRoute = prefs.getBool(AppConstants.keyRecordExactRoute) ?? false;
    debugPrint('DEBUG BG: recordRoute=$recordRoute');

    // Active journeys: zone_id → DB journey id
    final Map<String, String> activeJourneyIds = {};
    // Route points per active zone: zone_id → [{lat, lng}, ...]
    final Map<String, List<Map<String, double>>> activeRoutes = {};

    // Movement tracking: only log journey entries when the vehicle is actually
    // moving. Prevents false entries when parked at home inside a charge zone.
    LatLng? _lastMovedPoint;
    DateTime? _lastMovedTime;
    const double _minSpeedMs = 1.39; // 5 km/h in m/s
    const double _minMovementM = 200.0; // 200 metres in 5 minutes

    StreamSubscription<Position>? positionSub;

    positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      debugPrint('DEBUG LOC: ${position.latitude}, ${position.longitude} '
          'acc=${position.accuracy.toStringAsFixed(0)}m mocked=${position.isMocked}');

      // Skip mocked positions only in release builds unless mock GPS mode is enabled.
      if (kReleaseMode && !mockGpsMode && position.isMocked) return;

      final LatLng point = LatLng(position.latitude, position.longitude);
      final ZoneStatus current = ZoneDetectionService.instance.detect(point);

      // Broadcast current status to UI
      service.invoke('location', {
        'lat': position.latitude,
        'lng': position.longitude,
        'zones': current.activeZoneIds.toList(),
        'timestamp': current.timestamp.toIso8601String(),
      });

      // Accumulate route points for any currently active zones
      if (recordRoute && activeJourneyIds.isNotEmpty) {
        final pt = {'lat': position.latitude, 'lng': position.longitude};
        for (final zoneId in activeJourneyIds.keys) {
          activeRoutes[zoneId] ??= [];
          activeRoutes[zoneId]!.add(pt);
        }
      }

      // Update movement tracking
      if (position.speed >= _minSpeedMs) {
        _lastMovedPoint = point;
        _lastMovedTime = DateTime.now();
      }
      final bool isMoving = position.speed >= _minSpeedMs ||
          (_lastMovedPoint != null &&
              _lastMovedTime != null &&
              DateTime.now().difference(_lastMovedTime!) <=
                  const Duration(minutes: 5) &&
              Geolocator.distanceBetween(point.latitude, point.longitude,
                      _lastMovedPoint!.latitude, _lastMovedPoint!.longitude) >
                  _minMovementM);

      final entries = ZoneDetectionService.instance.detectEntries(previousStatus, current);
      if (entries.isNotEmpty) {
        debugPrint('DEBUG ENTRY: Zone entries detected: ${entries.map((z) => z.shortName).join(', ')} isMoving=$isMoving');
      }

      // Handle zone exits — update journey with exit time and route
      final exits = ZoneDetectionService.instance.detectExits(previousStatus, current);
      for (final zone in exits) {
        final journeyId = activeJourneyIds.remove(zone.id);
        final route = activeRoutes.remove(zone.id);
        if (journeyId != null) {
          debugPrint('DEBUG EXIT: ${zone.shortName} — closing journey $journeyId');
          try {
            await _closeJourney(
              journeyId: journeyId,
              exitPoint: point,
              routePoints: recordRoute ? route : null,
            );
            debugPrint('DEBUG BG: Journey closed id=$journeyId zone=${zone.id}');
          } catch (e) {
            debugPrint('DEBUG BG: _closeJourney failed for ${zone.id}: $e');
          }
        }
      }

      if (entries.isNotEmpty) {
        // Resolve vehicle identity — prefer Hive, fall back to SharedPreferences cache
        String vehicleReg = prefs.getString(AppConstants.keySelectedVehicleReg) ?? 'Your vehicle';
        String vehicleType = prefs.getString(AppConstants.keySelectedVehicleType) ?? 'car';
        String vehicleFuelType = prefs.getString(AppConstants.keySelectedVehicleFuelType) ?? 'petrol';
        String vehicleEuroStandard = prefs.getString(AppConstants.keySelectedVehicleEuroStandard) ?? '';
        if (hiveAvailable) {
          try {
            final settingsBox = Hive.box(AppConstants.settingsBox);
            final selectedId = settingsBox.get(AppConstants.keySelectedVehicleId) as String?;
            if (selectedId != null) {
              final vehiclesBox = Hive.box<Vehicle>(AppConstants.vehiclesBox);
              final vehicle = vehiclesBox.values
                  .where((v) => v.id == selectedId)
                  .firstOrNull;
              vehicleReg = vehicle?.registration ?? vehicleReg;
              vehicleType = vehicle?.type ?? vehicleType;
              vehicleFuelType = vehicle?.fuelType ?? vehicleFuelType;
              vehicleEuroStandard = vehicle?.euroStandard ?? vehicleEuroStandard;
            }
          } catch (e) {
            debugPrint('DEBUG BG: Hive vehicle lookup failed: $e');
            // keep SharedPreferences fallback values
          }
        }
        debugPrint('DEBUG BG: Vehicle=$vehicleReg type=$vehicleType fuel=$vehicleFuelType euro=$vehicleEuroStandard');

        // Per-day zones (ULEZ, CCZ, LEZ, CAZ): only charge once per calendar day.
        // Per-crossing zones (Dartford, tunnels, M6): always log every crossing.
        final loggableEntries = <ZoneInfo>[];
        for (final zone in entries) {
          if (zone.isCrossing) {
            loggableEntries.add(zone);
          } else {
            try {
              final alreadyToday = await DatabaseHelper.instance
                  .hasTodayEntry(zone.id, vehicleReg);
              if (!alreadyToday) {
                loggableEntries.add(zone);
              } else {
                debugPrint('DEBUG BG: ${zone.shortName} — already charged today, skipping entry+notification');
              }
            } catch (e) {
              loggableEntries.add(zone); // fail-safe: log if DB check throws
              debugPrint('DEBUG BG: hasTodayEntry failed for ${zone.id}: $e');
            }
          }
        }

        // Log journey history only when moving — prevents false entries when
        // parked at home or stationary inside a charge zone boundary.
        if (isMoving) {
          for (final zone in loggableEntries) {
            try {
              final journeyId = await _logZoneEntry(
                  zone, point, vehicleReg, vehicleType, vehicleFuelType, vehicleEuroStandard);
              activeJourneyIds[zone.id] = journeyId;
              if (recordRoute) {
                activeRoutes[zone.id] = [{'lat': point.latitude, 'lng': point.longitude}];
              }
              debugPrint('DEBUG BG: Journey logged id=$journeyId zone=${zone.id}');
            } catch (e, st) {
              debugPrint('DEBUG BG: _logZoneEntry failed for ${zone.id}: $e\n$st');
            }
          }
        } else {
          debugPrint('DEBUG BG: Zone entry detected but vehicle is stationary — skipping history log');
        }

        // Send notification if enabled (or always in debug so we can test).
        // Filter by per-zone preferences — only notify for zones the user wants.
        final notifEnabled = prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;
        debugPrint('DEBUG BG: notifEnabled=$notifEnabled kDebugMode=$kDebugMode');
        if (notifEnabled || kDebugMode) {
          final notifiableEntries = loggableEntries.where((zone) {
            final key = '${AppConstants.keyNotifyZonePrefix}${zone.id}';
            return prefs.getBool(key) ?? true; // default ON if not set
          }).toList();
          if (notifiableEntries.isNotEmpty) {
            final isPremium = hiveAvailable
                ? (Hive.box(AppConstants.settingsBox).get(AppConstants.keyPremiumActive, defaultValue: false) as bool)
                : (prefs.getBool(AppConstants.keyPremiumActive) ?? false);

            // Free tier: only freeAlertZoneIds (ULEZ, Dartford) trigger notifications.
            // Pro tier: all detected zones (London + UK-wide) trigger notifications.
            // All zones are still detected and logged to history regardless.
            final zoneFiltered = isPremium || kDebugMode
                ? notifiableEntries
                : notifiableEntries
                    .where((z) => AppConstants.freeAlertZoneIds.contains(z.id))
                    .toList();

            // Enforce free tier monthly alert cap.
            final alertsAllowed = isPremium || kDebugMode
                ? zoneFiltered
                : _filterByMonthlyLimit(zoneFiltered, prefs);
            if (alertsAllowed.isNotEmpty) {
              try {
                await NotificationService.instance.notifyZoneEntries(
                  alertsAllowed,
                  vehicleReg,
                  vehicleType: vehicleType,
                );
                debugPrint('DEBUG BG: Notification sent for ${alertsAllowed.map((z) => z.shortName).join(', ')}');
              } catch (e) {
                debugPrint('DEBUG BG: Notification failed: $e');
              }
            } else {
              debugPrint('DEBUG BG: Free tier monthly alert limit reached');
            }
          } else {
            debugPrint('DEBUG BG: All entered zones are muted by user preference');
          }
        }

        // Schedule payment reminders if enabled
        if (prefs.getBool(AppConstants.keyPaymentRemindersEnabled) ?? true) {
          final minutesBefore =
              prefs.getInt(AppConstants.keyReminderMinutesBefore) ?? 60;
          for (final zone in loggableEntries) {
            try {
              final deadline = _nextPaymentDeadline(zone.id);
              await NotificationService.instance.schedulePaymentReminder(
                id: zone.id.hashCode,
                zone: zone,
                deadline: deadline,
                minutesBefore: minutesBefore,
              );
            } catch (_) {
              // non-fatal
            }
          }
        }
      }

      previousStatus = current;
    }, onError: (Object e) {
      debugPrint('DEBUG BG: Position stream error: $e');
    });

    // Listen for stop signal
    service.on('stop').listen((_) {
      positionSub?.cancel();
      if (service is AndroidServiceInstance) {
        service.stopSelf();
      }
    });
  }

  /// Returns a filtered list of zones that can still fire alerts under the
  /// free tier monthly cap (15 alerts/month). Increments the counter in prefs.
  /// Fires a one-time "limit reached" notification when the cap is first hit.
  static List<ZoneInfo> _filterByMonthlyLimit(
      List<ZoneInfo> zones, SharedPreferences prefs) {
    final now = DateTime.now();
    final monthKey = 'free_alert_count_${now.year}_${now.month}';
    final notifiedKey = 'free_alert_limit_notified_${now.year}_${now.month}';
    int used = prefs.getInt(monthKey) ?? 0;
    final remaining = AppConstants.freeMonthlyAlertLimit - used;
    if (remaining <= 0) {
      // Show one-time "limit reached" notification
      if (!(prefs.getBool(notifiedKey) ?? false)) {
        prefs.setBool(notifiedKey, true);
        NotificationService.instance.showZoneEntry(
          title: 'Free alert limit reached',
          body: "You've used all 15 free alerts this month. Upgrade to Pro for unlimited alerts.",
        );
      }
      return [];
    }
    final allowed = zones.take(remaining).toList();
    prefs.setInt(monthKey, used + allowed.length);
    return allowed;
  }

  static Future<String> _logZoneEntry(ZoneInfo zone, LatLng position,
      String vehicleReg, String vehicleType, String vehicleFuelType,
      String vehicleEuroStandard) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    double charge = zone.chargeFor(vehicleType);

    final isElectricOrHybrid = vehicleFuelType == 'electric' ||
        vehicleFuelType == 'hybrid' ||
        vehicleFuelType == 'phev';

    // ULEZ: full compliance check including Euro standard.
    // Electric/PHEV always exempt. Petrol/hybrid Euro 4+ exempt. Diesel Euro 6 only.
    if (zone.id == 'ulez' && charge > 0.0) {
      if (_isUlezCompliant(vehicleFuelType, vehicleEuroStandard)) charge = 0.0;
    }

    // CCZ: electric, hybrid, PHEV are exempt.
    if (zone.id == 'ccz' && charge > 0.0 && isElectricOrHybrid) {
      charge = 0.0;
    }

    // UK CAZ zones (Bath, Birmingham, Bradford, Portsmouth, Bristol):
    // electric and PHEV are exempt from daily CAZ charges.
    const _cazZoneIds = {'birmingham', 'bath', 'portsmouth', 'bradford', 'bristol'};
    if (_cazZoneIds.contains(zone.id) && charge > 0.0 && isElectricOrHybrid) {
      charge = 0.0;
    }

    // Free overnight for road tunnels/crossings (22:00–06:00 daily).
    const _overnightFreeZones = {'dartford', 'silvertown', 'blackwall'};
    if (_overnightFreeZones.contains(zone.id) && _isCrossingFreeNow()) {
      charge = 0.0;
    }

    // Auto-set exempt when charge is zero (free vehicle type, or fuel-based exemption).
    final paymentStatus = charge == 0.0 ? PaymentStatus.exempt : PaymentStatus.unpaid;
    debugPrint('DEBUG BG: _logZoneEntry zone=${zone.id} charge=$charge status=$paymentStatus');
    final db = DatabaseHelper.instance;
    await db.insertJourney(Journey(
      id: id,
      vehicleRegistration: vehicleReg,
      zoneId: zone.id,
      zoneName: zone.shortName,
      entryTime: DateTime.now(),
      entryLat: position.latitude,
      entryLng: position.longitude,
      charge: charge,
      paymentStatus: paymentStatus,
    ));
    return id;
  }

  static Future<void> _closeJourney({
    required String journeyId,
    required LatLng exitPoint,
    List<Map<String, double>>? routePoints,
  }) async {
    final db = DatabaseHelper.instance;
    final journey = await db.getJourneyById(journeyId);
    if (journey == null) return;
    journey.exitTime = DateTime.now();
    journey.exitLat = exitPoint.latitude;
    journey.exitLng = exitPoint.longitude;
    journey.routePoints = routePoints;
    await db.updateJourney(journey);
  }

  /// Returns true if the vehicle is ULEZ-compliant (no charge applies).
  /// Mirrors Vehicle.isUlezCompliant in vehicle.dart.
  static bool _isUlezCompliant(String fuelType, String euroStandard) {
    if (fuelType == 'electric' || fuelType == 'phev') return true;
    if (fuelType == 'petrol' || fuelType == 'hybrid') {
      return euroStandard == 'Euro 4' ||
          euroStandard == 'Euro 5' ||
          euroStandard == 'Euro 6';
    }
    if (fuelType == 'diesel') return euroStandard == 'Euro 6';
    return false;
  }

  /// Returns true if it's currently the overnight free window (22:00–06:00).
  /// Dartford, Silvertown, and Blackwall tunnels are free during this window.
  static bool _isCrossingFreeNow() {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 6;
  }

  static DateTime _nextPaymentDeadline(String zoneId) {
    final now = DateTime.now();
    final today2359 = DateTime(now.year, now.month, now.day, 23, 59);
    switch (zoneId) {
      case 'ccz':
        // Pay by midnight on the third day after entry
        return DateTime(now.year, now.month, now.day + 3, 23, 59);
      case 'dartford':
        // Pay by midnight the day after crossing
        return today2359.add(const Duration(days: 1));
      case 'silvertown':
      case 'blackwall':
        // Pay by midnight same day
        return now.isBefore(today2359) ? today2359 : today2359.add(const Duration(days: 1));
      case 'm6_toll_north':
      case 'm6_toll_south':
        // Immediate at point of crossing
        return now;
      default:
        // ULEZ, LEZ, CAZ zones: pay by midnight same day
        return now.isBefore(today2359) ? today2359 : today2359.add(const Duration(days: 1));
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
