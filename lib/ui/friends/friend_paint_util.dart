// Small drawing helpers shared by the friend painters (SVG-style shapes in
// the 200 x 200 design units of the 13-character doc).

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
