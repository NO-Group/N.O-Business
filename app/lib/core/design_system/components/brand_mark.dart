import 'package:flutter/material.dart';

import '../tokens.dart';

/// The N.O Business mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.glow = false});

  final double size;

  /// Adds the brand glow. Reserve for hero placements (sign-in, splash).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: glow ? NobShadows.glow(NobColors.cobalt, strength: 0.55) : NobShadows.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/brand/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'N.O Business',
      ),
    );
  }
}

/// Mark + product name, with the parent company as a quiet overline.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 36, this.showParent = true});

  final double markSize;
  final bool showParent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        const SizedBox(width: NobSpace.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showParent)
              Text(
                'N.O GROUP',
                style: NobText.overline.copyWith(color: NobColors.textMuted, fontSize: 9.5),
              ),
            Text(
              'N.O Business',
              style: NobText.subtitle.copyWith(
                color: NobColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Text painted with the brand gradient. For a single hero word or figure.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = NobGradients.brand,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
