// Wardrobe layers drawn on top of Zeep (items and flowers). The character
// itself lives in zeep_character.dart and is never changed by these.

part of 'zeep_character.dart';

class _Geo {
  final double cx, cy, a, b, s, ey, edx;
  final Offset top, stemCtl, tip;
  const _Geo({
    required this.cx,
    required this.cy,
    required this.a,
    required this.b,
    required this.s,
    required this.ey,
    required this.edx,
    required this.top,
    required this.stemCtl,
    required this.tip,
  });

  /// Point on the body outline at angle [th] (same formula as the body path).
  Offset outline(double th, [double grow = 1]) {
    final sn = math.sin(th), cs = math.cos(th);
    const ex = 2.0 / 2.7;
    var x = a * cs.sign * math.pow(cs.abs(), ex).toDouble();
    var y = b * sn.sign * math.pow(sn.abs(), ex).toDouble();
    x *= 1 + 0.07 * (y / b);
    if (y > 0) y *= 0.96;
    return Offset(cx + x * grow, cy + y * grow);
  }

  /// Point on the sprout stem, 0 = base, 1 = tip.
  Offset stem(double t) {
    final u = 1 - t;
    return top * (u * u) + stemCtl * (2 * u * t) + tip * (t * t);
  }
}

const _bowPink = Color(0xFFF4A7B9);
const _petalPink = Color(0xFFF7B6C2);
const _petalLilac = Color(0xFFC9B8F5);
const _flowerHeart = Color(0xFFFFE08A);
const _vineGreen = Color(0xFF8FCB9B);
const _beanie = Color(0xFFF3B6A8);
const _beanieRib = Color(0xFFE39A8A);
const _beanieBrim = Color(0xFFF7CDC3);
const _capBlue = Color(0xFFC9D4F5);
const _capBrim = Color(0xFFDDE4F9);
const _pom = Color(0xFFFFF8EE);
const _wingTop = Color(0xFFC9B8F5);
const _wingLow = Color(0xFFFFD27F);

void _drawOutfit(Canvas p, Outfit o, _Geo g, double time, bool reduceMotion, void Function() sprout) {
  final head = o[OutfitSlot.head];
  if (head != null) {
    switch (head) {
      case OutfitItem.flowerCrown:
        _flowerCrown(p, g);
      case OutfitItem.beanie:
        _beanieHat(p, g);
      case OutfitItem.sleepCap:
        _sleepCap(p, g);
      case OutfitItem.mushroomHat:
        _mushroomHat(p, g);
      case OutfitItem.catEars:
        _catEars(p, g);
      case OutfitItem.strawHat:
        _strawHat(p, g);
      case OutfitItem.goldLeafCrown:
        _goldLeafCrown(p, g);
      case OutfitItem.wizardHat:
        _wizardHat(p, g);
      case OutfitItem.halo:
        _halo(p, g, time, reduceMotion);
      case OutfitItem.lotusCrown:
        _lotusCrown(p, g);
      default:
    }
    // the sprout always pokes through whatever is on the head
    sprout();
  }
  switch (o[OutfitSlot.sprout]) {
    case OutfitItem.sproutBow:
      _sproutBow(p, g);
    case OutfitItem.ladybug:
      _ladybug(p, g);
    case OutfitItem.dewDrop:
      _dewDrop(p, g);
    case OutfitItem.windChime:
      _hanging(p, g, time, reduceMotion, chime: true);
    case OutfitItem.lantern:
      _hanging(p, g, time, reduceMotion, chime: false);
    case OutfitItem.rainbowRibbon:
      _sproutBow(p, g, rainbow: true);
    default:
  }
  switch (o[OutfitSlot.face]) {
    case OutfitItem.roundGlasses:
      _glasses(p, g);
    case OutfitItem.heartGlasses:
      _heartGlasses(p, g);
    case OutfitItem.starStickers:
      _starStickers(p, g);
    case OutfitItem.rainbowGlasses:
      _glasses(p, g, rainbow: true);
    case OutfitItem.catEyeGlasses:
      _catEyeGlasses(p, g);
    default:
  }
  switch (o[OutfitSlot.friend]) {
    case OutfitItem.butterfly:
      _butterfly(p, g, time, reduceMotion);
    case OutfitItem.cloud:
      _cloud(p, g, time, reduceMotion);
    case OutfitItem.bee:
      _bee(p, g, time, reduceMotion);
    case OutfitItem.skyFish:
      _skyFish(p, g, time, reduceMotion);
    case OutfitItem.bird:
      _bird(p, g, time, reduceMotion);
    case OutfitItem.firefly:
      _firefly(p, g, time, reduceMotion);
    case OutfitItem.crescentMoon:
      _moon(p, g, time, reduceMotion);
    default:
  }
}

const _red = Color(0xFFE8505B);
const _gold = Color(0xFFF5C969);
const _goldLight = Color(0xFFFBE3A6);
const _straw = Color(0xFFEBD39A);
const _wizard = Color(0xFF9E8BE0);
const _skyBlue = Color(0xFF8FB0F0);
const _rainbow = [
  Color(0xFFF59A9A),
  Color(0xFFFFCF70),
  Color(0xFFFFE97A),
  Color(0xFFB5E3C2),
  Color(0xFF8FB0F0),
  Color(0xFFC9B8F5),
];

/// Where a friend floats: right of the head or left of it, with a gentle bob.
Offset _friendAt(_Geo g, double time, bool reduceMotion, {required bool right}) {
  final s = g.s;
  final bob = reduceMotion ? Offset.zero : Offset(math.cos(time * 0.8) * 3 * s, math.sin(time * 1.6) * 4 * s);
  return (right ? Offset(g.cx + g.a * 1.45, g.cy - g.b * 0.95) : Offset(g.cx - g.a * 1.5, g.cy - g.b * 1.0)) + bob;
}

// ---- sprout items

