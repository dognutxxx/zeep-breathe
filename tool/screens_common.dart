// Shared helpers for the headless screenshot tests (screens_test.dart for
// English, screens_th_test.dart for Thai).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/exercises/exercises.dart';
import 'package:zeep_breathe/game/balance_game.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/balance_game_screen.dart';
import 'package:zeep_breathe/screens/balance_menu_screen.dart';
import 'package:zeep_breathe/screens/share_screen.dart';
import 'package:zeep_breathe/screens/splash_screen.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/share/share_card.dart';
import 'package:zeep_breathe/tilt/tilt_physics.dart';
import 'package:zeep_breathe/tilt/tilt_sensor.dart';
import 'package:zeep_breathe/ui/zeep_colors.dart';

/// Every screenshot run uses this "now" (a Friday late in the month), so the
/// images do not depend on the day the tests run.
final fixedNow = DateTime(2026, 11, 20, 22, 30);

Future<AppController> makeApp() async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  final music = MusicService()..available = true; // not initialised: silent in tests
  return AppController(settings: settings, haptics: HapticsService(), music: music)..clock = () => fixedNow;
}

Future<void> advance(WidgetTester t, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  t.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  t.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
}

void seedHistory(AppController app) {
  final now = fixedNow;
  // (days ago, hour, minute, seconds, mode id, completed)
  // ignore: invalid_use_of_visible_for_testing_member
  app.history.seed([
    for (final (d, h, m, secs, ex, done) in [
      (16, 7, 15, 180, 'default', true),
      (15, 22, 0, 240, 'box', true),
      (14, 7, 15, 300, 'belly', true),
      (13, 21, 40, 180, 'default', true),
      (9, 8, 5, 120, 'custom', false),
      (6, 22, 15, 600, '478', true),
      (4, 7, 15, 300, 'belly', true),
      (3, 22, 15, 420, 'box', true),
      (2, 7, 15, 300, 'belly', true),
      (1, 12, 40, 300, 'box', true),
      (1, 22, 15, 600, '478', true),
      (0, 7, 15, 300, 'box', true),
      (0, 12, 30, 95, 'belly', false),
      (0, 21, 50, 600, '478', true),
    ])
      SessionRecord(
        start: DateTime(now.year, now.month, now.day - d, h, m),
        seconds: secs,
        breaths: secs ~/ 12,
        exercise: ex,
        completed: done,
      ),
  ]);
}

/// Taps a day number in the Progress calendar (days ago from today).
Future<void> tapCalendarDay(WidgetTester t, int daysAgo) async {
  final now = fixedNow;
  final d = DateTime(now.year, now.month, now.day - daysAgo);
  final cell = find.widgetWithText(InkResponse, '${d.day}');
  await t.ensureVisible(cell.first);
  await t.tap(cell.first);
}

Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile(name));

