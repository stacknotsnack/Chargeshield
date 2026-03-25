import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/journey.dart';

/// Handles all reads and writes between the app and Cloud Firestore.
/// All methods are static — no instance required.
class FirestoreSyncService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Journey history
  // ---------------------------------------------------------------------------

  /// Upload [journeys] to Firestore under users/{uid}/journey_history/.
  /// Uses batched writes of up to 400 at a time (Firestore limit is 500).
  static Future<void> syncJourneysUp(
      String uid, List<Journey> journeys) async {
    const batchSize = 400;
    for (var i = 0; i < journeys.length; i += batchSize) {
      final chunk = journeys.skip(i).take(batchSize).toList();
      final batch = _db.batch();
      for (final j in chunk) {
        final ref = _db
            .collection('users')
            .doc(uid)
            .collection('journey_history')
            .doc(j.id);
        batch.set(ref, _toFirestore(j), SetOptions(merge: true));
      }
      await batch.commit();
    }
    debugPrint('FirestoreSyncService: uploaded ${journeys.length} journeys for $uid');
  }

  /// Download all journey history for [uid] from Firestore.
  static Future<List<Journey>> fetchJourneys(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('journey_history')
        .orderBy('entryTime', descending: true)
        .limit(500)
        .get();
    final result = snapshot.docs
        .map((d) => _fromFirestore(d.data()))
        .whereType<Journey>()
        .toList();
    debugPrint('FirestoreSyncService: fetched ${result.length} journeys for $uid');
    return result;
  }

  /// Write a single journey to Firestore (called after local save on new entry).
  static Future<void> saveJourney(String uid, Journey journey) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('journey_history')
        .doc(journey.id)
        .set(_toFirestore(journey), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Licence key
  // ---------------------------------------------------------------------------

  /// Store the activated licence key against the user's Firestore document.
  static Future<void> saveLicenceKey(String uid, String key) async {
    await _db.collection('users').doc(uid).set(
      {
        'licenceKey': key,
        'licenceUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Return the user's saved licence key, or null if none exists.
  static Future<String?> fetchLicenceKey(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['licenceKey'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Serialisation helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _toFirestore(Journey j) => {
        'id': j.id,
        'vehicleRegistration': j.vehicleRegistration,
        'zoneId': j.zoneId,
        'zoneName': j.zoneName,
        'entryTime': Timestamp.fromDate(j.entryTime),
        'entryLat': j.entryLat,
        'entryLng': j.entryLng,
        'exitTime':
            j.exitTime != null ? Timestamp.fromDate(j.exitTime!) : null,
        'exitLat': j.exitLat,
        'exitLng': j.exitLng,
        'charge': j.charge,
        'paymentStatus': j.paymentStatus.name,
        'routePoints': j.routePoints,
      };

  static Journey? _fromFirestore(Map<String, dynamic> d) {
    try {
      return Journey(
        id: d['id'] as String,
        vehicleRegistration: d['vehicleRegistration'] as String,
        zoneId: d['zoneId'] as String,
        zoneName: d['zoneName'] as String,
        entryTime: (d['entryTime'] as Timestamp).toDate(),
        entryLat: (d['entryLat'] as num).toDouble(),
        entryLng: (d['entryLng'] as num).toDouble(),
        exitTime: d['exitTime'] != null
            ? (d['exitTime'] as Timestamp).toDate()
            : null,
        exitLat:
            d['exitLat'] != null ? (d['exitLat'] as num).toDouble() : null,
        exitLng:
            d['exitLng'] != null ? (d['exitLng'] as num).toDouble() : null,
        charge: (d['charge'] as num).toDouble(),
        paymentStatus: PaymentStatus.values.firstWhere(
          (s) => s.name == d['paymentStatus'],
          orElse: () => PaymentStatus.unpaid,
        ),
        routePoints: d['routePoints'] != null
            ? (d['routePoints'] as List)
                .map((e) => Map<String, double>.from((e as Map)
                    .map((k, v) => MapEntry(k as String, (v as num).toDouble()))))
                .toList()
            : null,
      );
    } catch (e) {
      debugPrint('FirestoreSyncService: failed to parse journey: $e');
      return null;
    }
  }
}
