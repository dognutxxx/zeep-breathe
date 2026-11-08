// Session log, streaks and stats. Stored on the device with
// shared_preferences (no account, no server).

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionRecord {
  final DateTime start;
  final int seconds;
  final int breaths;
  final String exercise; // display name, e.g. "Calm tide" or "Custom"
  final bool completed;

  const SessionRecord({
    required this.start,
    required this.seconds,
    required this.breaths,
    required this.exercise,
    required this.completed,
  });

  Map<String, Object> toJson() => {
    't': start.toIso8601String(),
    's': seconds,
    'b': breaths,
    'e': exercise,
    'c': completed,
  };

  static SessionRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = DateTime.tryParse('${j['t']}');
    if (t == null) return null;
    return SessionRecord(
      start: t,
      seconds: (j['s'] as num?)?.toInt() ?? 0,
      breaths: (j['b'] as num?)?.toInt() ?? 0,
      exercise: '${j['e'] ?? 'custom'}',
      completed: j['c'] == true,
    );
  }
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Pure stats over a list of records, so they can be unit-tested.
class HistoryStats {
  final Map<DateTime, int> secondsByDay;
  final int currentStreak, longestStreak, totalSeconds, sessions;

  HistoryStats._(this.secondsByDay, this.currentStreak, this.longestStreak, this.totalSeconds, this.sessions);

  /// A day counts toward a streak once it has at least [minSecondsPerDay].
  factory HistoryStats.from(List<SessionRecord> records, DateTime now, {int minSecondsPerDay = 30}) {
    final byDay = <DateTime, int>{};
    var total = 0;
    for (final r in records) {
      final d = dayOf(r.start);
      byDay[d] = (byDay[d] ?? 0) + r.seconds;
      total += r.seconds;
    }
    final active = byDay.entries.where((e) => e.value >= minSecondsPerDay).map((e) => e.key).toSet();

    // current streak: ends today, or yesterday if today has no session yet
    final today = dayOf(now);
    var cursor = active.contains(today) ? today : today.subtract(const Duration(days: 1));
    var current = 0;
    while (active.contains(cursor)) {
      current++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    // longest streak
    final days = active.toList()..sort();
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d) ? run + 1 : 1;
      longest = math.max(longest, run);
      prev = d;
    }
    return HistoryStats._(byDay, current, longest, total, records.length);
  }

  int get totalMinutes => (totalSeconds / 60).round();

  bool practisedOn(DateTime day, {int minSeconds = 30}) => (secondsByDay[dayOf(day)] ?? 0) >= minSeconds;

  /// Minutes in the 7 days ending today.
  int minutesThisWeek(DateTime now) {
    final today = dayOf(now);
    var s = 0;
    for (var i = 0; i < 7; i++) {
      s += secondsByDay[DateTime(today.year, today.month, today.day - i)] ?? 0;
    }
    return (s / 60).round();
  }
}

class SessionHistory extends ChangeNotifier {
  static const _key = 'zeep.history';
  static const _maxRecords = 2000;

  SharedPreferences? _prefs;
  final List<SessionRecord> records = [];
  HistoryStats? _stats;
  DateTime? _statsDay;

  /// Shortest session worth logging (stopped sessions under this are ignored).
  static const minLoggedSeconds = 30;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          records
            ..clear()
            ..addAll(list.map(SessionRecord.fromJson).whereType<SessionRecord>());
        }
      }
    } catch (_) {
      // corrupt or unavailable storage: start empty
    }
  }

  HistoryStats stats(DateTime now) {
    final day = dayOf(now);
    if (_stats == null || _statsDay != day) {
      _stats = HistoryStats.from(records, now);
      _statsDay = day;
    }
    return _stats!;
  }

  /// Sessions that started on [day], earliest first.
  List<SessionRecord> onDay(DateTime day) {
    final d = dayOf(day);
    return records.where((r) => dayOf(r.start) == d).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  void add(SessionRecord r) {
    if (r.seconds < minLoggedSeconds) return;
    records.add(r);
    if (records.length > _maxRecords) records.removeRange(0, records.length - _maxRecords);
    _stats = null;
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(records.map((e) => e.toJson()).toList()));
  }

  @visibleForTesting
  void seed(List<SessionRecord> rs) {
    records
      ..clear()
      ..addAll(rs);
    _stats = null;
  }
}
