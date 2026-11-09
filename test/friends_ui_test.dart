// "My friends" picker (C), the new-friend cards (D) and where the active
// character shows (E), 1.7.0.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/friend_cards.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/share/share_card.dart';
import 'package:zeep_breathe/ui/friends/friend_painter.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

const s = S.en;

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

Future<AppController> makeApp({int days = 0}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  final app = AppController(settings: settings, haptics: HapticsService(), music: QuietMusic()..available = true)
    ..clock = () => DateTime(2026, 11, 20, 9);
  await app.wardrobe.load(const []); // saves to the (mock) device from now on
  if (days > 0) app.wardrobe.setForTest(practiceDays: days);
  app.wardrobe.markAllSeen();
  return app;
}

Future<void> frames(WidgetTester t, AppController app, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    app.tick(0.016);
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> launch(WidgetTester t, AppController app) async {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(ZeepBreatheApp(controller: app));
  await frames(t, app, 5);
}

Future<void> openPicker(WidgetTester t, AppController app) async {
  await t.tap(find.text(s.friendsChip));
  await frames(t, app);
  expect(find.text(s.friendsTitle), findsOneWidget);
}

/// The semantics label of the picker row whose label starts with [start].
Finder row(String start) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label != null && w.properties.label!.startsWith(start),
);

String? label(WidgetTester t, String start) => t.widget<Semantics>(row(start).first).properties.label;

Future<void> finishSession(WidgetTester t, AppController app) async {
  app.startSession();
  await frames(t, app, 3);
  app.engine.sessionElapsed = 40; // long enough to be saved
  await frames(t, app, 3);
  await t.tap(find.byTooltip(s.stop));
  await frames(t, app, 40);
}

Future<void> tapText(WidgetTester t, AppController app, String text) async {
  await t.tap(find.text(text).last);
  await frames(t, app);
}

