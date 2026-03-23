import 'package:shared_preferences/shared_preferences.dart';

import 'dvla_service.dart';

/// Handles local storage of MOT and tax expiry dates (per vehicle registration).
/// Dates are stored in SharedPreferences — no Hive migration required.
class MotTaxService {
  MotTaxService._();
  static final MotTaxService instance = MotTaxService._();

  static String _clean(String reg) => reg.replaceAll(' ', '').toUpperCase();
  static String _motKey(String reg) => 'mot_expiry_${_clean(reg)}';
  static String _taxKey(String reg) => 'tax_due_${_clean(reg)}';
  static String _fetchedKey(String reg) => 'dvla_fetched_${_clean(reg)}';

  Future<void> saveDates(
    String registration, {
    DateTime? mot,
    DateTime? tax,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (mot != null) {
      await prefs.setString(_motKey(registration), mot.toIso8601String());
    }
    if (tax != null) {
      await prefs.setString(_taxKey(registration), tax.toIso8601String());
    }
    await prefs.setString(
        _fetchedKey(registration), DateTime.now().toIso8601String());
  }

  Future<DateTime?> getMotExpiry(String registration) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_motKey(registration));
    return s != null ? DateTime.tryParse(s) : null;
  }

  Future<DateTime?> getTaxDue(String registration) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_taxKey(registration));
    return s != null ? DateTime.tryParse(s) : null;
  }

  /// Returns true if dates have never been fetched or were fetched > 7 days ago.
  Future<bool> needsRefresh(String registration) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_fetchedKey(registration));
    if (s == null) return true;
    final fetched = DateTime.tryParse(s);
    if (fetched == null) return true;
    return DateTime.now().difference(fetched).inDays > 7;
  }

  /// Re-fetches from DVLA and updates stored dates. Returns true on success.
  Future<bool> refreshFromDvla(String registration) async {
    try {
      final result = await DvlaService.instance.lookup(registration);
      await saveDates(
        registration,
        mot: result.motExpiryDate,
        tax: result.taxDueDate,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
