// Wongwong (วงวง), the tiny ringed planet with a mini moon: a port of
// `tpl-ww` in the dark characters page (specs/assets/dark-characters-src.html,
// SVG viewBox 0 0 200 200, with the `ww-body`, `ww-clip`, `ww-front` and
// `soft-halo` defs). Drawn in those SVG units; the caller scales the canvas.
//
// Like Saisai, Wongwong has a purple outline (#9B8BE0) and purple features
// (#583EAD), not the #3B302C ink, and glows on its own (`soft-halo`).
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1; the sleepy `--zz` is not
// used): the body swells (x 1.07) and floats up 5 units, the ring opens (its
// height grows from 0.20 to 0.36 of its width), the moon rises; on hold the
// moon glows and sparkles show.
//
// The ring is drawn in two passes, the whole ring behind the body and its
// front half over it, each as a tilted ellipse of the computed height (not a
// scaled circle), so the stroke stays even (the SVG's non-scaling-stroke).

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

/// The purple outline of the body (and of the moon and sparkles, see below).
const wongwongOutline = Color(0xFF9B8BE0);
const _feature = Color(0xFF583EAD);
const _ringOuter = Color(0xFFB7A8F2);
const _ringInner = Color(0xFFF7F6F2);
const _moon = Color(0xFFFFF1C9);
const _blush = Color(0xFFF4B6CF);

/// The flower anchor (`.anchor` circle): the left top of the planet, above
/// the ring.
const wongwongAnchor = Offset(76, 64);

/// How far Wongwong floats up at a full breath.
const wongwongFloat = 5.0;

/// The planet's centre and radius (`ww-clip`); the ring turns round it.
const wongwongCentre = Offset(100, 108);
const wongwongRadius = 50.0;

/// The ring's tilt.
const wongwongTilt = -14 * math.pi / 180;

/// Where [wongwongAnchor] is at lung level [lv] (it floats with Wongwong).
Offset wongwongAnchorAt(double lv) => wongwongAnchor.translate(0, -wongwongFloat * lv.clamp(0.0, 1.0));

/// The ring's height as a fraction of its width at lung level [lv]: flat at
/// rest, open at a full breath.
double wongwongRingOpen(double lv) => 0.2 + lv.clamp(0.0, 1.0) * 0.16;

/// The moon's centre at lung level [lv] (before the body's float).
Offset wongwongMoonAt(double lv) => Offset(30 + 10 * lv.clamp(0.0, 1.0), 132 - 14 * lv.clamp(0.0, 1.0));

final _bands = [
  Path()
    ..moveTo(40, 118)
    ..quadraticBezierTo(100, 102, 160, 118)
    ..lineTo(160, 128)
    ..quadraticBezierTo(100, 112, 40, 128)
    ..close(),
  Path()
    ..moveTo(40, 140)
    ..quadraticBezierTo(100, 126, 160, 140)
    ..lineTo(160, 147)
    ..quadraticBezierTo(100, 133, 40, 147)
    ..close(),
];

final _eyes = Path()
  ..moveTo(80, 104)
  ..quadraticBezierTo(87, 111, 94, 104)
  ..moveTo(106, 104)
  ..quadraticBezierTo(113, 111, 120, 104);

final _mouth = Path()
  ..moveTo(96, 114)
  ..quadraticBezierTo(100, 118, 104, 114);

final _sparkles = [
  sparkle(const Offset(170, 83), 7),
  sparkle(const Offset(40, 60), 6),
  sparkle(const Offset(150, 166), 6),
];

/// The two strokes of the ring (outer lilac, inner white) as tilted ellipses
/// of height [open] x width, in the planet's frame. [front] keeps only the
/// half below the ring's own axis (`ww-front`), which passes over the body.
void _ring(Canvas p, double open, {required bool front}) {
  p.save();
  p.translate(wongwongCentre.dx, wongwongCentre.dy);
  p.rotate(wongwongTilt);
  if (front) p.clipRect(const Rect.fromLTRB(-120, 0, 120, 120));
  for (final (r, colour, width, alpha) in [(84.0, _ringOuter, 5.0, 0.7), (74.0, _ringInner, 7.0, front ? 1.0 : 0.85)]) {
    ellipse(p, Offset.zero, r, r * open, stroke(withOpacity(colour, alpha), width));
  }
  p.restore();
}

/// Draws Wongwong in SVG units at lung level [lv] (0..1) and [hold] (0..1).
/// [flower] paints the worn flower centred on the given point. [glow]
/// false leaves out the halo and the moon's glow (silhouettes); [room] is
/// the box it is drawn in (SVG units), which the halo stays inside.
void drawWongwong(
  Canvas p,
  double lv,
  double hold, {
  void Function(Canvas, Offset)? flower,
  bool glow = true,
  Rect? room,
}) {
  lv = lv.clamp(0.0, 1.0);
  hold = hold.clamp(0.0, 1.0);

  // the self-glow (`soft-halo`): grows and brightens with the breath
  if (glow) softHalo(p, wongwongCentre, 88 * (0.8 + lv * 0.24), 0.25 + lv * 0.55, room: room, maxR: 88 * 1.04);

  p.save();
  p.translate(0, -wongwongFloat * lv);
  final open = wongwongRingOpen(lv);

  // pass 1: the ring behind the body
  _ring(p, open, front: false);

  // the planet swells
  p.save();
  p.translate(wongwongCentre.dx, wongwongCentre.dy);
  p.scale(1 + lv * 0.07);
  p.translate(-wongwongCentre.dx, -wongwongCentre.dy);
  // `ww-body`: centre (.38, .3), radius .8 of the 100-unit box
  const gc = Offset(50 + 38, 58 + 30), gr = 80.0;
  p.drawCircle(
    wongwongCentre,
    wongwongRadius,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFF7F6F2), Color(0xFFDCD3F6), Color(0xFF9D8BE3)],
        stops: [0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: gc, radius: gr)),
  );
  p.save();
  p.clipPath(Path()..addOval(Rect.fromCircle(center: wongwongCentre, radius: wongwongRadius)));
  final band = fill(withOpacity(_ringOuter, 0.45));
  for (final b in _bands) {
    p.drawPath(b, band);
  }
  p.restore();
  p.drawCircle(wongwongCentre, wongwongRadius, stroke(wongwongOutline, 2.5));
  p.save();
  p.translate(80, 80);
  p.rotate(-30 * math.pi / 180);
  ellipse(p, Offset.zero, 11, 6, fill(withOpacity(const Color(0xFFFFFFFF), 0.85)));
  p.restore();
  p.drawPath(_eyes, stroke(_feature, 3.5));
  ellipse(p, const Offset(75, 115), 7, 4, fill(_blush));
  ellipse(p, const Offset(125, 115), 7, 4, fill(_blush));
  p.drawPath(_mouth, stroke(_feature, 3));
  p.restore();

  // pass 2: the front half of the ring over the body
  _ring(p, open, front: true);

  // the mini moon rises; it glows on hold. A thin purple outline so the pale
  // moon shows on the app's light screens
  final moon = wongwongMoonAt(lv);
  p.drawCircle(moon, 8, fill(_moon));
  p.drawCircle(moon, 8, stroke(wongwongOutline, 2));
  if (glow) p.drawCircle(moon, 14, fill(withOpacity(_moon, 0.12 + hold * 0.3)));
  p.restore();

  // sparkles while holding (they do not float)
  sparkles(p, _sparkles, hold, wongwongOutline);

  flower?.call(p, wongwongAnchorAt(lv));
}
