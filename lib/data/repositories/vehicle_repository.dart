import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/vehicle.dart';
import '../../core/constants/app_constants.dart';

class VehicleRepository {
  VehicleRepository() : _box = Hive.box<Vehicle>(AppConstants.vehiclesBox);

  final Box<Vehicle> _box;
  final _uuid = const Uuid();

  List<Vehicle> getAll() => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Vehicle? getById(String id) =>
      _box.values.where((v) => v.id == id).firstOrNull;

  Vehicle? getDefault() =>
      _box.values.where((v) => v.isDefault).firstOrNull ?? _box.values.firstOrNull;

  Future<Vehicle> add({
    required String registration,
    required String nickname,
    required String type,
    required String fuelType,
    required String euroStandard,
  }) async {
    final vehicle = Vehicle(
      id: _uuid.v4(),
      registration: registration.toUpperCase().trim(),
      nickname: nickname.trim(),
      type: type,
      fuelType: fuelType,
      euroStandard: euroStandard,
      createdAt: DateTime.now(),
      isDefault: _box.isEmpty,
    );
    await _box.put(vehicle.id, vehicle);
    return vehicle;
  }

  Future<void> update(Vehicle vehicle) async {
    await vehicle.save();
  }

  Future<void> delete(String id) async {
    final vehicle = getById(id);
    if (vehicle != null) {
      // If it was default, assign default to next vehicle
      if (vehicle.isDefault && _box.length > 1) {
        final next = _box.values.where((v) => v.id != id).first;
        next.isDefault = true;
        await next.save();
      }
      await vehicle.delete();
    }
  }

  Future<void> setDefault(String id) async {
    for (final v in _box.values) {
      v.isDefault = v.id == id;
      await v.save();
    }
  }

  int get count => _box.length;

  Stream<BoxEvent> get changes => _box.watch();
}
