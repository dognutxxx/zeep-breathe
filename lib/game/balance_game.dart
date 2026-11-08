// Zeep Balance game rules (no Flutter, no sensors): the circle for each
// level, the score, and when to give edge haptics. Positions are in screen
// pixels relative to the centre of the board (x right, y down), the same
// space as [BallPhysics].

import 'dart:math' as math;

import '../tilt/tilt_physics.dart';

enum BalanceLevel { easy, medium, hard }

/// The circle Zeep has to stay in.
class GameCircle {
  final Vec2 centre;
  final double radius;
  const GameCircle(this.centre, this.radius);

  bool contains(Vec2 p) => (p - centre).length <= radius;
}

/// Where the circle is for a level at a moment of play.
///
/// [halfW]/[halfH] is half the board size. [breath] (0..1) is the breathing
/// engine's lung level, used by the medium level so the circle grows on the
/// inhale and shrinks on the exhale (rhythm from Breathing settings, SH1).
/// [time] is seconds since play started, used by the hard level's slow drift.
GameCircle circleFor(
  BalanceLevel level, {
  required double halfW,
  required double halfH,
  double breath = 0,
  double time = 0,
}) {
  final m = math.max(0.0, math.min(halfW, halfH));
  switch (level) {
    case BalanceLevel.easy:
      return GameCircle(Vec2.zero, 0.62 * m);
    case BalanceLevel.medium:
      final b = breath.clamp(0.0, 1.0);
      return GameCircle(Vec2.zero, (0.32 + 0.30 * b) * m);
    case BalanceLevel.hard:
      // a slow figure-of-eight; periods are long and unrelated so it never
      // feels like a loop, the circle always stays on the board, and it starts
      // centred so Zeep (who starts in the middle) begins inside
      const tau = 2 * math.pi;
      final r = 0.28 * m;
      final cx = (halfW - r) * 0.55 * math.sin(tau * time / 19);
      final cy = (halfH - r) * 0.45 * math.sin(tau * time / 13);
      return GameCircle(Vec2(cx, cy), r);
  }
}

/// Share of play time spent with Zeep's centre inside the circle.
class BalanceScore {
  double inside = 0, total = 0;

  void add(double dt, bool isInside) {
    if (dt <= 0) return;
    total += dt;
    if (isInside) inside += dt;
  }

  /// 0..100, rounded down so 94.9 % never shows as 3 stars.
  int get percent => total <= 0 ? 0 : (100 * inside / total).floor().clamp(0, 100);

  void reset() => inside = total = 0;
}

/// 0..3 stars: 60 %, 80 %, 95 % (from the approved game deck).
int starsFor(int percent) => percent >= 95
    ? 3
    : percent >= 80
    ? 2
    : percent >= 60
    ? 1
    : 0;

enum EdgeEvent { left, entered }

/// Turns inside/outside into edge haptics: one soft pulse when Zeep leaves
/// the circle, a tiny tick when it comes back. While Zeep sits right on the
/// edge it would flip every frame, so after a pulse no other edge pulse is
/// given for [guard] seconds.
class EdgeHaptics {
  final double guard;
  bool? _inside;
  double _lastPulse = double.negativeInfinity;

  EdgeHaptics({this.guard = 0.5});

  /// Call every frame of play; returns the pulse to play, if any. The first
  /// call only records where Zeep is.
  EdgeEvent? update(bool inside, double now) {
    final was = _inside;
    _inside = inside;
    if (was == null || was == inside) return null;
    if (now - _lastPulse < guard) return null;
    _lastPulse = now;
    return inside ? EdgeEvent.entered : EdgeEvent.left;
  }

  void reset() {
    _inside = null;
    _lastPulse = double.negativeInfinity;
  }
}

/// History id for a game session, e.g. "game-medium" (see exercises.dart).
String gameHistoryId(BalanceLevel level) => 'game-${level.name}';

/// The level of a history id from [gameHistoryId], or null.
BalanceLevel? gameLevelOf(String id) {
  if (!id.startsWith('game-')) return null;
  for (final l in BalanceLevel.values) {
    if (id == 'game-${l.name}') return l;
  }
  return null;
}