void _ladybug(Canvas p, _Geo g) {
  final s = g.s * 1.5;
  // sits on the right sprout leaf
  final c = g.tip + Offset(4.5 * s, -3.6 * s);
  p.drawCircle(c + Offset(-3.2 * s, -0.5 * s), 2 * s, _fill(ZeepColors.ink));
  _ellipse(p, c, 4 * s, 3.4 * s, 0.2, _red, ZeepColors.ink, 1.3 * s);
  p.drawLine(c + Offset(-3.6 * s, -1.4 * s), c + Offset(3.6 * s, 1.4 * s), _stroke(ZeepColors.ink, 1 * s));
  for (final d in const [(-1.4, -1.6), (1.8, -0.8), (-0.6, 1.6), (2.0, 1.8)]) {
    p.drawCircle(c + Offset(d.$1 * s, d.$2 * s), 0.8 * s, _fill(ZeepColors.ink));
  }
}

void _dewDrop(Canvas p, _Geo g) {
  final s = g.s * 1.5;
  // hangs from the left sprout leaf
  final top = g.tip + Offset(-8.5 * s, 0.5 * s);
  final drop = Path()
    ..moveTo(top.dx, top.dy)
    ..quadraticBezierTo(top.dx + 4.2 * s, top.dy + 5 * s, top.dx + 3.2 * s, top.dy + 7.5 * s)
    ..arcToPoint(Offset(top.dx - 3.2 * s, top.dy + 7.5 * s), radius: Radius.circular(3.4 * s))
    ..quadraticBezierTo(top.dx - 4.2 * s, top.dy + 5 * s, top.dx, top.dy)
    ..close();
  p.drawPath(drop, _fill(const Color(0xFFCFE9FA)));
  p.drawPath(drop, _stroke(ZeepColors.ink, 1.3 * s));
  _ellipse(p, top + Offset(-1.2 * s, 6.5 * s), 0.9 * s, 1.6 * s, 0.3, const Color(0xFFFFFFFF));
}

/// A wind chime (gold bell) or a paper lantern hanging from the stem.
void _hanging(Canvas p, _Geo g, double time, bool reduceMotion, {required bool chime}) {
  final s = g.s * 1.5;
  final side = chime ? -1.0 : 1.0;
  final knot = g.stem(0.55);
  final swing = reduceMotion ? 0.0 : math.sin(time * 1.4 + (chime ? 0 : 1)) * 0.12;
  final hook = knot + Offset(side * 9 * s, -1 * s);
  final hang = hook + Offset.fromDirection(math.pi / 2 + swing, 7 * s);
  _quadLine(p, knot, knot + Offset(side * 5 * s, -3 * s), hook, 1.2 * s, ZeepColors.ink);
  p.drawLine(hook, hang, _stroke(ZeepColors.ink, 1.1 * s));
  if (chime) {
    final bell = Path()
      ..moveTo(hang.dx - 2.4 * s, hang.dy)
      ..quadraticBezierTo(hang.dx - 2.8 * s, hang.dy + 5 * s, hang.dx - 4.6 * s, hang.dy + 7 * s)
      ..lineTo(hang.dx + 4.6 * s, hang.dy + 7 * s)
      ..quadraticBezierTo(hang.dx + 2.8 * s, hang.dy + 5 * s, hang.dx + 2.4 * s, hang.dy)
      ..close();
    p.drawPath(bell, _fill(_gold));
    p.drawPath(bell, _stroke(ZeepColors.ink, 1.3 * s));
    p.drawCircle(hang + Offset(0, 8.4 * s), 1.3 * s, _fill(ZeepColors.ink));
  } else {
    final c = hang + Offset(0, 5.5 * s);
    _ellipse(p, c, 4.6 * s, 4.2 * s, 0, const Color(0xFFF27D8C), ZeepColors.ink, 1.3 * s);
    p.drawOval(
      Rect.fromCenter(center: c, width: 3.6 * s, height: 8.4 * s),
      _stroke(withAlpha(ZeepColors.ink, 0.5), 0.9 * s),
    );
    for (final dy in const [-4.6, 4.6]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + Offset(0, dy * s), width: 5 * s, height: 1.8 * s),
        Radius.circular(0.6 * s),
      );
      p.drawRRect(r, _fill(_gold));
      p.drawRRect(r, _stroke(ZeepColors.ink, 1 * s));
    }
    p.drawLine(c + Offset(0, 5.5 * s), c + Offset(0, 8 * s), _stroke(_gold, 1.2 * s));
  }
}

// ---- face items

void _heartGlasses(Canvas p, _Geo g) {
  final s = g.s;
  final frame = _stroke(ZeepColors.ink, 2 * s);
  for (final sign in const [-1.0, 1.0]) {
    final c = Offset(g.cx + sign * g.edx, g.ey + 1 * s);
    final k = 10.5 * s;
    final heart = Path()
      ..moveTo(c.dx, c.dy + k * 0.85)
      ..cubicTo(c.dx - k * 1.25, c.dy + k * 0.05, c.dx - k * 0.75, c.dy - k * 0.95, c.dx, c.dy - k * 0.35)
      ..cubicTo(c.dx + k * 0.75, c.dy - k * 0.95, c.dx + k * 1.25, c.dy + k * 0.05, c.dx, c.dy + k * 0.85)
      ..close();
    p.drawPath(heart, _fill(withAlpha(const Color(0xFFF7A1B5), 0.5)));
    p.drawPath(heart, frame);
    p.drawLine(Offset(c.dx + sign * k * 0.95, c.dy - 2 * s), Offset(g.cx + sign * g.a * 0.93, g.ey - 3 * s), frame);
  }
  _quadLine(
    p,
    Offset(g.cx - g.edx + 7 * s, g.ey - 2 * s),
    Offset(g.cx, g.ey - 5 * s),
    Offset(g.cx + g.edx - 7 * s, g.ey - 2 * s),
    2 * s,
    ZeepColors.ink,
  );
}

