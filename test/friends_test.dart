// Zeep and friends (1.7.0; the day-30/60/100 friends 1.8.0): unlock rules,
// the friend card that is due, and the saved state (with 1.6.1 and 1.7.x
// saves loading as before).

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/wardrobe/wardrobe_controller.dart';

const _miu = Character.miu, _lumi = Character.lumi, _zeep = Character.zeep;
const _mun = Character.mun, _tuntun = Character.tuntun, _nuan = Character.nuan;

/// What 1.7.1 saved: [save161] plus the friend keys of 1.7.0.
Map<String, Object?> save171(
  int days, {
  String character = 'zeep',
  String? choice,
  bool shown3 = false,
  bool seen10 = false,
}) => {
  ...save161(days),
  'character': character,
  'day3Choice': ?choice,
  'day3CardShown': shown3,
  'day10CardSeen': seen10,
};

/// What 1.6.1 saved under `zeep.wardrobe` (no friend keys at all).
Map<String, Object?> save161(int days) => {
  'v': 3,
  'steps': days,
  'days': {for (var i = 0; i < days; i++) '2026-10-${i + 1}': 1},
  'wear': ['sproutBow'],
  'flower': null,
  'seen': ['sproutBow'],
  'summary': false,
  'pendingNew': [],
};

Future<WardrobeController> loadFrom(Map<String, Object?> json) async {
  SharedPreferences.setMockInitialValues({'zeep.wardrobe': jsonEncode(json)});
  final w = WardrobeController();
  await w.load(const []);
  return w;
}

Future<Map<String, Object?>> saved() async {
  final p = await SharedPreferences.getInstance();
  return jsonDecode(p.getString('zeep.wardrobe')!) as Map<String, Object?>;
}