/// Breathe tab -> Exercises -> each mode's screen -> start -> Progress.
/// [p] prefixes the file names, [s] is the language being rendered.
Future<void> tabsFlow(WidgetTester t, String p, S s) async {
  phone(t);
  final app = await makeApp();
  seedHistory(app);
  await t.pumpWidget(ZeepBreatheApp(controller: app));
  await advance(t, 0.8);
  await shot('screens/${p}8_breathe_tab.png');

  await t.tap(find.text(s.tabExercises).last);
  await advance(t, 0.5);
  await shot('screens/${p}9_exercises.png');

  // one screen per mode: 2 phases, 3 phases, 2 x 2
  for (final (i, e) in exercises.indexed) {
    await t.tap(find.text(e.name(s)));
    await advance(t, 0.6);
    await shot('screens/${p}14_mode_${i + 1}_${e.id}.png');
    if (i < exercises.length - 1) {
      await t.tap(find.byTooltip(s.back));
      await advance(t, 0.6);
    }
  }
  // box breathing: pick 10 min and start
  await t.tap(find.text(s.minutes(10)));
  await advance(t, 0.3);
  await t.tap(find.text(s.startBreathing));
  await advance(t, 6.0); // into the hold phase
  await shot('screens/${p}15_session_box.png');
  app.stopSession();
  await advance(t, 0.4);
  await shot('screens/${p}10_breathe_box.png');

  await t.tap(find.text(s.tabProgress).last);
  await advance(t, 0.5);
  await shot('screens/${p}11_progress.png');
  await t.drag(find.byType(ListView), const Offset(0, -2000));
  await advance(t, 0.5);
  await shot('screens/${p}12_progress_scrolled.png');
  // another day with two sessions, then a day with none
  await tapCalendarDay(t, 1);
  await advance(t, 0.3);
  await t.drag(find.byType(ListView), const Offset(0, -2000));
  await advance(t, 0.3);
  await shot('screens/${p}16_timeline_yesterday.png');
  await tapCalendarDay(t, 5);
  await advance(t, 0.3);
  await t.drag(find.byType(ListView), const Offset(0, -2000));
  await advance(t, 0.3);
  await shot('screens/${p}17_timeline_empty_day.png');

  // the picked day survives a tab switch
  await t.tap(find.text(s.tabBreathe).last);
  await advance(t, 0.3);
  await t.tap(find.text(s.tabProgress).last);
  await advance(t, 0.3);
  final picked = DateTime(fixedNow.year, fixedNow.month, fixedNow.day - 5);
  expect(app.progressDay, picked);
  await t.drag(find.byType(ListView), const Offset(0, -2000));
  await advance(t, 0.3);
  expect(find.text(s.dayHeading(picked)), findsOneWidget);

  // the next morning: today has no sessions yet -> "Breathe now" button
  app.clock = () => DateTime(fixedNow.year, fixedNow.month, fixedNow.day + 1, 8, 0);
  app.progressDay = null;
  app.setTab(HomeTab.breathe);
  await advance(t, 0.2);
  await t.tap(find.text(s.tabProgress).last);
  await advance(t, 0.3);
  await t.drag(find.byType(ListView), const Offset(0, -2000));
  await advance(t, 0.3);
  await shot('screens/${p}18_timeline_today_empty.png');
  app.clock = () => fixedNow;

  // finish a 1-minute session -> streak badge on the finish card; a picked
  // day goes back to today once the session is saved
  app.progressDay = DateTime(fixedNow.year, fixedNow.month, fixedNow.day - 3);
  app.settings.update((x) => x.sessionMinutes = 1, persist: false);
  app.setTab(HomeTab.breathe);
  app.startSession();
  await advance(t, 0.3);
  app.engine.sessionElapsed = 59.8;
  await advance(t, 0.6);
  await shot('screens/${p}13_finished_streak.png');
  expect(app.progressDay, isNull);
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

class _FakeTilt implements TiltSource {
  final controller = StreamController<Vec3>();
  @override
  Stream<Vec3> readings() => controller.stream;
}

class _FakeRotation implements DisplayRotationSource {
  final int value;
  const _FakeRotation([this.value = 0]);
  @override
  Future<int> rotation() async => value;
}

/// A bare MaterialApp around [home] (share screen, game), for other tools.
Widget plainApp(Widget home) => _gameApp(home);

Widget _gameApp(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ZeepColors.blue, surface: Colors.white),
    scaffoldBackgroundColor: ZeepColors.bgBottom,
  ),
  home: home,
);

Future<void> _tilt(WidgetTester t, _FakeTilt src, Vec3 g, double seconds) async {
  for (var i = 0; i < (seconds / 0.05).round(); i++) {
    src.controller.add(g);
    await advance(t, 0.05);
  }
}

