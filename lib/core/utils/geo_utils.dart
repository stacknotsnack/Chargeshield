import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Geospatial utilities for zone detection.
class GeoUtils {
  GeoUtils._();

  /// Ray-casting point-in-polygon. Works for convex and concave polygons.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    final double lat = point.latitude;
    final double lng = point.longitude;
    bool inside = false;

    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final double iLat = polygon[i].latitude;
      final double iLng = polygon[i].longitude;
      final double jLat = polygon[j].latitude;
      final double jLng = polygon[j].longitude;

      if (((iLng > lng) != (jLng > lng)) &&
          (lat < (jLat - iLat) * (lng - iLng) / (jLng - iLng) + iLat)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Haversine distance in metres between two coordinates.
  static double distanceInMetres(LatLng a, LatLng b) {
    const double r = 6371000; // Earth radius in metres
    final double dLat = _toRad(b.latitude - a.latitude);
    final double dLng = _toRad(b.longitude - a.longitude);
    final double h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
