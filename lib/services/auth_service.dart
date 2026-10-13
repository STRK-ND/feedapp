import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_sync_service.dart';

/// Firebase Authentication wrapper — Google one-tap + email/password.
///
/// The app is fully usable signed out; this only adds accounts + cloud sync.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isSignedIn => _auth.currentUser != null;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _google.initialize();
    _googleInitialized = true;
  }

  /// Google one-tap. Returns null when the user cancels the sheet.
  Future<User?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-no-id-token',
          message: 'Google sign-in returned no id token',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return (await _auth.signInWithCredential(credential)).user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async =>
      (await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user;

  Future<User?> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Verification mail is a courtesy; no feature gates on it.
    unawaited(
      cred.user?.sendEmailVerification().catchError((Object _) => <void>{}),
    );
    return cred.user;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    if (_googleInitialized) {
      try {
        await _google.signOut();
      } catch (_) {
        // Google session cleanup is best-effort; the Firebase sign-out
        // below is what gates cloud access.
      }
    }
    await _auth.signOut();
  }

  /// Permanently deletes the account (R-2 — Play policy: any app that
  /// creates accounts must offer an in-app deletion path).
  ///
  /// ORDERING MATTERS: the Firestore mirror is wiped FIRST. If
  /// `user.delete()` succeeded first and the wipe then failed, the auth
  /// record would be gone and we could no longer prove ownership of the
  /// data — leaving it orphaned with no path back.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Remove the cloud mirror (articles, settings, sources, sync
    //    state, and the user root document).
    if (GetIt.instance.isRegistered<CloudSyncService>()) {
      await GetIt.instance<CloudSyncService>().purgeUserData(user.uid);
    }

    // 2. Google session cleanup so a re-auth prompt isn't needed.
    if (_googleInitialized) {
      try {
        await _google.signOut();
      } catch (_) {
        // Best-effort; deletion below is what matters.
      }
    }

    // 3. Then the auth record. Firebase may still throw
    //    requires-recent-login on long-lived sessions; the caller
    //    surfaces that as a failure snackbar and the cloud wipe having
    //    already completed is the safe failure direction (account locked
    //    out of its data, not data orphaned without an owner).
    await user.delete();
  }
}
