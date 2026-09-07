import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    // User ရဲ့ Login State ပြောင်းလဲမှုကို စောင့်ကြည့်မည်
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Email/Password ဖြင့် Login ဝင်ခြင်း
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message ?? 'Login failed.';
      notifyListeners();
      return false;
    }
  }

  // Email/Password ဖြင့် အကောင့်သစ်ဖွင့်ခြင်း
  Future<bool> signUp(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message ?? 'Sign up failed.';
      notifyListeners();
      return false;
    }
  }

  // Logout ထွက်ခြင်း
  Future<void> logout() async {
    await _auth.signOut();
  }
}
