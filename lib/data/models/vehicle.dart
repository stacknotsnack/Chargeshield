import 'package:hive/hive.dart';

part 'vehicle.g.dart';

@HiveType(typeId: 0)
class Vehicle extends HiveObject {
  Vehicle({
    required this.id,
    required this.registration,
    required this.nickname,
    required this.type,
    required this.fuelType,
    required this.euroStandard,
    required this.createdAt,
    this.isDefault = false,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String registration; // e.g. "AB12 CDE"

  @HiveField(2)
  String nickname; // e.g. "My Blue Focus"

  @HiveField(3)
  String type; // car, van, motorbike, hgv, bus, coach

  @HiveField(4)
  String fuelType; // petrol, diesel, electric, hybrid, phev

  @HiveField(5)
  String euroStandard; // Euro 3, Euro 4, Euro 5, Euro 6, Electric

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  bool isDefault;

  /// Whether this vehicle is exempt from CCZ charge.
  bool get isCczExempt =>
      fuelType == 'electric' ||
      fuelType == 'hybrid' ||
      fuelType == 'phev';

  /// Whether this vehicle is ULEZ compliant.
  /// TfL rules:
  ///   Electric / PHEV (plug-in hybrid) → always compliant.
  ///   Petrol / Hybrid (petrol hybrid)  → Euro 4 or above.
  ///   Diesel                           → Euro 6 only.
  bool get isUlezCompliant {
    if (fuelType == 'electric' || fuelType == 'phev') return true;
    if (fuelType == 'petrol' || fuelType == 'hybrid') {
      return euroStandard == 'Euro 4' ||
          euroStandard == 'Euro 5' ||
          euroStandard == 'Euro 6';
    }
    if (fuelType == 'diesel') {
      return euroStandard == 'Euro 6';
    }
    return false;
  }

  @override
  String toString() => '$nickname ($registration)';
}
