import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/breathing/breathing_engine.dart';
import 'package:zeep_breathe/exercises/exercises.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/l10n/strings.dart';

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
    expect(exerciseFor(const BreathDurations(4, 0, 6, 0))?.id, 'belly');
    expect(exerciseFor(const BreathDurations(4, 7, 8, 0))?.id, '478');
    expect(exerciseFor(const BreathDurations(4, 4, 4, 4))?.id, 'box');
    expect(exerciseId(const BreathDurations(4, 2, 6, 0)), 'default');
    expect(exerciseId(const BreathDurations(9, 1, 4, 0)), 'custom');
    expect(exercises.map((e) => e.id).toSet().length, exercises.length);
    expect(exercises.firstWhere((e) => e.id == '478').pattern, '4 · 7 · 8');
    expect(exercises.firstWhere((e) => e.id == 'box').phases, Phase.values);
    expect(exercises.firstWhere((e) => e.id == 'belly').phases, [Phase.inhale, Phase.exhale]);
  });

  test('history names are localised; legacy English names are mapped', () {
    expect(exerciseDisplayName('478', S.thai), 'หายใจแบบ 4-7-8');
    expect(exerciseDisplayName('478', S.en), '4-7-8 breathing');
    expect(exerciseDisplayName('default', S.thai), 'ค่าเริ่มต้น');
    // saved before 1.2 as English names
    expect(exerciseDisplayName('Calm tide', S.thai), 'ค่าเริ่มต้น');
    expect(exerciseDisplayName('Box breathing', S.thai), 'หายใจสี่เหลี่ยม');
    expect(exerciseDisplayName('4-7-8 Sleep', S.thai), 'หายใจแบบ 4-7-8');
    expect(exerciseDisplayName('Custom', S.thai), 'กำหนดเอง');
    expect(exerciseDisplayName('Morning wake', S.en), 'Custom');
    expect(SessionRecord.fromJson({'t': '2026-11-01T08:00:00.000', 's': 60})!.exercise, 'custom');
    expect(S.thai.monthYear(DateTime(2026, 11)), 'พฤศจิกายน 2569');
  });

  test('durations show minutes and seconds', () {
    expect(S.en.duration(45), '45 s');
    expect(S.en.duration(60), '1 min');
    expect(S.en.duration(95), '1 min 35 s');
    expect(S.thai.duration(95), '1 นาที 35 วิ');
    expect(S.thai.duration(600), '10 นาที');
  });

  test('onDay returns only that day, earliest first', () {
    final h = SessionHistory();
    // ignore: invalid_use_of_visible_for_testing_member
    h.seed([
      rec(DateTime(2026, 11, 20, 21, 50), 600),
      rec(DateTime(2026, 11, 19, 23, 59), 120),
      rec(DateTime(2026, 11, 20, 7, 15), 300),
      rec(DateTime(2026, 11, 21, 0, 0), 60),
      rec(DateTime(2026, 11, 20, 12, 30), 95),
    ]);
    final day = h.onDay(DateTime(2026, 11, 20, 18));
    expect(day.map((r) => r.start.hour), [7, 12, 21]);
    expect(h.onDay(DateTime(2026, 11, 18)), isEmpty);
  });
}
