import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_muchik/config/constants.dart';

class UserSession extends ChangeNotifier {
  // Patrón Singleton
  static final UserSession _instance = UserSession._internal();

  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  String? _accessToken;
  String? _userName;

  String? get accessToken => _accessToken;
  String? get userName => _userName;

  bool get isLoggedIn => _accessToken != null;

  void setUserData({required String token, required String name}) {
    _accessToken = token;
    _userName = name;
    notifyListeners();
  }

  void clearSession() {
    _accessToken = null;
    _userName = null;
    notifyListeners();
  }
}