void main() {
  testWidgets('T1: the "Friends" chip and the character both open the picker (C1)', (t) async {
    final app = await makeApp();
    await launch(t, app);
    expect(find.bySemanticsLabel(s.openFriends), findsOneWidget);
    await t.tap(find.bySemanticsLabel(s.openFriends));
    await frames(t, app);
    expect(find.text(s.friendsTitle), findsOneWidget);
    Navigator.of(t.element(find.text(s.friendsTitle))).pop();
    await frames(t, app);
    await openPicker(t, app);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('picker with Zeep only: Miu or Lumi in 3 days, three mystery friends (C2)', (t) async {
    final app = await makeApp();
    await launch(t, app);
    await openPicker(t, app);
    expect(label(t, 'Zeep'), 'Zeep, ${s.characterTagline(Character.zeep)}, ${s.inUse}');
    expect(label(t, s.miuOrLumi), '${s.miuOrLumi}, ${s.chooseNewFriend}, ${s.friendIn(3)}');
    for (final n in [30, 60, 100]) {
      expect(find.text(s.mysteryWhen(n)), findsOneWidget);
    }
    expect(find.text(s.mysteryFriend), findsNWidgets(3));
    expect(find.text(s.practiceDays(0)), findsOneWidget);
    // no level or bond bar anywhere
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('day 6, Miu picked: Miu in use, Lumi greyed for 4 more days (C2)', (t) async {
    final app = await makeApp(days: 6);
    app.wardrobe.chooseFirstFriend(Character.miu);
    await launch(t, app);
    await openPicker(t, app);
    expect(label(t, 'Miu'), 'Miu, ${s.characterTagline(Character.miu)}, ${s.inUse}');
    expect(label(t, 'Zeep'), endsWith(s.tapToSwitch));
    expect(label(t, 'Lumi'), endsWith(s.friendIn(4)));
    // Lumi is not here yet: tapping does nothing
    await t.tap(row('Lumi').first);
    await frames(t, app);
    expect(app.wardrobe.activeCharacter, Character.miu);
    // switching back to Zeep is free and immediate (C3)
    await t.tap(row('Zeep').first);
    await frames(t, app);
    expect(app.wardrobe.activeCharacter, Character.zeep);
    expect(find.text(s.friendsTitle), findsNothing); // the sheet closed
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('day 12: all three can be picked; the switch is saved (C2, C3)', (t) async {
    final app = await makeApp(days: 12);
    await launch(t, app);
    await openPicker(t, app);
    for (final n in ['Miu', 'Lumi']) {
      expect(label(t, n), endsWith(s.tapToSwitch));
    }
    await t.tap(row('Lumi').first);
    await frames(t, app);
    expect(app.wardrobe.activeCharacter, Character.lumi);
    // T1 now draws Lumi, and Lumi greets
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FriendPainter), findsWidgets);
    expect(find.text(s.greetingOf(Character.lumi)), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zeep.wardrobe'), contains('"character":"lumi"'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a mystery friend whose day has come is "on the way" (C2)', (t) async {
    final app = await makeApp(days: 35);
    await launch(t, app);
    await openPicker(t, app);
    expect(find.text(s.mysteryOnTheWay), findsOneWidget);
    expect(find.text(s.mysteryWhen(60)), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('day 5, no pick: the "choose" row opens the day-3 card; picking Lumi (C2, D1)', (t) async {
    final app = await makeApp(days: 5);
    await launch(t, app);
    expect(find.bySemanticsLabel('${s.friendsTitle}, ${s.chooseNewFriend}'), findsOneWidget); // dot on the chip
    await openPicker(t, app);
    await t.tap(row(s.chooseNewFriend).first);
    await frames(t, app);
    expect(find.text(s.newFriendTitle), findsWidgets);
    expect(find.text(s.otherFriendLater), findsOneWidget);
    expect(find.text(s.chooseFriend('Miu')), findsOneWidget);
    // the tiles: Miu selected first
    expect(find.bySemanticsLabel('Miu, ${s.characterTagline(Character.miu)}, ${s.selectedLabel}'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Lumi, ${s.characterTagline(Character.lumi)}'));
    await frames(t, app);
    expect(find.text(s.chooseFriend('Lumi')), findsOneWidget);
    await tapText(t, app, s.chooseFriend('Lumi'));
    expect(app.wardrobe.day3Choice, Character.lumi);
    expect(app.wardrobe.activeCharacter, Character.lumi);
    expect(app.wardrobe.dueFriendCard, isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('reaching day 3: card N first, then the day-3 card once; "Later" picks nobody (D1, D3)', (t) async {
    final app = await makeApp(days: 2);
    await launch(t, app);
    await finishSession(t, app);
    expect(app.wardrobe.practiceDays, 3);
    expect(find.text(s.newItemTitle), findsOneWidget); // the existing card comes first
    expect(find.text(s.newFriendTitle), findsNothing);
    await tapText(t, app, s.later);
    expect(find.text(s.newItemTitle), findsNothing);
    expect(find.text(s.newFriendTitle), findsOneWidget);
    await tapText(t, app, s.later);
    expect(find.text(s.newFriendTitle), findsNothing);
    expect(app.wardrobe.day3Choice, isNull);
    expect(app.wardrobe.activeCharacter, Character.zeep);
    expect(app.wardrobe.friendChoicePending, isTrue); // can still pick in the picker
    // the next session end shows no friend card again
    await finishSession(t, app);
    expect(find.byType(FriendCardDialog), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('"Try it on" on card N goes to the wardrobe; the friend card waits', (t) async {
    final app = await makeApp(days: 2);
    await launch(t, app);
    await finishSession(t, app);
    await tapText(t, app, s.tryItOn);
    expect(find.byType(FriendCardDialog), findsNothing);
    expect(app.wardrobe.dueFriendCard, FriendCard.day3);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('day 10 with Miu picked: "Lumi is here", "Breathe with Lumi" switches (D2)', (t) async {
    final app = await makeApp(days: 9);
    app.wardrobe.chooseFirstFriend(Character.miu);
    await launch(t, app);
    await finishSession(t, app);
    expect(app.wardrobe.practiceDays, 10);
    // items unlocked on day 10 come first
    while (find.text(s.newItemTitle).evaluate().isNotEmpty) {
      await tapText(t, app, s.later);
    }
    expect(find.text(s.friendArrived('Lumi')), findsOneWidget);
    expect(find.byType(LiveFriend), findsOneWidget);
    await tapText(t, app, s.breatheWith('Lumi'));
    expect(app.wardrobe.activeCharacter, Character.lumi);
    expect(app.wardrobe.dueFriendCard, isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('day 10 without a pick: one "two new friends" card, not two cards (D2, D3)', (t) async {
    final app = await makeApp(days: 12);
    await launch(t, app);
    await finishSession(t, app);
    while (find.text(s.newItemTitle).evaluate().isNotEmpty) {
      await tapText(t, app, s.later);
    }
    expect(find.text(s.twoFriendsTitle), findsOneWidget);
    expect(find.byType(LiveFriend), findsNWidgets(2));
    await tapText(t, app, s.later);
    expect(find.byType(FriendCardDialog), findsNothing);
    expect(app.wardrobe.activeCharacter, Character.zeep);
    expect(app.wardrobe.dueFriendCard, isNull); // no day-3 card afterwards either
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the session screen draws the active friend (E1)', (t) async {
    final app = await makeApp(days: 12);
    app.wardrobe.selectCharacter(Character.miu);
    await launch(t, app);
    app.startSession();
    await frames(t, app, 30);
    final p = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FriendPainter);
    expect(p, findsOneWidget);
    expect((t.widget<CustomPaint>(p).painter! as FriendPainter).character, Character.miu);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ZeepPainter), findsNothing);
    app.stopSession();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the share card draws the active character (E2)', (t) async {
    for (final c in const [Character.zeep, Character.lumi]) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: ShareCard(
              achievement: StreakAchievement(DateTime(2026, 11, 20), days: 3, totalMinutes: 20),
              character: c,
            ),
          ),
        ),
      );
      expect(find.byType(ZeepAvatar), c == Character.zeep ? findsOneWidget : findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FriendPainter),
        c == Character.zeep ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('the wardrobe stays Zeep with a friend active (E4)', (t) async {
    final app = await makeApp(days: 12);
    app.wardrobe.selectCharacter(Character.lumi);
    app.wardrobe.toggle(OutfitItem.sproutBow);
    await launch(t, app);
    await t.tap(find.byTooltip(s.openWardrobe));
    await frames(t, app);
    expect(find.text(s.wardrobe), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ZeepPainter), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
