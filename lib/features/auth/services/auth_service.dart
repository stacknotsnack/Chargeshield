import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Lazy singleton — only instantiated when first accessed, never on app startup.
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  final _googleSignIn = GoogleSignIn();
  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('AUTH: calling _googleSignIn.signIn()');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('AUTH: user cancelled sign-in');
        return null;
      }
      debugPrint('AUTH: got google user ${googleUser.email}, fetching auth tokens');
      final googleAuth = await googleUser.authentication;
      debugPrint('AUTH: got tokens, signing in with Firebase credential');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      debugPrint('AUTH: Firebase sign-in success uid=${result.user?.uid}');
      return result.user;
    } catch (e, st) {
      debugPrint('AUTH ERROR: $e');
      debugPrint('AUTH STACK: $st');
      rethrow;
    }
  }

  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await result.user?.sendEmailVerification();
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Register error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static String getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again or reset it.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
