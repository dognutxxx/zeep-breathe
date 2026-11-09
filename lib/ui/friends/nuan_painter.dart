// Nuan (นวล), the moon in a nightcap: a port of `tpl-nuan` in the
// 13-character doc (SVG viewBox 0 0 200 200, with the `nuan-clip` def).
// Drawn in those SVG units; the caller scales the canvas.
//
// Breathing (SVG `--lv` 0..1 and `--hold` 0/1): the lilac shadow slides off
// the moon to the right (100 units, clipped to the moon circle), so the moon
// is a crescent at rest and full at the top of the breath; Nuan floats up 4
// units and two stars show on hold.

import 'package:flutter/painting.dart';

import 'friend_paint_util.dart';

const _moon = Color(0xFFFFF1B8);
const _crater = Color(0xFFF1DC93);
const _shadow = Color(0xFFC9C3E8);
const _cap = Color(0xFFA9BDEB);
const _capStripe = Color(0xFF8FA6E0);
const _brim = Color(0xFFF7F1FF);
const _blush = Color(0xFFF5AFA6);
const _star = Color(0xFFFFE08A);

/// The flower anchor (`.anchor` circle): tucked in the nightcap's brim.
const nuanAnchor = Offset(64, 76);

/// The moon's centre and radius (and `nuan-clip`).
const nuanCentre = Offset(100, 106);
const nuanRadius = 58.0;

/// Where [nuanAnchor] is at lung level [lv] (it floats with Nuan).
Offset nuanAnchorAt(double lv) => nuanAnchor.translate(0, -4 * lv.clamp(0.0, 1.0));

final _eyes = Path()
  ..moveTo(76, 110)
  ..quadraticBezierTo(84, 118, 92, 110)
  ..moveTo(108, 110)
  ..quadraticBezierTo(116, 118, 124, 110);

final _mouth = Path()
  ..moveTo(95, 124)
  ..quadraticBezierTo(100, 129, 105, 124);

final _capPath = Path()
  ..moveTo(48, 84)
  ..quadraticBezierTo(58, 42, 104, 44)
  ..quadraticBezierTo(142, 46, 166, 22)
  ..quadraticBezierTo(170, 56, 152, 76)
  ..quadraticBezierTo(100, 60, 48, 84)
  ..close();

final _stripes = Path()
  ..moveTo(84, 50)
  ..quadraticBezierTo(92, 62, 90, 70)
  ..moveTo(122, 50)
  ..quadraticBezierTo(126, 58, 126, 66);

final _brimPath = Path()
  ..moveTo(46, 86)
  ..quadraticBezierTo(100, 58, 154, 78);

final _stars = [
  Path()
    ..moveTo(28, 132)
    ..quadraticBezierTo(29, 138, 35, 139)
    ..quadraticBezierTo(29, 140, 28, 146)
    ..quadraticBezierTo(27, 140, 21, 139)
    ..quadraticBezierTo(27, 138, 28, 132)
    ..close(),
  Path()
    ..moveTo(178, 112)
    ..quadraticBezierTo(179, 118, 185, 119)
    ..quadraticBezierTo(179, 120, 178, 126)
    ..quadraticBezierTo(177, 120, 171, 119)
    ..quadraticBezierTo(177, 118, 178, 112)
    ..close(),
];

/// Draws Nuan in SVG units at lung level [lv] (0..1) and [hold] (0..1).
/// [flower] paints the worn flower centred on the given point.
void drawNuan(Canvas p, double lv, double hold, {void Function(Canvas, Offset)? flower}) {
  lv = lv.clamp(0.0, 1.0);
  hold = hold.clamp(0.0, 1.0);
  ellipse(p, const Offset(100, 190), 40, 5, fill(withOpacity(friendInk, 0.12)));

  p.save();
  p.translate(0, -4 * lv);
  p.drawCircle(nuanCentre, nuanRadius, fill(_moon));
  p.drawCircle(const Offset(70, 84), 7, fill(_crater));
  p.drawCircle(const Offset(134, 136), 9, fill(_crater));
  p.drawCircle(const Offset(132, 92), 5, fill(_crater));

  // the shadow slides off the moon (`nuan-clip`): a full moon at a full breath
  if (lv < 1) {
    p.save();
    p.clipPath(Path()..addOval(Rect.fromCircle(center: nuanCentre, radius: nuanRadius)));
    p.drawCircle(Offset(126 + 100 * lv, 106), 60, fill(withOpacity(_shadow, 0.85)));
    p.restore();
  }
  p.drawCircle(nuanCentre, nuanRadius, stroke(friendInk, outlineWidth));

  p.drawPath(_eyes, stroke(friendInk, outlineWidth));
  ellipse(p, const Offset(74, 124), 8, 4.5, fill(withOpacity(_blush, 0.85)));
  ellipse(p, const Offset(126, 124), 8, 4.5, fill(withOpacity(_blush, 0.85)));
  p.drawPath(_mouth, stroke(friendInk, 3.5));

  // the nightcap, its brim and the pompom
  outlined(p, _capPath, _cap);
  p.drawPath(_stripes, stroke(_capStripe, 4));
  p.drawPath(_brimPath, stroke(friendInk, 15));
  p.drawPath(_brimPath, stroke(_brim, 6));
  p.drawCircle(const Offset(168, 22), 9, fill(_brim));
  p.drawCircle(const Offset(168, 22), 9, stroke(friendInk, outlineWidth));
  p.restore();

  // stars while holding (they do not float)
  if (hold > 0.01) {
    final f = fill(withOpacity(_star, hold)), s = stroke(withOpacity(friendInk, hold), 2.5);
    for (final st in _stars) {
      p.drawPath(st, f);
      p.drawPath(st, s);
    }
  }

  flower?.call(p, nuanAnchorAt(lv));
}
