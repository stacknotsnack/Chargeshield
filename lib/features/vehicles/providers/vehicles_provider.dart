import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../subscription/providers/subscription_provider.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

final vehiclesProvider = StateNotifierProvider<VehiclesNotifier, List<Vehicle>>((ref) {
  return VehiclesNotifier(ref.read(vehicleRepositoryProvider), ref);
});

final selectedVehicleProvider = StateProvider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehiclesProvider);
  return vehicles.where((v) => v.isDefault).firstOrNull ?? vehicles.firstOrNull;
});

class VehiclesNotifier extends StateNotifier<List<Vehicle>> {
  VehiclesNotifier(this._repo, this._ref) : super([]) {
    _load();
  }

  final VehicleRepository _repo;
  final Ref _ref;

  void _load() {
    state = _repo.getAll();
  }

  Future<void> addVehicle({
    required String registration,
    required String nickname,
    required String type,
    required String fuelType,
    required String euroStandard,
  }) async {
    final isPremium = _ref.read(subscriptionProvider).isPremium;
    final maxVehicles =
        isPremium ? AppConstants.proVehicleLimit : AppConstants.freeVehicleLimit;
    if (state.length >= maxVehicles) {
      throw Exception('Vehicle limit reached');
    }
    await _repo.add(
      registration: registration,
      nickname: nickname,
      type: type,
      fuelType: fuelType,
      euroStandard: euroStandard,
    );
    _load();
  }

  Future<void> deleteVehicle(String id) async {
    await _repo.delete(id);
    _load();
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await _repo.update(vehicle);
    _load();
  }

  Future<void> setDefault(String id) async {
    await _repo.setDefault(id);
    _load();
  }

  int get count => state.length;
}
