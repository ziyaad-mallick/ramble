import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ramble design system — "Zen editorial": calm black-and-white, serif type,
/// generous whitespace. Built for a thinking partner, not a toy.
///
/// Single source of truth for color, type, spacing. The old kawaii color names
/// are kept as aliases (so widgets keep compiling) but now resolve to a strict
/// monochrome palette. Miko (the logo art) is the one spot of colour.
class RambleColors {
  // ── Monochrome core ──────────────────────────────────────────────────────
  static const paper = Color(0xFFFAFAF8); // light background
  static const ink = Color(0xFF161614); // primary text / black
  static const inkMute = Color(0xFF6E6E68); // secondary text
  static const line = Color(0xFFE5E3DD); // hairline border
  static const white = Color(0xFFFFFFFF);

  // ── Back-compat aliases (resolve to monochrome) ──────────────────────────
  static const mikoPurple = ink; // "primary" → black
  static const pixelPink = Color(0xFF2B2B29); // emphasis → near-black
  static const creamBase = paper;
  static const warmWhite = white;
  static const deepNavy = ink;
  static const softBlush = Color(0xFFEDEDEA);
  static const pixelLavender = Color(0xFFB7B7B1);
  static const gameboyGray = inkMute;
  static const crtOffBlack = Color(0xFF0E0E0D);
  static const darkSurface = Color(0xFF1A1A18);
  static const darkText = Color(0xFFEDEDE8);

  // Semantic accents — desaturated to near-grey so the canvas stays zen.
  static const bit8Green = Color(0xFF2F2F2D); // "support"
  static const retroOrange = Color(0xFF4A4A46); // "correction"
  static const pixelSky = Color(0xFF3A3A37); // "question"
  static const warmRed = Color(0xFF7C4A45); // danger — one muted brick tone
}

/// Brand tone per note intent type. All map to monochrome shades now —
/// differentiation comes from type label + serif, not colour.
enum RambleNoteTone { idea, task, meeting, study, reflection, research, feedback }

Color noteToneColor(RambleNoteTone tone) {
  switch (tone) {
    case RambleNoteTone.idea:
      return RambleColors.ink;
    case RambleNoteTone.task:
      return const Color(0xFF3A3A37);
    case RambleNoteTone.meeting:
      return const Color(0xFF4A4A46);
    case RambleNoteTone.study:
      return const Color(0xFF2F2F2D);
    case RambleNoteTone.reflection:
      return const Color(0xFF555550);
    case RambleNoteTone.research:
      return const Color(0xFF44443F);
    case RambleNoteTone.feedback:
      return const Color(0xFF6E6E68);
  }
}

/// Spacing scale (4px base grid).
class RambleSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
  static const s8 = 64.0;
}

/// Geometry — softened and thinned for the editorial look.
class RambleGeo {
  static const cardRadius = 10.0;
  static const inputRadius = 8.0;
  static const badgeRadius = 6.0;
  static const borderWidth = 1.0;
  static const pixelShadowOffset = 0.0;
}

/// Typography. Fraunces (a warm modern serif) for display/headings, Newsreader
/// for reading text. All via google_fonts — no asset bundling.
class RambleType {
  static TextStyle wordmark(Color c) => GoogleFonts.fraunces(
      fontSize: 34, fontWeight: FontWeight.w600, height: 1.1, color: c);

  static TextStyle screenTitle(Color c) => GoogleFonts.fraunces(
      fontSize: 24, fontWeight: FontWeight.w600, height: 1.2, color: c);

  static TextStyle sectionHeader(Color c) => GoogleFonts.fraunces(
      fontSize: 19, fontWeight: FontWeight.w600, height: 1.3, color: c);

  static TextStyle mikoMessage(Color c) => GoogleFonts.newsreader(
      fontSize: 15, fontStyle: FontStyle.italic, height: 1.6, color: c);

  static TextStyle body(Color c) => GoogleFonts.newsreader(
      fontSize: 16, fontWeight: FontWeight.w400, height: 1.65, color: c);

  // Small uppercase eyebrow labels — serif, letterspaced, quiet.
  static TextStyle label(Color c) => GoogleFonts.newsreader(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: 1.8,
      color: c);

  static TextStyle caption(Color c) => GoogleFonts.newsreader(
      fontSize: 13, fontWeight: FontWeight.w400, height: 1.45, color: c);

  static TextStyle transcript(Color c) => GoogleFonts.newsreader(
      fontSize: 15, fontStyle: FontStyle.italic, height: 1.7, color: c);
}

/// Semantic colours that flip between light and dark. Accessed via `context.ramble`.
class RambleScheme {
  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color shadow;
  final Color border;
  final bool isDark;

  const RambleScheme({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.shadow,
    required this.border,
    required this.isDark,
  });

  static const light = RambleScheme(
    bg: RambleColors.paper,
    surface: RambleColors.white,
    ink: RambleColors.ink,
    inkSoft: RambleColors.inkMute,
    shadow: RambleColors.line, // hard shadows become faint hairlines
    border: RambleColors.line,
    isDark: false,
  );

  static const dark = RambleScheme(
    bg: RambleColors.crtOffBlack,
    surface: RambleColors.darkSurface,
    ink: RambleColors.darkText,
    inkSoft: RambleColors.pixelLavender,
    shadow: Color(0xFF000000),
    border: Color(0xFF2C2C2A),
    isDark: true,
  );
}

class RambleTheme {
  static ThemeData themeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final s = isDark ? RambleScheme.dark : RambleScheme.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: s.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RambleColors.ink,
        brightness: brightness,
        primary: s.ink,
        secondary: s.inkSoft,
        surface: s.surface,
      ),
      textTheme: GoogleFonts.newsreaderTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).apply(bodyColor: s.ink, displayColor: s.ink),
      useMaterial3: true,
    );
  }
}

/// `context.ramble` → current [RambleScheme] based on platform brightness.
extension RambleThemeX on BuildContext {
  RambleScheme get ramble => Theme.of(this).brightness == Brightness.dark
      ? RambleScheme.dark
      : RambleScheme.light;
}
