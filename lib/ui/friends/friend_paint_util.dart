// Small drawing helpers shared by the friend painters (SVG-style shapes in
// the 200 x 200 design units of the 13-character doc).

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// `#3B302C`: the outline colour of every friend.
const friendInk = Color(0xFF3B302C);

/// The doc's `.ol` class: 5 px outline, round joins and caps.
const outlineWidth = 5.0;

Color withOpacity(Color c, double a) => c.withValues(alpha: (c.a * a).clamp(0.0, 1.0));

Paint fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void ellipse(Canvas p, Offset c, double rx, double ry, Paint paint) =>
    p.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), paint);

/// Fill then the 5 px ink outline (`class="ol"`).
void outlined(Canvas p, Path path, Color fillColour) {
  p.drawPath(path, fill(fillColour));
  p.drawPath(path, stroke(friendInk, outlineWidth));
}

// ---- the glowing friends of 1.9.0 (Saisai, Wongwong)

/// The cream of their sparkles and glowing tips.
const friendCream = Color(0xFFFFF6D8);

/// `soft-halo`: a lilac glow that fades to nothing at [r]. In a box
/// ([room], in the same units) too tight for the glow at its largest
/// ([maxR]), the glow is drawn smaller (still growing with the breath), so it
/// never spills out of the friend's box onto the screen around it.
void softHalo(Canvas p, Offset c, double r, double opacity, {Rect? room, double maxR = 0}) {
  if (room != null && maxR > 0) {
    final fit = [c.dx - room.left, room.right - c.dx, c.dy - room.top, room.bottom - c.dy].reduce(math.min);
    if (fit < maxR) r *= math.max(0, fit) / maxR;
  }
  if (!(r > 0) || opacity <= 0) return;
  final a = opacity.clamp(0.0, 1.0);
  p.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          withOpacity(const Color(0xFFB7A8F2), 0.75 * a),
          withOpacity(const Color(0xFF583EAD), 0.28 * a),
          withOpacity(const Color(0xFF583EAD), 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
}

/// A four-point sparkle centred at [c] with half-size [r] (the doc's
/// `M x y-r Q ... Z` stars).
Path sparkle(Offset c, double r) {
  const q = 1.0; // the control points sit 1 unit off the centre
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + q, c.dy - q, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + q, c.dy + q, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - q, c.dy + q, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - q, c.dy - q, c.dx, c.dy - r)
    ..close();
}

/// Cream sparkles at [hold]: on the app's light screens the cream alone
/// would not show, so they get a thin outline in the friend's purple.
void sparkles(Canvas p, List<Path> stars, double hold, Color outline) {
  if (hold <= 0.01) return;
  final f = fill(withOpacity(friendCream, hold)), s = stroke(withOpacity(outline, hold), 2);
  for (final st in stars) {
    p.drawPath(st, f);
    p.drawPath(st, s);
  }
}
