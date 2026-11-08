// Flower-garden rules (approved deck "Zeep flower garden", 2026-11-08).
// Pure functions, so they can be unit-tested.
//
// - One "step" = one saved session with completed == true (breathing modes and
//   Zeep Balance games alike), at most [maxStepsPerDay] per calendar day.
// - Level L needs leavesForLevel(L) leaves, then one more step blooms a flower
//   and the level goes up. Bloom n (0-based) is flowerKinds[n % 20]; after all
//   20 the kinds repeat and the garden counts each kind.
// - Practice days (for wardrobe items) = days with at least one saved session,
//   in a row or not.

import '../history/session_history.dart';
import 'flowers.dart';

const maxStepsPerDay = 3;

/// Whether a saved session grows the sprout.
bool countsAsStep(SessionRecord r) => r.completed;

class GardenLevel {
  /// Current level, from 1.
  final int level;

  /// Leaves grown in the current level (0 .. leavesNeeded).
  final int leaves;
  final int leavesNeeded;

  /// Flowers bloomed so far (= level - 1).
  final int blooms;
  const GardenLevel(this.level, this.leaves, this.leavesNeeded, this.blooms);

  /// Steps still needed for the next bloom (1 when all leaves are there).
  int get stepsToBloom => leavesNeeded - leaves + 1;

  /// How many times each kind has bloomed, by index in [flowerKinds].
  List<int> get bloomCounts {
    final n = flowerKinds.length;
    return [for (var i = 0; i < n; i++) blooms ~/ n + (i < blooms % n ? 1 : 0)];
  }

  /// The kind of the most recent bloom, if any.
  FlowerKind? get newestFlower => blooms == 0 ? null : flowerKinds[(blooms - 1) % flowerKinds.length];

  @override
  bool operator ==(Object other) => other is GardenLevel && other.level == level && other.leaves == leaves;
  @override
  int get hashCode => Object.hash(level, leaves);
  @override
  String toString() => 'GardenLevel(level $level, leaves $leaves/$leavesNeeded)';
}

GardenLevel gardenFromSteps(int steps) {
  var level = 1, rest = steps < 0 ? 0 : steps;
  while (rest >= leavesForLevel(level) + 1) {
    rest -= leavesForLevel(level) + 1;
    level++;
  }
  return GardenLevel(level, rest, leavesForLevel(level), level - 1);
}

/// Steps and practice days from a whole history (used once, to bring existing
/// users in at the level their past sessions earned).
({int steps, int practiceDays, DateTime? lastDay, int stepsOnLastDay}) progressFromHistory(
  List<SessionRecord> records,
) {
  final sorted = [...records]..sort((a, b) => a.start.compareTo(b.start));
  final stepsByDay = <DateTime, int>{};
  final days = <DateTime>{};
  for (final r in sorted) {
    final d = dayOf(r.start);
    days.add(d);
    if (countsAsStep(r)) {
      final n = stepsByDay[d] ?? 0;
      if (n < maxStepsPerDay) stepsByDay[d] = n + 1;
    }
  }
  final steps = stepsByDay.values.fold(0, (a, b) => a + b);
  DateTime? last;
  for (final d in days) {
    if (last == null || d.isAfter(last)) last = d;
  }
  return (
    steps: steps,
    practiceDays: days.length,
    lastDay: last,
    stepsOnLastDay: last == null ? 0 : stepsByDay[last] ?? 0,
  );
}
