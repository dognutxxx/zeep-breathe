// Headless screenshots of Zeep and friends (1.7.0), in English and Thai:
// the "My friends" picker (Zeep only, day 6 with Miu picked, day 12), the
// day-3 / day-10 / both-at-once cards, T1 with Miu and with Lumi, and a
// session with Lumi mid-inhale and on hold; 1.7.1: share cards with Miu and
// Lumi, the picker at day 5 with no pick and at day 1; 1.8.0: the picker at
// day 35, 65 and 120, Mun, Tuntun and Nuan on T1 and in a session (inhale and
// hold), the "Mun is here" card, the three-friends card and a share card with
// Nuan. Uses Windows' Leelawadee UI font
// for both languages (Roboto has no Thai glyphs).
//   flutter test tool/friends_screens_test.dart --update-goldens

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/exercises/exercises.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/game/balance_game.dart';
import 'package:zeep_breathe/screens/friend_cards.dart';
import 'package:zeep_breathe/screens/share_screen.dart';
import 'package:zeep_breathe/share/share_card.dart';

import 'screens_common.dart';

Future<void> _loadFonts() async {
  Future<ByteData> f(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f(r'C:\Windows\Fonts\LeelawUI.ttf'))
        ..addFont(f(r'C:\Windows\Fonts\LeelaUIb.ttf')))
      .load();
  final icons =
      '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\User\flutter'}'
      '/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  await (FontLoader('MaterialIcons')..addFont(f(icons))).load();
}

/// An app at [days] practice days, with two flowers bloomed (sakura worn).
Future<AppController> _app(WidgetTester t, int days) async {
  phone(t);
  final app = await makeApp();
  app.wardrobe.setForTest(steps: 2 * 3 + 1, practiceDays: days);
  app.wardrobe.markAllSeen();
  return app;
}