Path _star(Offset c, double r, [double inner = 0.45]) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * inner;
    final pt = c + Offset.fromDirection(-math.pi / 2 + i * math.pi / 5, rr);
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  return path..close();
}

void _starStickers(Canvas p, _Geo g) {
  final s = g.s;
  for (final sign in const [-1.0, 1.0]) {
    final c = Offset(g.cx + sign * g.a * 0.62, g.ey + 4 * s);
    final st = _star(c, 6.5 * s, 0.5);
    p.drawPath(st, _fill(const Color(0xFFFFD34F)));
    p.drawPath(st, _stroke(ZeepColors.ink, 1.2 * s));
  }
}

void _catEyeGlasses(Canvas p, _Geo g) {
  final s = g.s;
  final frame = _stroke(ZeepColors.ink, 2 * s);
  for (final sign in const [-1.0, 1.0]) {
    final c = Offset(g.cx + sign * g.edx, g.ey + 1.5 * s);
    final lens = Path()
      ..moveTo(c.dx - sign * 9 * s, c.dy - 4 * s)
      ..quadraticBezierTo(c.dx, c.dy - 7 * s, c.dx + sign * 12.5 * s, c.dy - 9 * s)
      ..quadraticBezierTo(c.dx + sign * 11 * s, c.dy + 8 * s, c.dx, c.dy + 7.5 * s)
      ..quadraticBezierTo(c.dx - sign * 10 * s, c.dy + 6 * s, c.dx - sign * 9 * s, c.dy - 4 * s)
      ..close();
    p.drawPath(lens, _fill(withAlpha(const Color(0xFFC9B8F5), 0.45)));
    p.drawPath(lens, frame);
    p.drawLine(Offset(c.dx + sign * 12 * s, c.dy - 7 * s), Offset(g.cx + sign * g.a * 0.93, g.ey - 4 * s), frame);
  }
  _quadLine(
    p,
    Offset(g.cx - g.edx + 9 * s, g.ey - 2 * s),
    Offset(g.cx, g.ey - 5 * s),
    Offset(g.cx + g.edx - 9 * s, g.ey - 2 * s),
    2 * s,
    ZeepColors.ink,
  );
}

// ---- head items

void _mushroomHat(Canvas p, _Geo g) {
  final s = g.s, cx = g.cx, a = g.a, b = g.b;
  final base = g.cy - b * 0.55;
  final cap = Path()
    ..moveTo(cx - a * 1.12, base)
    ..cubicTo(cx - a * 1.1, g.cy - b * 1.45, cx + a * 1.1, g.cy - b * 1.45, cx + a * 1.12, base)
    ..quadraticBezierTo(cx, base - 7 * s, cx - a * 1.12, base)
    ..close();
  p.drawPath(cap, _fill(_red));
  p.save();
  p.clipPath(cap);
  for (final d in const [
    (-0.6, -0.8, 5.0),
    (0.05, -1.1, 6.0),
    (0.62, -0.78, 4.6),
    (-0.25, -0.72, 3.4),
    (0.35, -1.02, 3.0),
  ]) {
    p.drawCircle(Offset(cx + a * d.$1, g.cy + b * d.$2), d.$3 * s, _fill(const Color(0xFFFFF8EE)));
  }
  p.restore();
  p.drawPath(cap, _stroke(ZeepColors.ink, 2.4 * s));
}

void _catEars(Canvas p, _Geo g) {
  final s = g.s;
  const fur = Color(0xFF6B5A8E);
  for (final sign in const [-1.0, 1.0]) {
    final base = g.outline((sign < 0 ? -0.72 : -0.28) * math.pi, 0.97);
    final ear = Path()
      ..moveTo(base.dx - 9 * s, base.dy + 3 * s)
      ..lineTo(base.dx + sign * 3 * s, base.dy - 14 * s)
      ..lineTo(base.dx + 9 * s, base.dy + 3 * s)
      ..close();
    final inner = Path()
      ..moveTo(base.dx - 5 * s, base.dy + 1 * s)
      ..lineTo(base.dx + sign * 2.2 * s, base.dy - 8.5 * s)
      ..lineTo(base.dx + 5 * s, base.dy + 1 * s)
      ..close();
    p.drawPath(ear, _fill(fur));
    p.drawPath(ear, _stroke(ZeepColors.ink, 2 * s));
    p.drawPath(inner, _fill(const Color(0xFFF7B6C2)));
  }
  final band = Path();
  for (var i = 0; i <= 24; i++) {
    final pt = g.outline(lerpD(-0.92 * math.pi, -0.08 * math.pi, i / 24), 0.97);
    i == 0 ? band.moveTo(pt.dx, pt.dy) : band.lineTo(pt.dx, pt.dy);
  }
  p.drawPath(band, _stroke(ZeepColors.ink, 5 * s));
  p.drawPath(band, _stroke(fur, 3 * s));
}

void _strawHat(Canvas p, _Geo g) {
  final s = g.s, cx = g.cx, a = g.a, b = g.b;
  final brimY = g.cy - b * 0.62;
  final brim = Rect.fromCenter(center: Offset(cx, brimY), width: a * 2.7, height: 16 * s);
  p.drawOval(brim, _fill(_straw));
  p.drawOval(brim, _stroke(ZeepColors.ink, 2.2 * s));
  final crown = Path()
    ..moveTo(cx - a * 0.72, brimY)
    ..cubicTo(cx - a * 0.72, g.cy - b * 1.3, cx + a * 0.72, g.cy - b * 1.3, cx + a * 0.72, brimY)
    ..close();
  p.drawPath(crown, _fill(_straw));
  p.save();
  p.clipPath(crown);
  final weave = _stroke(withAlpha(const Color(0xFFB8945A), 0.6), 1.2 * s);
  for (var y = brimY - 12 * s; y > g.cy - b * 1.3; y -= 4.5 * s) {
    p.drawLine(Offset(cx - a, y), Offset(cx + a, y), weave);
  }
  p.drawRect(Rect.fromLTRB(cx - a, brimY - 8 * s, cx + a, brimY), _fill(const Color(0xFFF4A7B9)));
  p.restore();
  p.drawPath(crown, _stroke(ZeepColors.ink, 2.2 * s));
}

