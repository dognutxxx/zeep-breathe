// "Zeep" - the floating meditation character - and its animation state
// machine. Port of `app/src/character.rs`.
//
// States: Idle, Inhale, Hold, Exhale, Rest. Each state produces a target Pose
// (named parameters, like Rive state-machine inputs). On a state change the
// animator snapshots the current pose and cross-fades into the new state's
// pose, so there are never abrupt jumps. `breath` comes straight from the
// breathing engine, so body size, water level and progress bar are
// frame-exact with the timer.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../wardrobe/outfits.dart';
import 'zeep_colors.dart';

const _tau = math.pi * 2;

enum AnimState { idle, inhale, hold, exhale, rest }

class Pose {
  final double breath, armLift, cheekPuff, eyeSqueeze, mouthOpen, hold;
  final Color tint;
  const Pose({
    required this.breath,
    required this.armLift,
    required this.cheekPuff,
    required this.eyeSqueeze,
    required this.mouthOpen,
    required this.hold,
    required this.tint,
  });

  static Pose lerp(Pose a, Pose b, double t) => Pose(
    breath: lerpD(a.breath, b.breath, t),
    armLift: lerpD(a.armLift, b.armLift, t),
    cheekPuff: lerpD(a.cheekPuff, b.cheekPuff, t),
    eyeSqueeze: lerpD(a.eyeSqueeze, b.eyeSqueeze, t),
    mouthOpen: lerpD(a.mouthOpen, b.mouthOpen, t),
    hold: lerpD(a.hold, b.hold, t),
    tint: Color.lerp(a.tint, b.tint, t)!,
  );
}

const tintInhale = Color.fromARGB(255, 189, 222, 247);
const tintHold = Color.fromARGB(255, 204, 199, 245);
const tintExhale = Color.fromARGB(255, 186, 230, 224);

class Animator {
  AnimState state = AnimState.idle;
  late Pose _from;
  double _blendT = 1, _blendDur = 1;
  late Pose pose;
  double time = 0;

  Animator() {
    pose = _target(0, 0, false);
    _from = pose;
  }

  void setState(AnimState s) {
    if (s == state) return;
    _from = pose;
    _blendT = 0;
    _blendDur = (s == AnimState.idle || state == AnimState.idle) ? 0.9 : 0.35;
    state = s;
  }

  void update(double dt, double level, double phaseT, bool paused, {bool reduceMotion = false}) {
    time += dt;
    final target = _target(level, phaseT, paused);
    _blendT += dt;
    pose = Pose.lerp(_from, target, smoothstep(_blendT / _blendDur));
  }

  Pose _target(double level, double phaseT, bool paused) {
    final t = time;
    switch (state) {
      case AnimState.idle:
        final b = 0.22 + 0.10 * math.sin(t * _tau / 5);
        return Pose(
          breath: b,
          armLift: b * 0.5,
          cheekPuff: 0.12,
          eyeSqueeze: 0,
          mouthOpen: 0,
          hold: 0,
          tint: tintInhale,
        );
      case AnimState.inhale:
        return Pose(
          breath: level,
          armLift: level,
          cheekPuff: 0.15 + 0.3 * level,
          eyeSqueeze: 0.25 * level,
          mouthOpen: 0,
          hold: 0,
          tint: tintInhale,
        );
      case AnimState.hold:
        final shimmer = paused ? 0.0 : 0.012 * math.sin(t * _tau * 0.9);
        return Pose(
          breath: level + shimmer,
          armLift: 1,
          cheekPuff: 0.7,
          eyeSqueeze: 0.45,
          mouthOpen: 0,
          hold: 1,
          tint: tintHold,
        );
      case AnimState.exhale:
        final pt = phaseT.clamp(0.0, 1.0);
        final m = math.pow(math.sin(pt * math.pi), 0.5) * (1 - pt * 0.35);
        return Pose(
          breath: level,
          armLift: level,
          cheekPuff: 0.1 * level,
          eyeSqueeze: 0,
          mouthOpen: m.toDouble(),
          hold: 0,
          tint: tintExhale,
        );
      case AnimState.rest:
        final b = 0.03 * math.sin(t * _tau / 4).abs();
        return Pose(breath: b, armLift: 0, cheekPuff: 0.1, eyeSqueeze: 0, mouthOpen: 0, hold: 0, tint: tintInhale);
    }
  }
}

