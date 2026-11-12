import 'package:flutter/material.dart';

/// N.O Business design tokens.
///
/// The palette is sampled from the N.O Business mark (brand/no-business-logo.png):
/// a near-black navy field lit by cyan → cobalt → violet → magenta, with a
/// restrained emerald accent. Every colour used anywhere in the app comes
/// from here; widgets never hard-code a hex value.
abstract final class NobColors {
  // Surfaces, darkest to lightest.
  static const background = Color(0xFF050817);
  static const backgroundRaised = Color(0xFF080D22);
  static const surface = Color(0xFF0B1230);
  static const surfaceHigh = Color(0xFF111A40);
  static const border = Color(0xFF1B2650);
  static const borderStrong = Color(0xFF2B3A75);

  // Brand spectrum.
  static const cyan = Color(0xFF00EFFF);
  static const cobalt = Color(0xFF075BFF);
  static const violet = Color(0xFF761BFF);
  static const magenta = Color(0xFFF000E8);
  static const emerald = Color(0xFF00E9A8);

  // Text. Contrast against the lightest surface it sits on ([surfaceHigh]):
  // primary 15.8:1, secondary 7.5:1, muted 4.7:1. All pass WCAG AA for body text.
  static const textPrimary = Color(0xFFF5F7FF);
  static const textSecondary = Color(0xFFA3ADC6);
  static const textMuted = Color(0xFF7A86A8);
  static const onAccent = Color(0xFFFFFFFF);
  static const onCyan = Color(0xFF00141A);

  // Semantic.
  static const success = emerald;
  static const warning = Color(0xFFFFB84D);
  static const danger = Color(0xFFFF5470);
  static const info = cyan;
}

abstract final class NobGradients {
  /// The full brand sweep. Reserved for the mark, hero accents and the one
  /// primary call-to-action on a screen.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [NobColors.cyan, NobColors.cobalt, NobColors.violet, NobColors.magenta],
    stops: [0, 0.38, 0.72, 1],
  );

  /// Primary action fill.
  static const action = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [NobColors.cobalt, NobColors.violet],
  );

  /// Barely-there sheen for glass-like cards.
  static const sheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x05FFFFFF)],
  );

  /// Ambient backdrop behind auth / onboarding screens.
  static const backdrop = RadialGradient(
    center: Alignment(-0.8, -0.9),
    radius: 1.4,
    colors: [Color(0x33075BFF), Color(0x00050817)],
  );
}

/// 4-point spacing scale.
abstract final class NobSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class NobRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(xl));
}

/// Elevation is expressed with borders first; shadows and glow are accents.
abstract final class NobShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12)),
  ];

  /// Controlled glow. Use on at most one element per view.
  static List<BoxShadow> glow(Color color, {double strength = 0.35}) => [
    BoxShadow(color: color.withValues(alpha: strength), blurRadius: 28, spreadRadius: -6),
  ];
}

abstract final class NobMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;
}

/// Layout breakpoints (logical pixels).
abstract final class NobBreakpoints {
  static const double compact = 600;
  static const double expanded = 1024;
  static const double contentMax = 1280;

  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compact;
  static bool isExpanded(BuildContext context) => MediaQuery.sizeOf(context).width >= expanded;
}

/// Type scale (Manrope). Numbers use tabular figures so columns line up.
abstract final class NobText {
  static const String family = 'Manrope';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );
  static const TextStyle subtitle = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static const TextStyle overline = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );
  static const TextStyle metric = TextStyle(
    fontFamily: family,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: tabular,
  );
  static const TextStyle numeric = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    fontFeatures: tabular,
  );
}
