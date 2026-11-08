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
  _quadLine(p, top, Offset(cx - 3 * s, (top.dy + tip.dy) * 0.5), tip, 2.2 * s, ZeepColors.ink);
  final open = 0.55 + 0.25 * br + 0.1 * math.sin(time * 1.3);
  const leaf = Color(0xFFB5E3C2);
  _ellipse(p, tip + Offset(-7 * s, -1 * s), 8 * s, 4.2 * s, -open, leaf, ZeepColors.ink, 1.8 * s);
  _ellipse(p, tip + Offset(6.5 * s, -2.5 * s), 7 * s, 3.8 * s, open * 0.9, leaf, ZeepColors.ink, 1.8 * s);

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
}

/// Paints Zeep inside a box. The design is laid out for a 395-pt-wide phone;
/// the character's resting centre sits at 58 % of the box height.
class ZeepPainter extends CustomPainter {
  final Pose pose;
  final double time;
  final List<double> ripples;
  final bool reduceMotion;

  ZeepPainter({required this.pose, required this.time, required this.ripples, this.reduceMotion = false});

  @override
  void paint(Canvas canvas, Size size) {
    // ~1.35x the desktop size on a 393-pt iPhone; shrinks on short screens
    final s = math.min(size.width / 290, size.height / 225);
    final center = Offset(size.width / 2, size.height * 0.52);
    drawZeep(canvas, center, s, pose, time, center.dy + 92 * s, ripples, reduceMotion: reduceMotion);
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
