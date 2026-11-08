// Breathing timer logic: phases, session countdown and live re-configuration.
//
// Port of `app/src/engine.rs`. A small deterministic state machine driven by
// `update(dt)`. It never animates anything itself; it reports *where* in the
// breath we are (phase + progress + lung level) and returns events on phase
// transitions so the character, progress bar, label and haptics all read from
// one single source of truth and stay in sync.

import 'dart:math' as math;

enum Phase { inhale, hold, exhale, rest }

extension PhaseLabel on Phase {
  String get label => switch (this) {
        Phase.inhale => 'Inhale',
        Phase.hold => 'Hold',
        Phase.exhale => 'Exhale',
        Phase.rest => 'Rest',
      };
}

enum RunState { ready, running, paused, finished }

class BreathDurations {
  final double inhale, hold, exhale, rest; // seconds
  const BreathDurations(this.inhale, this.hold, this.exhale, [this.rest = 0]);

  double of(Phase p) => switch (p) {
        Phase.inhale => inhale,
        Phase.hold => hold,
        Phase.exhale => exhale,
        Phase.rest => rest,
      };

  double get cycle => inhale + hold + exhale + rest;

  BreathDurations copyWith({double? inhale, double? hold, double? exhale, double? rest}) =>
      BreathDurations(inhale ?? this.inhale, hold ?? this.hold, exhale ?? this.exhale, rest ?? this.rest);

  @override
  bool operator ==(Object other) =>
      other is BreathDurations &&
      other.inhale == inhale &&
      other.hold == hold &&
      other.exhale == exhale &&
      other.rest == rest;

  @override
  int get hashCode => Object.hash(inhale, hold, exhale, rest);
}

sealed class EngineEvent {
  const EngineEvent();
}

class PhaseStarted extends EngineEvent {
  final Phase phase;
  const PhaseStarted(this.phase);
  @override
  bool operator ==(Object other) => other is PhaseStarted && other.phase == phase;
  @override
  int get hashCode => phase.hashCode;
  @override
  String toString() => 'PhaseStarted($phase)';
}

class SessionFinished extends EngineEvent {
  const SessionFinished();
  @override
  bool operator ==(Object other) => other is SessionFinished;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'SessionFinished';
}

/// Natural breathing curve: slow start, fastest in the middle, slow finish.
double breathEase(double t) => 0.5 - 0.5 * math.cos(math.pi * t.clamp(0.0, 1.0));

class BreathingEngine {
  BreathDurations durations;
  Phase phase = Phase.inhale;
  double phaseElapsed = 0;
  double sessionLength;
  double sessionElapsed = 0;
  RunState state = RunState.ready;

  /// Completed breath cycles in this session.
  int breaths = 0;

  BreathingEngine(this.durations, this.sessionLength);

  List<EngineEvent> start() {
    state = RunState.running;
    phase = Phase.inhale;
    phaseElapsed = 0;
    sessionElapsed = 0;
    breaths = 0;
    return const [PhaseStarted(Phase.inhale)];
  }

  void pause() {
    if (state == RunState.running) state = RunState.paused;
  }

  void resume() {
    if (state == RunState.paused) state = RunState.running;
  }

  void stop() {
    state = RunState.ready;
    phase = Phase.inhale;
    phaseElapsed = 0;
    sessionElapsed = 0;
  }

  bool get isActive => state == RunState.running || state == RunState.paused;

  Phase _next(Phase p) {
    var n = p;
    for (var i = 0; i < 4; i++) {
      n = Phase.values[(n.index + 1) % 4];
      if (durations.of(n) > 0) return n;
    }
    return Phase.inhale;
  }

  List<EngineEvent> update(double dt) {
    final ev = <EngineEvent>[];
    if (state != RunState.running) return ev;
    sessionElapsed += dt;
    if (sessionElapsed >= sessionLength) {
      sessionElapsed = sessionLength;
      state = RunState.finished;
      ev.add(const SessionFinished());
      return ev;
    }
    phaseElapsed += dt;
    var guard = 0;
    while (phaseElapsed >= durations.of(phase) && guard < 8) {
      phaseElapsed -= durations.of(phase);
      final np = _next(phase);
      if (np == Phase.inhale) breaths++;
      phase = np;
      ev.add(PhaseStarted(np));
      guard++;
    }
    return ev;
  }

  /// Apply new durations to a live session without a visual jump: the
  /// fraction of the current phase is preserved, so the lung level (and with
  /// it the character size and progress bar) stays continuous.
  List<EngineEvent> setDurations(BreathDurations d) {
    final old = durations.of(phase);
    final frac = old > 0 ? phaseElapsed / old : 1.0;
    durations = d;
    final ev = <EngineEvent>[];
    if (isActive) {
      final nw = d.of(phase);
      if (nw <= 0) {
        phase = _next(phase);
        phaseElapsed = 0;
        ev.add(PhaseStarted(phase));
      } else {
        phaseElapsed = frac.clamp(0.0, 1.0) * nw;
      }
    }
    return ev;
  }

  double get phaseDuration => durations.of(phase);

  double get phaseProgress {
    final d = phaseDuration;
    return d <= 0 ? 1.0 : (phaseElapsed / d).clamp(0.0, 1.0);
  }

  double get phaseRemaining => math.max(0, phaseDuration - phaseElapsed);

  double get sessionRemaining => math.max(0, sessionLength - sessionElapsed);

  /// Lung level 0 (empty) .. 1 (full) for the current moment.
  double get level {
    final t = phaseProgress;
    return switch (phase) {
      Phase.inhale => breathEase(t),
      Phase.hold => 1.0,
      Phase.exhale => 1.0 - breathEase(t),
      Phase.rest => 0.0,
    };
  }
}
