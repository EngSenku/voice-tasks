import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFF0E0F0C);
  static const tx = Color(0xFFECECE4);
  static const mut = Color(0xFF8B8D80);
  static const lime = Color(0xFFD3E87A);
  static const warn = Color(0xFFE9C46A);
  static const orange = Color(0xFFE08A5A);
  static const ink = Color(0xFF1A1C08);
  static const panel = Color(0xFF1D1F17);
}

TextStyle t(double size,
        {FontWeight w = FontWeight.w300,
        Color c = C.tx,
        double? height,
        double? ls}) =>
    GoogleFonts.outfit(
        fontSize: size,
        fontWeight: w,
        color: c,
        height: height,
        letterSpacing: ls);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
        primary: C.lime, onPrimary: C.ink, surface: C.panel, onSurface: C.tx),
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme)
        .apply(bodyColor: C.tx, displayColor: C.tx),
    splashFactory: InkRipple.splashFactory,
  );
}
