import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

@immutable
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.isAnonymous,
  });

  final String uid;
  final String email;
  final bool isAnonymous;
}

class AuthSessionService {
  AuthSessionService(this._auth)
    : _googleSignIn = kIsWeb ? null : GoogleSignIn(),
      _sessionController = null,
      _memorySession = null;

  AuthSessionService.memory()
    : _auth = null,
      _googleSignIn = null,
      _sessionController = StreamController<AuthSession?>.broadcast(),
      _memorySession = null;

  final FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  final StreamController<AuthSession?>? _sessionController;
  AuthSession? _memorySession;

  Stream<AuthSession?> sessionChanges() {
    if (_auth != null) {
      return _auth.authStateChanges().map(_mapUser);
    }
    return _sessionController!.stream;
  }

  AuthSession? get currentSession =>
      _auth != null ? _mapUser(_auth.currentUser) : _memorySession;

  Future<void> signIn({
    required String email,
    required String password,
    required bool registerMode,
  }) async {
    if (_auth == null) {
      _memorySession = AuthSession(
        uid: 'memory-user',
        email: email.isEmpty ? 'Anonymous session' : email,
        isAnonymous: email.isEmpty,
      );
      _sessionController!.add(_memorySession);
      return;
    }

    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw ArgumentError('Email and password are required.');
    }

    if (registerMode) {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return;
    }

    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    if (_auth == null) {
      _memorySession = const AuthSession(
        uid: 'memory-google-user',
        email: 'google.user@wavemed.app',
        isAnonymous: false,
      );
      _sessionController!.add(_memorySession);
      return;
    }

    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }

    final GoogleSignInAccount? account = await _googleSignIn!.signIn();
    if (account == null) {
      throw const AuthSessionCancelledException();
    }
    final GoogleSignInAuthentication googleAuth =
        await account.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      throw ArgumentError('Email is required');
    }
    if (_auth == null) {
      return;
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (_auth != null) {
      await _auth.signOut();
      await _googleSignIn?.signOut();
      return;
    }
    _memorySession = null;
    _sessionController!.add(null);
  }

  Future<String?> getFreshIdToken() async {
    if (_auth != null) {
      return _auth.currentUser?.getIdToken(true);
    }
    return 'memory-token';
  }

  AuthSession? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthSession(
      uid: user.uid,
      email: user.email ?? (user.isAnonymous ? 'Anonymous session' : ''),
      isAnonymous: user.isAnonymous,
    );
  }
}

class AuthSessionCancelledException implements Exception {
  const AuthSessionCancelledException();
}
