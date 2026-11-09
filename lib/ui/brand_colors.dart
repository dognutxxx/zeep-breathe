import 'package:flutter/painting.dart';

/// The new dark brand palette (approved 2026-11-09, `specs/splash-dark-1.9.0.md`).
/// Used by the launch splash only for now; the rest of the app moves to it later.
///
/// Violet and blue on Midnight are only about 2.1-2.2 : 1, so they are light
/// (glows, highlights, icons), never text. Text on dark uses [onDark].
class BrandColors {
  /// Rest Violet: glow, highlights.
  static const primary = Color(0xFF583EAD);

  /// Quiet Blue: gradient partner, icons, links.
  static const secondary = Color(0xFF1555A6);

  /// Midnight: the splash background.
  static const background = Color(0xFF14213D);

  /// Soft Paper: logo and text on dark.
  static const onDark = Color(0xFFF7F6F2);

  /// Lavender Mist: stars, soft light.
  static const accent = Color(0xFFEAE5F7);

  /// The splash glow, centre to edge: Rest Violet into Midnight.
  static const glow = [primary, Color(0xFF3A3290), Color(0xFF1F2A5C), background];
}
