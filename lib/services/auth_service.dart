import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'active_user_store.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });
}

/// Google Sign-In backed by FirebaseAuth.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Web client ID Firebase auto-created when Google sign-in was enabled for
  // this project; required so GoogleSignIn returns an idToken Firebase Auth
  // can verify (see console: Authentication > Sign-in method > Google >
  // Web SDK configuration).
  static const _googleWebClientId =
      '997847107903-nb46nc46b88rt1fri7b8esj61n1vjdk5.apps.googleusercontent.com';

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  AppUser? _currentUser;
  bool _loaded = false;

  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      await _googleSignIn.initialize(serverClientId: _googleWebClientId);
    } catch (_) {
      // Google button will surface its own error on tap if this failed.
    }
    _auth.authStateChanges().listen((user) {
      _currentUser = _userFromFirebase(user);
      _loaded = true;
      notifyListeners();
      // Ties subsequent Analytics events to this user via their Firebase Auth
      // UID (not email/PII -- Analytics' terms disallow sending raw PII).
      // Cross-reference the UID against the Authentication > Users console
      // tab to see which student it corresponds to.
      _analytics.setUserId(id: user?.uid);
      // Lets the background alarm isolate (no access to AuthService) know
      // whose alarms to look up when re-arming a repeating alarm.
      ActiveUserStore.set(user?.uid);
    });
  }

  AppUser? _userFromFirebase(fb.User? user) {
    if (user == null) return null;
    final name = user.displayName;
    return AppUser(
      uid: user.uid,
      displayName: (name != null && name.isNotEmpty)
          ? name
          : (user.email ?? 'WakeForce user'),
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  /// Returns true on success, false if the user cancelled or it failed.
  Future<bool> signInWithGoogle() async {
    if (!_googleSignIn.supportsAuthenticate()) return false;
    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return false;
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      if (result.additionalUserInfo?.isNewUser ?? false) {
        await _analytics.logSignUp(signUpMethod: 'google');
      } else {
        await _analytics.logLogin(loginMethod: 'google');
      }
      return true;
    } on GoogleSignInException {
      return false;
    } on fb.FirebaseAuthException {
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort; FirebaseAuth sign-out above is what actually matters.
    }
  }
}
