import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/journey.dart';
import '../../../data/repositories/journey_repository.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository();
});

final isPremiumProvider = StateProvider<bool>((ref) {
  final box = Hive.box(AppConstants.settingsBox);
  return box.get(AppConstants.keyPremiumActive, defaultValue: false) as bool;
});

final journeyHistoryProvider =
    FutureProvider.family<List<Journey>, String?>((ref, vehicleReg) async {
  final repo = ref.read(journeyRepositoryProvider);
  final isPremium = ref.watch(isPremiumProvider);
  return repo.getRecent(
    vehicleRegistration: vehicleReg,
    limitDays: isPremium ? AppConstants.proHistoryDays : AppConstants.freeHistoryDays,
    limit: isPremium ? 500 : 50,
  );
});

final monthlyTotalProvider =
    FutureProvider.family<double, String>((ref, vehicleReg) async {
  final repo = ref.read(journeyRepositoryProvider);
  return repo.monthlyTotal(vehicleReg);
});
