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

import '../friends/characters.dart';
import '../friends/characters.dart'
    as friends
    show unlockedCharacters, friendChoicePending, dueFriendCard, dueLaterFriends, isUnlocked;
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

  /// Step counts before and after the session (to save a pending bloom).
  final int stepsBefore, stepsAfter;
  const GrowthEvent({
    required this.before,
    required this.after,
    required this.grew,
    required this.dailyLimit,
    required this.newItems,
    this.stepsBefore = 0,
    this.stepsAfter = 0,
  });

  /// A saved bloom, read back after the app was closed.
  factory GrowthEvent.fromSteps(int before, int after) => GrowthEvent(
    before: gardenFromSteps(before),
    after: gardenFromSteps(after),
    grew: true,
    dailyLimit: false,
    newItems: const [],
    stepsBefore: before,
    stepsAfter: after,
  );

  bool get bloomed => after.blooms > before.blooms;
  FlowerKind? get newFlower => bloomed ? after.newestFlower : null;
}

class WardrobeController extends ChangeNotifier {
  static const _key = 'zeep.wardrobe';
  static const _version = 3;

  SharedPreferences? _prefs;

  int _steps = 0;

  /// Every day with at least one saved session (keys) and the steps counted
  /// on it (values, at most 3). One entry per practice day, never trimmed, so
  /// a session dated before or after the others (clock changes, time-zone
  /// trips) is still counted right.
  final Map<DateTime, int> _dayStepsMap = {};
  Outfit _outfit = Outfit.none;

  /// null = wear the newest flower, '' = no flower, else a FlowerKind id.
  String? _flowerChoice;
  final Set<OutfitItem> _seen = {};

  /// Unlocked by sessions but not shown on a card N yet. Kept here (not on
  /// the session) so "Again" before "Done" does not lose them.
  final List<OutfitItem> _pendingNew = [];

  /// The latest bloom not yet celebrated on card L.
  GrowthEvent? _pendingBloom;

  /// Existing users get one summary card the first time (decision 3).
  bool summaryPending = false;

  GardenLevel? _garden;
  SproutGrowth? _growth;

  // ---- Zeep and friends (1.7.0); saved in the same JSON
  Character _active = Character.zeep;
  Character? _day3Choice;
  bool _day3CardShown = false, _day10CardSeen = false;

  /// Day-30/60/100 friends whose "here" card was shown (1.8.0).
  final Set<Character> _laterCardsSeen = {};

  int get steps => _steps;
  int get practiceDays => _dayStepsMap.length;
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

  // ---------------------------------------------------------------- friends

  /// Miu or Lumi, picked on day 3; null = not picked yet.
  Character? get day3Choice => _day3Choice;

  /// Characters the user can breathe with now.
  Set<Character> get unlockedCharacters => friends.unlockedCharacters(practiceDays, _day3Choice);

  bool isCharacterUnlocked(Character c) => unlockedCharacters.contains(c);

  /// Who is drawn on the Breathe tab, in sessions and on share cards. Falls
  /// back to Zeep if the saved one is not unlocked (corrupt data).
  Character get activeCharacter {
    final a = _active;
    // cheap: read every frame
    return friends.isUnlocked(a, practiceDays, _day3Choice) ? a : Character.zeep;
  }

  /// Days 3-9 with no pick yet (picker row "choose a new friend").
  bool get friendChoicePending => friends.friendChoicePending(practiceDays, _day3Choice);

  /// The friend card due after this session, if any.
  FriendCard? get dueFriendCard => friends.dueFriendCard(
    days: practiceDays,
    choice: _day3Choice,
    day3CardShown: _day3CardShown,
    day10CardSeen: _day10CardSeen,
    laterSeen: _laterCardsSeen,
  );

  /// The day-30/60/100 friends for the [FriendCard.later] card, in order.
  List<Character> get dueLaterFriends => friends.dueLaterFriends(practiceDays, _laterCardsSeen);

  /// Switch to [c] (free, at once). Ignored if [c] is not unlocked.
  void selectCharacter(Character c) {
    if (!isCharacterUnlocked(c) || _active == c) return;
    _active = c;
    _changed();
  }

  /// The day-3 pick: [c] comes now and becomes the active character.
  void chooseFirstFriend(Character c) {
    if (!c.isDay3Friend || practiceDays < firstFriendDays) return;
    if (_day3Choice == null && practiceDays < secondFriendDays) _day3Choice = c;
    _day3CardShown = true;
    if (isCharacterUnlocked(c)) _active = c;
    _changed();
  }

