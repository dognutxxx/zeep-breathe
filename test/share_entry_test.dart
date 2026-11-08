// The numbers each entry point (S.8, T3.1) puts on the share card.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/share_screen.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

final now = DateTime(2026, 11, 20, 22, 30);

class CountingMusic extends MusicService {
  int stops = 0;
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() => stops++;
}

Future<AppController> makeApp() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  return AppController(settings: settings, haptics: HapticsService(), music: CountingMusic())..clock = (() => now);
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> frames(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
}

SessionRecord rec(int daysAgo, int seconds) => SessionRecord(
  start: DateTime(now.year, now.month, now.day - daysAgo, 8),
  seconds: seconds,
  breaths: 10,
  exercise: 'box',
  completed: true,
);

/// The real Roboto: the default test font is much wider and overflows the
/// session screen.
Future<void> loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\User\flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String n) async => ByteData.sublistView(await File('$dir/$n').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f('roboto-regular.ttf'))
        ..addFont(f('roboto-medium.ttf'))
        ..addFont(f('roboto-bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'))).load();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('S.8: Share puts the session minutes, mode and breaths on the card; music stops', (t) async {
    phone(t);
    final app = await makeApp();
    app.settings.update((x) => x.sessionMinutes = 1, persist: false);
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await frames(t, 0.3);
    app.startSession();
    await frames(t, 0.3);
    app.engine.sessionElapsed = 59.8;
    await frames(t, 0.6);
    expect(find.text(S.en.sessionComplete), findsOneWidget);
    await t.tap(find.text(S.en.share));
    await frames(t, 1);
    expect(find.byType(ShareScreen), findsOneWidget);
    expect(find.text(S.en.minutes(1)), findsOneWidget);
    expect(find.text(S.en.cardBreaths(app.engine.breaths)), findsOneWidget);
    expect(find.text(S.en.cardRhythm('4 · 2 · 6')), findsOneWidget); // not just "Default"
    expect((app.music as CountingMusic).stops, greaterThan(0));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('T3.1: no streak, no Share button', (t) async {
    final semantics = t.ensureSemantics(); // the button must be reachable by screen readers
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await t.tap(find.text(S.en.tabProgress).last);
    await frames(t, 0.5);
    expect(find.bySemanticsLabel(S.en.shareStreak), findsNothing);
    await t.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('T3.1: Share puts the current streak and total minutes on the card', (t) async {
    final semantics = t.ensureSemantics(); // the button must be reachable by screen readers
    phone(t);
    final app = await makeApp();
    // a 3-day streak (today, yesterday, the day before); a longer old run
    // must not be used
    // ignore: invalid_use_of_visible_for_testing_member
    app.history.seed([
      rec(10, 300), rec(9, 300), rec(8, 300), rec(7, 300), rec(6, 300), //
      rec(2, 120), rec(1, 180), rec(0, 240),
    ]);
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await t.tap(find.text(S.en.tabProgress).last);
    await frames(t, 0.5);
    // activate it the way TalkBack / VoiceOver do (QA #1), and it is 48 high
    final node = t.getSemantics(find.bySemanticsLabel(S.en.shareStreak));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.rect.height, greaterThanOrEqualTo(48));
    t.semantics.tap(find.semantics.byLabel(S.en.shareStreak));
    await frames(t, 1);
    expect(find.byType(ShareScreen), findsOneWidget);
    expect(find.text(S.en.cardDays(3)), findsOneWidget);
    expect(find.text(S.en.cardTotal(34)), findsOneWidget); // 2040 s
    await t.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}
