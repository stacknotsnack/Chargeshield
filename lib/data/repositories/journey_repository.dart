import '../database/database_helper.dart';
import '../models/journey.dart';

class JourneyRepository {
  JourneyRepository() : _db = DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<List<Journey>> getRecent({
    String? vehicleRegistration,
    int? limitDays,
    int limit = 50,
  }) =>
      _db.getJourneys(
        vehicleRegistration: vehicleRegistration,
        limitDays: limitDays,
        limit: limit,
      );

  Future<void> add(Journey journey) => _db.insertJourney(journey);

  Future<void> updatePaymentStatus(String id, PaymentStatus status) =>
      _db.updatePaymentStatus(id, status);

  Future<void> delete(String id) => _db.deleteJourney(id);

  Future<double> monthlyTotal(String vehicleRegistration) {
    final now = DateTime.now();
    return _db.totalCharges(
      vehicleRegistration: vehicleRegistration,
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      onlyUnpaid: true,
    );
  }

  Future<void> pruneOldHistory({bool isPremium = false}) =>
      _db.deleteJourneysOlderThan(isPremium ? 365 : 7);
}
