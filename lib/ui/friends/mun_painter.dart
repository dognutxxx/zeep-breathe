// Mun (หมุนหมุน), the pinwheel: a port of `tpl-mun` in the 13-character doc
// (SVG viewBox 0 0 200 200). Everything is drawn in those SVG units; the
// caller scales the canvas.
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1): the rotor turns with the
// breath (the doc's `spin` keyframes, see lib/friends/pinwheel.dart: a fast
// turn while inhaling, a slow drift on hold, slowing down while exhaling).
// Where nothing drives it (stills, Reduce Motion) it rests at lv x 45
// degrees, as in the SVG's own transform. Wind lines show with lv and a
// sparkle on hold. The face sits on the hub and does not turn.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

const _stem = Color(0xFFE8C39E);
const _hub = Color(0xFFFFF4E2);
const _blush = Color(0xFFF4A9A0);
const _gold = Color(0xFFFFE08A);

/// The four blades, in SVG order (0, 90, 180, 270 degrees).
const _blades = [Color(0xFFF7C6D4), Color(0xFFBFE3D2), _gold, Color(0xFFC9B8EE)];

/// The flower anchor (`.anchor` circle): a ribbon on the stem under the rotor.
const munAnchor = Offset(100, 128);

/// The rotor's axle.
const munHub = Offset(100, 86);

/// Where [munAnchor] is at lung level [lv] (Mun stands still; only the rotor
/// turns).
Offset munAnchorAt(double lv) => munAnchor;

/// The rotor's resting angle in degrees when nothing spins it (SVG
/// `rotate(calc(var(--lv) * 45deg))`).
double munStillAngle(double lv) => lv.clamp(0.0, 1.0) * 45;

final _blade = Path()
  ..moveTo(0, 0)
  ..lineTo(-6, -62)
  ..quadraticBezierTo(34, -58, 44, -14)
  ..close();

final _wind = Path()
  ..moveTo(2, 120)
  ..quadraticBezierTo(14, 114, 28, 120)
  ..moveTo(8, 136)
  ..quadraticBezierTo(18, 132, 30, 136)
  ..moveTo(166, 150)
  ..quadraticBezierTo(178, 144, 192, 150)
  ..moveTo(172, 164)
  ..quadraticBezierTo(182, 160, 192, 164);

final _eyes = Path()
  ..moveTo(85, 85)
  ..quadraticBezierTo(90.5, 91, 96, 85)
  ..moveTo(104, 85)
  ..quadraticBezierTo(109.5, 91, 115, 85);

final _mouth = Path()
  ..moveTo(97, 95)
  ..quadraticBezierTo(100, 98, 103, 95);

final _sparkle = Path()
  ..moveTo(168, 30)
  ..quadraticBezierTo(169, 36, 175, 37)
  ..quadraticBezierTo(169, 38, 168, 44)
  ..quadraticBezierTo(167, 38, 161, 37)
  ..quadraticBezierTo(167, 36, 168, 30)
  ..close();

/// Draws Mun in SVG units at lung level [lv] (0..1) and [hold] (0..1), the
/// rotor at [angle] degrees (null: [munStillAngle]). [flower] paints the worn
/// flower centred on the given point.
void drawMun(Canvas p, double lv, double hold, {double? angle, void Function(Canvas, Offset)? flower}) {
  lv = lv.clamp(0.0, 1.0);
  hold = hold.clamp(0.0, 1.0);
  ellipse(p, const Offset(100, 190), 34, 5, fill(withOpacity(friendInk, 0.14)));

  // the wooden stem: thick ink with the wood inside
  p.drawLine(const Offset(100, 96), const Offset(100, 186), stroke(friendInk, 13));
  p.drawLine(const Offset(100, 96), const Offset(100, 186), stroke(_stem, 5));

  // wind lines, clearer as the lungs fill
  if (lv > 0.01) p.drawPath(_wind, stroke(withOpacity(friendInk, lv), 3));

  // the rotor
  p.save();
  p.translate(munHub.dx, munHub.dy);
  p.rotate((angle ?? munStillAngle(lv)) * math.pi / 180);
  for (final colour in _blades) {
    outlined(p, _blade, colour);
    p.rotate(math.pi / 2);
  }
  p.restore();

  // the face on the hub (does not turn)
  p.drawCircle(munHub, 25, fill(_hub));
  p.drawCircle(munHub, 25, stroke(friendInk, outlineWidth));
  p.drawPath(_eyes, stroke(friendInk, outlineWidth));
  ellipse(p, const Offset(84, 95), 5.5, 3.2, fill(withOpacity(_blush, 0.9)));
  ellipse(p, const Offset(116, 95), 5.5, 3.2, fill(withOpacity(_blush, 0.9)));
  p.drawPath(_mouth, stroke(friendInk, 3));

  // a sparkle while holding
  if (hold > 0.01) {
    p.drawPath(_sparkle, fill(withOpacity(_gold, hold)));
    p.drawPath(_sparkle, stroke(withOpacity(friendInk, hold), 2.5));
  }

  flower?.call(p, munAnchorAt(lv));
}
