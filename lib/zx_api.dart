import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';

/// Logged-in user ki info (server se aati hai).
/// IMPORTANT: chat/friends mein hamesha `Session.username` use hota hai,
/// email ya jo login box mein type kiya wo nahi.
class Session {
  static String token = '';
  static String username = '';
  static String name = '';
  static String email = '';
  static String avatar = ''; // profile photo ka server path ('' = koi nahi)

  static bool get loggedIn => token.isNotEmpty;

  static void setFrom(Map<String, dynamic> j) {
    token = (j['token'] ?? '').toString();
    username = (j['username'] ?? '').toString();
    name = (j['name'] ?? '').toString();
    email = (j['email'] ?? '').toString();
    avatar = (j['avatar'] ?? '').toString();
    save();
  }

  static void clear() {
    token = '';
    username = '';
    name = '';
    email = '';
    avatar = '';
    _forget();
  }

  // ---- Login yaad rakhna: jab tak user khud Log out na kare, app khulte hi seedha andar.
  static const _kKey = 'zx_session';

  /// Phone/browser mein session save karo (token + naam wagairah).
  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _kKey,
        jsonEncode({
          'token': token,
          'username': username,
          'name': name,
          'email': email,
          'avatar': avatar,
        }),
      );
    } catch (_) {}
  }

  static Future<void> _forget() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kKey);
    } catch (_) {}
  }

  /// App shuru hone par pichla login wapas lao. true => user pehle se logged in hai.
  static Future<bool> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kKey);
      if (raw == null || raw.isEmpty) return false;
      final j = jsonDecode(raw);
      if (j is! Map) return false;
      token = (j['token'] ?? '').toString();
      username = (j['username'] ?? '').toString();
      name = (j['name'] ?? '').toString();
      email = (j['email'] ?? '').toString();
      avatar = (j['avatar'] ?? '').toString();
      if (username.isEmpty) {
        token = '';
      }
      return loggedIn;
    } catch (_) {
      return false;
    }
  }
}

class ApiResult {
  final int status; // 0 = network error
  final dynamic data;
  final String? error;
  const ApiResult(this.status, this.data, this.error);

  bool get ok => status >= 200 && status < 300;
  Map<String, dynamic> get map =>
      data is Map<String, dynamic> ? data as Map<String, dynamic> : {};
  List<dynamic> get list => data is List ? data as List : [];
  String get message => ZxApi.friendly(error);
}

/// Kaun si chat abhi khuli hai (naye message ka banner us chat ke liye nahi dikhta).
class ChatPresence {
  static String peer = '';
}

class ZxApi {
  /// Server ka address. Chrome/laptop par: localhost.
  /// Phone par test karte waqt laptop ka IP likho, jaise 'http://192.168.1.5:3000'
  static String get baseUrl {
    // APK / phone: pehle app ke andar daala hua server address, phir build ke time wala (ZX_SERVER), warna localhost.
    if (!kIsWeb) {
      if (_customServer.isNotEmpty) return _customServer;
      if (_buildServer.isNotEmpty) return _buildServer;
      return 'http://localhost:3000';
    }
    final b = Uri.base;
    final local = b.host == 'localhost' || b.host == '127.0.0.1';
    // Development: Flutter alag port (5000) par, server 3000 par. Public link: app aur server ek hi address par.
    if (local && b.port != 3000) return 'http://localhost:3000';
    return b.origin;
  }

  static const String _buildServer = String.fromEnvironment('ZX_SERVER', defaultValue: '');
  static const String _kServerKey = 'zx_server';
  static String _customServer = '';

  /// Phone par jo server link set hai (app ke andar wala, warna build wala). Khali = abhi set nahi.
  static String get configuredServer => _customServer.isNotEmpty ? _customServer : _buildServer;

  /// Phone par app ke andar se server address (Login screen > Server) badalne ke liye.
  static String get serverShown => baseUrl;

