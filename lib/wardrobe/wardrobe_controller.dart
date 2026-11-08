// Wardrobe and flower-garden state (SYS.10): what is unlocked, what Zeep
// wears, and how far the sprout has grown. Saved on the device with
// shared_preferences under one key.
//
// Progress is kept as counters (not recomputed from the history) because the
// history keeps only the latest 2000 sessions; existing users are brought in
// once from their history when this first loads.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../history/session_history.dart';
import 'flowers.dart';
import 'garden.dart';
import 'outfits.dart';

/// What one saved session changed, for the finish screen (S.9) and the
/// new-item card (N).
class GrowthEvent {
  final GardenLevel before, after;

  /// True when the session counted (completed, under the daily limit).
  final bool grew;

  /// True when the session was completed but today already had 3 steps.
  final bool dailyLimit;
  final List<OutfitItem> newItems;
  const GrowthEvent({
    required this.before,
    required this.after,
    required this.grew,
    required this.dailyLimit,
    required this.newItems,
  });

  bool get bloomed => after.blooms > before.blooms;
  FlowerKind? get newFlower => bloomed ? after.newestFlower : null;
}

class WardrobeController extends ChangeNotifier {
  static const _key = 'zeep.wardrobe';
  static const _version = 2;

  /// Per-day step counts are kept for this many days back from the newest
  /// practice day (enough for clock changes and time-zone trips).
  static const _keepStepDays = 14;

  SharedPreferences? _prefs;

  int _steps = 0;

  /// Every day with at least one saved session. A set, so a session dated
  /// before the newest day (clock changed, travel) is still counted right.
  final Set<DateTime> _days = {};

  /// Steps counted per day, for the 3-a-day limit (recent days only).
  final Map<DateTime, int> _stepsByDay = {};
  Outfit _outfit = Outfit.none;

  /// null = wear the newest flower, '' = no flower, else a FlowerKind id.
  String? _flowerChoice;
  final Set<OutfitItem> _seen = {};

  /// Unlocked by sessions but not shown on a card N yet. Kept here (not on
  /// the session) so "Again" before "Done" does not lose them.
  final List<OutfitItem> _pendingNew = [];

  /// Existing users get one summary card the first time (decision 3).
  bool summaryPending = false;

  GardenLevel? _garden;
  SproutGrowth? _growth;

  int get steps => _steps;
  int get practiceDays => _days.length;
  GardenLevel get garden => _garden ??= gardenFromSteps(_steps);
  Outfit get outfit => _outfit;

  bool isUnlocked(OutfitItem i) => i.unlockDays <= practiceDays;
  List<OutfitItem> get unlocked => OutfitItem.values.where(isUnlocked).toList();

  /// Practice days still needed for [i] (0 when unlocked).
  int daysLeft(OutfitItem i) => isUnlocked(i) ? 0 : i.unlockDays - practiceDays;

  /// Unlocked items not yet looked at in the wardrobe (red dot on T1.9).
  List<OutfitItem> get unseen => unlocked.where((i) => !_seen.contains(i)).toList();

  /// Flower kinds bloomed at least once.
  List<FlowerKind> get bloomedKinds {
    final counts = garden.bloomCounts;
    return [
      for (var i = 0; i < flowerKinds.length; i++)
        if (counts[i] > 0) flowerKinds[i],
    ];
  }

  FlowerKind? get wornFlower {
    final c = _flowerChoice;
    if (c == null) return garden.newestFlower;
    if (c.isEmpty) return null;
    for (final f in bloomedKinds) {
      if (f.id == c) return f;
    }
    return garden.newestFlower;
  }

  /// "No flower" chosen explicitly.
  bool get flowerOff => _flowerChoice == '';

  /// What grows on the sprout now. Read every frame, so it is cached.
  SproutGrowth get growth => _growth ??= SproutGrowth(leaves: garden.leaves, flower: wornFlower);

  void _changed({bool grown = false}) {
    if (grown) {
      _garden = null;
      _growth = null;
    }
    _save();
    notifyListeners();
  }

