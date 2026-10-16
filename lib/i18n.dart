import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_data.dart';

/// App ki language. Saari UI text English mein likhi hai; dusri language chunne par
/// `kTranslations` se uska anuvaad dikhta hai. Jo text nahi mila wo English hi dikhta hai.
class Lang {
  final String code;
  final String native; // us language mein naam
  final String english;
  final bool rtl;
  const Lang(this.code, this.native, this.english, {this.rtl = false});
}

const List<Lang> kLanguages = [
  Lang('en', 'English', 'English'),
  Lang('hinglish', 'Hinglish', 'Hindi in English letters'),
  Lang('hi', 'हिन्दी', 'Hindi'),
  Lang('bn', 'বাংলা', 'Bengali'),
  Lang('mr', 'मराठी', 'Marathi'),
  Lang('gu', 'ગુજરાતી', 'Gujarati'),
  Lang('ta', 'தமிழ்', 'Tamil'),
  Lang('te', 'తెలుగు', 'Telugu'),
  Lang('ur', 'اردو', 'Urdu', rtl: true),
  Lang('es', 'Español', 'Spanish'),
  Lang('fr', 'Français', 'French'),
  Lang('de', 'Deutsch', 'German'),
  Lang('pt', 'Português', 'Portuguese'),
  Lang('ru', 'Русский', 'Russian'),
  Lang('ar', 'العربية', 'Arabic', rtl: true),
  Lang('id', 'Bahasa Indonesia', 'Indonesian'),
  Lang('zh', '中文', 'Chinese'),
  Lang('ja', '日本語', 'Japanese'),
];

class L {
  static final ValueNotifier<String> lang = ValueNotifier<String>('en');
  static Map<String, String> _table = const {};

  static bool get rtl {
    for (final l in kLanguages) {
      if (l.code == lang.value) return l.rtl;
    }
    return false;
  }

  /// English text -> chuni hui language ka text (na mile to English).
  static String t(String key) {
    if (lang.value == 'en') return key;
    return _table[key] ?? key;
  }

  /// App shuru hone par saved language padho.
  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final code = p.getString('lang');
      if (code != null && kLanguages.any((l) => l.code == code)) _apply(code);
    } catch (_) {
      // storage na mile to English hi chalega
    }
  }

  static void _apply(String code) {
    _table = kTranslations[code] ?? const {};
    lang.value = code;
  }

  /// Language badlo: save karo aur poori app dobara draw karo.
  static Future<void> set(String code) async {
    _apply(code);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', code);
    } catch (_) {}
    _rebuildAll();
  }

  // Const widgets bhi naye text ke saath dobara bane, isliye har element ko dirty mark karte hain.
  static void _rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}

/// `tx('Hello {name}', {'name': first})` - placeholders {name} ko value se badalta hai.
String tx(String key, [Map<String, Object?> args = const {}]) {
  var s = L.t(key);
  args.forEach((k, v) {
    s = s.replaceAll('{$k}', '$v');
  });
  return s;
}

extension TrX on String {
  /// `'Home'.tr` - chuni hui language mein text.
  String get tr => L.t(this);
}
