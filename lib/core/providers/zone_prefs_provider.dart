import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../constants/zone_polygons.dart';

/// All zone IDs that have pref toggles — excludes coming-soon zones.
List<String> get _allZoneIds => AllZones.allForDisplay
    .where((z) => !z.comingSoon)
    .map((z) => z.id)
    .toList();

// ---------------------------------------------------------------------------
// Notification preferences — controls which zones fire push alerts
// ---------------------------------------------------------------------------
final zoneNotifsProvider =
    StateNotifierProvider<ZoneNotifsNotifier, Map<String, bool>>(
        (_) => ZoneNotifsNotifier());

class ZoneNotifsNotifier extends StateNotifier<Map<String, bool>> {
  ZoneNotifsNotifier()
      : super({for (final id in _allZoneIds) id: AppConstants.freeAlertZoneIds.contains(id)}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      for (final id in _allZoneIds)
        id: prefs.getBool('${AppConstants.keyNotifyZonePrefix}$id') ??
            AppConstants.freeAlertZoneIds.contains(id),
    };
  }

  Future<void> setZone(String id, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${AppConstants.keyNotifyZonePrefix}$id', v);
    state = {...state, id: v};
  }
}

// ---------------------------------------------------------------------------
// Display preferences — controls which zones appear on the status card
// ---------------------------------------------------------------------------
final zoneDisplayProvider =
    StateNotifierProvider<ZoneDisplayNotifier, Map<String, bool>>(
        (_) => ZoneDisplayNotifier());

class ZoneDisplayNotifier extends StateNotifier<Map<String, bool>> {
  ZoneDisplayNotifier()
      : super({for (final id in _allZoneIds) id: true}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      for (final id in _allZoneIds)
        id: prefs.getBool('${AppConstants.keyDisplayZonePrefix}$id') ?? true,
    };
  }

  Future<void> setZone(String id, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${AppConstants.keyDisplayZonePrefix}$id', v);
    state = {...state, id: v};
  }
}