void _goldLeafCrown(Canvas p, _Geo g) {
  final s = g.s;
  final band = Path();
  for (var i = 0; i <= 24; i++) {
    final pt = g.outline(lerpD(-0.86 * math.pi, -0.14 * math.pi, i / 24), 0.97);
    i == 0 ? band.moveTo(pt.dx, pt.dy) : band.lineTo(pt.dx, pt.dy);
  }
  for (var i = 0; i < 9; i++) {
    final f = lerpD(-0.85, -0.15, i / 8);
    if ((f + 0.5).abs() < 0.06) continue; // leave the sprout free
    final ang = f * math.pi;
    final pt = g.outline(ang, 0.98);
    _ellipse(p, pt + Offset.fromDirection(ang, 4 * s), 6.5 * s, 3 * s, ang, _gold, ZeepColors.ink, 1.4 * s);
  }
  p.drawPath(band, _stroke(ZeepColors.ink, 4 * s));
  p.drawPath(band, _stroke(const Color(0xFFE0A93B), 2.2 * s));
}

void _wizardHat(Canvas p, _Geo g) {
  final s = g.s, cx = g.cx, a = g.a, b = g.b;
  final brimY = g.cy - b * 0.62;
  final cone = Path()
    ..moveTo(cx - a * 0.75, brimY)
    ..quadraticBezierTo(cx - a * 0.2, g.cy - b * 1.3, cx + a * 0.15, g.cy - b * 1.85)
    ..quadraticBezierTo(cx + a * 0.4, g.cy - b * 1.6, cx + a * 0.62, g.cy - b * 1.62)
    ..quadraticBezierTo(cx + a * 0.3, g.cy - b * 1.2, cx + a * 0.75, brimY)
    ..close();
  p.drawPath(cone, _fill(_wizard));
  p.save();
  p.clipPath(cone);
  for (final d in const [(-0.3, -0.9, 3.4), (0.25, -1.15, 2.6), (0.05, -1.45, 2.2), (0.4, -0.8, 2.0)]) {
    p.drawPath(_star(Offset(cx + a * d.$1, g.cy + b * d.$2), d.$3 * s), _fill(const Color(0xFFFFE08A)));
  }
  p.restore();
  p.drawPath(cone, _stroke(ZeepColors.ink, 2.4 * s));
  final brim = Rect.fromCenter(center: Offset(cx, brimY), width: a * 2.2, height: 12 * s);
  p.drawOval(brim, _fill(_wizard));
  p.drawOval(brim, _stroke(ZeepColors.ink, 2.2 * s));
}

void _halo(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s;
  final lift = reduceMotion ? 0.0 : math.sin(time * 1.2) * 1.5 * s;
  final c = Offset(g.cx, g.cy - g.b * 1.22 + lift);
  final r = Rect.fromCenter(center: c, width: g.a * 1.3, height: 13 * s);
  p.drawOval(r.inflate(5 * s), _stroke(withAlpha(_goldLight, 0.55), 6 * s));
  p.drawOval(r, _stroke(ZeepColors.ink, 6.4 * s));
  p.drawOval(r, _stroke(_gold, 3.6 * s));
}

void _lotusCrown(Canvas p, _Geo g) {
  final s = g.s * 1.3;
  final c = Offset(g.cx, g.cy - g.b * 0.92);
  void petal(double ang, double len, double wid, Color col) {
    final dir = Offset.fromDirection(ang), nrm = Offset(-dir.dy, dir.dx);
    final tipP = c + dir * len, mid = c + dir * (len * 0.55);
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(mid.dx + nrm.dx * wid, mid.dy + nrm.dy * wid, tipP.dx, tipP.dy)
      ..quadraticBezierTo(mid.dx - nrm.dx * wid, mid.dy - nrm.dy * wid, c.dx, c.dy)
      ..close();
    p.drawPath(path, _fill(col));
    p.drawPath(path, _stroke(ZeepColors.ink, 1.6 * s));
  }

  for (final ang in const [-2.75, -0.39, -2.25, -0.89]) {
    petal(ang, 22 * s, 7 * s, _gold);
  }
  for (final ang in const [-2.0, -1.14]) {
    petal(ang, 24 * s, 6.5 * s, _goldLight);
  }
  _ellipse(p, c + Offset(0, 2 * s), 12 * s, 4 * s, 0, const Color(0xFFE0A93B), ZeepColors.ink, 1.6 * s);
}

// ---- friends

void _bee(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 2.3;
  final c = _friendAt(g, time, reduceMotion, right: true);
  final f = reduceMotion ? 0.8 : 0.5 + 0.5 * math.sin(time * 9).abs();
  for (final sign in const [-1.0, 1.0]) {
    _ellipse(
      p,
      c + Offset(sign * 2.5 * s, -5 * s),
      3 * s,
      4.2 * s * f + 0.5 * s,
      sign * 0.4,
      withAlpha(const Color(0xFFFFFFFF), 0.9),
      ZeepColors.ink,
      0.9 * s,
    );
  }
  final body = Rect.fromCenter(center: c, width: 12 * s, height: 9 * s);
  p.drawOval(body, _fill(const Color(0xFFFFD34F)));
  p.save();
  p.clipPath(Path()..addOval(body));
  for (final x in const [-1.0, 2.6]) {
    p.drawRect(Rect.fromLTWH(c.dx + x * s, c.dy - 5 * s, 1.8 * s, 10 * s), _fill(ZeepColors.ink));
  }
  p.restore();
  p.drawOval(body, _stroke(ZeepColors.ink, 1 * s));
  p.drawCircle(c + Offset(-3.6 * s, -0.8 * s), 0.8 * s, _fill(ZeepColors.ink));
  p.drawLine(c + Offset(6 * s, 0), c + Offset(7.6 * s, 0.6 * s), _stroke(ZeepColors.ink, 1 * s));
}