Future<void> _picker(WidgetTester t, String p, S s, String name, AppController app) async {
  await t.pumpWidget(ZeepBreatheApp(controller: app));
  await advance(t, 0.6);
  await t.tap(find.text(s.friendsChip));
  await advance(t, 0.8);
  await shot('screens/$p$name.png');
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

Future<void> _card(WidgetTester t, String p, String name, AppController app) async {
  await t.pumpWidget(ZeepBreatheApp(controller: app));
  await advance(t, 0.4);
  showFriendCard(t.element(find.byType(Scaffold).first), app);
  await advance(t, 1.6); // the friends mid-inhale
  await shot('screens/$p$name.png');
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

Future<void> _flow(WidgetTester t, String p, S s) async {
  // C: the picker
  await _picker(t, p, s, '40_friends_zeep_only', await _app(t, 0));
  final day6 = await _app(t, 6);
  day6.wardrobe.chooseFirstFriend(Character.miu);
  await _picker(t, p, s, '41_friends_day6_miu', day6);
  final day12 = await _app(t, 12);
  day12.wardrobe.chooseFirstFriend(Character.miu);
  day12.wardrobe.markFriendCardShown(FriendCard.day10);
  day12.wardrobe.selectCharacter(Character.lumi);
  await _picker(t, p, s, '42_friends_day12', day12);

  // 1.7.1: the highlighted "choose a new friend" row (day 5, no pick) and
  // the grey "Miu or Lumi" row counting down (day 1)
  await _picker(t, p, s, '52_friends_day5_choose', await _app(t, 5));
  await _picker(t, p, s, '53_friends_day1', await _app(t, 1));

  // D: the cards
  await _card(t, p, '43_friend_card_day3', await _app(t, 3));
  // Miu picked on day 3, then 10 days reached
  final pick = await _app(t, 3);
  pick.wardrobe.chooseFirstFriend(Character.miu);
  pick.wardrobe.setForTest(practiceDays: 10);
  await _card(t, p, '44_friend_card_day10', pick);
  await _card(t, p, '45_friend_card_both', await _app(t, 12));

  // 1.8.0: the picker with Mun (day 35), Mun and Tuntun (day 65), everyone (day 120)
  for (final (days, name) in const [(35, '54_friends_day35'), (65, '55_friends_day65'), (120, '56_friends_day120')]) {
    final app = await _app(t, days);
    app.wardrobe.chooseFirstFriend(Character.miu);
    app.wardrobe.markFriendCardShown(FriendCard.day10);
    await _picker(t, p, s, name, app);
  }

  // 1.8.0: "Mun is here" at day 30, and three friends at once (day 120 after an update)
  final day30 = await _app(t, 30);
  day30.wardrobe.markFriendCardShown(FriendCard.both);
  await _card(t, p, '66_friend_card_mun', day30);
  final day120 = await _app(t, 120);
  day120.wardrobe.markFriendCardShown(FriendCard.both);
  await _card(t, p, '67_friend_card_three', day120);

  // 1.8.0: T1 and the session (mid-inhale, hold) with each new friend
  for (final (c, n, name) in [
    (Character.mun, 57, 'mun'),
    (Character.tuntun, 58, 'tuntun'),
    (Character.nuan, 59, 'nuan'),
  ]) {
    final app = await _app(t, 120);
    app.wardrobe.markFriendCardShown(FriendCard.both);
    app.wardrobe.markFriendCardShown(FriendCard.later, shown: laterFriends);
    app.wardrobe.selectCharacter(c);
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await advance(t, 1.2);
    await shot('screens/$p${n}_breathe_$name.png');
    app.startSession();
    await advance(t, 2.0);
    await shot('screens/$p${n + 3}_session_${name}_inhale.png');
    await advance(t, 2.8);
    await shot('screens/$p${n + 6}_session_${name}_hold.png');
    app.stopSession();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  // E1: T1 and the session
  for (final (c, name) in [(Character.miu, '46_breathe_miu'), (Character.lumi, '47_breathe_lumi')]) {
    final app = await _app(t, 12);
    app.wardrobe.markFriendCardShown(FriendCard.both);
    app.wardrobe.selectCharacter(c);
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await advance(t, 1.2);
    await shot('screens/$p$name.png');
    if (c == Character.lumi) {
      app.startSession();
      await advance(t, 2.0);
      await shot('screens/${p}48_session_lumi_inhale.png');
      await advance(t, 2.8);
      await shot('screens/${p}49_session_lumi_hold.png');
      app.stopSession();
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  // 1.7.1: share cards with a friend, as tall as Zeep on 26 / 28
  for (final (c, name, a, colour) in [
    (Character.miu, '50_share_miu', StreakAchievement(fixedNow, days: 7, totalMinutes: 52), ShareCardColor.lavender),
    (
      Character.lumi,
      '51_share_lumi',
      GameAchievement(fixedNow, level: BalanceLevel.hard, score: 96),
      ShareCardColor.sky,
    ),
    // 1.8.0: Nuan on a session card
    (
      Character.nuan,
      '68_share_nuan',
      SessionAchievement(fixedNow, exerciseName: exercises[1].name(s), minutes: 15, breaths: 47),
      ShareCardColor.mint,
    ),
  ]) {
    phone(t);
    await t.pumpWidget(plainApp(ShareScreen(achievement: a, character: c, sharer: (_, _, _) async {})));
    await advance(t, 0.3);
    if (colour != ShareCardColor.lavender) {
      await t.tap(find.byTooltip(s.cardThemeName(colour)));
      await advance(t, 0.3);
    }
    await shot('screens/$p$name.png');
    await t.pumpWidget(const SizedBox());
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('friends (en)', (t) async {
    debugDisableShadows = false;
    try {
      await _flow(t, '', S.en);
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('friends (th)', (t) async {
    debugDisableShadows = false;
    try {
      t.platformDispatcher.localesTestValue = const [Locale('th', 'TH')];
      t.platformDispatcher.localeTestValue = const Locale('th', 'TH');
      await _flow(t, 'th_', S.thai);
    } finally {
      debugDisableShadows = true;
      t.platformDispatcher.clearAllTestValues();
    }
  });
}
