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

  SharedPreferences? _prefs;

  int _steps = 0;
  int _practiceDays = 0;
  DateTime? _lastDay;
  int _stepsOnLastDay = 0;
  Outfit _outfit = Outfit.none;

  /// null = wear the newest flower, '' = no flower, else a FlowerKind id.
  String? _flowerChoice;
  final Set<OutfitItem> _seen = {};

  /// Existing users get one summary card the first time (decision 3).
  bool summaryPending = false;

  int get steps => _steps;
  int get practiceDays => _practiceDays;
  GardenLevel get garden => gardenFromSteps(_steps);
  Outfit get outfit => _outfit;

  bool isUnlocked(OutfitItem i) => i.unlockDays <= _practiceDays;
  List<OutfitItem> get unlocked => OutfitItem.values.where(isUnlocked).toList();

  /// Practice days still needed for [i] (0 when unlocked).
  int daysLeft(OutfitItem i) => isUnlocked(i) ? 0 : i.unlockDays - _practiceDays;

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

  SproutGrowth get growth => SproutGrowth(leaves: garden.leaves, flower: wornFlower);

  /// Reads the saved state; the first time, starts from [history].
  Future<void> load(List<SessionRecord> history) async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        _fromJson(jsonDecode(raw));
        return;
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
    _practiceDays = h.practiceDays;
    _lastDay = h.lastDay;
    _stepsOnLastDay = h.stepsOnLastDay;
    // items already earned are not "new" one by one: one summary card instead
    _seen
      ..clear()
      ..addAll(unlocked);
    summaryPending = _steps > 0 || _practiceDays > 0;
  }

  /// Call after the history saved [r]. Returns what changed.
  GrowthEvent onSessionSaved(SessionRecord r) {
    final before = garden;
    final unlockedBefore = unlocked.toSet();
    final day = dayOf(r.start);
    final last = _lastDay;
    if (last == null || day.isAfter(last)) {
      _practiceDays++;
      _lastDay = day;
      _stepsOnLastDay = 0;
    }
    var grew = false, limit = false;
    if (countsAsStep(r)) {
      // sessions are saved in order, so a step always belongs to the latest day
      if (_stepsOnLastDay < maxStepsPerDay) {
        _stepsOnLastDay++;
        _steps++;
        grew = true;
      } else {
        limit = true;
      }
    }
    final newItems = unlocked.where((i) => !unlockedBefore.contains(i)).toList();
    _save();
    notifyListeners();
    return GrowthEvent(before: before, after: garden, grew: grew, dailyLimit: limit, newItems: newItems);
  }

  /// Tapping an item: wear it, swap within its slot, or take it off.
  void toggle(OutfitItem i) {
    if (!isUnlocked(i)) return;
    _outfit = _outfit.toggle(i);
    _save();
    notifyListeners();
  }

  /// Wear [i] (from the new-item card's "Try it on").
  void wear(OutfitItem i) {
    if (!isUnlocked(i) || _outfit.wears(i)) return;
    toggle(i);
  }

  void clearSlot(OutfitSlot s) {
    _outfit = _outfit.clear(s);
    _save();
    notifyListeners();
  }

  /// Picks the flower Zeep wears; null = no flower.
  void chooseFlower(FlowerKind? f) {
    _flowerChoice = f?.id ?? '';
    _save();
    notifyListeners();
  }

  /// The wardrobe was opened: every unlocked item has been seen.
  void markAllSeen() {
    if (unseen.isEmpty) return;
    _seen.addAll(unlocked);
    _save();
    notifyListeners();
  }

  void dismissSummary() {
    if (!summaryPending) return;
    summaryPending = false;
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- storage

  Map<String, Object?> _toJson() => {
    'v': 1,
    'steps': _steps,
    'days': _practiceDays,
    'last': _lastDay?.toIso8601String(),
    'lastSteps': _stepsOnLastDay,
    'wear': [for (final i in _outfit.items) i.name],
    'flower': _flowerChoice,
    'seen': [for (final i in _seen) i.name],
    'summary': summaryPending,
  };

  void _fromJson(Object? j) {
    if (j is! Map) throw const FormatException('wardrobe');
    _steps = (j['steps'] as num?)?.toInt() ?? 0;
    _practiceDays = (j['days'] as num?)?.toInt() ?? 0;
    _lastDay = DateTime.tryParse('${j['last']}');
    _stepsOnLastDay = (j['lastSteps'] as num?)?.toInt() ?? 0;
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
  }

  void _save() => _prefs?.setString(_key, jsonEncode(_toJson()));

  @visibleForTesting
  void setForTest({int? steps, int? practiceDays}) {
    if (steps != null) _steps = steps;
    if (practiceDays != null) _practiceDays = practiceDays;
    notifyListeners();
  }
}
