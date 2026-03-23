import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationPermissionStatus {
  granted,        // background location granted — ready to track
  foregroundOnly, // only when-in-use granted — limited tracking
  denied,         // denied but can ask again
  permanentlyDenied, // must open settings
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Check current permission state without prompting.
  Future<LocationPermissionStatus> checkPermission() async {
    final background = await Permission.locationAlways.status;
    if (background.isGranted) return LocationPermissionStatus.granted;

    final foreground = await Permission.locationWhenInUse.status;
    if (foreground.isGranted) return LocationPermissionStatus.foregroundOnly;
    if (foreground.isPermanentlyDenied || background.isPermanentlyDenied) {
      return LocationPermissionStatus.permanentlyDenied;
    }
    return LocationPermissionStatus.denied;
  }

  /// Request location permissions in the correct order required by Android.
  /// Must request foreground first, then background.
  Future<LocationPermissionStatus> requestPermission() async {
    // Step 1: request foreground (when-in-use)
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      if (foreground.isPermanentlyDenied) {
        return LocationPermissionStatus.permanentlyDenied;
      }
      return LocationPermissionStatus.denied;
    }

    // Step 2: request background (always) — only after foreground is granted
    final background = await Permission.locationAlways.request();
    if (background.isGranted) return LocationPermissionStatus.granted;
    if (background.isPermanentlyDenied) {
      return LocationPermissionStatus.permanentlyDenied;
    }

    // Foreground only
    return LocationPermissionStatus.foregroundOnly;
  }

  /// Returns true if we have at least foreground location permission.
  Future<bool> hasAnyLocationPermission() async {
    final status = await checkPermission();
    return status == LocationPermissionStatus.granted ||
        status == LocationPermissionStatus.foregroundOnly;
  }

  /// Returns true if background (always) permission is granted.
  Future<bool> hasBackgroundPermission() async {
    return (await checkPermission()) == LocationPermissionStatus.granted;
  }

  /// Check if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
}
