import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/breathing/breathing_engine.dart';

void main() {
  const d = BreathDurations(4, 2, 6, 0);

  test('cycles through phases', () {
    final e = BreathingEngine(d, 180)..start();
    final seen = <Phase>[];
    for (var i = 0; i < 13 * 60; i++) {
      for (final ev in e.update(1 / 60)) {
        if (ev is PhaseStarted) seen.add(ev.phase);
      }
    }
    expect(seen, [Phase.hold, Phase.exhale, Phase.inhale]);
  });

  test('zero hold is skipped', () {
    final e = BreathingEngine(d.copyWith(hold: 0), 180)..start();
    expect(e.update(4.01), [const PhaseStarted(Phase.exhale)]);
  });

  test('re-timing keeps fraction', () {
    final e = BreathingEngine(d, 180)..start();
    e.update(2.0);
    final before = e.level;
    e.setDurations(d.copyWith(inhale: 8));
    expect((e.level - before).abs(), lessThan(1e-4));
    expect((e.phaseElapsed - 4.0).abs(), lessThan(1e-4));
  });

  test('finishes', () {
    final e = BreathingEngine(d, 3)..start();
    expect(e.update(3.5), [const SessionFinished()]);
    expect(e.state, RunState.finished);
  });

  test('setting current phase to 0 advances immediately', () {
    final e = BreathingEngine(d, 180)..start();
    e.update(5.0); // in hold
    expect(e.phase, Phase.hold);
    final ev = e.setDurations(d.copyWith(hold: 0));
    expect(ev, [const PhaseStarted(Phase.exhale)]);
    expect(e.phaseElapsed, 0);
  });
}
