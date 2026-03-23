import 'dart:convert';

/// A logged journey / zone entry event stored in SQLite.
class Journey {
  Journey({
    required this.id,
    required this.vehicleRegistration,
    required this.zoneId,
    required this.zoneName,
    required this.entryTime,
    required this.entryLat,
    required this.entryLng,
    required this.charge,
    this.exitTime,
    this.exitLat,
    this.exitLng,
    this.paymentStatus = PaymentStatus.unpaid,
    this.routePoints,
  });

  final String id;
  final String vehicleRegistration;
  final String zoneId;
  final String zoneName;
  final DateTime entryTime;
  final double entryLat;
  final double entryLng;
  final double charge;
  DateTime? exitTime;
  double? exitLat;
  double? exitLng;
  PaymentStatus paymentStatus;

  /// GPS points recorded while inside the zone.
  /// Each point is {lat: double, lng: double}.
  /// Only populated when "Record exact route" is enabled (Pro feature).
  List<Map<String, double>>? routePoints;

  Duration? get duration =>
      exitTime != null ? exitTime!.difference(entryTime) : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_registration': vehicleRegistration,
        'zone_id': zoneId,
        'zone_name': zoneName,
        'entry_time': entryTime.toIso8601String(),
        'entry_lat': entryLat,
        'entry_lng': entryLng,
        'exit_time': exitTime?.toIso8601String(),
        'exit_lat': exitLat,
        'exit_lng': exitLng,
        'charge': charge,
        'payment_status': paymentStatus.name,
        'route_points': routePoints != null ? jsonEncode(routePoints) : null,
      };

  factory Journey.fromMap(Map<String, dynamic> map) => Journey(
        id: map['id'] as String,
        vehicleRegistration: map['vehicle_registration'] as String,
        zoneId: map['zone_id'] as String,
        zoneName: map['zone_name'] as String,
        entryTime: DateTime.parse(map['entry_time'] as String),
        entryLat: (map['entry_lat'] as num).toDouble(),
        entryLng: (map['entry_lng'] as num).toDouble(),
        exitTime: map['exit_time'] != null
            ? DateTime.parse(map['exit_time'] as String)
            : null,
        exitLat: map['exit_lat'] != null
            ? (map['exit_lat'] as num).toDouble()
            : null,
        exitLng: map['exit_lng'] != null
            ? (map['exit_lng'] as num).toDouble()
            : null,
        charge: (map['charge'] as num).toDouble(),
        paymentStatus: PaymentStatus.values
            .firstWhere((s) => s.name == map['payment_status'],
                orElse: () => PaymentStatus.unpaid),
        routePoints: map['route_points'] != null
            ? (jsonDecode(map['route_points'] as String) as List)
                .map((e) => Map<String, double>.from(
                    (e as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()))))
                .toList()
            : null,
      );
}

enum PaymentStatus { unpaid, paid, exempt }