/// Zeep Balance (T2.3): GM -> countdown -> GP medium -> out of the circle ->
/// GR, then GP hard in landscape and the game in the Progress timeline.
Future<void> gameFlow(WidgetTester t, String p, S s) async {
  phone(t);
  final app = await makeApp();
  seedHistory(app);
  app.settings.update((x) => x.gameBest = [92, 74, 0], persist: false);
  final src = _FakeTilt();
  await t.pumpWidget(_gameApp(BalanceMenuScreen(app: app, source: src, rotationSource: const _FakeRotation())));
  await advance(t, 0.5);
  await t.tap(find.text(s.levelName(BalanceLevel.medium)));
  await advance(t, 0.3);
  await shot('screens/${p}19_game_menu.png');

  await t.tap(find.text(s.startGame));
  await advance(t, 0.6);
  src.controller.add(const Vec3(0, 0, 9.81));
  await advance(t, 1.2);
  await shot('screens/${p}20_game_countdown.png');
  await advance(t, 2.3 + 1.5); // playing, mid-inhale
  await _tilt(t, src, const Vec3(-0.9, 0.5, 9.75), 0.5);
  await _tilt(t, src, const Vec3(0, 0, 9.81), 0.6);
  await shot('screens/${p}21_game_medium.png');
  await _tilt(t, src, const Vec3(-4, 1, 8.9), 1.0);
  await shot('screens/${p}22_game_out.png');
  await _tilt(t, src, const Vec3(3.2, -0.8, 9.2), 0.7);
  await _tilt(t, src, const Vec3(0, 0, 9.81), 0.3);
  await advance(t, 55);
  await shot('screens/${p}23_game_results.png');
  await t.pumpWidget(const SizedBox());

  // hard, landscape (screen turned 90 degrees)
  t.view.physicalSize = const Size(2556, 1179);
  t.view.padding = const FakeViewPadding(left: 59 * 3, right: 59 * 3, bottom: 21 * 3);
  t.view.viewPadding = const FakeViewPadding(left: 59 * 3, right: 59 * 3, bottom: 21 * 3);
  final src2 = _FakeTilt();
  await t.pumpWidget(
    _gameApp(
      BalanceGameScreen(
        app: app,
        level: BalanceLevel.hard,
        minutes: 2,
        source: src2,
        rotationSource: const _FakeRotation(1),
      ),
    ),
  );
  await advance(t, 0.2);
  src2.controller.add(remapTilt(const Vec3(0, 0, 9.81), 3));
  await advance(t, 3.5 + 6);
  await _tilt(t, src2, remapTilt(const Vec3(-1.2, -0.6, 9.7), 3), 0.5);
  await _tilt(t, src2, remapTilt(const Vec3(0, 0, 9.81), 3), 0.8);
  await shot('screens/${p}24_game_hard_landscape.png');
  await t.pumpWidget(const SizedBox());

  // the game shows in today's timeline
  phone(t);
  await t.pumpWidget(ZeepBreatheApp(controller: app));
  await advance(t, 0.5);
  await t.tap(find.text(s.tabProgress).last);
  await advance(t, 0.5);
  await t.drag(find.byType(ListView), const Offset(0, -2000));
  await advance(t, 0.5);
  await shot('screens/${p}25_timeline_game.png');
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
  unawaited(src.controller.close());
  unawaited(src2.controller.close());
}

/// Community phase 1 (CS): one share card of each kind, one per colour.
Future<void> shareFlow(WidgetTester t, String p, S s) async {
  phone(t);
  final cards = [
    ('26_share_streak', StreakAchievement(fixedNow, days: 7, totalMinutes: 52), ShareCardColor.lavender),
    (
      '27_share_session',
      SessionAchievement(fixedNow, exerciseName: exercises[1].name(s), minutes: 15, breaths: 47),
      ShareCardColor.mint,
    ),
    ('28_share_game', GameAchievement(fixedNow, level: BalanceLevel.hard, score: 96), ShareCardColor.sky),
  ];
  for (final (name, a, colour) in cards) {
    await t.pumpWidget(_gameApp(ShareScreen(achievement: a, sharer: (_, _, _) async {})));
    await advance(t, 0.3);
    if (colour != ShareCardColor.lavender) {
      await t.tap(find.byTooltip(s.cardThemeName(colour)));
      await advance(t, 0.3);
    }
    await shot('screens/$p$name.png');
  }
  await t.pumpWidget(const SizedBox());
}

/// Launch splash (1.9.0, dark, Zeep only): 0.2 s, the inhale peak (1.6 s),
/// the hold (2.0 s) and the exhale (2.9 s); Reduce Motion at its hold; the
/// inhale peak on a 320 px phone and an iPad in landscape.
Future<void> splashFlow(WidgetTester t, String p) async {
  Future<void> run(List<(String, double)> stops) async {
    final app = await makeApp();
    final logo = await t.runAsync(loadSplashLogo);
    await t.pumpWidget(ZeepBreatheApp(boot: Future.value(app), splashLogo: logo));
    for (final (shotName, secs) in stops) {
      await advance(t, secs);
      await shot('screens/$p$shotName.png');
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  phone(t);
  // 0.1 s static, 1.2 s inhale peak, 1.4 s hold, 2.0 s mid-exhale
  await run([('36_splash_start', 0.1), ('37_splash_inhale', 1.1), ('38_splash_hold', 0.2), ('39_splash_exhale', 0.6)]);
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  await run([('splash_reduce_motion', 0.6)]);
  t.platformDispatcher.clearAccessibilityFeaturesTestValue();
  t.view.physicalSize = const Size(640, 1136);
  t.view.devicePixelRatio = 2;
  t.view.padding = const FakeViewPadding(top: 20 * 2);
  t.view.viewPadding = const FakeViewPadding(top: 20 * 2);
  await run([('splash_320_inhale', 1.2)]);
  t.view.physicalSize = const Size(2732, 2048);
  t.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
  t.view.viewPadding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
  await run([('splash_ipad_landscape_inhale', 1.2)]);
  t.view.reset();
}
