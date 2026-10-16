import 'package:flutter/material.dart';

import 'zx_api.dart';

/// Zentrixa sunset / coral design system.
/// Is file ko lib/ folder mein rakho (baaki screens ke saath).
class ZX {
  static const Color bg = Color(0xFFF7F2ED); // warm cream background
  static const Color card = Color(0xFFFFF6EC); // soft card / sheet fill
  static const Color coral = Color(0xFFFF5733); // primary buttons
  static const Color coralSoft = Color(0xFFFFE1D8); // chips, soft highlights
  static const Color ink = Color(0xFF4A1004); // dark brown text
  static const Color muted = Color(0xFFA0643C); // secondary text
  static const Color border = Color(0xFF2A1A14); // bold border colour
  static const Color sun = Color(0xFFFFC46B); // yellow accent
  static const Color online = Color(0xFF16C25A);

  static const double borderWidth = 2;

  static const List<Color> avatarColors = [
    Color(0xFFFFE27A),
    Color(0xFFA8F5C8),
    Color(0xFFBFC9FF),
    Color(0xFFFFCFC2),
    Color(0xFFFFC09F),
  ];

  static Color avatarColor(String s) =>
      avatarColors[(s.isEmpty ? 0 : s.codeUnitAt(0)) % avatarColors.length];

  /// Rounded card with bold border.
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = 24,
    bool shadow = true,
  }) =>
      BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: shadow
            ? const [BoxShadow(color: border, offset: Offset(0, 3))]
            : null,
      );

  static InputDecoration input(String hint, {IconData? icon, Widget? suffix}) {
    OutlineInputBorder b(Color c, [double w = borderWidth]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: muted, fontSize: 15),
      prefixIcon: icon == null ? null : Icon(icon, color: muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: b(border),
      enabledBorder: b(border),
      focusedBorder: b(coral, 2.5),
    );
  }

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: coral,
          primary: coral,
          surface: bg,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: ink,
              displayColor: ink,
            ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: ink,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: border, width: borderWidth),
          ),
          titleTextStyle: const TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// Big coral rounded button with bold border.
class ZxButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  const ZxButton(this.label, {super.key, this.onPressed, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: outlined ? Colors.white : ZX.coral,
          foregroundColor: outlined ? ZX.coral : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: ZX.border, width: ZX.borderWidth),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Round avatar: profile photo (agar hai) warna naam ka pehla letter.
class ZxAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final bool online;

  /// Server ka path jaise '/uploads/a_user.jpg'. Khali ho to letter dikhta hai.
  final String photo;

  const ZxAvatar(
    this.name, {
    super.key,
    this.radius = 24,
    this.online = false,
    this.photo = '',
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final hasPhoto = photo.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: ZX.avatarColor(name),
          backgroundImage: hasPhoto ? NetworkImage(ZxApi.imageUrl(photo)) : null,
          onBackgroundImageError: hasPhoto ? (Object e, StackTrace? s) {} : null,
          child: hasPhoto
              ? null
              : Text(
                  letter,
                  style: TextStyle(
                    color: ZX.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: radius * 0.8,
                  ),
                ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: ZX.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
