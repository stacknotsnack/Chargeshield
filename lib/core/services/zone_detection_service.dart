import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/zone_polygons.dart';
import '../utils/geo_utils.dart';

/// Represents the current zone status for a given GPS position.
/// Uses a [Set<String>] of active zone IDs for extensibility — adding new zones
/// requires no changes here.
class ZoneStatus {
  const ZoneStatus({
    required this.activeZoneIds,
    required this.position,
    required this.timestamp,
  });

  final Set<String> activeZoneIds;
  final LatLng position;
  final DateTime timestamp;

  // Backward-compat getters for existing code that checks individual London zones.
  bool get inCcz => activeZoneIds.contains('ccz');
  bool get inUlez => activeZoneIds.contains('ulez');
  bool get inLez => activeZoneIds.contains('lez');
  bool get inDartford => activeZoneIds.contains('dartford');
  bool get inSilvertown => activeZoneIds.contains('silvertown');
  bool get inBlackwall => activeZoneIds.contains('blackwall');
  bool get inAnyZone => activeZoneIds.isNotEmpty;

  List<ZoneInfo> get activeZones => AllZones.detectableZones
      .where((z) => activeZoneIds.contains(z.id))
      .toList();

  static ZoneStatus empty(LatLng position) => ZoneStatus(
        activeZoneIds: const {},
        position: position,
        timestamp: DateTime.now(),
      );

  ZoneStatus copyWith({
    Set<String>? activeZoneIds,
    LatLng? position,
    DateTime? timestamp,
  }) =>
      ZoneStatus(
        activeZoneIds: activeZoneIds ?? this.activeZoneIds,
        position: position ?? this.position,
        timestamp: timestamp ?? this.timestamp,
      );
}

/// Detects which charge zones contain a given GPS coordinate.
class ZoneDetectionService {
  ZoneDetectionService._();
  static final ZoneDetectionService instance = ZoneDetectionService._();

  bool _inZone(LatLng position, ZoneInfo zone) {
    if (zone.comingSoon) return false; // never triggers
    // Polygon takes priority when set — allows precise boundaries alongside
    // a circle centre/radius that may still be used for map display.
    if (zone.polygon.isNotEmpty) {
      return GeoUtils.isPointInPolygon(position, zone.polygon);
    }
    if (zone.centre != null && zone.radiusMetres != null) {
      return GeoUtils.distanceInMetres(position, zone.centre!) <= zone.radiusMetres!;
    }
    return false;
  }

  ZoneStatus detect(LatLng position) {
    final active = <String>{};
    for (final zone in AllZones.detectableZones) {
      if (_inZone(position, zone)) active.add(zone.id);
    }
    debugPrint('DEBUG ZONE: ${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)} '
        'active=[${active.join(',')}]');
    return ZoneStatus(
      activeZoneIds: active,
      position: position,
      timestamp: DateTime.now(),
    );
  }

  List<ZoneInfo> detectEntries(ZoneStatus previous, ZoneStatus current) {
    final entries = <ZoneInfo>[];
    for (final zone in AllZones.detectableZones) {
      if (!previous.activeZoneIds.contains(zone.id) &&
          current.activeZoneIds.contains(zone.id)) {
        entries.add(zone);
      }
    }
    return entries;
  }

  List<ZoneInfo> detectExits(ZoneStatus previous, ZoneStatus current) {
    final exits = <ZoneInfo>[];
    for (final zone in AllZones.detectableZones) {
      if (previous.activeZoneIds.contains(zone.id) &&
          !current.activeZoneIds.contains(zone.id)) {
        exits.add(zone);
      }
    }
    return exits;
  }
}
