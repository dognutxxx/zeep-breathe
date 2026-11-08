import 'package:flutter/painting.dart';

/// Palette from `app/src/ui.rs`.
class ZeepColors {
  static const ink = Color(0xFF3B302C);
  static const text = Color(0xFF2D2F36);
  static const textSoft = Color(0xFF6B6F7A);
  static const textFaint = Color(0xFF9A9EA8);
  static const blue = Color(0xFF3B7BF0);
  static const blueSoft = Color(0xFFE3EFFB);
  static const shell = Color(0xFFFFF0E2);
  static const btnBg = Color(0xFFF6F0EA);
  static const track = Color(0xFFEFEBE6);
  static const bgTop = Color(0xFFF7FBFD);
  static const bgBottom = Color(0xFFEDF4FA);
  static const mint = Color(0xFF9FE0CF);
  static const mintDark = Color(0xFF1E4A41);
  static const label = Color(0xFF55596A);
}

Color withAlpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

double lerpD(double a, double b, double t) => a + (b - a) * t;

double smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
