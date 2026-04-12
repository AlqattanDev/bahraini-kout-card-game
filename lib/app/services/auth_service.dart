import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  String? _uid;
  String? _token;

  String? get currentUid => _uid;
  String? get token => _token;
  bool get isAuthenticated => _uid != null && _token != null;

  Future<void> signInAnonymously() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('auth_token');
    final cachedUid = prefs.getString('auth_uid');

    if (cachedToken != null && cachedUid != null) {
      try {
        final verify = await http.get(
          Uri.parse('${AppConfig.workerUrl}/api/auth/verify'),
          headers: {'Authorization': 'Bearer $cachedToken'},
        );
        if (verify.statusCode == 200) {
          _token = cachedToken;
          _uid = cachedUid;
          return;
        }
      } catch (_) {
        // Network error — fall through to fresh sign-in attempt
      }
      await prefs.remove('auth_token');
      await prefs.remove('auth_uid');
    }

    // Request new anonymous identity
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/auth/anonymous'),
    );

    if (response.statusCode != 200) {
      throw Exception('Auth failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _uid = body['uid'] as String;
    _token = body['token'] as String;

    // Cache credentials
    await prefs.setString('auth_token', _token!);
    await prefs.setString('auth_uid', _uid!);
  }

  Future<void> signOut() async {
    _uid = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_uid');
  }
}
