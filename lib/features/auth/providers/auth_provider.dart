// Before this works you must:
// 1. Go to Firebase Console → Authentication → Sign-in method → Enable Google
// 2. Add SHA-1 fingerprint for Android:
//    SHA1: E8:BE:93:B4:9D:48:59:A2:4C:C0:A9:45:F8:47:75:E2:69:68:34:70
// 3. Download updated google-services.json and replace android/app/google-services.json

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firestore_sync_service.dart';
import '../../../data/repositories/journey_repository.dart';

enum AuthStatus { anonymous, signingIn, signedIn }

class AuthState {
  const AuthState({
    this.status = AuthStatus.anonymous,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final User? user;
  final String? error;

  bool get isSignedIn => status == AuthStatus.signedIn;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : user ?? this.user,
        error: clearError ? null : error ?? this.error,
      );
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    // Reflect Firebase auth state changes immediately on startup
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        state = state.copyWith(
            status: AuthStatus.signedIn, user: user, clearError: true);
        _onSignedIn(user);
      } else {
        state = const AuthState(status: AuthStatus.anonymous);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.signingIn, clearError: true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the picker
        state = const AuthState(status: AuthStatus.anonymous);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // authStateChanges listener above updates state and calls _onSignedIn
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      state = const AuthState(
        status: AuthStatus.anonymous,
        error: 'Sign in failed. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    // authStateChanges listener resets state to anonymous
  }

  Future<void> _onSignedIn(User user) async {
    // 1. Push local journeys up to Firestore
    try {
      final repo = JourneyRepository();
      final journeys = await repo.getRecent(limit: 500);
      if (journeys.isNotEmpty) {
        await FirestoreSyncService.syncJourneysUp(user.uid, journeys);
      }
    } catch (e) {
      debugPrint('Journey upload on sign-in failed (non-fatal): $e');
    }

    // 2. Pull Firestore journeys down and merge into local SQLite
    // ConflictAlgorithm.replace means Firestore wins on conflicts
    try {
      final firestoreJourneys =
          await FirestoreSyncService.fetchJourneys(user.uid);
      if (firestoreJourneys.isNotEmpty) {
        final repo = JourneyRepository();
        for (final j in firestoreJourneys) {
          try {
            await repo.add(j);
          } catch (_) {}
        }
        debugPrint(
            'Merged ${firestoreJourneys.length} journeys from Firestore');
      }
    } catch (e) {
      debugPrint('Journey download on sign-in failed (non-fatal): $e');
    }

    // 3. Auto-restore Pro licence key from Firestore if not already active
    try {
      final box = Hive.box(AppConstants.settingsBox);
      final isPremium =
          box.get(AppConstants.keyPremiumActive, defaultValue: false) as bool;
      if (!isPremium) {
        final savedKey = await FirestoreSyncService.fetchLicenceKey(user.uid);
        if (savedKey != null) {
          await box.put(AppConstants.keyPremiumActive, true);
          await box.put(AppConstants.keyLicenceKey, savedKey);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(AppConstants.keyPremiumActive, true);
          debugPrint('Pro licence auto-restored from Firestore for ${user.email}');
        }
      }
    } catch (e) {
      debugPrint('Licence key restore failed (non-fatal): $e');
    }
  }
}