// ---------------------------------------------------------------- drawing

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _ellipse(Canvas c, Offset center, double rx, double ry, double rot, Color fill, [Color? stroke, double sw = 0]) {
  c.save();
  c.translate(center.dx, center.dy);
  if (rot != 0) c.rotate(rot);
  final r = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
  c.drawOval(r, _fill(fill));
  if (stroke != null) c.drawOval(r, _stroke(stroke, sw));
  c.restore();
}

void _quadLine(Canvas c, Offset p0, Offset ctl, Offset p1, double w, Color col) {
  final path = Path()
    ..moveTo(p0.dx, p0.dy)
    ..quadraticBezierTo(ctl.dx, ctl.dy, p1.dx, p1.dy);
  c.drawPath(path, _stroke(col, w));
}

/// Draws Zeep. `center` is the resting body centre, `s` the scale (1.0 at a
/// 395 px wide phone layout), `shadowY` where the floor shadow sits.
/// `ripples` are ages (seconds) of haptic pulses to visualise.
void drawZeep(
  Canvas p,
  Offset center,
  double s,
  Pose pose,
  double time,
  double shadowY,
  List<double> ripples, {
  bool reduceMotion = false,
  Outfit outfit = Outfit.none,
}) {
  final br = pose.breath.clamp(-0.1, 1.1);
  final float = reduceMotion ? 0.0 : math.sin(time * _tau / 3.8);
  final cx = center.dx;
  final cy = center.dy + float * 5 * s - br * 4 * s;

  final a = 57 * s * (1 + 0.12 * br);
  final b = 52 * s * (1 + 0.07 * br);

  // floor shadow: smaller + lighter when the character floats higher
  final lift = (-float * 0.5 + 0.5) * 0.6 + br * 0.4;
  _ellipse(
    p,
    Offset(cx, shadowY),
    22 * s * (1 - 0.18 * lift),
    4.5 * s * (1 - 0.1 * lift),
    0,
    withAlpha(const Color(0xFF9C8574), 0.62 - 0.2 * lift),
  );

  // hold halo
  if (pose.hold > 0.01) {
    final pulse = 0.5 + 0.5 * math.sin(time * _tau * 0.8);
    final r1 = a * (1.75 + 0.12 * pulse);
    final inner = withAlpha(const Color(0xFFC4B8F4), pose.hold * (0.35 + 0.12 * pulse));
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [inner, inner, withAlpha(inner, 0)],
        stops: [0, (a * 0.9) / r1, 1],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r1));
    p.drawCircle(Offset(cx, cy), r1, paint);
  }

  // haptic ripples
  for (final age in ripples) {
    final u = (age / 0.7).clamp(0.0, 1.0);
    final r = a * 1.1 + u * 46 * s;
    p.drawCircle(
      Offset(cx, cy + 4 * s),
      r,
      _stroke(withAlpha(const Color(0xFF7FA6F2), (1 - u) * 0.75), (2.5 - 1.5 * u) * s),
    );
  }

  // ---- body outline (soft squircle, slightly wider at the base)
  const n = 96;
  const ex = 2.0 / 2.7;
  final body = Path();
  for (var i = 0; i < n; i++) {
    final th = i / n * _tau;
    final sn = math.sin(th), cs = math.cos(th);
    var x = a * cs.sign * math.pow(cs.abs(), ex).toDouble();
    var y = b * sn.sign * math.pow(sn.abs(), ex).toDouble();
    x *= 1 + 0.07 * (y / b);
    if (y > 0) y *= 0.96;
    if (i == 0) {
      body.moveTo(cx + x, cy + y);
    } else {
      body.lineTo(cx + x, cy + y);
    }
  }
  body.close();

  // sprout (behind the body top)
  final top = Offset(cx, cy - b * 0.97);
  final sway = reduceMotion ? 0.0 : math.sin(time * 1.7) * 2 * s;
  final tip = Offset(cx + sway, cy - b - (15 + 4 * br) * s);
  final stemCtl = Offset(cx - 3 * s, (top.dy + tip.dy) * 0.5);
  final open = 0.55 + 0.25 * br + 0.1 * math.sin(time * 1.3);
  void sprout() {
    _quadLine(p, top, stemCtl, tip, 2.2 * s, ZeepColors.ink);
    const leaf = Color(0xFFB5E3C2);
    _ellipse(p, tip + Offset(-7 * s, -1 * s), 8 * s, 4.2 * s, -open, leaf, ZeepColors.ink, 1.8 * s);
    _ellipse(p, tip + Offset(6.5 * s, -2.5 * s), 7 * s, 3.8 * s, open * 0.9, leaf, ZeepColors.ink, 1.8 * s);
  }

  sprout();

  // body fill
  p.drawPath(body, _fill(ZeepColors.shell));

  // water inside the body: rises with each inhale
  final waterY = cy + b * 0.96 - (2 * b) * (0.16 + 0.62 * pose.breath.clamp(0.0, 1.0));
  final waveAmp = 2.2 * s;
  double wave(double x) =>
      waterY + math.sin(x / s * 0.085 + time * 2.4) * waveAmp + math.sin(x / s * 0.05 - time * 1.3) * waveAmp * 0.5;
  final xl = cx - a * 1.2, xr = cx + a * 1.2;
  final surface = Path()..moveTo(xl, wave(xl));
  for (var i = 1; i <= 40; i++) {
    final x = lerpD(xl, xr, i / 40);
    surface.lineTo(x, wave(x));
  }
  final water = Path.from(surface)
    ..lineTo(xr, cy + b * 2)
    ..lineTo(xl, cy + b * 2)
    ..close();
  p.save();
  p.clipPath(body);
  p.drawPath(water, _fill(pose.tint));
  p.drawPath(surface, _stroke(mix(pose.tint, const Color(0xFF6F9FD8), 0.35), 1.6 * s));
  // small bubbles
  for (var i = 0; i < 3; i++) {
    final u = (time * 0.35 + i * 0.33) % 1.0;
    final bx = cx + (i - 1) * a * 0.45 + math.sin(time * 2 + i) * 3 * s;
    final by = lerpD(cy + b * 0.85, waterY + 6 * s, u);
    if (by > waterY + 4 * s) {
      p.drawCircle(Offset(bx, by), 1.8 * s, _stroke(withAlpha(const Color(0xFFFFFFFF), 0.8 * (1 - u)), 1 * s));
    }
  }
  p.restore();

  // outline + glint
  p.drawPath(body, _stroke(ZeepColors.ink, 2.4 * s));
  _ellipse(p, Offset(cx + a * 0.62, cy - b * 0.42), 2.6 * s, 7 * s, 0.35, withAlpha(const Color(0xFFFFFFFF), 0.95));
  p.drawCircle(Offset(cx + a * 0.70, cy - b * 0.12), 1.8 * s, _fill(withAlpha(const Color(0xFFFFFFFF), 0.95)));

  // ---- face
  final ey = cy - b * 0.16;
  final edx = a * 0.34;
  for (final sign in const [-1.0, 1.0]) {
    final ex0 = cx + sign * edx;
    final w = 7.5 * s;
    final depth = (4.2 - 2 * pose.eyeSqueeze) * s;
    _quadLine(p, Offset(ex0 - w, ey), Offset(ex0, ey + depth * 2), Offset(ex0 + w, ey), 2.4 * s, ZeepColors.ink);
    final oc = Offset(ex0 + sign * w, ey);
    p.drawLine(oc, oc + Offset(sign * 2.6 * s, -2.4 * s), _stroke(ZeepColors.ink, 1.8 * s));
    // cheeks with halftone dots
    final cc = Offset(cx + sign * a * 0.56, ey + 13 * s);
    final crx = 10 * s * (1 + 0.22 * pose.cheekPuff);
    final cry = 6.5 * s * (1 + 0.18 * pose.cheekPuff);
    _ellipse(p, cc, crx, cry, 0, withAlpha(const Color(0xFFF6A596), 0.55 + 0.25 * pose.cheekPuff));
    final step = 3.3 * s;
    final dot = _fill(withAlpha(const Color(0xFFE77F6C), 0.8));
    for (var gy = -cry; gy <= cry; gy += step) {
      for (var gx = -crx; gx <= crx; gx += step) {
        if (math.pow(gx / crx, 2) + math.pow(gy / cry, 2) < 0.7) {
          p.drawCircle(cc + Offset(gx, gy), 0.85 * s, dot);
        }
      }
    }
  }
  // mouth
  final mc = Offset(cx, ey + 12 * s);
  final smile = (1 - pose.hold) * math.max(0.0, 1 - pose.mouthOpen);
  final mw = 4.5 * s;
  if (pose.mouthOpen < 0.6) {
    final k = 1 - pose.mouthOpen / 0.6;
    _quadLine(
      p,
      Offset(mc.dx - mw, mc.dy),
      Offset(mc.dx, mc.dy + 4.5 * s * smile),
      Offset(mc.dx + mw, mc.dy),
      2 * s,
      withAlpha(ZeepColors.ink, k),
    );
  }
  if (pose.mouthOpen > 0.05) {
    final m = pose.mouthOpen;
    _ellipse(
      p,
      mc + Offset(0, 1 * s),
      2 * s + 2 * s * m,
      2 * s + 3 * s * m,
      0,
      const Color(0xFF8A4E48),
      ZeepColors.ink,
      1.8 * s,
    );
    // exhaled breath puffs drifting away
    for (var i = 0; i < 4; i++) {
      final u = (time * 0.8 + i * 0.25) % 1.0;
      final dir = i.isEven ? -1.0 : 1.0;
      final pos = mc + Offset(dir * (8 + u * 34) * s, (6 + u * 10 - math.sin(u * math.pi) * 14) * s);
      p.drawCircle(pos, (2 + u * 3.5) * s, _fill(withAlpha(const Color(0xFFBFDDF3), m * (1 - u) * 0.85)));
    }
  }

  // ---- crossed legs (lotus)
  final legY = cy + b * 0.86;
  for (final sign in const [1.0, -1.0]) {
    _ellipse(
      p,
      Offset(cx + sign * a * 0.34, legY),
      a * 0.44,
      8.5 * s,
      sign * -0.06,
      ZeepColors.shell,
      ZeepColors.ink,
      2.2 * s,
    );
  }

  // ---- arms (noodle arms, lift with the breath)
  final handsY = cy + b * 0.52 - pose.armLift * 3 * s;
  for (final sign in const [-1.0, 1.0]) {
    final sh = Offset(cx + sign * a * 0.96, cy + b * 0.02);
    final c1 = Offset(cx + sign * (a + 20 * s + pose.armLift * 6 * s), cy + b * 0.10 + 12 * s - pose.armLift * 12 * s);
    final c2 = Offset(cx + sign * (a * 0.55 + pose.armLift * 3 * s), cy + b * 0.70);
    final hand = Offset(cx + sign * 5 * s, handsY + 5 * s);
    final arm = Path()
      ..moveTo(sh.dx, sh.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, hand.dx, hand.dy);
    p.drawPath(arm, _stroke(ZeepColors.ink, 6.2 * s));
    p.drawPath(arm, _stroke(ZeepColors.shell, 2.6 * s));
  }
  // namaste hands
  for (final sign in const [-1.0, 1.0]) {
    _ellipse(
      p,
      Offset(cx + sign * 4.2 * s, handsY),
      4.6 * s,
      8.5 * s,
      sign * -0.32,
      ZeepColors.shell,
      ZeepColors.ink,
      2 * s,
    );
  }

  // hold sparkles
  if (pose.hold > 0.05) {
    final xs = [-a * 1.05, a * 1.1, a * 0.55];
    final ys = [-b * 0.9, -b * 0.55, -b * 1.25];
    for (var i = 0; i < 3; i++) {
      final ph = time * 2.2 + i * 2.1;
      final tw = (math.sin(ph) * 0.5 + 0.5) * pose.hold;
      final pos = Offset(cx + xs[i], cy + ys[i]);
      final r = (3 + 2 * tw) * s;
      final paint = _stroke(withAlpha(const Color(0xFFA996F0), tw), 1.6 * s);
      p.drawLine(pos - Offset(r, 0), pos + Offset(r, 0), paint);
      p.drawLine(pos - Offset(0, r), pos + Offset(0, r), paint);
    }
  }

  // ---- wardrobe: extra layers on top; the character itself is unchanged
  if (!outfit.isEmpty) {
    _drawOutfit(
      p,
      outfit,
      _Geo(cx: cx, cy: cy, a: a, b: b, s: s, ey: ey, edx: edx, top: top, stemCtl: stemCtl, tip: tip),
      time,
      reduceMotion,
      sprout,
    );
  }
}

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
      default:
    }
    // the sprout always pokes through whatever is on the head
    sprout();
  }
  switch (o[OutfitSlot.sprout]) {
    case OutfitItem.sproutBow:
      _sproutBow(p, g);
    case OutfitItem.sproutFlower:
      _flower(p, g.tip + Offset(0, -5 * g.s), g.s * 0.9, _petalPink);
    default:
  }
  if (o[OutfitSlot.face] == OutfitItem.roundGlasses) _glasses(p, g);
  switch (o[OutfitSlot.friend]) {
    case OutfitItem.butterfly:
      _butterfly(p, g, time, reduceMotion);
    case OutfitItem.cloud:
      _cloud(p, g, time, reduceMotion);
    default:
  }
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