void _skyFish(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 2.3;
  final c = _friendAt(g, time, reduceMotion, right: false);
  final wag = reduceMotion ? 0.0 : math.sin(time * 4) * 1.2 * s;
  final tail = Path()
    ..moveTo(c.dx + 5 * s, c.dy)
    ..lineTo(c.dx + 10 * s, c.dy - 4 * s + wag)
    ..lineTo(c.dx + 10 * s, c.dy + 4 * s + wag)
    ..close();
  p.drawPath(tail, _fill(const Color(0xFFF7B38A)));
  p.drawPath(tail, _stroke(ZeepColors.ink, 0.9 * s));
  _ellipse(p, c, 7 * s, 4.6 * s, 0, const Color(0xFFF59A9A), ZeepColors.ink, 0.9 * s);
  _ellipse(p, c + Offset(1 * s, -4 * s), 2.6 * s, 1.4 * s, -0.3, const Color(0xFFF7B38A), ZeepColors.ink, 0.8 * s);
  p.drawCircle(c + Offset(-3.6 * s, -0.8 * s), 0.9 * s, _fill(ZeepColors.ink));
  // a tiny bubble
  p.drawCircle(c + Offset(-9 * s, -4 * s), 1.4 * s, _stroke(withAlpha(_skyBlue, 0.9), 0.7 * s));
}

void _bird(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 2.3;
  final c = _friendAt(g, time, reduceMotion, right: true);
  final flap = reduceMotion ? 0.0 : math.sin(time * 5) * 0.35;
  final tail = Path()
    ..moveTo(c.dx + 4 * s, c.dy + 1 * s)
    ..lineTo(c.dx + 9 * s, c.dy - 1.5 * s)
    ..lineTo(c.dx + 8.5 * s, c.dy + 3 * s)
    ..close();
  p.drawPath(tail, _fill(_skyBlue));
  p.drawPath(tail, _stroke(ZeepColors.ink, 0.9 * s));
  p.drawCircle(c, 5.6 * s, _fill(_skyBlue));
  p.drawCircle(c, 5.6 * s, _stroke(ZeepColors.ink, 1 * s));
  _ellipse(p, c + Offset(-0.5 * s, 2.2 * s), 3.4 * s, 2.4 * s, 0, const Color(0xFFDDE8FB));
  _ellipse(p, c + Offset(1.6 * s, 0), 3.4 * s, 2 * s, -0.4 + flap, const Color(0xFF6F93DB), ZeepColors.ink, 0.9 * s);
  final beak = Path()
    ..moveTo(c.dx - 5.4 * s, c.dy - 1 * s)
    ..lineTo(c.dx - 8 * s, c.dy)
    ..lineTo(c.dx - 5.2 * s, c.dy + 1 * s)
    ..close();
  p.drawPath(beak, _fill(const Color(0xFFFFB347)));
  p.drawCircle(c + Offset(-2.6 * s, -1.6 * s), 0.8 * s, _fill(ZeepColors.ink));
}

void _firefly(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 2.3;
  final c = _friendAt(g, time, reduceMotion, right: false);
  final glow = reduceMotion ? 0.8 : 0.55 + 0.45 * math.sin(time * 2.4).abs();
  final tailC = c + Offset(3.2 * s, 1.6 * s);
  p.drawCircle(
    tailC,
    8 * s,
    Paint()
      ..shader = RadialGradient(
        colors: [withAlpha(const Color(0xFFFFF3A0), 0.85 * glow), withAlpha(const Color(0xFFFFF3A0), 0)],
      ).createShader(Rect.fromCircle(center: tailC, radius: 8 * s)),
  );
  for (final sign in const [-1.0, 1.0]) {
    _ellipse(
      p,
      c + Offset(sign * 1.6 * s, -3 * s),
      2 * s,
      3 * s,
      sign * 0.5,
      withAlpha(const Color(0xFFFFFFFF), 0.85),
      ZeepColors.ink,
      0.8 * s,
    );
  }
  _ellipse(p, c, 4 * s, 2.6 * s, 0.4, const Color(0xFF6B5A8E), ZeepColors.ink, 0.9 * s);
  p.drawCircle(tailC, 2.4 * s, _fill(const Color(0xFFFFE97A)));
  p.drawCircle(tailC, 2.4 * s, _stroke(ZeepColors.ink, 0.8 * s));
}

void _moon(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 2.3;
  final c = _friendAt(g, time, reduceMotion, right: false);
  final outer = Path()..addOval(Rect.fromCircle(center: c, radius: 8 * s));
  final bite = Path()..addOval(Rect.fromCircle(center: c + Offset(4.5 * s, -2.5 * s), radius: 7 * s));
  final moon = Path.combine(PathOperation.difference, outer, bite);
  p.drawPath(moon, _fill(const Color(0xFFFFF0B3)));
  p.drawPath(moon, _stroke(ZeepColors.ink, 1 * s));
  final e = c + Offset(-4.4 * s, 0.5 * s);
  _quadLine(p, e - Offset(1.4 * s, 0), e + Offset(0, 1.2 * s), e + Offset(1.4 * s, 0), 0.8 * s, ZeepColors.ink);
  _ellipse(p, c + Offset(-3.2 * s, 3.4 * s), 1.4 * s, 0.9 * s, 0, withAlpha(const Color(0xFFF6A596), 0.8));
  // a little star nearby
  p.drawPath(_star(c + Offset(6 * s, 5 * s), 1.8 * s), _fill(const Color(0xFFFFD34F)));
}

