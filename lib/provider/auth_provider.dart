import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRemembered = false;
  bool _isFirstTimeUser = true;

  User? get user => _user;
  bool get loading => _isLoading;
  String? get error => _errorMessage;
  bool get isRemembered => _isRemembered;
  bool get isFirstTimeUser => _isFirstTimeUser;
  User? get currentUser => _auth.currentUser;
  bool get signedIn => currentUser != null;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();

    _isRemembered = prefs.getBool('remember_me') ?? false;

    _isFirstTimeUser = prefs.getBool('is_first_time') ?? true;

    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  // ==========================================
  // ၁။ CREATE ACCOUNT (SIGN UP) & FIRESTORE STORE
  // ==========================================
  Future<bool> signUp(String name, String email, String pass) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // ၁.၁ Firebase Auth တွင် အကောင့်သစ်ပြုလုပ်ခြင်း
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      User? newUser = credential.user;

      if (newUser != null) {
        // ၁.၂ Firebase User Profile တွင် Display Name ထည့်သွင်းခြင်း
        await newUser.updateDisplayName(name);

        // ၁.၃ Cloud Firestore ၏ 'users' collection ထဲတွင် User data အချက်အလက် သိမ်းဆည်းခြင်း
        await _firestore.collection('users').doc(newUser.uid).set({
          'uid': newUser.uid,
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await newUser.reload();
        _user = _auth.currentUser;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getReadableErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred during sign up.';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // ၂။ LOGIN (SIGN IN)
  // ==========================================
  Future<bool> login(String email, String password, bool rememberMe) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', rememberMe);
      await prefs.setBool('is_first_time', false);

      _isRemembered = rememberMe;
      _isFirstTimeUser = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getReadableErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // ၃။ PASSWORD RESET
  // ==========================================
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getReadableErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to send reset email.';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // ၄။ LOGOUT
  // ==========================================
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    _isRemembered = false;
    _isFirstTimeUser = true;
    await _auth.signOut();
  }

  // ==========================================
  // ၅။ ERROR MESSAGES HELPER
  // ==========================================
  String _getReadableErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed. Please check your details.';
    }
  }
}
