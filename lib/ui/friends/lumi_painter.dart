// Lumi (ลูมิ), the paper lantern: a port of `tpl-lumi` in the 13-character
// doc (SVG viewBox 0 0 200 200, with the `lumi-glow`, `lumi-halo` and
// `lumi-clip` defs). Drawn in those SVG units; the caller scales the canvas.
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1): Lumi floats up 7 units, the
// glow inside and the halo around brighten, the tassel swings from -4 to +4
// degrees and three sparkles show while holding.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

const _paper = Color(0xFFFFE7C2);
const _lilac = Color(0xFFB79BD1);
const _rib = Color(0xFFE2AE78);
const _blush = Color(0xFFF2A7A0);
const _gold = Color(0xFFFFD27A);

/// The flower anchor (`.anchor` circle): on the hanging ring.
const lumiAnchor = Offset(114, 22);

/// Where [lumiAnchor] is at lung level [lv] (it floats with Lumi).
Offset lumiAnchorAt(double lv) => lumiAnchor.translate(0, -7 * lv.clamp(0.0, 1.0));

final _tasselBag = Path()
  ..moveTo(93, 174)
  ..lineTo(107, 174)
  ..lineTo(110, 189)
  ..quadraticBezierTo(100, 194, 90, 189)
  ..close();

final _ribs = Path()
  ..moveTo(73, 53)
  ..quadraticBezierTo(55, 102, 73, 151)
  ..moveTo(127, 53)
  ..quadraticBezierTo(145, 102, 127, 151);

final _eyes = Path()
  ..moveTo(76, 99)
  ..quadraticBezierTo(84, 107, 92, 99)
  ..moveTo(108, 99)
  ..quadraticBezierTo(116, 107, 124, 99);

final _mouth = Path()
  ..moveTo(94, 114)
  ..quadraticBezierTo(100, 120, 106, 114);

// the three four-point sparkles, as in the SVG
final _sparkles = [
  Path()
    ..moveTo(36, 52)
    ..quadraticBezierTo(37, 58, 43, 59)
    ..quadraticBezierTo(37, 60, 36, 66)
    ..quadraticBezierTo(35, 60, 29, 59)
    ..quadraticBezierTo(35, 58, 36, 52)
    ..close(),
  Path()
    ..moveTo(166, 66)
    ..quadraticBezierTo(167, 72, 173, 73)
    ..quadraticBezierTo(167, 74, 166, 80)
    ..quadraticBezierTo(165, 74, 159, 73)
    ..quadraticBezierTo(165, 72, 166, 66)
    ..close(),
  Path()
    ..moveTo(160, 140)
    ..quadraticBezierTo(161, 145, 166, 146)
    ..quadraticBezierTo(161, 147, 160, 152)
    ..quadraticBezierTo(159, 147, 154, 146)
    ..quadraticBezierTo(159, 145, 160, 140)
    ..close(),
];

/// Draws Lumi in SVG units at lung level [lv] (0..1) and [hold] (0..1).
/// [flower] paints the worn flower centred on the given point.
void drawLumi(Canvas p, double lv, double hold, {void Function(Canvas, Offset)? flower}) {
  lv = lv.clamp(0.0, 1.0);
  hold = hold.clamp(0.0, 1.0);

  // floor shadow: lighter as Lumi floats up
  ellipse(p, const Offset(100, 190), 44, 5, fill(withOpacity(friendInk, 0.16 - lv * 0.07)));

  // halo (`lumi-halo`): grows and brightens with the breath
  final haloR = 94 * (0.72 + lv * 0.3);
  final haloA = 0.08 + lv * 0.8;
  const haloC = Offset(100, 102);
  p.drawCircle(
    haloC,
    haloR,
    Paint()
      ..shader = RadialGradient(colors: [withOpacity(_gold, 0.9 * haloA), withOpacity(_gold, 0)])
          .createShader(Rect.fromCircle(center: haloC, radius: haloR)),
  );

  p.save();
  p.translate(0, -7 * lv);

  // hanging ring
  p.drawCircle(const Offset(100, 29), 7, stroke(friendInk, outlineWidth));
  // (the flower anchor sits here in the SVG; the flower is drawn last so the
  // ring's outline never cuts through it)

  // tassel swings with the breath
  p.save();
  p.translate(100, 160);
  p.rotate((lv * 8 - 4) * math.pi / 180);
  p.translate(-100, -160);
  p.drawLine(const Offset(100, 160), const Offset(100, 175), stroke(friendInk, 4));
  outlined(p, _tasselBag, _lilac);
  p.restore();

  // paper body and the light inside (`lumi-glow`, clipped by `lumi-clip`)
  ellipse(p, const Offset(100, 102), 58, 54, fill(_paper));
  final glowA = 0.15 + lv * 0.85;
  p.save();
  p.clipPath(Path()..addOval(Rect.fromCenter(center: const Offset(100, 102), width: 112, height: 104)));
  // objectBoundingBox gradient on the 116 x 108 ellipse at (100, 110):
  // centre (.5, .55), radius .55 of each side, so it is slightly oval
  p.translate(100, 56 + 0.55 * 108);
  p.scale(1, 108 / 116);
  const r = 0.55 * 116;
  p.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          withOpacity(const Color(0xFFFFF6CF), glowA),
          withOpacity(const Color(0xFFFFC66B), glowA),
          withOpacity(const Color(0xFFFFB25E), 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
  );
  p.restore();

  p.drawPath(_ribs, stroke(_rib, 3));
  ellipse(p, const Offset(100, 102), 58, 54, stroke(friendInk, outlineWidth));
  for (final rect in const [Rect.fromLTWH(76, 37, 48, 14), Rect.fromLTWH(78, 150, 44, 13)]) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    p.drawRRect(rr, fill(_lilac));
    p.drawRRect(rr, stroke(friendInk, outlineWidth));
  }

  p.drawPath(_eyes, stroke(friendInk, outlineWidth));
  ellipse(p, const Offset(74, 114), 9, 5, fill(withOpacity(_blush, 0.85)));
  ellipse(p, const Offset(126, 114), 9, 5, fill(withOpacity(_blush, 0.85)));
  p.drawPath(_mouth, stroke(friendInk, 3.5));

  // sparkles while holding
  if (hold > 0.01) {
    final f = fill(withOpacity(_gold, hold)), s = stroke(withOpacity(friendInk, hold), 2.5);
    for (final sp in _sparkles) {
      p.drawPath(sp, f);
      p.drawPath(sp, s);
    }
  }
  p.restore();

  flower?.call(p, lumiAnchorAt(lv));
}
