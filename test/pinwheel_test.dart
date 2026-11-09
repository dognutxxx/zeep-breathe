// Mun's rotor (1.8.0): the doc's `spin` keyframes per breathing phase, the
// demo breath on the cards, and the ticker-driven Pinwheel.

import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/breathing/breathing_engine.dart' show Phase;
import 'package:zeep_breathe/friends/pinwheel.dart';

void main() {
  test('one breath: a whole turn in, +30 on hold, +150 out, still at rest', () {
    expect(spinInPhase(Phase.inhale, 0), 0);
    expect(spinInPhase(Phase.inhale, 1), closeTo(360, 1e-9));
    expect(spinInPhase(Phase.hold, 1), 30);
    expect(spinInPhase(Phase.exhale, 1), closeTo(150, 1e-9));
    expect(spinInPhase(Phase.rest, 0.7), 0);
    // 540 degrees: a multiple of the blades' 90
    expect((spinInhale + spinHold + spinExhale) % 90, 0);
  });

  test('fast at the top of the inhale (ease-in), slowing down on the exhale (ease-out)', () {
    double speed(Phase p, double at) => (spinInPhase(p, at + 0.01) - spinInPhase(p, at)) / 0.01;
    expect(speed(Phase.inhale, 0.9), greaterThan(4 * speed(Phase.inhale, 0.05)));
    expect(speed(Phase.exhale, 0.05), greaterThan(4 * speed(Phase.exhale, 0.9)));
    // the hold drifts slower than either
    expect(speed(Phase.hold, 0.5), lessThan(speed(Phase.inhale, 0.9) / 10));
  });

  test('the demo breath (4-2-6 s) on the cards', () {
    expect(demoSpin(0), 0);
    expect(demoSpin(4), closeTo(360, 1e-6));
    expect(demoSpin(5), closeTo(375, 1e-6));
    expect(demoSpin(6), closeTo(390, 1e-6));
    expect(demoSpin(11.999), closeTo(540, 0.1));
    expect(demoSpin(12), 0); // 540 looks the same as 0
    for (var t = 0.0; t < 11.9; t += 0.1) {
      expect(demoSpin(t + 0.1), greaterThanOrEqualTo(demoSpin(t)), reason: 'only forwards at $t');
    }
  });

  group('Pinwheel on the ticker', () {
    /// Runs [phase] for [secs] seconds at 60 fps; returns degrees turned.
    double run(Pinwheel w, Phase? phase, double secs, {bool paused = false}) {
      var turned = 0.0;
      final n = (secs * 60).round();
      for (var i = 1; i <= n; i++) {
        final before = w.angle;
        w.update(1 / 60, phase: phase, progress: i / n, paused: paused);
        turned += (w.angle - before) % 360;
      }
      return turned;
    }

    test('a session breath turns 540 degrees, whatever the timing', () {
      for (final (inhale, hold, exhale) in const [(4.0, 2.0, 6.0), (4.0, 7.0, 8.0), (3.0, 0.0, 3.0)]) {
        final w = Pinwheel();
        var total = run(w, Phase.inhale, inhale);
        if (hold > 0) total += run(w, Phase.hold, hold);
        total += run(w, Phase.exhale, exhale);
        total += run(w, Phase.rest, 1);
        expect(total, closeTo(hold > 0 ? 540 : 510, 1), reason: '$inhale-$hold-$exhale');
        expect(w.angle, inInclusiveRange(0, 360));
      }
    });

    test('a new phase starts where the rotor is: no jump', () {
      final w = Pinwheel();
      run(w, Phase.inhale, 2);
      final before = w.angle;
      // the inhale is cut short (e.g. settings changed): the hold just goes on
      w.update(1 / 60, phase: Phase.hold, progress: 0.01);
      expect((w.angle - before) % 360, lessThan(1));
    });

    test('paused: still; outside a session: a slow drift', () {
      final w = Pinwheel();
      run(w, Phase.inhale, 1);
      final a = w.angle;
      expect(run(w, Phase.inhale, 1, paused: true), 0);
      expect(w.angle, a);
      expect(run(w, null, 1), closeTo(spinIdlePerSecond, 0.01));
    });
  });
}
