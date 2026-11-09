// Tuntun (ตุ่นตุ่น), the tortoise: a port of `tpl-tuntun` in the
// 13-character doc (SVG viewBox 0 0 200 200). Drawn in those SVG units; the
// caller scales the canvas.
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1): the head comes out from under
// the shell as the lungs fill (`translateY((1 - lv) x -10)`: at rest it is
// tucked 10 units up, behind the rim), the front legs spread out (7 units
// each way), the shell lifts 3 units, and the shine on the shell grows on
// hold.

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

const _skin = Color(0xFFF6DDB8);
const _shell = Color(0xFFB9D7A8);
const _plate = Color(0xFF9CC48A);
const _rim = Color(0xFFEBCB97);
const _shine = Color(0xFFEAF4E0);
const _blush = Color(0xFFF4A9A0);

/// The flower anchor (`.anchor` circle): the top of the shell.
const tuntunAnchor = Offset(100, 46);

/// Where [tuntunAnchor] is at lung level [lv] (it rides on the shell).
Offset tuntunAnchorAt(double lv) => tuntunAnchor.translate(0, -3 * lv.clamp(0.0, 1.0));

final _eyes = Path()
  ..moveTo(82, 151)
  ..quadraticBezierTo(89, 158, 96, 151)
  ..moveTo(104, 151)
  ..quadraticBezierTo(111, 158, 118, 151);

final _mouth = Path()
  ..moveTo(96, 164)
  ..quadraticBezierTo(100, 168, 104, 164);

final _dome = Path()
  ..moveTo(28, 130)
  ..quadraticBezierTo(28, 50, 100, 50)
  ..quadraticBezierTo(172, 50, 172, 130)
  ..close();

final _hex = Path()
  ..moveTo(84, 72)
  ..lineTo(116, 72)
  ..lineTo(126, 96)
  ..lineTo(116, 118)
  ..lineTo(84, 118)
  ..lineTo(74, 96)
  ..close();

final _seams = Path()
  ..moveTo(84, 72)
  ..lineTo(68, 58)
  ..moveTo(116, 72)
  ..lineTo(132, 58)
  ..moveTo(74, 96)
  ..lineTo(32, 100)
  ..moveTo(126, 96)
  ..lineTo(168, 100)
  ..moveTo(84, 118)
  ..lineTo(78, 128)
  ..moveTo(116, 118)
  ..lineTo(122, 128);

final _shinePath = Path()
  ..moveTo(48, 92)
  ..quadraticBezierTo(54, 70, 72, 60);

/// Draws Tuntun in SVG units at lung level [lv] (0..1) and [hold] (0..1).
/// [flower] paints the worn flower centred on the given point.
void drawTuntun(Canvas p, double lv, double hold, {void Function(Canvas, Offset)? flower}) {
  lv = lv.clamp(0.0, 1.0);
  hold = hold.clamp(0.0, 1.0);
  ellipse(p, const Offset(100, 188), 72, 6, fill(withOpacity(friendInk, 0.14)));

  // front legs step out
  for (final (x, dx) in const [(52.0, -7.0), (148.0, 7.0)]) {
    final r = Rect.fromCenter(center: Offset(x + dx * lv, 158 + 7 * lv), width: 32, height: 24);
    p.drawOval(r, fill(_skin));
    p.drawOval(r, stroke(friendInk, outlineWidth));
  }

  // the head peeks out from under the shell
  p.save();
  p.translate(0, (1 - lv) * -10);
  p.drawCircle(const Offset(100, 154), 26, fill(_skin));
  p.drawCircle(const Offset(100, 154), 26, stroke(friendInk, outlineWidth));
  p.drawPath(_eyes, stroke(friendInk, outlineWidth));
  ellipse(p, const Offset(80, 163), 7, 4, fill(withOpacity(_blush, 0.85)));
  ellipse(p, const Offset(120, 163), 7, 4, fill(withOpacity(_blush, 0.85)));
  p.drawPath(_mouth, stroke(friendInk, 3.5));
  p.restore();

  // the shell lifts a little
  p.save();
  p.translate(0, -3 * lv);
  outlined(p, _dome, _shell);
  p.drawPath(_hex, fill(_plate));
  p.drawPath(_hex, stroke(friendInk, 3));
  p.drawPath(_seams, stroke(friendInk, 3));
  p.drawPath(_shinePath, stroke(withOpacity(_shine, 0.25 + hold * 0.75), 6));
  final rim = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 122, 156, 18), const Radius.circular(9));
  p.drawRRect(rim, fill(_rim));
  p.drawRRect(rim, stroke(friendInk, outlineWidth));
  p.restore();

  flower?.call(p, tuntunAnchorAt(lv));
}
