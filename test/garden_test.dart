import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';
import 'package:zeep_breathe/wardrobe/garden.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';
import 'package:zeep_breathe/wardrobe/wardrobe_controller.dart';

SessionRecord rec(DateTime t, {bool done = true, String ex = 'box'}) =>
    SessionRecord(start: t, seconds: 300, breaths: 20, exercise: ex, completed: done);

void main() {
  group('levels', () {
    test('level 1 needs 3 leaves, the 4th step blooms', () {
      expect(gardenFromSteps(0), const GardenLevel(1, 0, 3, 0));
      expect(gardenFromSteps(3), const GardenLevel(1, 3, 3, 0));
      expect(gardenFromSteps(3).stepsToBloom, 1);
      final g = gardenFromSteps(4);
      expect((g.level, g.leaves, g.blooms), (2, 0, 1));
      expect(g.newestFlower, flowerKinds[0]);
    });

    test('20 steps reach level 6, 45 reach 11, 105 reach 21', () {
      expect(gardenFromSteps(19).level, 5);
      expect(gardenFromSteps(20).level, 6);
      expect(gardenFromSteps(20).leavesNeeded, 4);
      expect(gardenFromSteps(45).level, 11);
      expect(gardenFromSteps(45).leavesNeeded, 5);
      expect(gardenFromSteps(105).level, 21);
    });

    test('after 20 kinds the flowers repeat and are counted', () {
      final g = gardenFromSteps(105 + 6 * 2); // 22 blooms
      expect(g.blooms, 22);
      expect(g.bloomCounts[0], 2);
      expect(g.bloomCounts[1], 2);
      expect(g.bloomCounts[2], 1);
      expect(g.newestFlower, flowerKinds[1]);
    });
  });

  group('history', () {
    test('only completed sessions grow, at most 3 a day; any saved session is a practice day', () {
      final d1 = DateTime(2026, 11, 1, 7);
      final d2 = DateTime(2026, 11, 3, 7);
      final h = progressFromHistory([
        for (var i = 0; i < 5; i++) rec(d1.add(Duration(hours: i))),
        rec(d2, done: false),
        rec(d2.add(const Duration(hours: 1)), ex: 'game-easy'),
      ]);
      expect(h.steps, 4); // 3 capped on day 1 + 1 game on day 2
      expect(h.practiceDays, 2);
      expect(h.lastDay, DateTime(2026, 11, 3));
      expect(h.stepsOnLastDay, 1);
    });
  });

  group('controller', () {
    late WardrobeController w;
    setUp(() {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      w = WardrobeController();
    });

    test('a new user starts at level 1 with nothing unlocked and no summary', () async {
      await w.load(const []);
      expect(w.garden.level, 1);
      expect(w.unlocked, isEmpty);
      expect(w.summaryPending, isFalse);
      expect(w.growth.isNone, isTrue);
    });

    test('existing users get their level and items at once, one summary, no N cards', () async {
      final start = DateTime(2026, 10, 1, 8);
      await w.load([for (var d = 0; d < 6; d++) rec(start.add(Duration(days: d)))]);
      expect(w.practiceDays, 6);
      expect(w.steps, 6);
      expect(w.garden.level, 2);
      expect(w.unlocked, [OutfitItem.sproutBow, OutfitItem.roundGlasses, OutfitItem.flowerCrown]);
      expect(w.unseen, isEmpty);
      expect(w.summaryPending, isTrue);
      w.dismissSummary();
      expect(w.summaryPending, isFalse);
    });

    test('sessions grow leaves, bloom, respect the daily limit and unlock items', () async {
      await w.load(const []);
      final day = DateTime(2026, 11, 20, 7);
      var e = w.onSessionSaved(rec(day));
      expect(e.grew, isTrue);
      expect(e.after.leaves, 1);
      expect(e.newItems, [OutfitItem.sproutBow]);
      w.onSessionSaved(rec(day.add(const Duration(hours: 1))));
      w.onSessionSaved(rec(day.add(const Duration(hours: 2))));
      e = w.onSessionSaved(rec(day.add(const Duration(hours: 3))));
      expect(e.grew, isFalse);
      expect(e.dailyLimit, isTrue);
      expect(w.garden.leaves, 3);
      e = w.onSessionSaved(rec(day.add(const Duration(days: 1))));
      expect(e.bloomed, isTrue);
      expect(e.newFlower, flowerKinds[0]);
      expect(w.garden.level, 2);
      expect(w.wornFlower, flowerKinds[0]);
      // a stopped session counts as a practice day but does not grow
      e = w.onSessionSaved(rec(day.add(const Duration(days: 2)), done: false));
      expect(e.grew, isFalse);
      expect(e.dailyLimit, isFalse);
      expect(w.practiceDays, 3);
      expect(e.newItems, [OutfitItem.roundGlasses]);
    });

    test('outfit and flower choice survive a restart; locked items cannot be worn', () async {
      await w.load(const []);
      w.setForTest(steps: 4 + 4, practiceDays: 7);
      w.toggle(OutfitItem.beanie);
      w.toggle(OutfitItem.butterfly); // needs 10 days: ignored
      w.chooseFlower(flowerKinds[0]);
      final again = WardrobeController();
      await again.load(const []);
      expect(again.outfit, Outfit.of([OutfitItem.beanie]));
      expect(again.wornFlower, flowerKinds[0]);
      again.chooseFlower(null);
      expect(again.wornFlower, isNull);
      expect(again.flowerOff, isTrue);
    });

    test('opening the wardrobe marks new items as seen', () async {
      await w.load(const []);
      w.onSessionSaved(rec(DateTime(2026, 11, 20, 7)));
      expect(w.unseen, [OutfitItem.sproutBow]);
      w.markAllSeen();
      expect(w.unseen, isEmpty);
      expect(w.daysLeft(OutfitItem.roundGlasses), 2);
    });
  });
}
