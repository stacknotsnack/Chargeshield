import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

class AuthState {
  const AuthState({
    this.isSignedIn = false,
    this.email,
    this.uid,
    this.isLoading = false,
  });

  final bool isSignedIn;
  final String? email;
  final String? uid;
  final bool isLoading;

  AuthState copyWith({
    bool? isSignedIn,
    String? email,
    String? uid,
    bool? isLoading,
  }) =>
      AuthState(
        isSignedIn: isSignedIn ?? this.isSignedIn,
        email: email ?? this.email,
        uid: uid ?? this.uid,
        isLoading: isLoading ?? this.isLoading,
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

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);
    final user = await AuthService.instance.signInWithGoogle();
    if (user != null) {
      state = AuthState(isSignedIn: true, email: user.email, uid: user.uid);
      return true;
    }
    state = const AuthState();
    return false;
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
