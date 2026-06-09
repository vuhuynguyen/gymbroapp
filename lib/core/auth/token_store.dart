import 'dart:convert';
import 'package:flutter/foundation.dart';

/// In-memory holder for the short-lived access JWT. Deliberately NOT persisted — on a cold start
/// the session is restored by a silent refresh against the secure-storage refresh cookie (see
/// TokenRefresher). This keeps the long-lived credential out of reach of app-level compromise.
///
/// A [ChangeNotifier] so the router can react to login/logout immediately.
class TokenStore extends ChangeNotifier {
  String? _accessToken;

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  void setToken(String token) {
    _accessToken = token;
    notifyListeners();
  }

  void clear() {
    if (_accessToken == null) return;
    _accessToken = null;
    notifyListeners();
  }

  /// `is_admin` claim — Members are never admins, but mirrored from the JWT for parity with the Portal.
  bool get isPlatformAdmin => _readIsAdmin(_accessToken);

  static bool _readIsAdmin(String? token) {
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return false;
      final payload = base64Url.normalize(parts[1]);
      final map = jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
      final v = map['is_admin'];
      return v == true || v == 'true';
    } catch (_) {
      return false;
    }
  }
}