/// Five round petals with a yellow heart; [k] scales it.
void _flower(Canvas p, Offset c, double k, Color petal) {
  final r = 3.2 * k, d = 3.5 * k;
  final centers = [for (var i = 0; i < 5; i++) c + Offset.fromDirection(-math.pi / 2 + i * _tau / 5, d)];
  for (final pc in centers) {
    p.drawCircle(pc, r, _stroke(ZeepColors.ink, 2.4 * k / 1.6));
  }
  for (final pc in centers) {
    p.drawCircle(pc, r, _fill(petal));
  }
  p.drawCircle(c, 2.1 * k, _fill(_flowerHeart));
  p.drawCircle(c, 2.1 * k, _stroke(ZeepColors.ink, 1.1 * k));
}

void _flowerCrown(Canvas p, _Geo g) {
  final s = g.s;
  final vine = Path();
  const from = -0.86 * math.pi, to = -0.14 * math.pi;
  for (var i = 0; i <= 30; i++) {
    final pt = g.outline(lerpD(from, to, i / 30), 0.98);
    i == 0 ? vine.moveTo(pt.dx, pt.dy) : vine.lineTo(pt.dx, pt.dy);
  }
  p.drawPath(vine, _stroke(ZeepColors.ink, 4.2 * s));
  p.drawPath(vine, _stroke(_vineGreen, 2.2 * s));
  // little leaves between the flowers
  for (final (f, side) in const [(-0.75, -1.0), (-0.58, 1.0), (-0.42, -1.0), (-0.25, 1.0)]) {
    final pt = g.outline(f * math.pi, 0.98);
    _ellipse(
      p,
      pt + Offset(0, side * 3 * s),
      4.2 * s,
      2.2 * s,
      f * math.pi + math.pi / 2 + side * 0.5,
      const Color(0xFFB5E3C2),
      ZeepColors.ink,
      1.3 * s,
    );
  }
  // no flower at the very top, where the sprout grows
  const colors = [_petalPink, _petalLilac, _petalLilac, _petalPink];
  for (final (i, f) in const [-0.83, -0.67, -0.33, -0.17].indexed) {
    _flower(p, g.outline(f * math.pi, 0.98), s * 1.15, colors[i]);
  }
}

/// Knitted band shared by the beanie and the sleep cap.
void _brim(Canvas p, _Geo g, Color fill) {
  final s = g.s;
  final r = RRect.fromLTRBR(
    g.cx - g.a * 1.02,
    g.cy - g.b * 0.68,
    g.cx + g.a * 1.02,
    g.cy - g.b * 0.42,
    Radius.circular(8 * s),
  );
  p.drawRRect(r, _fill(fill));
  p.save();
  p.clipRRect(r);
  final rib = _stroke(withAlpha(ZeepColors.ink, 0.16), 1.4 * s);
  for (var x = r.left + 5 * s; x < r.right; x += 6 * s) {
    p.drawLine(Offset(x, r.top + 3 * s), Offset(x, r.bottom - 3 * s), rib);
  }
  p.restore();
  p.drawRRect(r, _stroke(ZeepColors.ink, 2.2 * s));
}

void _beanieHat(Canvas p, _Geo g) {
  final s = g.s, cx = g.cx, a = g.a, b = g.b;
  final base = g.cy - b * 0.62;
  final dome = Path()
    ..moveTo(cx - a * 0.97, base)
    ..cubicTo(cx - a * 0.94, g.cy - b * 1.42, cx + a * 0.94, g.cy - b * 1.42, cx + a * 0.97, base)
    ..close();
  p.drawPath(dome, _fill(_beanie));
  p.save();
  p.clipPath(dome);
  final rib = _stroke(_beanieRib, 1.6 * s);
  for (var k = -3; k <= 3; k++) {
    final x = cx + k * a * 0.26;
    p.drawPath(
      Path()
        ..moveTo(x, base)
        ..quadraticBezierTo(x + k * 3 * s, g.cy - b * 0.95, cx + k * a * 0.08, g.cy - b * 1.2),
      rib,
    );
  }
  p.restore();
  p.drawPath(dome, _stroke(ZeepColors.ink, 2.4 * s));
  _brim(p, g, _beanieBrim);
}

void _sleepCap(Canvas p, _Geo g) {
  final s = g.s, cx = g.cx, a = g.a, b = g.b;
  final base = g.cy - b * 0.62;
  // a long floppy cap whose tail hangs down Zeep's right side
  final pom = Offset(cx + a * 1.18, g.cy - b * 0.30);
  final cap = Path()
    ..moveTo(cx - a * 0.97, base)
    ..cubicTo(cx - a * 0.95, g.cy - b * 1.30, cx - a * 0.35, g.cy - b * 1.52, cx + a * 0.18, g.cy - b * 1.46)
    ..cubicTo(cx + a * 0.80, g.cy - b * 1.40, cx + a * 1.22, g.cy - b * 0.95, pom.dx + 3 * s, pom.dy - 5 * s)
    ..quadraticBezierTo(cx + a * 0.98, g.cy - b * 0.80, cx + a * 0.90, base)
    ..close();
  void paintCap() {
    p.drawPath(cap, _fill(_capBlue));
    p.save();
    p.clipPath(cap);
    // tiny stars on the cap
    for (final (dx, dy) in const [
      (-0.55, -0.95),
      (-0.1, -1.25),
      (0.35, -0.95),
      (-0.35, -0.75),
      (0.75, -1.1),
      (1.0, -0.65),
    ]) {
      final c = Offset(cx + a * dx, g.cy + b * dy);
      p.drawCircle(c, 1.7 * s, _fill(_flowerHeart));
    }
    p.restore();
    p.drawPath(cap, _stroke(ZeepColors.ink, 2.4 * s));
  }

  paintCap();
  _brim(p, g, _capBrim);
  // the hanging tail falls in front of the band
  p.save();
  p.clipRect(Rect.fromLTRB(cx + a * 1.0, g.cy - b * 3, cx + a * 3, g.cy + b));
  paintCap();
  p.restore();
  p.drawCircle(pom, 6.5 * s, _fill(_pom));
  p.drawCircle(pom, 6.5 * s, _stroke(ZeepColors.ink, 2 * s));
}

