import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Attempts to restore a previously logged-in session from shared prefs.
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    final passkey = prefs.getString('passkey');
    if (phone != null && passkey != null) {
      _currentUser = StaticUsers.authenticate(phone, passkey);
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> login(String phone, String passkey) async {
    _isLoading = true;
    notifyListeners();

    // Simulate a short auth delay for UX
    await Future.delayed(const Duration(milliseconds: 500));

    final user = StaticUsers.authenticate(phone, passkey);
    if (user != null) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', phone);
      await prefs.setString('passkey', passkey);
      _isLoading = false;
      notifyListeners();
      return null;
    } else {
      _isLoading = false;
      notifyListeners();
      return 'Invalid phone number or passkey.';
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    await prefs.remove('passkey');
    notifyListeners();
  }
}
