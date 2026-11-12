import 'package:flutter/material.dart';

/// Faint brand seal behind the app UI (owner request 2026-09-01) — a single,
/// large, centred logo at ~4.5% opacity, replacing the old tiled slanted
/// text. Purely decorative: wrapped in IgnorePointer so it never intercepts
/// touches, and `errorBuilder` keeps it invisible if the asset is missing
/// rather than throwing into the app.
class WatermarkBackground extends StatelessWidget {
  const WatermarkBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: watermarkOpacity,
          child: FractionallySizedBox(
            widthFactor: 0.55,
            heightFactor: 0.55,
            child: Image.asset(
              'assets/branding/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opacity of the brand seal (kept here so the value stays single-source).
const double watermarkOpacity = 0.045; // ~4.5% ink