void _sproutBow(Canvas p, _Geo g, {bool rainbow = false}) {
  final s = g.s * 1.25;
  final k = g.stem(0.42);
  // ribbon tails
  final tail = _stroke(ZeepColors.ink, 3.6 * s);
  final tailIn = _stroke(rainbow ? _rainbow[2] : _bowPink, 1.8 * s);
  for (final sign in const [-1.0, 1.0]) {
    final path = Path()
      ..moveTo(k.dx, k.dy)
      ..quadraticBezierTo(k.dx + sign * 3 * s, k.dy + 4 * s, k.dx + sign * 4.5 * s, k.dy + 7.5 * s);
    p.drawPath(path, tail);
    p.drawPath(path, tailIn);
  }
  for (final sign in const [-1.0, 1.0]) {
    final loop = rainbow ? (sign < 0 ? _rainbow[0] : _rainbow[4]) : _bowPink;
    _ellipse(p, k + Offset(sign * 5 * s, -1 * s), 5 * s, 3.3 * s, sign * -0.35, loop, ZeepColors.ink, 1.5 * s);
  }
  p.drawCircle(k, 2.3 * s, _fill(rainbow ? _rainbow[3] : _bowPink));
  p.drawCircle(k, 2.3 * s, _stroke(ZeepColors.ink, 1.5 * s));
}

