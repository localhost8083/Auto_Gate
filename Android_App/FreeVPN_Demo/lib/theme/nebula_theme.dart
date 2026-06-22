import 'package:flutter/material.dart';

/// Nebula design system — dark cosmic teal-glow palette.
class NebulaColors {
  static const bg = Color(0xFF06121A);
  static const bgDeep = Color(0xFF03090F);
  static const surface = Color(0xFF0E1F2A);
  static const surfaceAlt = Color(0xFF12262F);
  static const border = Color(0xFF1C3743);

  static const teal = Color(0xFF2DD4BF);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF34D399);

  static const textPrimary = Color(0xFFEAF6F4);
  static const textSecondary = Color(0xFF8FA8B2);
  static const textFaint = Color(0xFF5B7682);

  // Feature accents
  static const purple = Color(0xFFA78BFA);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF59E0B);
}

class NebulaGradients {
  /// Bright teal→cyan→green glow used for the ring, logo and primary buttons.
  static const glow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [NebulaColors.green, NebulaColors.teal, NebulaColors.cyan],
  );

  static const tealCyan = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [NebulaColors.teal, NebulaColors.cyan],
  );

  /// Deep cosmic backdrop.
  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1C28), NebulaColors.bg, NebulaColors.bgDeep],
    stops: [0.0, 0.45, 1.0],
  );
}

class NebulaText {
  static const heading = TextStyle(
    color: NebulaColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const tagline = TextStyle(
    color: NebulaColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const status = TextStyle(
    color: NebulaColors.teal,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
  );

  static const timer = TextStyle(
    color: NebulaColors.textPrimary,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
  );

  static const cardTitle = TextStyle(
    color: NebulaColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const cardSub = TextStyle(
    color: NebulaColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
}

/// Text painted with the teal→cyan glow gradient.
class GlowText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GlowText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = NebulaGradients.tealCyan,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}