  /// A friend card was shown (whatever the user tapped). For the
  /// [FriendCard.later] card, [shown] are the friends on it.
  void markFriendCardShown(FriendCard card, {Iterable<Character> shown = const []}) {
    if (card == FriendCard.later) {
      _laterCardsSeen.addAll(shown.where((c) => c.isLaterFriend));
    } else {
      _day3CardShown = true;
      if (card != FriendCard.day3) _day10CardSeen = true;
    }
    _changed();
  }

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
    _dayStepsMap
      ..clear()
      ..addAll({for (final d in h.days) d: h.stepsByDay[d] ?? 0});
    _garden = null;
    _growth = null;
    // items already earned are not "new" one by one: one summary card instead
    _seen
      ..clear()
      ..addAll(unlocked);
    summaryPending = _steps > 0 || _dayStepsMap.isNotEmpty;
  }

  /// Call after the history saved [r]. Returns what changed.
  GrowthEvent onSessionSaved(SessionRecord r) {
    final before = garden;
    final stepsBefore = _steps;
    final unlockedBefore = unlocked.toSet();
    final day = dayOf(r.start);
    _dayStepsMap.putIfAbsent(day, () => 0);
    var grew = false, limit = false;
    if (countsAsStep(r)) {
      final n = _dayStepsMap[day]!;
      if (n < maxStepsPerDay) {
        _dayStepsMap[day] = n + 1;
        _steps++;
        grew = true;
      } else {
        limit = true;
      }
    }
    final newItems = unlocked.where((i) => !unlockedBefore.contains(i)).toList();
    _pendingNew.addAll(newItems);
    if (grew) {
      _garden = null;
      _growth = null;
    }
    final e = GrowthEvent(
      before: before,
      after: garden,
      grew: grew,
      dailyLimit: limit,
      newItems: newItems,
      stepsBefore: stepsBefore,
      stepsAfter: _steps,
    );
    if (e.bloomed) _pendingBloom = e;
    // saved after the pending cards are set, so they survive closing the app
    _changed(grown: grew);
    return e;
  }

  /// The bloom for card L, if one has not been shown yet; clears it.
  GrowthEvent? takePendingBloom() {
    final e = _pendingBloom;
    if (e == null) return null;
    _pendingBloom = null;
    _save();
    return e;
  }

  /// Items for card N that have not been shown yet; clears the list.
  List<OutfitItem> takePendingNewItems() {
    final items = List.of(_pendingNew);
    if (items.isEmpty) return items;
    _pendingNew.clear();
    _save();
    return items;
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
    'days': {for (final e in _dayStepsMap.entries) _dayKey(e.key): e.value},
    'wear': [for (final i in _outfit.items) i.name],
    'flower': _flowerChoice,
    'seen': [for (final i in _seen) i.name],
    'summary': summaryPending,
    // cards L and N not shown yet (the app may close before "Done")
    'pendingNew': [for (final i in _pendingNew) i.name],
    if (_pendingBloom != null) 'pendingBloom': [_pendingBloom!.stepsBefore, _pendingBloom!.stepsAfter],
    // Zeep and friends (1.7.0); a 1.6.1 save has none of these
    'character': _active.name,
    if (_day3Choice != null) 'day3Choice': _day3Choice!.name,
    'day3CardShown': _day3CardShown,
    'day10CardSeen': _day10CardSeen,
    // 1.8.0: the day-30/60/100 cards shown; a 1.7.x save has none
    'laterCardsSeen': [
      for (final c in laterFriends)
        if (_laterCardsSeen.contains(c)) c.name,
    ],
  };

  void _fromJson(Map j) {
    _steps = (j['steps'] as num?)?.toInt() ?? 0;
    _dayStepsMap.clear();
    final days = j['days'];
    if (days is Map) {
      for (final e in days.entries) {
        final d = _parseDay(e.key), n = e.value;
        if (d != null && n is num) _dayStepsMap[d] = n.toInt().clamp(0, maxStepsPerDay);
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
    final pn = j['pendingNew'];
    _pendingNew
      ..clear()
      ..addAll([
        if (pn is List)
          for (final n in pn) ?OutfitItem.byName('$n'),
      ]);
    final pb = j['pendingBloom'];
    _pendingBloom = pb is List && pb.length == 2 && pb[0] is num && pb[1] is num
        ? GrowthEvent.fromSteps((pb[0] as num).toInt(), (pb[1] as num).toInt())
        : null;
    final active = Character.byName(j['character']);
    // (activeCharacter falls back to Zeep if this one is not unlocked)
    _active = active ?? Character.zeep;
    final choice = Character.byName(j['day3Choice']);
    _day3Choice = choice != null && choice.isDay3Friend ? choice : null;
    _day3CardShown = j['day3CardShown'] == true;
    _day10CardSeen = j['day10CardSeen'] == true;
    final later = j['laterCardsSeen'];
    _laterCardsSeen
      ..clear()
      ..addAll(
        [
          if (later is List)
            for (final n in later) ?Character.byName(n),
        ].where((c) => c.isLaterFriend),
      );
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
      while (_dayStepsMap.length < practiceDays) {
        _dayStepsMap.putIfAbsent(DateTime(2000, 1, 1 + i++), () => 0);
      }
    }
    _changed(grown: true);
  }
}
