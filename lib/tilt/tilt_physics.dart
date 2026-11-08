// SYS.9 tilt logic (no sensors, no Flutter): turns accelerometer readings into
// a smooth rolling motion for Zeep.
//
//   reading (gravity, device axes)
//     -> TiltMapper.raw: tilt relative to the pose held at calibration
//     -> low-pass filter: removes hand tremor
//     -> TiltMapper.shape: dead zone (holding still = no tilt at all) + cap
//     -> BallPhysics: tilt = acceleration, damping, soft walls
//
// Device axes follow Android (sensors_plus uses the same on iOS): x to the
// right edge, y to the top edge, z out of the screen. A flat phone reads
// about (0, 0, 9.8). Screen coordinates: x right, y down.

import 'dart:math' as math;

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  double get length => math.sqrt(dot(this));
  Vec3 get unit {
    final l = length;
    return l < 1e-9 ? const Vec3(0, 0, 0) : this * (1 / l);
  }

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// A 2D value in screen axes (x right, y down).
class Vec2 {
  final double x, y;
  const Vec2(this.x, this.y);
  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);

  @override
  String toString() => 'Vec2($x, $y)';
}

/// Tilt relative to the "level" pose captured by [calibrate]. Whatever way
/// the phone is held at calibration (flat, upright, lying in bed) counts as
/// level, so the game works in any comfortable position.
class TiltMapper {
  /// Below this (sin of the angle, ~1.7°) the phone counts as still.
  final double deadZone;

  /// Tilt is capped here (sin 35°) so a steep angle doesn't fling Zeep.
  final double maxTilt;

  Vec3? _up, _right, _forward;

  TiltMapper({this.deadZone = 0.03, this.maxTilt = 0.57});

  bool get calibrated => _up != null;

  /// Uses [g] (the reading while the player holds the phone the way they
  /// want to play) as the level pose. Returns false for an unusable reading.
  bool calibrate(Vec3 g) {
    final up = g.unit;
    if (up.length == 0) return false;
    // Screen-right projected onto the level plane. The app is portrait-locked,
    // so the device x axis is never parallel to gravity in normal play; if it
    // is (phone on its side) fall back to the y axis.
    var right = _project(const Vec3(1, 0, 0), up);
    if (right.length < 0.2) right = _cross(_project(const Vec3(0, 1, 0), up).unit, up);
    right = right.unit;
    _up = up;
    _right = right;
    _forward = _cross(up, right).unit; // towards the top edge
    return true;
  }

  /// Raw tilt in screen axes (sin of the angle from level): positive x =
  /// Zeep should roll right, positive y = roll down the screen.
  Vec2 raw(Vec3 g) {
    final up = _up;
    if (up == null) return Vec2.zero;
    final n = g.unit;
    // Gravity seen in the level frame. Lowering the right edge moves the
    // reading towards -right, so Zeep rolls right; lowering the top edge
    // moves it towards -forward, so Zeep rolls up (negative screen y).
    return Vec2(-n.dot(_right!), n.dot(_forward!));
  }

  /// Applies the dead zone and the cap: each axis ends in -[maxTilt]..[maxTilt].
  Vec2 shape(Vec2 t) => Vec2(_shape(t.x), _shape(t.y));

  /// [raw] then [shape].
  Vec2 tilt(Vec3 g) => shape(raw(g));

  double _shape(double v) {
    final a = v.abs();
    if (a <= deadZone) return 0;
    // continuous at the dead-zone edge, so there's no jump when leaving it
    final out = math.min(a - deadZone, maxTilt);
    return v.sign * out;
  }

  static Vec3 _project(Vec3 v, Vec3 n) => v - n * v.dot(n);
  static Vec3 _cross(Vec3 a, Vec3 b) => Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
}

/// First-order low-pass filter with a time constant, so smoothing doesn't
/// depend on the sensor rate.
class LowPass {
  final double tau;
  Vec2 value = Vec2.zero;
  bool _primed = false;
  LowPass({this.tau = 0.09});

  Vec2 add(Vec2 v, double dt) {
    if (!_primed) {
      _primed = true;
      value = v;
      return value;
    }
    final a = 1 - math.exp(-dt / tau);
    value = value + (v - value) * a;
    return value;
  }

  void reset() {
    value = Vec2.zero;
    _primed = false;
  }
}

/// Zeep as a rolling ball inside a box centred on (0, 0).
class BallPhysics {
  /// Acceleration in px/s² at tilt 1.0.
  final double gain;

  /// Velocity decay per second (rolling friction + air).
  final double damping;

  /// Share of speed kept after hitting a wall (soft bounce).
  final double bounce;

  /// Below this speed with no tilt, Zeep stops completely.
  final double restSpeed;

  Vec2 pos = Vec2.zero;
  Vec2 vel = Vec2.zero;

  /// Half the size of the area Zeep's centre may move in.
  double halfW = 0, halfH = 0;

  BallPhysics({this.gain = 2200, this.damping = 2.2, this.bounce = 0.35, this.restSpeed = 8});

  void setBounds(double halfWidth, double halfHeight) {
    halfW = math.max(0, halfWidth);
    halfH = math.max(0, halfHeight);
    pos = Vec2(pos.x.clamp(-halfW, halfW), pos.y.clamp(-halfH, halfH));
  }

  void reset() {
    pos = Vec2.zero;
    vel = Vec2.zero;
  }

  void step(double dt, Vec2 tilt) {
    if (dt <= 0) return;
    // large gaps (app resumed, dropped frames) are split so walls still hold
    while (dt > 0) {
      final h = math.min(dt, 1 / 120);
      _step(h, tilt);
      dt -= h;
    }
  }

  void _step(double dt, Vec2 tilt) {
    vel = vel + tilt * (gain * dt);
    vel = vel * math.exp(-damping * dt);
    if (tilt.x == 0 && tilt.y == 0 && vel.length < restSpeed) vel = Vec2.zero;
    var x = pos.x + vel.x * dt;
    var y = pos.y + vel.y * dt;
    var vx = vel.x, vy = vel.y;
    if (x > halfW) {
      x = halfW;
      vx = -vx.abs() * bounce;
    } else if (x < -halfW) {
      x = -halfW;
      vx = vx.abs() * bounce;
    }
    if (y > halfH) {
      y = halfH;
      vy = -vy.abs() * bounce;
    } else if (y < -halfH) {
      y = -halfH;
      vy = vy.abs() * bounce;
    }
    pos = Vec2(x, y);
    vel = Vec2(vx, vy);
  }
}

/// Mapper + filter + physics in one object, driven once per frame.
class TiltController {
  final TiltMapper mapper;
  final LowPass filter;
  final BallPhysics ball;
  Vec3? _latest;

  TiltController({TiltMapper? mapper, LowPass? filter, BallPhysics? ball})
    : mapper = mapper ?? TiltMapper(),
      filter = filter ?? LowPass(),
      ball = ball ?? BallPhysics();

  bool get calibrated => mapper.calibrated;
  bool get hasReading => _latest != null;

  void onReading(Vec3 g) => _latest = g;

  /// Takes the latest reading as level and puts Zeep back in the middle.
  bool calibrate() {
    final g = _latest;
    if (g == null || !mapper.calibrate(g)) return false;
    filter.reset();
    ball.reset();
    return true;
  }

  void update(double dt) {
    final g = _latest;
    if (g == null || !mapper.calibrated) return;
    // filter first, then the dead zone: tremor is smoothed away before the
    // still-check, so a steady hand gives exactly zero tilt
    final t = mapper.shape(filter.add(mapper.raw(g), dt));
    ball.step(dt, t);
  }
}
