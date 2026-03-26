import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

class AuthState {
  const AuthState({
    this.isSignedIn = false,
    this.email,
    this.uid,
    this.isLoading = false,
    this.verificationEmailSent = false,
  });

  final bool isSignedIn;
  final String? email;
  final String? uid;
  final bool isLoading;
  final bool verificationEmailSent;

  AuthState copyWith({
    bool? isSignedIn,
    String? email,
    String? uid,
    bool? isLoading,
    bool? verificationEmailSent,
  }) =>
      AuthState(
        isSignedIn: isSignedIn ?? this.isSignedIn,
        email: email ?? this.email,
        uid: uid ?? this.uid,
        isLoading: isLoading ?? this.isLoading,
        verificationEmailSent:
            verificationEmailSent ?? this.verificationEmailSent,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    // Only reads already-persisted sign-in state — does NOT trigger
    // any auth flows or start any listeners on app startup.
    _checkExistingSignIn();
  }

  Future<void> _checkExistingSignIn() async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      state = AuthState(isSignedIn: true, email: user.email, uid: user.uid);
    }
  }

  Future<String?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user != null) {
        state = AuthState(isSignedIn: true, email: user.email, uid: user.uid);
        return null; // null = success
      }
      state = const AuthState();
      return null; // null = user cancelled
    } catch (e) {
      state = const AuthState();
      return e.toString();
    }
  }

  Future<String?> registerWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await AuthService.instance.registerWithEmail(email, password);
      if (user != null) {
        state = AuthState(
          isSignedIn: true,
          email: user.email,
          uid: user.uid,
          verificationEmailSent: true,
        );
        return null; // null = success
      }
      state = const AuthState();
      return 'Registration failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      state = const AuthState();
      return AuthService.getErrorMessage(e.code);
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await AuthService.instance.signInWithEmail(email, password);
      if (user != null) {
        state = AuthState(isSignedIn: true, email: user.email, uid: user.uid);
        return null; // null = success
      }
      state = const AuthState();
      return 'Sign in failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      state = const AuthState();
      return AuthService.getErrorMessage(e.code);
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await AuthService.instance.resetPassword(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearVerificationFlag() {
    state = state.copyWith(verificationEmailSent: false);
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
