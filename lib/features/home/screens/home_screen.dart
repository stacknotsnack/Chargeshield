import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/zone_prefs_provider.dart';
import '../../../core/services/background_service.dart';
import '../../../core/services/zone_detection_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/vehicle.dart';
import '../../vehicles/providers/vehicles_provider.dart';
import '../../history/providers/history_provider.dart';
import '../widgets/zone_status_card.dart';
import '../widgets/vehicle_selector.dart';

/// Live location data from background service.
final _locationProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final _trackingProvider = StateProvider<bool>((ref) {
  final box = Hive.box(AppConstants.settingsBox);
  return box.get(AppConstants.keyTrackingEnabled, defaultValue: false) as bool;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription? _locationSub;
  StreamSubscription? _errorSub;
  Timer? _serviceCheckTimer;

  @override
  void initState() {
    super.initState();
    _listenToService();
    _syncTrackingState();
    // Always get a fresh position on open so the status card never shows stale
    // or missing data, regardless of whether the background service is running.
    _bootstrapLocation();
    // Periodically sync UI with actual service running state
    _serviceCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _syncTrackingState();
    });
  }

  /// Reads isRunning() and updates the provider to match reality.
  Future<void> _syncTrackingState() async {
    final running = await BackgroundLocationService.isRunning();
    if (mounted) {
      ref.read(_trackingProvider.notifier).state = running;
      if (!running) {
        // Keep Hive in sync too
        Hive.box(AppConstants.settingsBox).put(AppConstants.keyTrackingEnabled, false);
      } else if (ref.read(_locationProvider) == null) {
        // Service is running but hasn't broadcast a location to this UI session
        // yet (e.g. app was reopened). Get a one-shot fix to populate the card.
        _bootstrapLocation();
      }
    }
  }

  /// Gets an immediate GPS position and updates the zone status card.
  /// Only used as a fallback when the background service hasn't broadcast yet.
  Future<void> _bootstrapLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final status = ZoneDetectionService.instance.detect(
        LatLng(pos.latitude, pos.longitude),
      );
      ref.read(_locationProvider.notifier).state = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'zones': status.activeZoneIds.toList(),
        'timestamp': status.timestamp.toIso8601String(),
      };
    } catch (_) {
      // GPS unavailable — leave card as "Waiting for location"
    }
  }

  void _listenToService() {
    _locationSub = FlutterBackgroundService()
        .on('location')
        .listen((event) {
      if (event != null && mounted) {
        ref.read(_locationProvider.notifier).state = event;
      }
    });

    // If background service reports an error, reflect that in UI
    _errorSub = FlutterBackgroundService()
        .on('permission_error')
        .listen((_) {
      if (mounted) {
        ref.read(_trackingProvider.notifier).state = false;
        Hive.box(AppConstants.settingsBox).put(AppConstants.keyTrackingEnabled, false);
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _errorSub?.cancel();
    _serviceCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    final box = Hive.box(AppConstants.settingsBox);
    final isRunning = await BackgroundLocationService.isRunning();

    if (isRunning) {
      await BackgroundLocationService.stop();
      await box.put(AppConstants.keyTrackingEnabled, false);
      ref.read(_trackingProvider.notifier).state = false;
    } else {
      // Check foreground location permission
      final foreground = await Permission.locationWhenInUse.status;
      if (!foreground.isGranted) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required for tracking.')),
            );
          }
          return;
        }
      }

      // Optimistically show green immediately — timer will correct it if service fails
      ref.read(_trackingProvider.notifier).state = true;
      await box.put(AppConstants.keyTrackingEnabled, true);
      await BackgroundLocationService.start();
    }
  }

  /// Cache the selected vehicle to SharedPreferences so the background
  /// isolate can read it without needing Hive.
  Future<void> _cacheVehicle(Vehicle v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySelectedVehicleReg, v.registration);
    await prefs.setString(AppConstants.keySelectedVehicleType, v.type);
    await prefs.setString(AppConstants.keySelectedVehicleFuelType, v.fuelType);
    ref.read(selectedVehicleProvider.notifier).state = v;
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final selectedVehicle = ref.watch(selectedVehicleProvider);
    final locationData = ref.watch(_locationProvider);
    final tracking = ref.watch(_trackingProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final zoneDisplay = ref.watch(zoneDisplayProvider);

    ZoneStatus? zoneStatus;
    if (locationData != null) {
      final lat = locationData['lat'] as double;
      final lng = locationData['lng'] as double;
      final zones = (locationData['zones'] as List?)?.cast<String>() ?? [];
      zoneStatus = ZoneStatus(
        activeZoneIds: Set<String>.from(zones),
        position: LatLng(lat, lng),
        timestamp: DateTime.parse(locationData['timestamp'] as String),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 20),
            const SizedBox(width: 8),
            const Text('ChargeShield'),
            if (isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.premium,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Zone Map',
            onPressed: () => context.push('/map'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle selector
            VehicleSelector(
              vehicles: vehicles,
              selected: selectedVehicle,
              onSelect: (v) => _cacheVehicle(v),
              onAdd: () => context.push('/vehicles/add'),
            ),

            const SizedBox(height: 16),

            // Tracking toggle
            _TrackingCard(
              isTracking: tracking,
              onToggle: _toggleTracking,
            ),

            const SizedBox(height: 16),

            // Zone status — filtered by per-zone display preferences
            ZoneStatusCard(
              status: zoneStatus,
              vehicle: selectedVehicle,
              hiddenZoneIds: zoneDisplay.entries
                  .where((e) => !e.value)
                  .map((e) => e.key)
                  .toSet(),
            ),

            const SizedBox(height: 16),

            // Quick stats (premium: this month, free: last 7 days)
            if (selectedVehicle != null)
              _StatsCard(vehicleReg: selectedVehicle.registration),

            const SizedBox(height: 16),

            // Quick nav buttons
            Row(
              children: [
                Expanded(
                  child: _QuickNavButton(
                    icon: Icons.history,
                    label: 'Journey History',
                    onTap: () => context.push('/history'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickNavButton(
                    icon: Icons.directions_car,
                    label: 'My Vehicles',
                    onTap: () => context.push('/vehicles'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!isPremium)
              _UpgradeBanner(onTap: () => context.push('/subscription')),
          ],
        ),
      ),
        ),  // Expanded
      ],
    ),      // body Column
  ),        // Scaffold
);          // PopScope
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.isTracking, required this.onToggle});

  final bool isTracking;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              isTracking ? Icons.gps_fixed : Icons.gps_off,
              color: isTracking ? AppColors.safe : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTracking ? 'Tracking Active' : 'Tracking Off',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isTracking
                        ? 'Monitoring for zone entries in the background.'
                        : 'Tap to start monitoring.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: isTracking,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.safe,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.vehicleReg});

  final String vehicleReg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(monthlyTotalProvider(vehicleReg));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("This month's charges",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                totalAsync.when(
                  data: (total) => Text(
                    '£${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  loading: () => const Text('—'),
                  error: (_, __) => const Text('—'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickNavButton extends StatelessWidget {
  const _QuickNavButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: AppColors.premium, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to ChargeShield Pro',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Unlimited vehicles • Full history • Priority alerts',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