  /// "abc.trycloudflare.com" / "192.168.1.5:3000" / "https://..." - sab chalega.
  static String normalizeServer(String raw) {
    var u = raw.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      final isLan = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?$').hasMatch(u) || u.startsWith('localhost');
      u = (isLan ? 'http://' : 'https://') + u;
    }
    return u;
  }

  static Future<void> loadServer() async {
    if (kIsWeb) return;
    try {
      final p = await SharedPreferences.getInstance();
      _customServer = p.getString(_kServerKey) ?? '';
    } catch (_) {}
  }

  /// Khali string = default (build wala / localhost) par wapas.
  static Future<void> setServer(String raw) async {
    _customServer = normalizeServer(raw);
    try {
      final p = await SharedPreferences.getInstance();
      if (_customServer.isEmpty) {
        await p.remove(_kServerKey);
      } else {
        await p.setString(_kServerKey, _customServer);
      }
    } catch (_) {}
  }

  /// Server chal raha hai ya nahi (login se pehle jaanch).
  static Future<bool> pingServer(String raw) async {
    final u = normalizeServer(raw);
    if (u.isEmpty) return false;
    try {
      final r = await http.get(Uri.parse('$u/api/health')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Session expire hone par (401) main.dart yahan login screen kholta hai.
  static void Function()? onUnauthorized;

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (Session.token.isNotEmpty) 'Authorization': 'Bearer ${Session.token}',
      };

  static ApiResult _wrap(http.Response r) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      data = null;
    }
    String? err;
    if (r.statusCode >= 400) {
      err = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'HTTP_${r.statusCode}';
      if (r.statusCode == 401 && Session.loggedIn && err == 'UNAUTHORIZED') {
        Session.clear();
        onUnauthorized?.call();
      }
    }
    return ApiResult(r.statusCode, data, err);
  }

  static Future<ApiResult> get(String path, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      return _wrap(await http.get(uri, headers: _headers()));
    } catch (_) {
      return const ApiResult(0, null, 'NETWORK');
    }
  }

  static Future<ApiResult> post(String path, Map<String, dynamic> body) async {
    try {
      return _wrap(await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ));
    } catch (_) {
      return const ApiResult(0, null, 'NETWORK');
    }
  }

  static String imageUrl(String p) => p.startsWith('http') ? p : '$baseUrl$p';

  /// Server ke error code ko aasaan message mein badalta hai.
  static String friendly(String? code) {
    switch (code) {
      case null:
        return 'Something went wrong'.tr;
      case 'NETWORK':
        return "Couldn't connect to the server. Is it running?".tr;
      case 'UNAUTHORIZED':
        return 'Session expired, please log in again'.tr;
      case 'INVALID_CREDENTIALS':
        return 'Wrong username/email or password'.tr;
      case 'TOO_MANY_ATTEMPTS':
        return 'Too many attempts. Please try again later'.tr;
      case 'EMAIL_ALREADY_REGISTERED':
        return 'This email is already registered'.tr;
      case 'INVALID_NAME':
        return 'Please enter a valid name'.tr;
      case 'INVALID_EMAIL':
        return 'Please enter a valid email'.tr;
      case 'PASSWORD_TOO_SHORT':
        return 'Password must be at least 6 characters'.tr;
      case 'WAIT_BEFORE_RESEND':
        return 'Please wait, try again in 30 seconds'.tr;
      case 'EMAIL_SEND_FAILED':
        return "Couldn't send the OTP email. Try again later".tr;
      case 'NO_PENDING_SIGNUP':
        return 'Please sign up first to get an OTP'.tr;
      case 'OTP_EXPIRED':
        return 'OTP expired, request a new one'.tr;
      case 'INVALID_OTP':
        return 'Wrong OTP'.tr;
      case 'WRONG_OLD_PASSWORD':
        return 'Old password is wrong'.tr;
      case 'ALREADY_EXISTS':
        return 'Already done'.tr;
      case 'NOT_FRIENDS':
        return 'Follow this person first to chat'.tr;
      case 'REQUEST_NOT_FOUND':
        return 'Request not found'.tr;
      case 'INVALID_IMAGE':
        return 'Invalid image (max 8 MB, JPG/PNG/GIF/WEBP)'.tr;
      case 'EMPTY_POST':
        return 'Write something or choose a photo'.tr;
      case 'INVALID_VIDEO':
        return 'Invalid video (max 12 MB, MP4 or WEBM)'.tr;
      case 'INVALID_REFERRAL':
        return "This invite code doesn't belong to any user".tr;
      case 'BLOCKED':
        return "This action isn't possible because of a block".tr;
      case 'NOT_ENOUGH_COINS':
        return "You don't have enough coins".tr;
      case 'CANNOT_TIP_SELF':
        return "You can't gift coins on your own post".tr;
      case 'INVALID_AMOUNT':
        return 'Invalid amount'.tr;
      case 'TOO_LONG':
        return 'Text is too long'.tr;
      case 'USER_NOT_FOUND':
        return 'User not found'.tr;
      case 'POST_NOT_FOUND':
        return 'Post not found (it may have been deleted)'.tr;
      case 'STORY_NOT_FOUND':
        return 'Story not found (the 24 hours may be over)'.tr;
      case 'ROOM_NOT_FOUND':
        return 'No room with this code (it may have ended)'.tr;
      case 'ROOM_FULL':
        return 'This room already has two people'.tr;
      case 'NOT_IN_ROOM':
        return "You aren't in this room".tr;
      case 'INVALID_MOVIE':
        return "That link doesn't look right".tr;
      case 'INVALID_USER':
        return "You can only invite people you follow or who follow you".tr;
      case 'NOT_ALLOWED':
        return "You can't do that".tr;
      case 'INVALID_REPORT':
        return "Couldn't send the report".tr;
      default:
        return tx('Error: {code}'.tr, {'code': code});
    }
  }
}

/// "just now", "5m ago", "2h ago", "3d ago"
String timeAgo(num epochSeconds) {
  if (epochSeconds <= 0) return '';
  final diff = DateTime.now().millisecondsSinceEpoch ~/ 1000 - epochSeconds.toInt();
  if (diff < 60) return 'just now'.tr;
  if (diff < 3600) return tx('{n}m ago'.tr, {'n': diff ~/ 60});
  if (diff < 86400) return tx('{n}h ago'.tr, {'n': diff ~/ 3600});
  return tx('{n}d ago'.tr, {'n': diff ~/ 86400});
}
