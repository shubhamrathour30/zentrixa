import 'package:shared_preferences/shared_preferences.dart';

/// Phone (APK) ke do mode:
///  - shell (default): app server se poora Zentrixa khol leta hai => server par update karo, phone par khud aa jata hai.
///  - native (classic): app ke andar bana purana tareeka (har update par naya APK).
class AppMode {
  static const _k = 'zx_mode';

  static Future<bool> isShell() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getString(_k) ?? 'shell') == 'shell';
    } catch (_) {
      return true;
    }
  }

  static Future<void> set(bool shell) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k, shell ? 'shell' : 'native');
    } catch (_) {}
  }
}