void _sproutBow(Canvas p, _Geo g) {
  final s = g.s * 1.25;
  final k = g.stem(0.42);
  // ribbon tails
  final tail = _stroke(ZeepColors.ink, 3.6 * s);
  final tailIn = _stroke(_bowPink, 1.8 * s);
  for (final sign in const [-1.0, 1.0]) {
    final path = Path()
      ..moveTo(k.dx, k.dy)
      ..quadraticBezierTo(k.dx + sign * 3 * s, k.dy + 4 * s, k.dx + sign * 4.5 * s, k.dy + 7.5 * s);
    p.drawPath(path, tail);
    p.drawPath(path, tailIn);
  }
  for (final sign in const [-1.0, 1.0]) {
    _ellipse(p, k + Offset(sign * 5 * s, -1 * s), 5 * s, 3.3 * s, sign * -0.35, _bowPink, ZeepColors.ink, 1.5 * s);
  }
  p.drawCircle(k, 2.3 * s, _fill(_bowPink));
  p.drawCircle(k, 2.3 * s, _stroke(ZeepColors.ink, 1.5 * s));
}

void _glasses(Canvas p, _Geo g) {
  final s = g.s;
  final r = 10.5 * s;
  final lens = _fill(withAlpha(const Color(0xFFFFFFFF), 0.28));
  final frame = _stroke(ZeepColors.ink, 2.1 * s);
  for (final sign in const [-1.0, 1.0]) {
    final c = Offset(g.cx + sign * g.edx, g.ey + 1.5 * s);
    p.drawCircle(c, r, lens);
    p.drawCircle(c, r, frame);
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

/// Paints Zeep inside a box. The design is laid out for a 395-pt-wide phone;
/// the character's resting centre sits at 58 % of the box height.
class ZeepPainter extends CustomPainter {
  final Pose pose;
  final double time;
  final List<double> ripples;
  final bool reduceMotion;
  final Outfit outfit;

  ZeepPainter({
    required this.pose,
    required this.time,
    required this.ripples,
    this.reduceMotion = false,
    this.outfit = Outfit.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ~1.35x the desktop size on a 393-pt iPhone; shrinks on short screens
    final s = math.min(size.width / 290, size.height / 225);
    final center = Offset(size.width / 2, size.height * 0.52);
    drawZeep(canvas, center, s, pose, time, center.dy + 92 * s, ripples, reduceMotion: reduceMotion, outfit: outfit);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Small face used as an icon in the settings / instructions sheets.
class MiniFacePainter extends CustomPainter {
  final AnimState kind;
  MiniFacePainter(this.kind);

  @override
  void paint(Canvas p, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final s = r / 13;
    p.drawCircle(c, r, _fill(const Color(0xFFF9D9C4)));
    final cheek = withAlpha(const Color(0xFFEE8C78), 0.8);
    _ellipse(p, c + Offset(-6.5 * s, 3.5 * s), 3.2 * s, 2 * s, 0, cheek);
    _ellipse(p, c + Offset(6.5 * s, 3.5 * s), 3.2 * s, 2 * s, 0, cheek);
    for (final sign in const [-1.0, 1.0]) {
      final e = c + Offset(sign * 4.5 * s, -2 * s);
      _quadLine(p, e - Offset(2.6 * s, 0), e + Offset(0, 2.6 * s), e + Offset(2.6 * s, 0), 1.3 * s, ZeepColors.ink);
    }
    final m = c + Offset(0, 5 * s);
    switch (kind) {
      case AnimState.exhale:
        p.drawCircle(m, 2.2 * s, _fill(const Color(0xFF8A4E48)));
      case AnimState.hold:
        p.drawLine(m - Offset(2.2 * s, 0), m + Offset(2.2 * s, 0), _stroke(ZeepColors.ink, 1.3 * s));
      default:
        _quadLine(p, m - Offset(2.5 * s, 0), m + Offset(0, 2.5 * s), m + Offset(2.5 * s, 0), 1.3 * s, ZeepColors.ink);
    }
    // tiny arrow showing the phase direction
    final ac = c + Offset(r * 0.95, -r * 0.7);
    switch (kind) {
      case AnimState.inhale:
        p.drawPath(
          Path()
            ..moveTo(ac.dx, ac.dy - 3.5 * s)
            ..lineTo(ac.dx + 3.2 * s, ac.dy + 1.5 * s)
            ..lineTo(ac.dx - 3.2 * s, ac.dy + 1.5 * s)
            ..close(),
          _fill(ZeepColors.blue),
        );
      case AnimState.exhale:
        p.drawPath(
          Path()
            ..moveTo(ac.dx, ac.dy + 3.5 * s)
            ..lineTo(ac.dx - 3.2 * s, ac.dy - 1.5 * s)
            ..lineTo(ac.dx + 3.2 * s, ac.dy - 1.5 * s)
            ..close(),
          _fill(ZeepColors.blue),
        );
      case AnimState.hold:
        p.drawCircle(ac, 2.4 * s, _fill(const Color(0xFFA996F0)));
      default:
        p.drawCircle(ac, 2.4 * s, _stroke(ZeepColors.textFaint, 1.2 * s));
    }
  }

  @override
  bool shouldRepaint(covariant MiniFacePainter old) => old.kind != kind;
}

/// Small, still Zeep used on cards (exercise list, progress header).
class ZeepAvatar extends StatelessWidget {
  final Color tint;
  final double size;
  final double breath;
  final double hold;
  const ZeepAvatar({super.key, required this.tint, this.size = 64, this.breath = 0.55, this.hold = 0});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _AvatarPainter(tint, breath, hold)),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final Color tint;
  final double breath, hold;
  _AvatarPainter(this.tint, this.breath, this.hold);

  @override
  void paint(Canvas canvas, Size size) {
    // Zeep spans ~190 x 175 design units (arms, sprout, legs, shadow)
    final s = size.shortestSide / 160;
    final pose = Pose(
      breath: breath,
      armLift: breath,
      cheekPuff: 0.3,
      eyeSqueeze: 0.1,
      mouthOpen: 0,
      hold: hold,
      tint: tint,
    );
    // time 0.95: float near rest, leaves open (same as the app icon)
    drawZeep(
      canvas,
      Offset(size.width / 2, size.height * 0.52),
      s,
      pose,
      0.95,
      size.height * 0.52 + 75 * s,
      const [],
      reduceMotion: true,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.tint != tint || old.breath != breath || old.hold != hold;
}
