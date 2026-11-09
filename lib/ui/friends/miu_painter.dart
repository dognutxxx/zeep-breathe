// Miu (หมิว), the bread-loaf cat: a port of `tpl-miu` in the 13-character
// doc (SVG viewBox 0 0 200 200). Everything is drawn in those SVG units; the
// caller scales the canvas.
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1): the body grows taller (scale
// y 1 + 0.11 lv, x 1 + 0.035 lv, from the floor), the belly patch grows
// (1 + 0.12 lv) and the ears tilt out on hold.

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

const _fur = Color(0xFFF3D9B1);
const _earInner = Color(0xFFF4B7A8);
const _stripe = Color(0xFFD9A877);
const _belly = Color(0xFFFFF4E2);
const _blush = Color(0xFFF4A9A0);
const _nose = Color(0xFFE58E86);

/// The flower anchor (`.anchor` circle): next to the left ear.
const miuAnchor = Offset(74, 70);

/// Where [miuAnchor] is at lung level [lv] (it moves with the body).
Offset miuAnchorAt(double lv) => _bodyMap(lv, miuAnchor);

Offset _bodyMap(double lv, Offset p) {
  final sx = 1 + lv * 0.035, sy = 1 + lv * 0.11;
  return Offset(100 + (p.dx - 100) * sx, 182 + (p.dy - 182) * sy);
}

final _tail = Path()
  ..moveTo(150, 172)
  ..cubicTo(184, 174, 192, 140, 172, 128);

final _earL = Path()
  ..moveTo(50, 94)
  ..lineTo(58, 50)
  ..quadraticBezierTo(60, 43, 66, 47)
  ..lineTo(94, 70)
  ..close();
final _earLInner = Path()
  ..moveTo(60, 80)
  ..lineTo(63, 58)
  ..lineTo(80, 70)
  ..close();
final _earR = Path()
  ..moveTo(150, 94)
  ..lineTo(142, 50)
  ..quadraticBezierTo(140, 43, 134, 47)
  ..lineTo(106, 70)
  ..close();
final _earRInner = Path()
  ..moveTo(140, 80)
  ..lineTo(137, 58)
  ..lineTo(120, 70)
  ..close();

final _body = Path()
  ..moveTo(38, 172)
  ..lineTo(38, 116)
  ..quadraticBezierTo(38, 64, 100, 64)
  ..quadraticBezierTo(162, 64, 162, 116)
  ..lineTo(162, 172)
  ..quadraticBezierTo(162, 180, 154, 180)
  ..lineTo(46, 180)
  ..quadraticBezierTo(38, 180, 38, 172)
  ..close();

final _stripes = Path()
  ..moveTo(92, 70)
  ..lineTo(94, 82)
  ..moveTo(100, 68)
  ..lineTo(100, 83)
  ..moveTo(108, 70)
  ..lineTo(106, 82);

final _eyes = Path()
  ..moveTo(66, 112)
  ..quadraticBezierTo(75, 121, 84, 112)
  ..moveTo(116, 112)
  ..quadraticBezierTo(125, 121, 134, 112);

final _noseP = Path()
  ..moveTo(95, 121)
  ..lineTo(105, 121)
  ..lineTo(100, 127)
  ..close();

final _mouth = Path()
  ..moveTo(91, 131)
  ..quadraticBezierTo(95.5, 136, 100, 131)
  ..quadraticBezierTo(104.5, 136, 109, 131);

final _whiskers = Path()
  ..moveTo(44, 120)
  ..lineTo(28, 117)
  ..moveTo(44, 128)
  ..lineTo(29, 131)
  ..moveTo(156, 120)
  ..lineTo(172, 117)
  ..moveTo(156, 128)
  ..lineTo(171, 131);

/// Draws Miu in SVG units at lung level [lv] (0..1) and [hold] (0..1).
/// [flower] paints the worn flower centred on the given point, after the body.
void drawMiu(Canvas p, double lv, double hold, {void Function(Canvas, Offset)? flower}) {
  lv = lv.clamp(0.0, 1.0);
  hold = hold.clamp(0.0, 1.0);
  // floor shadow (does not stretch)
  ellipse(p, const Offset(100, 188), 60, 6, fill(withOpacity(friendInk, 0.14)));

  p.save();
  // the whole cat stretches up from the floor
  p.translate(100, 182);
  p.scale(1 + lv * 0.035, 1 + lv * 0.11);
  p.translate(-100, -182);

  // tail: thick ink stroke with fur inside
  p.drawPath(_tail, stroke(friendInk, 17));
  p.drawPath(_tail, stroke(_fur, 7));

  // ears tilt out while holding
  for (final (path, inner, pivot, sign) in [
    (_earL, _earLInner, const Offset(72, 80), -1.0),
    (_earR, _earRInner, const Offset(128, 80), 1.0),
  ]) {
    p.save();
    p.translate(pivot.dx, pivot.dy);
    p.rotate(sign * hold * 9 * math.pi / 180);
    p.translate(-pivot.dx, -pivot.dy);
    outlined(p, path, _fur);
    p.drawPath(inner, fill(_earInner));
    p.restore();
  }

  outlined(p, _body, _fur);
  p.drawPath(_stripes, stroke(_stripe, 4));

  // belly patch grows with the breath
  p.save();
  final b = 1 + lv * 0.12;
  p.translate(100, 172);
  p.scale(b, b);
  p.translate(-100, -172);
  ellipse(p, const Offset(100, 153), 40, 21, fill(_belly));
  p.restore();

  p.drawPath(_eyes, stroke(friendInk, outlineWidth));
  ellipse(p, const Offset(62, 127), 10, 5.5, fill(withOpacity(_blush, 0.8)));
  ellipse(p, const Offset(138, 127), 10, 5.5, fill(withOpacity(_blush, 0.8)));
  p.drawPath(_noseP, fill(_nose));
  p.drawPath(_noseP, stroke(friendInk, 2.5));
  p.drawPath(_mouth, stroke(friendInk, 3.5));
  p.drawPath(_whiskers, stroke(friendInk, 3));

  for (final x in const [78.0, 122.0]) {
    final r = Rect.fromCenter(center: Offset(x, 179), width: 32, height: 18);
    p.drawOval(r, fill(_belly));
    p.drawOval(r, stroke(friendInk, outlineWidth));
  }
  p.restore();

  // the flower moves with the body but is not stretched
  flower?.call(p, miuAnchorAt(lv));
}
