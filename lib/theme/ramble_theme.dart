import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ramble design system — "Playful 90s Retro Pixel Kawaii".
///
/// This is the single source of truth for all colors, typography, spacing,
/// and the signature hard-pixel-shadow surfaces. Every widget imports from here.
/// Do not hardcode colors or text styles anywhere else.
class RambleColors {
  // ── Primary palette ──────────────────────────────────────────────────────
  static const mikoPurple = Color(0xFF7C3AED);
  static const pixelPink = Color(0xFFEC4899);
  static const creamBase = Color(0xFFFAF5F0);
  static const deepNavy = Color(0xFF1A1A2E);
  static const softBlush = Color(0xFFF9A8D4);

  // ── Extended palette ─────────────────────────────────────────────────────
  static const pixelLavender = Color(0xFFC4B5FD);
  static const warmWhite = Color(0xFFFFFBF7);
  static const gameboyGray = Color(0xFF6B7280);
  static const bit8Green = Color(0xFF10B981);
  static const retroOrange = Color(0xFFF59E0B);
  static const pixelSky = Color(0xFF60A5FA);
  static const crtOffBlack = Color(0xFF0F0F1A);
  static const warmRed = Color(0xFFEF4444);

  // ── Dark-mode surfaces ───────────────────────────────────────────────────
  static const darkSurface = Color(0xFF16162A);
  static const darkText = Color(0xFFE8E8F0);
}

/// Brand color per note intent type. Used for badges, card accent stripes,
/// and graph nodes. Keep in lockstep with [NoteType] in models/note.dart.
enum RambleNoteTone { idea, task, meeting, study, reflection, research, feedback }

Color noteToneColor(RambleNoteTone tone) {
  switch (tone) {
    case RambleNoteTone.idea:
      return RambleColors.mikoPurple;
    case RambleNoteTone.task:
      return RambleColors.retroOrange;
    case RambleNoteTone.meeting:
      return RambleColors.pixelSky;
    case RambleNoteTone.study:
      return RambleColors.bit8Green;
    case RambleNoteTone.reflection:
      return RambleColors.pixelPink;
    case RambleNoteTone.research:
      return RambleColors.softBlush;
    case RambleNoteTone.feedback:
      return RambleColors.warmRed;
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

/// Shared geometry constants.
class RambleGeo {
  static const cardRadius = 8.0;
  static const inputRadius = 6.0;
  static const badgeRadius = 4.0;
  static const borderWidth = 2.0;
  static const pixelShadowOffset = 4.0;
}

/// Signature gradients. Used on hero elements only (wordmark, record button,
/// Miko panels) — never as wallpaper. Keeps the brand from going generic.
class RambleGradients {
  static const miko = LinearGradient(
    colors: [RambleColors.mikoPurple, RambleColors.pixelPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dusk = LinearGradient(
    colors: [RambleColors.mikoPurple, RambleColors.pixelSky],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ember = LinearGradient(
    colors: [RambleColors.pixelPink, RambleColors.retroOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Soft neon glow — the "cool" counterpart to the hard pixel shadow. Use it to
/// make a hero element feel lit from within (record button, active states).
class RambleShadows {
  static List<BoxShadow> glow(Color color,
          {double blur = 24, double spread = 1, double opacity = 0.5}) =>
      [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];
}

/// Typography. Press Start 2P for display/wordmark/Miko, DM Sans for UI/body,
/// JetBrains Mono for transcripts. Built via google_fonts so no asset bundling.
class RambleType {
  static TextStyle wordmark(Color c) =>
      GoogleFonts.pressStart2p(fontSize: 24, height: 1.2, color: c);

  static TextStyle screenTitle(Color c) =>
      GoogleFonts.pressStart2p(fontSize: 14, height: 1.4, color: c);

  static TextStyle mikoMessage(Color c) =>
      GoogleFonts.pressStart2p(fontSize: 11, height: 1.8, color: c);

  static TextStyle sectionHeader(Color c) => GoogleFonts.dmSans(
      fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: c);

  static TextStyle body(Color c) =>
      GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6, color: c);

  static TextStyle label(Color c) =>
      GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: c);

  static TextStyle caption(Color c) =>
      GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4, color: c);

  static TextStyle transcript(Color c) =>
      GoogleFonts.jetBrainsMono(fontSize: 14, height: 1.7, color: c);
}

/// A pair of semantic colors that flips between light and dark mode.
/// Accessed via `context.ramble` (see [RambleThemeX]).
class RambleScheme {
  final Color bg; // app background (cream / crt-off-black)
  final Color surface; // card/elevated surface
  final Color ink; // primary text
  final Color inkSoft; // secondary text/metadata
  final Color shadow; // hard pixel-shadow color (navy in light, purple in dark)
  final Color border; // default hairline/box border
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
    bg: RambleColors.creamBase,
    surface: RambleColors.warmWhite,
    ink: RambleColors.deepNavy,
    inkSoft: RambleColors.gameboyGray,
    shadow: RambleColors.deepNavy,
    border: RambleColors.deepNavy,
    isDark: false,
  );

  static const dark = RambleScheme(
    bg: RambleColors.crtOffBlack,
    surface: RambleColors.darkSurface,
    ink: RambleColors.darkText,
    inkSoft: RambleColors.pixelLavender,
    shadow: RambleColors.mikoPurple,
    border: RambleColors.mikoPurple,
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
        seedColor: RambleColors.mikoPurple,
        brightness: brightness,
        primary: RambleColors.mikoPurple,
        secondary: RambleColors.pixelPink,
        surface: s.surface,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).apply(bodyColor: s.ink, displayColor: s.ink),
      useMaterial3: true,
    );
  }
}

/// `context.ramble` → current [RambleScheme] based on platform brightness.
extension RambleThemeX on BuildContext {
  RambleScheme get ramble =>
      Theme.of(this).brightness == Brightness.dark
          ? RambleScheme.dark
          : RambleScheme.light;
}