void _glasses(Canvas p, _Geo g, {bool rainbow = false}) {
  final s = g.s;
  final r = 10.5 * s;
  final lens = _fill(withAlpha(const Color(0xFFFFFFFF), 0.28));
  final frame = _stroke(ZeepColors.ink, 2.1 * s);
  for (final sign in const [-1.0, 1.0]) {
    final c = Offset(g.cx + sign * g.edx, g.ey + 1.5 * s);
    p.drawCircle(c, r, lens);
    p.drawCircle(c, r, frame);
    if (rainbow) {
      p.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * s
          ..shader = SweepGradient(colors: [..._rainbow, _rainbow.first])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    // glint
    p.drawArc(
      Rect.fromCircle(center: c, radius: r - 3 * s),
      -2.6,
      0.9,
      false,
      _stroke(withAlpha(const Color(0xFFFFFFFF), 0.9), 1.6 * s),
    );
    // arm towards the side of the body
    p.drawLine(c + Offset(sign * r, -2 * s), Offset(g.cx + sign * g.a * 0.93, g.ey - 3 * s), frame);
  }
  _quadLine(
    p,
    Offset(g.cx - g.edx + r, g.ey),
    Offset(g.cx, g.ey - 4 * s),
    Offset(g.cx + g.edx - r, g.ey),
    2.1 * s,
    ZeepColors.ink,
  );
}

void _butterfly(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 1.7;
  final bob = reduceMotion ? Offset.zero : Offset(math.cos(time * 0.8) * 3 * s, math.sin(time * 1.6) * 4 * s);
  final c = Offset(g.cx + g.a * 1.45, g.cy - g.b * 0.95) + bob;
  final f = reduceMotion ? 0.85 : 0.55 + 0.45 * math.sin(time * 6).abs();
  p.save();
  p.translate(c.dx, c.dy);
  p.rotate(0.25);
  for (final sign in const [-1.0, 1.0]) {
    _ellipse(
      p,
      Offset(sign * 4.5 * s * f, 3.5 * s),
      4.2 * s * f,
      3.6 * s,
      sign * -0.5,
      _wingLow,
      ZeepColors.ink,
      1.4 * s,
    );
    _ellipse(p, Offset(sign * 6 * s * f, -3 * s), 6 * s * f, 5 * s, sign * 0.45, _wingTop, ZeepColors.ink, 1.4 * s);
  }
  _ellipse(p, Offset.zero, 1.6 * s, 6 * s, 0, ZeepColors.ink);
  for (final sign in const [-1.0, 1.0]) {
    _quadLine(
      p,
      Offset(0, -5 * s),
      Offset(sign * 1.5 * s, -9 * s),
      Offset(sign * 4 * s, -11 * s),
      1.2 * s,
      ZeepColors.ink,
    );
  }
  p.restore();
}

void _cloud(Canvas p, _Geo g, double time, bool reduceMotion) {
  final s = g.s * 1.7;
  final drift = reduceMotion ? 0.0 : math.sin(time * 0.5) * 3 * s;
  final c = Offset(g.cx - g.a * 1.5 + drift, g.cy - g.b * 1.0);
  var shape = Path()
    ..addRRect(RRect.fromLTRBR(c.dx - 12 * s, c.dy - 2 * s, c.dx + 12 * s, c.dy + 7 * s, Radius.circular(4.5 * s)));
  for (final (dx, dy, r) in const [(-6.5, 0.5, 5.5), (0.5, -2.5, 7.5), (7.5, 0.5, 5.0)]) {
    shape = Path.combine(
      PathOperation.union,
      shape,
      Path()..addOval(Rect.fromCircle(center: c + Offset(dx * s, dy * s), radius: r * s)),
    );
  }
  p.drawPath(shape, _fill(const Color(0xFFFFFFFF)));
  p.drawPath(shape, _stroke(ZeepColors.ink, 1.8 * s));
  // sleepy little face
  for (final sign in const [-1.0, 1.0]) {
    final e = c + Offset(sign * 3.2 * s, 1.5 * s);
    _quadLine(p, e - Offset(1.6 * s, 0), e + Offset(0, 1.4 * s), e + Offset(1.6 * s, 0), 1.1 * s, ZeepColors.ink);
    _ellipse(p, c + Offset(sign * 6.2 * s, 4 * s), 1.8 * s, 1.1 * s, 0, withAlpha(const Color(0xFFF6A596), 0.8));
  }
}

// ---------------------------------------------------------------- flowers

/// Draws one flower of [kind] centred at [c]; [k] is the scale (Zeep's `s`).
void drawBloom(Canvas p, FlowerKind kind, Offset c, double k) {
  final ink = _stroke(ZeepColors.ink, 0.9 * k);
  switch (kind.style) {
    case FlowerStyle.tulip:
      final cup = Path()
        ..moveTo(c.dx - 5.5 * k, c.dy - 4 * k)
        ..quadraticBezierTo(c.dx - 5.5 * k, c.dy + 5 * k, c.dx, c.dy + 5 * k)
        ..quadraticBezierTo(c.dx + 5.5 * k, c.dy + 5 * k, c.dx + 5.5 * k, c.dy - 4 * k)
        ..lineTo(c.dx + 2.8 * k, c.dy - 1.2 * k)
        ..lineTo(c.dx, c.dy - 5.5 * k)
        ..lineTo(c.dx - 2.8 * k, c.dy - 1.2 * k)
        ..close();
      p.drawPath(cup, _fill(kind.petal));
      p.drawPath(cup, ink);
    case FlowerStyle.lavender:
      final buds = [for (var i = 0; i < 7; i++) c + Offset((i.isEven ? -1.4 : 1.4) * k, (4 - 2.4 * i) * k)];
      for (final b in buds) {
        p.drawCircle(b, 2.2 * k, _stroke(ZeepColors.ink, 1.6 * k));
      }
      for (final b in buds) {
        p.drawCircle(b, 2.2 * k, _fill(kind.petal));
      }
    case FlowerStyle.rose:
      p.drawCircle(c, 6 * k, _fill(kind.petal));
      p.drawCircle(c, 6 * k, ink);
      final swirl = _stroke(withAlpha(ZeepColors.ink, 0.7), 1.1 * k);
      p.drawArc(Rect.fromCircle(center: c + Offset(0.5 * k, 0.5 * k), radius: 4 * k), -2.6, 3.6, false, swirl);
      p.drawArc(Rect.fromCircle(center: c + Offset(-0.4 * k, 0), radius: 2.4 * k), 0.6, 3.8, false, swirl);
      p.drawArc(Rect.fromCircle(center: c, radius: 1 * k), -1, 3.4, false, swirl);
    case FlowerStyle.hydrangea:
      for (final o in const [(0.0, -3.6), (3.4, -1.0), (2.1, 3.0), (-2.1, 3.0), (-3.4, -1.0), (0.0, 0.0)]) {
        final m = c + Offset(o.$1 * k, o.$2 * k);
        for (var i = 0; i < 4; i++) {
          p.drawCircle(
            m + Offset.fromDirection(i * math.pi / 2 + 0.4, 1.5 * k),
            1.6 * k,
            _stroke(ZeepColors.ink, 0.9 * k),
          );
        }
        for (var i = 0; i < 4; i++) {
          p.drawCircle(m + Offset.fromDirection(i * math.pi / 2 + 0.4, 1.5 * k), 1.6 * k, _fill(kind.petal));
        }
        p.drawCircle(m, 0.7 * k, _fill(const Color(0xFFFFFFFF)));
      }
    case FlowerStyle.radial:
      _petalRing(p, kind, kind.petal, c, k, 0, 1);
      if (kind.inner != null) _petalRing(p, kind, kind.inner!, c, k, math.pi / kind.petals, 0.62);
      final cr = (kind.petals >= 14 ? 3.4 : 2.2) * k;
      p.drawCircle(c, cr, _fill(kind.center));
      p.drawCircle(c, cr, _stroke(ZeepColors.ink, 0.8 * k));
  }
}

void _petalRing(Canvas p, FlowerKind kind, Color color, Offset c, double k, double rot, double scale) {
  final n = kind.petals;
  final shapes = <Path>[];
  for (var i = 0; i < n; i++) {
    final ang = -math.pi / 2 + rot + i * _tau / n;
    final dir = Offset(math.cos(ang), math.sin(ang));
    final nrm = Offset(-dir.dy, dir.dx);
    final q = k * scale;
    final path = Path();
    switch (kind.shape) {
      case PetalShape.round:
        path.addOval(Rect.fromCircle(center: c + dir * (4.2 * q), radius: 3.4 * q));
      case PetalShape.oval:
        final pc = c + dir * (4.8 * q);
        path.addPath(
          Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 9 * q, height: 4.4 * q)),
          Offset.zero,
          matrix4: _rotateAt(pc, ang),
        );
      case PetalShape.pointed:
        final base = c + dir * (1.5 * q), tipP = c + dir * (8.6 * q);
        final mid = c + dir * (5 * q);
        path
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(mid.dx + nrm.dx * 3.2 * q, mid.dy + nrm.dy * 3.2 * q, tipP.dx, tipP.dy)
          ..quadraticBezierTo(mid.dx - nrm.dx * 3.2 * q, mid.dy - nrm.dy * 3.2 * q, base.dx, base.dy)
          ..close();
      case PetalShape.notched:
        for (final side in const [-1.0, 1.0]) {
          path.addOval(Rect.fromCircle(center: c + dir * (4.8 * q) + nrm * (side * 1.3 * q), radius: 2.5 * q));
        }
        path.addOval(Rect.fromCircle(center: c + dir * (3.4 * q), radius: 2.4 * q));
    }
    shapes.add(path);
  }
  final outline = _stroke(ZeepColors.ink, 1.7 * k * scale.clamp(0.7, 1.0));
  for (final s in shapes) {
    p.drawPath(s, outline);
  }
  for (final s in shapes) {
    p.drawPath(s, _fill(color));
  }
}

/// Column-major 4x4 matrix: rotate by [ang] around the origin, then move to [c].
Float64List _rotateAt(Offset c, double ang) {
  final cs = math.cos(ang), sn = math.sin(ang);
  return Float64List.fromList([cs, sn, 0, 0, -sn, cs, 0, 0, 0, 0, 1, 0, c.dx, c.dy, 0, 1]);
}