void main() {
  group('unlock rules (B1, B2, B4)', () {
    test('Zeep only before day 3, whatever was chosen', () {
      for (final d in [0, 1, 2]) {
        expect(unlockedCharacters(d, null), {_zeep});
        expect(unlockedCharacters(d, _miu), {_zeep});
        expect(friendChoicePending(d, null), isFalse);
      }
    });

    test('days 3-9: a pick is pending until made, then only the pick comes', () {
      for (var d = 3; d <= 9; d++) {
        expect(unlockedCharacters(d, null), {_zeep}, reason: 'day $d');
        expect(friendChoicePending(d, null), isTrue);
        expect(unlockedCharacters(d, _miu), {_zeep, _miu});
        expect(unlockedCharacters(d, _lumi), {_zeep, _lumi});
        expect(friendChoicePending(d, _lumi), isFalse);
      }
    });

    test('day 10 and up: both Miu and Lumi, with or without a pick', () {
      for (final d in [10, 11, 29]) {
        for (final c in [null, _miu, _lumi]) {
          expect(unlockedCharacters(d, c), {_zeep, _miu, _lumi}, reason: 'day $d, pick $c');
        }
        expect(friendChoicePending(d, null), isFalse);
      }
    });

    test('Mun at 30 days, Tuntun at 60, Nuan at 100, whatever the day-3 pick (1.8.0 #4)', () {
      expect(laterFriends, [_mun, _tuntun, _nuan]);
      expect([for (final c in laterFriends) c.days], [30, 60, 100]);
      for (final c in [null, _miu, _lumi]) {
        expect(unlockedCharacters(29, c), {_zeep, _miu, _lumi});
        expect(unlockedCharacters(30, c), {_zeep, _miu, _lumi, _mun});
        expect(unlockedCharacters(59, c), {_zeep, _miu, _lumi, _mun});
        expect(unlockedCharacters(60, c), {_zeep, _miu, _lumi, _mun, _tuntun});
        expect(unlockedCharacters(99, c), {_zeep, _miu, _lumi, _mun, _tuntun});
        expect(unlockedCharacters(100, c), Character.values.toSet());
        expect(unlockedCharacters(1000, c), Character.values.toSet());
      }
      for (final c in laterFriends) {
        expect(c.isLaterFriend, isTrue);
        expect(c.isDay3Friend, isFalse);
        expect(isUnlocked(c, c.days - 1, _miu), isFalse);
        expect(isUnlocked(c, c.days, null), isTrue);
      }
    });

    test('more days never lock anyone again', () {
      for (final c in [null, _miu, _lumi]) {
        var before = unlockedCharacters(0, c);
        for (var d = 1; d <= 120; d++) {
          final now = unlockedCharacters(d, c);
          expect(now.containsAll(before), isTrue, reason: 'day $d, pick $c');
          before = now;
        }
      }
    });
  });

  group('friend card due (D1, D2)', () {
    FriendCard? due(int d, Character? c, {bool shown3 = false, bool seen10 = false, Set<Character> later = const {}}) =>
        dueFriendCard(days: d, choice: c, day3CardShown: shown3, day10CardSeen: seen10, laterSeen: later);

    test('day 3 card once, only while a pick is pending', () {
      expect(due(2, null), isNull);
      expect(due(3, null), FriendCard.day3);
      expect(due(9, null), FriendCard.day3);
      expect(due(5, null, shown3: true), isNull);
      expect(due(5, _miu), isNull);
    });

    test('day 10: the other friend, or both when nobody was picked', () {
      expect(due(10, _miu), FriendCard.day10);
      expect(due(10, _miu, shown3: true), FriendCard.day10);
      expect(due(10, null), FriendCard.both);
      expect(due(25, null, shown3: true), FriendCard.both);
      expect(due(10, _lumi, seen10: true), isNull);
      expect(due(29, null, shown3: true, seen10: true), isNull);
    });

    test('day 30 / 60 / 100: one card each, once (1.8.0 #5)', () {
      expect(due(30, _miu, shown3: true, seen10: true), FriendCard.later);
      expect(dueLaterFriends(30, {}), [_mun]);
      expect(due(30, _miu, shown3: true, seen10: true, later: {_mun}), isNull);
      expect(due(60, _miu, shown3: true, seen10: true, later: {_mun}), FriendCard.later);
      expect(dueLaterFriends(60, {_mun}), [_tuntun]);
      expect(due(99, _miu, shown3: true, seen10: true, later: {_mun, _tuntun}), isNull);
      expect(dueLaterFriends(100, {_mun, _tuntun}), [_nuan]);
      expect(due(500, _miu, shown3: true, seen10: true, later: {_mun, _tuntun, _nuan}), isNull);
    });

    test('several due at once: one card with all of them (1.8.0 #5)', () {
      expect(dueLaterFriends(65, {}), [_mun, _tuntun]);
      expect(dueLaterFriends(120, {}), [_mun, _tuntun, _nuan]);
      expect(dueLaterFriends(120, {_tuntun}), [_mun, _nuan]);
    });

    test('the Miu and Lumi cards come first; the 30/60/100 card waits a session end (1.8.0 #5)', () {
      // 35 days, no day-3 pick: "two new friends" first, Mun at the next session end
      expect(due(35, null), FriendCard.both);
      expect(due(35, null, shown3: true, seen10: true), FriendCard.later);
      // 65 days with Miu picked and the day-10 card not seen yet
      expect(due(65, _miu, shown3: true), FriendCard.day10);
      expect(due(65, _miu, shown3: true, seen10: true), FriendCard.later);
    });
  });

  group('controller and saved data (B3, F1-F3)', () {
    test('a 1.6.1 save loads with Zeep active and no pick (F2)', () async {
      final w = await loadFrom(save161(2));
      expect(w.practiceDays, 2);
      expect(w.activeCharacter, _zeep);
      expect(w.day3Choice, isNull);
      expect(w.unlockedCharacters, {_zeep});
      expect(w.dueFriendCard, isNull);
      // everything else is still there
      expect(w.outfit.items.map((i) => i.name), ['sproutBow']);
      expect(w.steps, 2);
    });

    test('existing users with 3+ or 10+ days get it right after the update (B3)', () async {
      final w5 = await loadFrom(save161(5));
      expect(w5.friendChoicePending, isTrue);
      expect(w5.dueFriendCard, FriendCard.day3);
      expect(w5.unlockedCharacters, {_zeep});

      final w12 = await loadFrom(save161(12));
      expect(w12.unlockedCharacters, {_zeep, _miu, _lumi});
      expect(w12.dueFriendCard, FriendCard.both);
      expect(w12.friendChoicePending, isFalse);
    });

    test('pick, switch and reload: everything round-trips (F1)', () async {
      final w = await loadFrom(save161(4));
      w.chooseFirstFriend(_lumi);
      expect(w.day3Choice, _lumi);
      expect(w.activeCharacter, _lumi);
      expect(w.unlockedCharacters, {_zeep, _lumi});
      // Miu is not here yet: switching to her does nothing
      w.selectCharacter(_miu);
      expect(w.activeCharacter, _lumi);
      w.selectCharacter(_zeep);
      expect(w.activeCharacter, _zeep);
      w.selectCharacter(_lumi);
      w.markFriendCardShown(FriendCard.day3);

      final j = await saved();
      expect(j['v'], 3);
      expect(j['character'], 'lumi');
      expect(j['day3Choice'], 'lumi');
      expect(j['day3CardShown'], true);
      expect(j['day10CardSeen'], false);

      final again = await loadFrom(j);
      expect(again.activeCharacter, _lumi);
      expect(again.day3Choice, _lumi);
      expect(again.dueFriendCard, isNull);
      expect(again.practiceDays, 4);
    });

    test('day 10 card seen is saved', () async {
      final w = await loadFrom({...save161(11), 'day3Choice': 'miu', 'character': 'miu', 'day3CardShown': true});
      expect(w.dueFriendCard, FriendCard.day10);
      w.markFriendCardShown(FriendCard.day10);
      final again = await loadFrom(await saved());
      expect(again.dueFriendCard, isNull);
      expect(again.activeCharacter, _miu);
    });

    test('a saved character that is not unlocked falls back to Zeep (F3)', () async {
      for (final (days, json) in [
        (2, {'character': 'lumi', 'day3Choice': 'lumi'}), // too few days
        (5, {'character': 'miu', 'day3Choice': 'lumi'}), // not the pick
        (5, {'character': 'miu'}), // no pick
        (40, {'character': 'friend30'}), // a 1.7.0 placeholder name: unknown now
        (29, {'character': 'mun'}), // one day short
        (65, {'character': 'nuan'}), // Nuan comes at 100
        (
          99,
          {
            'character': 'nuan',
            'laterCardsSeen': ['nuan'],
          },
        ), // a seen flag unlocks nothing
        (40, {'character': 'dragon'}), // unknown
        (40, {'character': 7, 'day3Choice': 'zeep'}), // wrong types
      ]) {
        final w = await loadFrom({...save161(days), ...json});
        expect(w.activeCharacter, _zeep, reason: '$json at $days days');
      }
      // a bad pick is dropped, so it is still pending
      final w = await loadFrom({...save161(5), 'day3Choice': 'zeep'});
      expect(w.day3Choice, isNull);
      expect(w.friendChoicePending, isTrue);
    });

    test('the day-3 pick is ignored before day 3 or for non-friends', () async {
      final w = await loadFrom(save161(2));
      w.chooseFirstFriend(_miu);
      expect(w.day3Choice, isNull);
      expect(w.activeCharacter, _zeep);
      w.setForTest(practiceDays: 3);
      w.chooseFirstFriend(Character.mun);
      expect(w.day3Choice, isNull);
      w.chooseFirstFriend(_miu);
      expect(w.day3Choice, _miu);
      expect(w.activeCharacter, _miu);
      // the pick is made once
      w.chooseFirstFriend(_lumi);
      expect(w.day3Choice, _miu);
    });

    test('a 1.7.1 save loads as it was and gets the day-30/60/100 friends it earned (1.8.0 #6)', () async {
      final w = await loadFrom(save171(65, character: 'lumi', choice: 'miu', shown3: true, seen10: true));
      expect(w.activeCharacter, _lumi);
      expect(w.day3Choice, _miu);
      expect(w.unlockedCharacters, {_zeep, _miu, _lumi, _mun, _tuntun});
      // one card with both new friends
      expect(w.dueFriendCard, FriendCard.later);
      expect(w.dueLaterFriends, [_mun, _tuntun]);
      expect(w.outfit.items.map((i) => i.name), ['sproutBow']);
      expect(w.steps, 65);
      // nothing changes on save but the new key
      w.markFriendCardShown(FriendCard.later, shown: w.dueLaterFriends);
      final j = await saved();
      expect(j['laterCardsSeen'], ['mun', 'tuntun']);
      expect(j['character'], 'lumi');
      expect(j['day3Choice'], 'miu');
      expect(j['day3CardShown'], true);
      expect(j['day10CardSeen'], true);
      expect(j['v'], 3);

      final again = await loadFrom(j);
      expect(again.dueFriendCard, isNull);
      expect(again.activeCharacter, _lumi);
      // day 100 later: only Nuan is new
      again.setForTest(practiceDays: 100);
      expect(again.dueFriendCard, FriendCard.later);
      expect(again.dueLaterFriends, [_nuan]);
    });

    test('switching to a day-30/60/100 friend is saved; seen flags ignore bad entries (1.8.0 #6)', () async {
      final w = await loadFrom({
        ...save171(100, choice: 'lumi', shown3: true, seen10: true),
        'laterCardsSeen': ['nuan', 'miu', 7, 'dragon'],
      });
      expect(w.dueLaterFriends, [_mun, _tuntun]);
      w.selectCharacter(_nuan);
      expect(w.activeCharacter, _nuan);
      final again = await loadFrom(await saved());
      expect(again.activeCharacter, _nuan);
      expect((await saved())['laterCardsSeen'], ['nuan']);
      // marking a later card with Miu on it changes nothing for Miu
      again.markFriendCardShown(FriendCard.later, shown: const [_miu, _mun]);
      expect(again.dueLaterFriends, [_tuntun]);
      expect(again.dueFriendCard, FriendCard.later);
    });

    test('practice days only go up: a gap of missed days keeps friends (B4)', () async {
      final w = WardrobeController();
      w.setForTest(practiceDays: 4);
      w.chooseFirstFriend(_miu);
      // weeks without practice: nothing is counted down
      expect(w.activeCharacter, _miu);
      w.setForTest(practiceDays: 10);
      expect(w.unlockedCharacters, {_zeep, _miu, _lumi});
      expect(w.activeCharacter, _miu);
    });
  });
}
