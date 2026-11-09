// Saisai (ใสใส), the sky jellyfish: a port of `tpl-sai` in the dark
// characters page (specs/assets/dark-characters-src.html, SVG viewBox
// 0 0 200 200, with the `sai-bell`, `sai-core` and `soft-halo` defs). Drawn
// in those SVG units; the caller scales the canvas.
//
// Unlike the earlier friends, Saisai has a purple outline (#9B8BE0) and
// purple features (#583EAD), not the #3B302C ink, and glows on its own
// (`soft-halo`).
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1; the sleepy `--zz` is not
// used): the bell swells and floats up 8 units, the tentacles shorten
// (scaleY 1.06 -> 0.90) and sway, the centre glow brightens; on hold the
// tentacle tips glow and three sparkles show.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

/// The purple outline of the bell (and of the sparkles, see below).
const saisaiOutline = Color(0xFF9B8BE0);
const _feature = Color(0xFF583EAD);
const _tentacleOuter = Color(0xFFCFC3FF);
const _tentacleInner = Color(0xFFE6DEFF);
const _tentacleMid = Color(0xFFF7F6F2);
const _cream = friendCream;
const _dots = Color(0xFFB9A6EE);
const _blush = Color(0xFFF4B6CF);

/// The flower anchor (`.anchor` circle): the left top of the bell.
const saisaiAnchor = Offset(86, 60);

/// How far Saisai floats up at a full breath.
const saisaiFloat = 8.0;

/// Where [saisaiAnchor] is at lung level [lv] (it floats with Saisai).
Offset saisaiAnchorAt(double lv) => saisaiAnchor.translate(0, -saisaiFloat * lv.clamp(0.0, 1.0));

/// The tentacles' vertical scale (from y 104) at lung level [lv].
double saisaiTentacleScale(double lv) => 1.06 - lv.clamp(0.0, 1.0) * 0.16;

final _tentacles = [
  (
    Path()
      ..moveTo(66, 106)
      ..quadraticBezierTo(60, 128, 70, 146)
      ..quadraticBezierTo(78, 160, 70, 172),
    _tentacleOuter,
    4.0,
  ),
  (
    Path()
      ..moveTo(134, 106)
      ..quadraticBezierTo(140, 128, 130, 146)
      ..quadraticBezierTo(122, 160, 130, 172),
    _tentacleOuter,
    4.0,
  ),
  (
    Path()
      ..moveTo(84, 108)
      ..quadraticBezierTo(78, 132, 88, 150)
      ..quadraticBezierTo(94, 162, 88, 178),
    _tentacleInner,
    4.0,
  ),
  (
    Path()
      ..moveTo(116, 108)
      ..quadraticBezierTo(122, 132, 112, 150)
      ..quadraticBezierTo(106, 162, 112, 178),
    _tentacleInner,
    4.0,
  ),
  (
    Path()
      ..moveTo(100, 108)
      ..quadraticBezierTo(92, 124, 100, 138)
      ..quadraticBezierTo(108, 150, 100, 160),
    withOpacity(_tentacleMid, 0.85),
    7.0,
  ),
];

const _tips = [Offset(70, 172), Offset(130, 172), Offset(88, 178), Offset(112, 178)];

final _bell = Path()
  ..moveTo(44, 104)
  ..cubicTo(44, 56, 156, 56, 156, 104)
  ..quadraticBezierTo(150, 113, 140, 107)
  ..quadraticBezierTo(130, 115, 120, 107)
  ..quadraticBezierTo(110, 115, 100, 107)
  ..quadraticBezierTo(90, 115, 80, 107)
  ..quadraticBezierTo(70, 115, 60, 107)
  ..quadraticBezierTo(50, 113, 44, 104)
  ..close();

final _eyes = Path()
  ..moveTo(78, 90)
  ..quadraticBezierTo(85, 97, 92, 90)
  ..moveTo(108, 90)
  ..quadraticBezierTo(115, 97, 122, 90);

final _mouth = Path()
  ..moveTo(96, 99)
  ..quadraticBezierTo(100, 103, 104, 99);

final _sparkles = [
  sparkle(const Offset(36, 67), 7),
  sparkle(const Offset(166, 77), 7),
  sparkle(const Offset(158, 144), 6),
];

/// Draws Saisai in SVG units at lung level [lv] (0..1) and [hold] (0..1).
/// [flower] paints the worn flower centred on the given point. [glow]
/// false leaves out the halo (silhouettes); [room] is the box it is drawn
/// in (SVG units), which the halo stays inside.
void drawSaisai(
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
  if (glow) softHalo(p, const Offset(100, 100), 88 * (0.82 + lv * 0.22), 0.3 + lv * 0.55, room: room, maxR: 88 * 1.04);

  p.save();
  p.translate(0, -saisaiFloat * lv);

  // tentacles: shorter at a full breath, swaying a little
  p.save();
  p.translate(100, 104);
  p.scale(1, saisaiTentacleScale(lv));
  p.rotate((lv - 0.5) * 5 * math.pi / 180);
  p.translate(-100, -104);
  for (final (path, colour, width) in _tentacles) {
    p.drawPath(path, stroke(colour, width));
  }
  // the tips glow on hold
  final tip = fill(withOpacity(_cream, 0.45 + hold * 0.55));
  for (final t in _tips) {
    p.drawCircle(t, 4, tip);
  }
  p.restore();

  // the bell swells
  p.save();
  p.translate(100, 106);
  p.scale(1 + lv * 0.06, 1 + lv * 0.1);
  p.translate(-100, -106);
  // `sai-bell`: objectBoundingBox gradient on the bell (x 44..156, y 68..111),
  // centre (.45, .3), radius .75 of each side: an oval
  p.save();
  p.clipPath(_bell);
  const bw = 112.0, bh = 43.0;
  p.translate(44 + 0.45 * bw, 68 + 0.3 * bh);
  p.scale(1, bh / bw);
  const r = 0.75 * bw;
  p.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFEAE5F7), Color(0xFFBFB0F0)],
        stops: [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
  );
  p.restore();
  p.drawPath(_bell, stroke(saisaiOutline, 2.5));

  // the light in the middle (`sai-core`)
  final coreA = (0.15 + lv * 0.35 + hold * 0.5).clamp(0.0, 1.0);
  const core = Offset(100, 86);
  p.drawCircle(
    core,
    34,
    Paint()
      ..shader = RadialGradient(colors: [withOpacity(_cream, 0.95 * coreA), withOpacity(_cream, 0)])
          .createShader(Rect.fromCircle(center: core, radius: 34)),
  );

  // shine, freckles, face
  p.save();
  p.translate(80, 70);
  p.rotate(-20 * math.pi / 180);
  ellipse(p, Offset.zero, 12, 7, fill(withOpacity(const Color(0xFFFFFFFF), 0.8)));
  p.restore();
  final dot = fill(_dots);
  p.drawCircle(const Offset(58, 96), 3.5, dot);
  p.drawCircle(const Offset(142, 96), 3.5, dot);
  p.drawCircle(const Offset(66, 80), 2.5, dot);
  p.drawCircle(const Offset(134, 80), 2.5, dot);
  p.drawPath(_eyes, stroke(_feature, 3.5));
  ellipse(p, const Offset(73, 100), 7, 4, fill(_blush));
  ellipse(p, const Offset(127, 100), 7, 4, fill(_blush));
  p.drawPath(_mouth, stroke(_feature, 3));
  p.restore();

  p.restore();

  // sparkles while holding (they do not float)
  sparkles(p, _sparkles, hold, saisaiOutline);

  flower?.call(p, saisaiAnchorAt(lv));
}
