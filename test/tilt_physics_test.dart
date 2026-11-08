import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/tilt/tilt_physics.dart';

const g = 9.81;
double rad(double deg) => deg * math.pi / 180;

/// Flat phone with the right edge lowered by [deg] degrees.
Vec3 flatRightDown(double deg) => Vec3(-g * math.sin(rad(deg)), 0, g * math.cos(rad(deg)));

/// Flat phone with the top edge lowered by [deg] degrees.
Vec3 flatTopDown(double deg) => Vec3(0, -g * math.sin(rad(deg)), g * math.cos(rad(deg)));

void main() {
  group('TiltMapper', () {
    test('no tilt before calibration', () {
      expect(TiltMapper().tilt(flatRightDown(20)).length, 0);
    });

    test('level pose reads zero', () {
      final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
      final t = m.tilt(const Vec3(0, 0, g));
      expect(t.x, 0);
      expect(t.y, 0);
    });

    test('lowering the right edge rolls Zeep right', () {
      final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
      final t = m.tilt(flatRightDown(10));
      expect(t.x, greaterThan(0.1));
      expect(t.y, 0);
    });

    test('lowering the top edge rolls Zeep up the screen', () {
      final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
      final t = m.tilt(flatTopDown(10));
      expect(t.y, lessThan(-0.1));
      expect(t.x, 0);
    });

    test('works from any held pose: upright phone', () {
      final m = TiltMapper()..calibrate(const Vec3(0, g, 0));
      expect(m.tilt(const Vec3(0, g, 0)).length, 0);
      // upright, right edge lowered (rotate about the screen normal)
      final right = m.tilt(Vec3(-g * math.sin(rad(12)), g * math.cos(rad(12)), 0));
      expect(right.x, greaterThan(0.1));
      expect(right.y.abs(), lessThan(1e-9));
      // upright, top tipped away from the player: top edge goes down and the
      // screen turns towards the sky (z grows)
      final away = m.tilt(Vec3(0, g * math.cos(rad(12)), g * math.sin(rad(12))));
      expect(away.y, lessThan(-0.1));
      expect(away.x.abs(), lessThan(1e-9));
    });

    test('works from a reclined pose (45°)', () {
      final held = Vec3(0, g * math.sin(rad(45)), g * math.cos(rad(45)));
      final m = TiltMapper()..calibrate(held);
      expect(m.tilt(held).length, 0);
      final t = m.tilt(Vec3(-g * math.sin(rad(10)), held.y * math.cos(rad(10)), held.z * math.cos(rad(10))));
      expect(t.x, greaterThan(0.1));
    });

    test('small tremor inside the dead zone is ignored', () {
      final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
      expect(m.tilt(flatRightDown(1)).x, 0);
      expect(m.tilt(flatTopDown(-1.2)).y, 0);
    });

    test('leaving the dead zone is continuous (no jump)', () {
      final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
      final edgeDeg = math.asin(m.deadZone) * 180 / math.pi;
      expect(m.tilt(flatRightDown(edgeDeg + 0.05)).x, lessThan(0.002));
    });

    test('steep tilt is capped', () {
      final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
      expect(m.tilt(flatRightDown(80)).x, closeTo(m.maxTilt, 1e-9));
      expect(m.tilt(flatRightDown(-80)).x, closeTo(-m.maxTilt, 1e-9));
    });

    test('rejects a zero reading', () {
      expect(TiltMapper().calibrate(const Vec3(0, 0, 0)), isFalse);
    });
  });

  group('LowPass', () {
    test('first sample passes through, then follows with the time constant', () {
      final f = LowPass(tau: 0.1);
      expect(f.add(const Vec2(1, 0), 0.016).x, 1);
      f.reset();
      f.add(Vec2.zero, 0.016);
      // after one time constant ~63 %, regardless of step size
      var v = Vec2.zero;
      for (var i = 0; i < 10; i++) {
        v = f.add(const Vec2(1, 0), 0.01);
      }
      expect(v.x, closeTo(1 - math.exp(-1), 1e-6));
    });
  });

  group('BallPhysics', () {
    BallPhysics ball() => BallPhysics()..setBounds(150, 250);

    test('no tilt from rest: Zeep stays exactly still', () {
      final b = ball();
      for (var i = 0; i < 600; i++) {
        b.step(1 / 60, Vec2.zero);
      }
      expect(b.pos.x, 0);
      expect(b.pos.y, 0);
    });

    test('tilt accelerates Zeep in that direction', () {
      final b = ball();
      for (var i = 0; i < 20; i++) {
        b.step(1 / 60, const Vec2(0.2, -0.1));
      }
      expect(b.pos.x, greaterThan(0));
      expect(b.pos.y, lessThan(0));
    });

    test('never leaves the board, even with big time steps', () {
      final b = ball();
      for (var i = 0; i < 300; i++) {
        b.step(i.isEven ? 1 / 60 : 0.5, const Vec2(0.57, 0.57));
        expect(b.pos.x.abs(), lessThanOrEqualTo(150));
        expect(b.pos.y.abs(), lessThanOrEqualTo(250));
      }
      expect(b.pos.x, 150);
      expect(b.pos.y, 250);
    });

    test('comes to a full stop when tilt returns to level', () {
      final b = ball();
      for (var i = 0; i < 15; i++) {
        b.step(1 / 60, const Vec2(0.3, 0));
      }
      for (var i = 0; i < 300; i++) {
        b.step(1 / 60, Vec2.zero);
      }
      expect(b.vel.length, 0);
      final x = b.pos.x;
      b.step(1, Vec2.zero);
      expect(b.pos.x, x);
    });

    test('shrinking the board pulls Zeep inside', () {
      final b = ball()..pos = const Vec2(140, -240);
      b.setBounds(100, 100);
      expect(b.pos.x, 100);
      expect(b.pos.y, -100);
    });
  });

  group('TiltController', () {
    test('cannot calibrate before the first reading', () {
      expect(TiltController().calibrate(), isFalse);
    });

    test('holding still with hand tremor keeps Zeep in the centre', () {
      final c = TiltController()
        ..ball.setBounds(150, 250)
        ..onReading(const Vec3(0, 0.4, g));
      expect(c.calibrate(), isTrue);
      final rnd = math.Random(7);
      for (var i = 0; i < 600; i++) {
        // ±1° jitter around the held pose
        final dx = (rnd.nextDouble() * 2 - 1) * rad(1);
        final dy = (rnd.nextDouble() * 2 - 1) * rad(1);
        c.onReading(Vec3(-g * math.sin(dx), 0.4 - g * math.sin(dy), g));
        c.update(1 / 60);
      }
      expect(c.ball.pos.length, 0);
    });

    test('a held tilt rolls Zeep to the wall and keeps it there', () {
      final c = TiltController()
        ..ball.setBounds(150, 250)
        ..onReading(const Vec3(0, 0, g));
      c.calibrate();
      for (var i = 0; i < 180; i++) {
        c.onReading(flatRightDown(15));
        c.update(1 / 60);
      }
      expect(c.ball.pos.x, 150);
      expect(c.ball.pos.y, 0);
    });

    test('calibrating from shaky readings: the held pose still reads level', () {
      // review #2: the countdown ends while the hand jitters, and the very
      // last sample carries a 0.6 m/s² sideways bump (≈3.5°, beyond the dead
      // zone). The level pose is averaged, so holding still keeps Zeep put.
      const held = Vec3(0, 3, 9.33);
      final c = TiltController()..ball.setBounds(150, 250);
      final rnd = math.Random(3);
      for (var i = 0; i < 150; i++) {
        // 50 Hz sensor, ±0.4 m/s² of hand jitter on x and y
        final jx = (rnd.nextDouble() * 2 - 1) * 0.4;
        final jy = (rnd.nextDouble() * 2 - 1) * 0.4;
        c.onReading(Vec3(held.x + jx, held.y + jy, held.z));
        c.tick(1 / 50);
      }
      c.onReading(Vec3(held.x + 0.6, held.y, held.z));
      expect(c.calibrate(), isTrue);
      for (var i = 0; i < 600; i++) {
        c.onReading(held);
        c.update(1 / 60);
      }
      expect(c.ball.pos.x, 0);
      expect(c.ball.pos.y, 0);
    });

    test('only the last half second counts towards the level pose', () {
      final c = TiltController();
      for (var i = 0; i < 100; i++) {
        c.onReading(flatRightDown(20)); // old pose, before the player settled
        c.tick(1 / 50);
      }
      for (var i = 0; i < 40; i++) {
        c.onReading(const Vec3(0, 0, g));
        c.tick(1 / 50);
      }
      final avg = c.averageReading!;
      expect(avg.x, 0);
      expect(avg.z, g);
    });

    test('readings stop mid-game: Zeep slows to a stop instead of rolling on', () {
      // review #3: a stale reading must not keep Zeep pinned to a wall
      final c = TiltController()
        ..ball.setBounds(1000, 1000)
        ..onReading(const Vec3(0, 0, g));
      c.calibrate();
      c.onReading(flatRightDown(15));
      for (var i = 0; i < 20; i++) {
        c.update(1 / 60);
      }
      expect(c.ball.vel.x, greaterThan(0));
      for (var i = 0; i < 300; i++) {
        c.update(1 / 60); // no new readings
      }
      expect(c.ball.vel.length, 0);
      final x = c.ball.pos.x;
      expect(x, lessThan(1000));
      c.update(1 / 60);
      expect(c.ball.pos.x, x);
    });

    test('recalibrating re-centres Zeep and makes the current pose level', () {
      final c = TiltController()
        ..ball.setBounds(150, 250)
        ..onReading(const Vec3(0, 0, g));
      c.calibrate();
      for (var i = 0; i < 60; i++) {
        c.onReading(flatRightDown(15));
        c.update(1 / 60);
      }
      expect(c.calibrate(), isTrue);
      expect(c.ball.pos.length, 0);
      for (var i = 0; i < 120; i++) {
        c.onReading(flatRightDown(15));
        c.update(1 / 60);
      }
      expect(c.ball.pos.length, 0);
    });
  });

  group('remapTilt', () {
    const v = Vec3(1, 2, 3);

    test('the table for all four rotations (z never changes)', () {
      Vec3 r(int k) => remapTilt(v, k);
      expect([r(0).x, r(0).y, r(0).z], [1, 2, 3]);
      expect([r(1).x, r(1).y, r(1).z], [-2, 1, 3]);
      expect([r(2).x, r(2).y, r(2).z], [-1, -2, 3]);
      expect([r(3).x, r(3).y, r(3).z], [2, -1, 3]);
    });

    test('turning back undoes it', () {
      for (var k = 0; k < 4; k++) {
        final back = remapTilt(remapTilt(v, k), (4 - k) % 4);
        expect([back.x, back.y, back.z], [1, 2, 3]);
      }
    });

    // Physical checks: lay the phone flat, turn the screen, then lower the
    // edge that is on the RIGHT of the screen. The screen reading must look
    // like flatRightDown in every rotation. Device edges in each case:
    //   0: right edge (device +x)       1 (turned CCW): bottom edge (-y)
    //   2: left edge (-x)               3 (turned CW): top edge (+y)
    // Lowering a device edge e makes the reading -g*sin(a) along e.
    // Same numbers on iOS and Android: sensors_plus gives both in the
    // Android convention and zeep/display uses the same quarter turns.
    final s = math.sin(rad(10)) * g, c = math.cos(rad(10)) * g;
    final lowered = <int, Vec3>{
      0: Vec3(-s, 0, c), // right edge down
      1: Vec3(0, s, c), // bottom edge down
      2: Vec3(s, 0, c), // left edge down
      3: Vec3(0, -s, c), // top edge down
    };
    for (var k = 0; k < 4; k++) {
      test('rotation $k: lowering the screen-right edge reads as right', () {
        final m = TiltMapper()..calibrate(const Vec3(0, 0, g));
        final t = m.tilt(remapTilt(lowered[k]!, k));
        expect(t.x, greaterThan(0.1));
        expect(t.y.abs(), lessThan(1e-9));
      });
    }

    test('upright phone turned upside down (rotation 2) still reads level', () {
      final m = TiltMapper()..calibrate(remapTilt(const Vec3(0, -g, 0), 2));
      expect(m.tilt(remapTilt(const Vec3(0, -g, 0), 2)).length, 0);
    });
  });
}