  /// Reads the saved state; the first time, starts from [history].
  Future<void> load(List<SessionRecord> history) async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map && j['v'] == _version) {
          _fromJson(j);
          return;
        }
      }
    } catch (_) {
      // corrupt or unavailable storage: rebuild from the history below
    }
    migrate(history);
    _save();
  }

  /// Brings an existing user in at the level and items their history earned.
  @visibleForTesting
  void migrate(List<SessionRecord> history) {
    final h = progressFromHistory(history);
    _steps = h.steps;
    _days
      ..clear()
      ..addAll(h.days);
    _stepsByDay
      ..clear()
      ..addAll(h.stepsByDay);
    _prune();
    _garden = null;
    _growth = null;
    // items already earned are not "new" one by one: one summary card instead
    _seen
      ..clear()
      ..addAll(unlocked);
    summaryPending = _steps > 0 || _days.isNotEmpty;
  }

  /// Call after the history saved [r]. Returns what changed.
  GrowthEvent onSessionSaved(SessionRecord r) {
    final before = garden;
    final unlockedBefore = unlocked.toSet();
    final day = dayOf(r.start);
    _days.add(day);
    var grew = false, limit = false;
    if (countsAsStep(r)) {
      final n = _stepsByDay[day] ?? 0;
      if (n < maxStepsPerDay) {
        _stepsByDay[day] = n + 1;
        _steps++;
        grew = true;
      } else {
        limit = true;
      }
    }
    _prune();
    final newItems = unlocked.where((i) => !unlockedBefore.contains(i)).toList();
    _pendingNew.addAll(newItems);
    _changed(grown: grew);
    return GrowthEvent(before: before, after: garden, grew: grew, dailyLimit: limit, newItems: newItems);
  }

  /// Items for card N that have not been shown yet; clears the list.
  List<OutfitItem> takePendingNewItems() {
    final items = List.of(_pendingNew);
    _pendingNew.clear();
    return items;
  }

  void _prune() {
    if (_stepsByDay.isEmpty) return;
    final newest = _stepsByDay.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final oldest = DateTime(newest.year, newest.month, newest.day - _keepStepDays);
    _stepsByDay.removeWhere((d, _) => d.isBefore(oldest));
  }

  /// Tapping an item: wear it, swap within its slot, or take it off.
  void toggle(OutfitItem i) {
    if (!isUnlocked(i)) return;
    _outfit = _outfit.toggle(i);
    _changed();
  }

  /// Wear [i] (from the new-item card's "Try it on").
  void wear(OutfitItem i) {
    if (!isUnlocked(i) || _outfit.wears(i)) return;
    toggle(i);
  }

  void clearSlot(OutfitSlot s) {
    _outfit = _outfit.clear(s);
    _changed();
  }

  /// Picks the flower Zeep wears; null = no flower.
  void chooseFlower(FlowerKind? f) {
    _flowerChoice = f?.id ?? '';
    _changed(grown: true);
  }

  /// The wardrobe was opened: every unlocked item has been seen.
  void markAllSeen() {
    if (unseen.isEmpty) return;
    _seen.addAll(unlocked);
    _changed();
  }

  void dismissSummary() {
    if (!summaryPending) return;
    summaryPending = false;
    _changed();
  }

  // ---------------------------------------------------------------- storage

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static DateTime? _parseDay(Object? s) {
    final p = '$s'.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    return (y == null || m == null || d == null) ? null : DateTime(y, m, d);
  }

  Map<String, Object?> _toJson() => {
    'v': _version,
    'steps': _steps,
    'days': [for (final d in _days) _dayKey(d)],
    'daySteps': {for (final e in _stepsByDay.entries) _dayKey(e.key): e.value},
    'wear': [for (final i in _outfit.items) i.name],
    'flower': _flowerChoice,
    'seen': [for (final i in _seen) i.name],
    'summary': summaryPending,
  };

  void _fromJson(Map j) {
    _steps = (j['steps'] as num?)?.toInt() ?? 0;
    final days = j['days'];
    _days
      ..clear()
      ..addAll([
        if (days is List)
          for (final s in days) ?_parseDay(s),
      ]);
    _stepsByDay.clear();
    final ds = j['daySteps'];
    if (ds is Map) {
      for (final e in ds.entries) {
        final d = _parseDay(e.key), n = e.value;
        if (d != null && n is num) _stepsByDay[d] = n.toInt();
      }
    }
    final wear = j['wear'];
    _outfit = Outfit.of(
      [
        if (wear is List)
          for (final n in wear) ?OutfitItem.byName('$n'),
      ].where(isUnlocked),
    );
    final f = j['flower'];
    _flowerChoice = f is String ? f : null;
    final seen = j['seen'];
    _seen
      ..clear()
      ..addAll([
        if (seen is List)
          for (final n in seen) ?OutfitItem.byName('$n'),
      ]);
    summaryPending = j['summary'] == true;
    _garden = null;
    _growth = null;
  }

  void _save() => _prefs?.setString(_key, jsonEncode(_toJson()));

  /// Sets the step count and pads the practice days with days long ago.
  @visibleForTesting
  void setForTest({int? steps, int? practiceDays}) {
    if (steps != null) _steps = steps;
    if (practiceDays != null) {
      var i = 0;
      while (_days.length < practiceDays) {
        _days.add(DateTime(2000, 1, 1 + i++));
      }
    }
    _changed(grown: true);
  }
}
