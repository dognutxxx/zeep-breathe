import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/breathing/breathing_engine.dart';
import 'package:zeep_breathe/exercises/exercises.dart';
import 'package:zeep_breathe/history/session_history.dart';

SessionRecord rec(DateTime t, int seconds) =>
    SessionRecord(start: t, seconds: seconds, breaths: 5, exercise: 'Calm tide', completed: true);

void main() {
  final now = DateTime(2026, 11, 20, 21, 0);

  test('empty history', () {
    final s = HistoryStats.from([], now);
    expect(s.currentStreak, 0);
    expect(s.longestStreak, 0);
    expect(s.totalMinutes, 0);
  });

  test('streak counts consecutive days ending today', () {
    final s = HistoryStats.from([
      rec(DateTime(2026, 11, 18, 8), 180),
      rec(DateTime(2026, 11, 19, 8), 180),
      rec(DateTime(2026, 11, 20, 8), 180),
    ], now);
    expect(s.currentStreak, 3);
    expect(s.longestStreak, 3);
    expect(s.totalMinutes, 9);
  });

  test('streak still alive if today not done yet', () {
    final s = HistoryStats.from([rec(DateTime(2026, 11, 18), 120), rec(DateTime(2026, 11, 19), 120)], now);
    expect(s.currentStreak, 2);
  });

  test('a missed day breaks the streak; longest is kept', () {
    final s = HistoryStats.from([
      rec(DateTime(2026, 11, 10), 120),
      rec(DateTime(2026, 11, 11), 120),
      rec(DateTime(2026, 11, 12), 120),
      rec(DateTime(2026, 11, 13), 120),
      rec(DateTime(2026, 11, 20), 120),
    ], now);
    expect(s.currentStreak, 1);
    expect(s.longestStreak, 4);
  });

  test('streak crosses a month boundary', () {
    final s = HistoryStats.from([
      rec(DateTime(2026, 10, 31), 120),
      rec(DateTime(2026, 11, 1), 120),
    ], DateTime(2026, 11, 1, 22));
    expect(s.currentStreak, 2);
  });

  test('days under 30 s do not count; same-day sessions add up', () {
    final s = HistoryStats.from([
      rec(DateTime(2026, 11, 19, 8), 20),
      rec(DateTime(2026, 11, 20, 8), 20),
      rec(DateTime(2026, 11, 20, 9), 20),
    ], now);
    expect(s.practisedOn(DateTime(2026, 11, 19)), isFalse);
    expect(s.practisedOn(DateTime(2026, 11, 20)), isTrue);
    expect(s.currentStreak, 1);
  });

  test('minutes in last 7 days', () {
    final s = HistoryStats.from([
      rec(DateTime(2026, 11, 13), 600), // 8 days ago: excluded
      rec(DateTime(2026, 11, 14), 120),
      rec(DateTime(2026, 11, 20), 180),
    ], now);
    expect(s.minutesThisWeek(now), 5);
  });

  test('record json round-trip', () {
    final r = rec(DateTime(2026, 11, 20, 7, 30), 185);
    final back = SessionRecord.fromJson(r.toJson())!;
    expect(back.start, r.start);
    expect(back.seconds, 185);
    expect(back.exercise, 'Calm tide');
    expect(SessionRecord.fromJson({'t': 'nonsense'}), isNull);
  });

  test('exercise matching', () {
    expect(exerciseFor(const BreathDurations(4, 2, 6, 0))?.id, 'calm');
    expect(exerciseFor(const BreathDurations(4, 4, 4, 4))?.id, 'box');
    expect(exerciseName(const BreathDurations(9, 1, 4, 0)), 'Custom');
    expect(exercises.map((e) => e.id).toSet().length, exercises.length);
    expect(exercises.firstWhere((e) => e.id == 'sleep').pattern, '4 · 7 · 8');
  });
}
