import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firestore_sync_service.dart';

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionState {
  const SubscriptionState({
    this.isPremium = false,
    this.isActivating = false,
    this.error,
    this.licenceKey,
  });

  final bool isPremium;
  final bool isActivating;
  final String? error;
  final String? licenceKey;

  SubscriptionState copyWith({
    bool? isPremium,
    bool? isActivating,
    String? error,
    String? licenceKey,
    bool clearError = false,
  }) =>
      SubscriptionState(
        isPremium: isPremium ?? this.isPremium,
        isActivating: isActivating ?? this.isActivating,
        error: clearError ? null : error ?? this.error,
        licenceKey: licenceKey ?? this.licenceKey,
      );
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState()) {
    _init();
  }

  void _init() {
    final box = Hive.box(AppConstants.settingsBox);
    final isPremium =
        box.get(AppConstants.keyPremiumActive, defaultValue: false) as bool;
    final key = box.get(AppConstants.keyLicenceKey) as String?;
    state = state.copyWith(isPremium: isPremium, licenceKey: key);
  }

  static bool isValidLicenceKey(String key) {
    final trimmed = key.trim().toUpperCase();
    final regex = RegExp(r'^CS-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return regex.hasMatch(trimmed);
  }

  /// Validates and activates a licence key.
  /// Returns true on success, false on failure (error is set in state).
  Future<bool> activateLicenceKey(String rawKey) async {
    final key = rawKey.trim().toUpperCase();
    state = state.copyWith(isActivating: true, clearError: true);
    try {
      debugPrint('KEY VALIDATION: input="$rawKey" trimmed="$key"');

      if (!isValidLicenceKey(key)) {
        state = state.copyWith(
          isActivating: false,
          error: 'Invalid key format. Keys look like CS-XXXX-XXXX-XXXX.',
        );
        return false;
      }

      // Owner/test keys bypass server validation
      if (key == 'CS-PRO1-OWNS-2026' || key == 'CS-TEST-PASS-0001') {
        await _saveKeyLocally(key);
        return true;
      }

      // Server validation — send uid if signed in (preferred), else deviceId
      final deviceId = await _getDeviceId();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      try {
        final response = await http.post(
          Uri.parse('https://chargeshield.co.uk/.netlify/functions/validate-key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'key': key,
            'deviceId': deviceId,
            if (uid != null) 'uid': uid,
          }),
        ).timeout(const Duration(seconds: 10));

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['valid'] == true) {
          await _saveKeyLocally(key);
          return true;
        }

        switch (data['reason']) {
          case 'key_not_found':
            state = state.copyWith(
              isActivating: false,
              error: 'Licence key not found. Please check your email and try again.',
            );
          case 'already_activated':
            state = state.copyWith(
              isActivating: false,
              error: 'This key is already activated on another device. Contact support@chargeshield.co.uk to transfer.',
            );
          case 'key_revoked':
            state = state.copyWith(
              isActivating: false,
              error: 'This licence key has been revoked. Contact support@chargeshield.co.uk for help.',
            );
          default:
            state = state.copyWith(
              isActivating: false,
              error: 'Invalid licence key. Please check and try again.',
            );
        }
        return false;
      } on TimeoutException {
        // Server unreachable — fall back to format-only so users aren't locked out offline
        debugPrint('Validation server unreachable — falling back to format check');
        await _saveKeyLocally(key);
        return true;
      } catch (e) {
        debugPrint('Key validation network error: $e');
        state = state.copyWith(
          isActivating: false,
          error: 'Could not connect to validation server. Please check your internet connection.',
        );
        return false;
      }
    } catch (_) {
      state = state.copyWith(
        isActivating: false,
        error: 'Activation failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> _saveKeyLocally(String key) async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.keyPremiumActive, true);
    await box.put(AppConstants.keyLicenceKey, key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyPremiumActive, true);
    state = state.copyWith(
      isPremium: true,
      isActivating: false,
      licenceKey: key,
      clearError: true,
    );
    // If signed in, also persist key to Firestore for cross-device restore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreSyncService.saveLicenceKey(uid, key);
        debugPrint('Licence key saved to Firestore for $uid');
      } catch (e) {
        debugPrint('Failed to save licence key to Firestore (non-fatal): $e');
      }
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }
}
