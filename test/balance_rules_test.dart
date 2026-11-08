import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/exercises/exercises.dart';
import 'package:zeep_breathe/game/balance_game.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/tilt/tilt_physics.dart';

void main() {
  group('circleFor', () {
    test('easy: big and centred, the same at any time', () {
      final a = circleFor(BalanceLevel.easy, halfW: 150, halfH: 250);
      final b = circleFor(BalanceLevel.easy, halfW: 150, halfH: 250, time: 30, breath: 1);
      expect(a.radius, closeTo(93, 0.01));
      expect(a.centre.x, 0);
      expect(b.radius, a.radius);
    });

    test('medium: grows with the breath, centred', () {
      final empty = circleFor(BalanceLevel.medium, halfW: 150, halfH: 250, breath: 0);
      final full = circleFor(BalanceLevel.medium, halfW: 150, halfH: 250, breath: 1);
      expect(full.radius, greaterThan(empty.radius * 1.8));
      expect(full.radius, lessThanOrEqualTo(circleFor(BalanceLevel.easy, halfW: 150, halfH: 250).radius));
      expect(full.centre.x, 0);
    });

    test('hard: small, moves slowly, never leaves the board', () {
      const hw = 150.0, hh = 250.0;
      final start = circleFor(BalanceLevel.hard, halfW: hw, halfH: hh);
      expect(start.radius, lessThan(circleFor(BalanceLevel.medium, halfW: hw, halfH: hh).radius));
      var moved = 0.0;
      for (var t = 0.0; t < 120; t += 0.25) {
        final c = circleFor(BalanceLevel.hard, halfW: hw, halfH: hh, time: t);
        expect(c.centre.x.abs() + c.radius, lessThanOrEqualTo(hw));
        expect(c.centre.y.abs() + c.radius, lessThanOrEqualTo(hh));
        final d = (c.centre - start.centre).length;
        if (d > moved) moved = d;
        final next = circleFor(BalanceLevel.hard, halfW: hw, halfH: hh, time: t + 0.25);
        expect((next.centre - c.centre).length, lessThan(15));
      }
      expect(moved, greaterThan(40));
    });

    test('contains uses the distance to the centre', () {
      const c = GameCircle(Vec2(10, 0), 5);
      expect(c.contains(const Vec2(14, 0)), isTrue);
      expect(c.contains(const Vec2(16, 0)), isFalse);
    });
  });

  test('score: share of time inside, rounded down', () {
    final s = BalanceScore();
    expect(s.percent, 0);
    s.add(0.949, true);
    s.add(0.051, false);
    expect(s.percent, 94);
    s.add(-1, false);
    expect(s.total, closeTo(1, 1e-9));
    s.reset();
    expect(s.percent, 0);
  });

  test('stars at 60 / 80 / 95 %', () {
    expect([0, 59, 60, 79, 80, 94, 95, 100].map(starsFor), [0, 0, 1, 1, 2, 2, 3, 3]);
  });

  test('edge haptics: out, in, and no burst while on the edge', () {
    final e = EdgeHaptics();
    expect(e.update(true, 0), isNull); // first frame only records
    expect(e.update(false, 1), EdgeEvent.left);
    expect(e.update(true, 1.1), isNull); // within 0.5 s
    expect(e.update(false, 1.2), isNull);
    expect(e.update(true, 1.6), EdgeEvent.entered);
    expect(e.update(true, 3), isNull); // no change, no pulse
    e.reset();
    expect(e.update(false, 3.1), isNull);
  });

  test('history ids and names for games', () {
    expect(gameHistoryId(BalanceLevel.medium), 'game-medium');
    expect(gameLevelOf('game-hard'), BalanceLevel.hard);
    expect(gameLevelOf('game-x'), isNull);
    expect(gameLevelOf('box'), isNull);
    expect(historyExerciseId('game-easy'), 'game-easy');
    expect(exerciseDisplayName('game-easy', S.en), 'Zeep Balance · Easy');
    expect(exerciseDisplayName('game-hard', S.thai), 'Zeep ทรงตัว · ยาก');
  });

  test('score survives a JSON round trip; old records have none', () {
    final r = SessionRecord(
      start: DateTime(2026, 11, 20, 8),
      seconds: 60,
      breaths: 0,
      exercise: 'game-easy',
      completed: true,
      score: 87,
    );
    expect(SessionRecord.fromJson(r.toJson())!.score, 87);
    expect(SessionRecord.fromJson({'t': '2026-11-20T08:00:00', 's': 60, 'e': 'box'})!.score, isNull);
    expect(
      SessionRecord(start: DateTime(2026), seconds: 1, breaths: 1, exercise: 'box', completed: true).toJson(),
      isNot(contains('p')),
    );
  });
}
