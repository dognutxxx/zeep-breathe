// Mun's rotor (หมุนหมุน, 1.8.0): how far it has turned, following the doc's
// `spin` keyframes over one breath:
//   inhale  0 -> 360 degrees, ease-in   (a fast turn, fastest at the top)
//   hold    +30 degrees, linear         (a slow drift, "almost still")
//   exhale  +150 degrees, ease-out      (slowing down)
//   rest    still
// One 4-2-6 breath turns 540 degrees, a multiple of the blades' 90 degrees,
// so every breath starts from the same look. Any other timing works too: the
// turn per phase stays the same and only takes longer or shorter.

import 'package:flutter/animation.dart' show Curves;

import '../breathing/breathing_engine.dart' show Phase;

/// Degrees turned over each whole phase.
const spinInhale = 360.0, spinHold = 30.0, spinExhale = 150.0;

/// Outside a session: a very slow turn, as in a light breeze (the doc's idle).
const spinIdlePerSecond = 12.0;

/// Degrees turned from the start of [phase] to [progress] (0..1) into it.
double spinInPhase(Phase phase, double progress) {
  final p = progress.clamp(0.0, 1.0);
  return switch (phase) {
    Phase.inhale => spinInhale * Curves.easeIn.transform(p),
    Phase.hold => spinHold * p,
    Phase.exhale => spinExhale * Curves.easeOut.transform(p),
    Phase.rest => 0,
  };
}

/// The doc's 12 s demo breath (inhale 4 s, hold 2 s, exhale 6 s): the rotor
/// angle at [t] seconds, for the friend cards' live tiles.
double demoSpin(double t) {
  final u = t % 12;
  if (u < 4) return spinInPhase(Phase.inhale, u / 4);
  if (u < 6) return spinInhale + spinInPhase(Phase.hold, (u - 4) / 2);
  return spinInhale + spinHold + spinInPhase(Phase.exhale, (u - 6) / 6);
}

/// The rotor angle, moved on by the app's one ticker. No allocation per frame.
class Pinwheel {
  /// Degrees, kept in 0..360.
  double angle = 0;

  Phase? _phase;
  double _progress = 0;

  /// One frame: in a running session, the turn since the last frame within
  /// the breathing [phase] at [progress]; [paused] stops it; outside a
  /// session ([phase] null) a slow drift.
  void update(double dt, {Phase? phase, double progress = 0, bool paused = false}) {
    if (phase == null) {
      _phase = null;
      if (!paused) _turn(dt * spinIdlePerSecond);
      return;
    }
    if (paused) return;
    if (phase != _phase) {
      // finish the last phase's turn if it ran to its end (the frame that
      // crossed over), so a breath adds up to its whole turn; a phase cut
      // short is not finished. Either way the new one starts where the rotor
      // is: no jump.
      final last = _phase;
      if (last != null && _progress >= 0.9) _turn(spinInPhase(last, 1) - spinInPhase(last, _progress));
      _phase = phase;
      _progress = 0;
    }
    _turn(spinInPhase(phase, progress) - spinInPhase(phase, _progress));
    _progress = progress;
  }

  void _turn(double deg) {
    if (deg <= 0) return;
    angle = (angle + deg) % 360;
  }
}
