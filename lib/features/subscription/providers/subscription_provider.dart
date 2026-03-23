import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

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
      debugPrint('KEY VALIDATION: input="$rawKey" trimmed="$key" valid=${isValidLicenceKey(rawKey)}');

      final accepted = key == 'CS-PRO1-OWNS-2026' ||
          key == 'CS-TEST-PASS-0001' ||
          isValidLicenceKey(rawKey);

      if (!accepted) {
        state = state.copyWith(
          isActivating: false,
          error: 'Invalid key format. Keys look like CS-XXXX-XXXX-XXXX.',
        );
        return false;
      }

      // Key accepted — persist to Hive (UI isolate) and SharedPreferences (bg isolate).
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
      return true;
    } catch (_) {
      state = state.copyWith(
        isActivating: false,
        error: 'Activation failed. Please try again.',
      );
      return false;
    }
  }
}
