import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/breathing/breathing_engine.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/game/balance_game.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/screens/balance_game_screen.dart';
import 'package:zeep_breathe/screens/balance_menu_screen.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/tilt/tilt_physics.dart';
import 'package:zeep_breathe/tilt/tilt_sensor.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';

class FakeTilt implements TiltSource {
  final controller = StreamController<Vec3>();
  @override
  Stream<Vec3> readings() => controller.stream;
}

class ThrowingTilt implements TiltSource {
  @override
  Stream<Vec3> readings() => Stream.error(UnsupportedError('no sensor'));
}

class FakeRotation implements DisplayRotationSource {
  int value;
  FakeRotation([this.value = 0]);
  @override
  Future<int> rotation() async => value;
}

final now = DateTime(2026, 11, 20, 22, 30);

/// Haptics that only record what was fired.
class RecordingHaptics extends HapticsService {
  final fired = <HapticPattern>[];
  @override
  bool fire(HapticPattern p, double now) {
    final ok = super.fire(p, now);
    if (ok) fired.add(p);
    return ok;
  }
}

/// Music that records what the game asks of it (the real one has no player
/// in tests).
class RecordingMusic extends MusicService {
  bool? lastWant;
  int stops = 0;
  @override
  void update(double dt, bool want, int track) => lastWant = want;
  @override
  void stopNow() => stops++;
}

Future<AppController> makeApp() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  return AppController(settings: settings, haptics: RecordingHaptics(), music: RecordingMusic())..clock = (() => now);
}

Widget wrap(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

late AppController testApp;

Widget app(
  TiltSource src, {
  Locale locale = const Locale('en'),
  DisplayRotationSource? rotation,
  BalanceLevel level = BalanceLevel.easy,
  int minutes = 1,
}) => wrap(
  BalanceGameScreen(
    app: testApp,
    level: level,
    minutes: minutes,
    source: src,
    rotationSource: rotation ?? FakeRotation(),
  ),
  locale: locale,
);

/// The device reading that shows up as [screen] when the screen is turned
/// [rotation] quarter turns (the inverse of remapTilt).
Vec3 deviceReading(Vec3 screen, int rotation) => remapTilt(screen, (4 - rotation) % 4);

void landscape(WidgetTester t) {
  t.view.physicalSize = const Size(2556, 1179);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// A phone-sized portrait view (the default test view is 800×600 landscape).
void portrait(WidgetTester t) {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> frames(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
}

void main() {
  setUp(() async => testApp = await makeApp());

  testWidgets('no readings: shows the no-sensor message instead of crashing', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    await frames(t, 2.5);
    expect(find.text(S.en.noTiltSensor), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('sensor error: shows the no-sensor message (Thai)', (t) async {
    portrait(t);
    await t.pumpWidget(app(ThrowingTilt(), locale: const Locale('th')));
    await frames(t, 0.2);
    expect(find.text(S.thai.noTiltSensor), findsOneWidget);
  });

  testWidgets('countdown, then Zeep follows the tilt', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 0.2);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await frames(t, 3.2);
    expect(find.text(S.en.holdComfortably), findsNothing);
    final start = t.getTopLeft(find.byType(ZeepAvatar));

    // held still: Zeep does not move
    await frames(t, 1.0);
    expect(t.getTopLeft(find.byType(ZeepAvatar)), start);

    // lower the right edge: Zeep rolls right
    src.controller.add(const Vec3(-2.5, 0, 9.5));
    await frames(t, 0.6);
    expect(t.getTopLeft(find.byType(ZeepAvatar)).dx, greaterThan(start.dx + 20));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('sensor fails mid-game: shows the no-sensor message', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    expect(find.text(S.en.resetCentre), findsOneWidget);
    src.controller.addError(StateError('sensor lost'));
    await frames(t, 0.1);
    expect(find.text(S.en.noTiltSensor), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  for (var r = 0; r < 4; r++) {
    testWidgets('rotation $r: lowering the right edge of the screen rolls Zeep right', (t) async {
      r.isOdd ? landscape(t) : portrait(t);
      final src = FakeTilt();
      await t.pumpWidget(app(src, rotation: FakeRotation(r)));
      await t.pump();
      src.controller.add(deviceReading(const Vec3(0, 0, 9.81), r));
      await frames(t, 3.5);
      expect(find.text(S.en.holdComfortably), findsNothing);
      final start = t.getTopLeft(find.byType(ZeepAvatar));
      for (var i = 0; i < 12; i++) {
        src.controller.add(deviceReading(const Vec3(-2.5, 0, 9.5), r));
        await frames(t, 0.05);
      }
      final end = t.getTopLeft(find.byType(ZeepAvatar));
      expect(end.dx, greaterThan(start.dx + 20));
      expect((end.dy - start.dy).abs(), lessThan(1));
      await t.pumpWidget(const SizedBox());
      unawaited(src.controller.close());
    });
  }

  testWidgets('screen rotates mid-game: counts 3-2-1 again and re-centres', (t) async {
    portrait(t);
    final rot = FakeRotation();
    final src = FakeTilt();
    await t.pumpWidget(app(src, rotation: rot));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    expect(find.text(S.en.holdComfortably), findsNothing);

    // a 180-degree turn: the window shape doesn't change, the poll sees it
    rot.value = 2;
    await frames(t, 0.6);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    await frames(t, 3.2);
    expect(find.text(S.en.holdComfortably), findsNothing);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('lying flat, top edge lowered 32 degrees: the game keeps going, Zeep rolls up', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    final start = t.getTopLeft(find.byType(ZeepAvatar));
    const a = 32 * math.pi / 180;
    for (var i = 0; i < 20; i++) {
      src.controller.add(Vec3(0, -9.81 * math.sin(a), 9.81 * math.cos(a)));
      await frames(t, 0.05);
    }
    expect(find.text(S.en.holdComfortably), findsNothing);
    expect(find.text(S.en.noTiltSensor), findsNothing);
    expect(t.getTopLeft(find.byType(ZeepAvatar)).dy, lessThan(start.dy - 20));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  // a plain test: a real (unanswered) platform call never completes inside
  // testWidgets' fake time
  test('no display channel (tests, other platforms): treated as rotation 0', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await const PlatformDisplayRotation().rotation(), 0);
  });

  // ------------------------------------------------------------ full game

  Future<FakeTilt> startPlaying(WidgetTester t, {BalanceLevel level = BalanceLevel.easy, int minutes = 1}) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src, level: level, minutes: minutes));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    expect(find.text(S.en.holdComfortably), findsNothing);
    return src;
  }

  RecordingHaptics haptics() => testApp.haptics as RecordingHaptics;

  int shownScore(WidgetTester t) {
    final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? '');
    final m = texts.map(RegExp(r'^(\d+)%$').firstMatch).whereType<RegExpMatch>().first;
    return int.parse(m.group(1)!);
  }

  testWidgets('easy, held still for the whole game: 100 %, 3 stars, saved, best kept', (t) async {
    final src = await startPlaying(t);
    expect(find.text(S.en.inCircle), findsOneWidget);
    await frames(t, 61);
    expect(find.text(S.en.gameComplete), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.text(S.en.newBest), findsOneWidget);
    expect(haptics().fired, contains(HapticPattern.confirm));

    final r = testApp.history.records.single;
    expect(r.exercise, 'game-easy');
    expect(r.score, 100);
    expect(r.completed, isTrue);
    expect(r.seconds, 60);
    expect(r.start, now);
    expect(testApp.settings.gameBest, [100, 0, 0]);
    expect(find.text(S.en.streakBadge(1)), findsOneWidget);

    // play again: a fresh countdown and score
    await t.tap(find.text(S.en.playAgain));
    await frames(t, 0.2);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('rolling out of the circle: one soft pulse, a tick back in, the score drops', (t) async {
    final src = await startPlaying(t);
    await frames(t, 1);
    for (var i = 0; i < 40; i++) {
      src.controller.add(const Vec3(-4, 0, 9));
      await frames(t, 0.05);
    }
    expect(find.text(S.en.outOfCircle), findsOneWidget);
    expect(haptics().fired.where((p) => p == HapticPattern.edgeOut), hasLength(1));
    expect(haptics().fired, isNot(contains(HapticPattern.edgeIn)));
    // held at the wall it stays out: no repeated pulses
    await frames(t, 2);
    expect(haptics().fired.where((p) => p == HapticPattern.edgeOut), hasLength(1));

    // tilt back: one tick on the way in
    for (var i = 0; i < 40; i++) {
      src.controller.add(const Vec3(3, 0, 9.3));
      await frames(t, 0.05);
      if (haptics().fired.contains(HapticPattern.edgeIn)) break;
    }
    expect(haptics().fired.where((p) => p == HapticPattern.edgeIn), hasLength(1));
    expect(shownScore(t), lessThan(90));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('stopped after 10 s: results say it is not saved, no history entry', (t) async {
    final src = await startPlaying(t);
    await frames(t, 10);
    await t.tap(find.text(S.en.stop));
    await frames(t, 0.1);
    expect(find.text(S.en.gameStopped), findsOneWidget);
    expect(find.text(S.en.gameNotSaved), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(testApp.history.records, isEmpty);
    expect(testApp.settings.gameBest, [0, 0, 0]);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('stopped after 40 s: saved as stopped with its score, best not changed', (t) async {
    final src = await startPlaying(t);
    await frames(t, 40);
    await t.tap(find.text(S.en.stop));
    await frames(t, 0.1);
    final r = testApp.history.records.single;
    expect(r.completed, isFalse);
    expect(r.score, 100);
    expect(testApp.settings.gameBest, [0, 0, 0]);
    expect(find.text(S.en.gameNotSaved), findsNothing);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('going to the background pauses; the time stops; resume counts 3-2-1', (t) async {
    final src = await startPlaying(t);
    await frames(t, 5);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await frames(t, 0.1);
    expect(find.text(S.en.paused), findsOneWidget);
    expect(find.text('0:55'), findsOneWidget);
    await frames(t, 5);
    expect(find.text('0:55'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.tap(find.text(S.en.resume).first);
    await frames(t, 0.2);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    await frames(t, 3.5);
    expect(find.text(S.en.inCircle), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('medium: the circle breathes with the rhythm and shows the phase', (t) async {
    final src = await startPlaying(t, level: BalanceLevel.medium);
    expect(find.text(S.en.phase(Phase.inhale)), findsOneWidget);
    expect(haptics().fired, contains(HapticPattern.inhaleStart));
    await frames(t, 4.2); // default rhythm 4-2-6: now holding
    expect(find.text(S.en.phase(Phase.hold)), findsOneWidget);
    expect(haptics().fired, contains(HapticPattern.holdStart));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('vibration off: no game pulses at all', (t) async {
    testApp.setVibration(false);
    haptics().fired.clear();
    final src = await startPlaying(t, level: BalanceLevel.medium);
    for (var i = 0; i < 40; i++) {
      src.controller.add(const Vec3(-4, 0, 9));
      await frames(t, 0.05);
    }
    expect(haptics().fired, isEmpty);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('music button toggles the setting', (t) async {
    final src = await startPlaying(t);
    expect(testApp.settings.music, isTrue);
    await t.tap(find.byTooltip(S.en.musicOn));
    await t.pump();
    expect(testApp.settings.music, isFalse);
    expect(find.byTooltip(S.en.musicOff), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('level select: remembers level and length, starts that game', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(wrap(BalanceMenuScreen(app: testApp, source: src, rotationSource: FakeRotation())));
    expect(find.text(S.en.noBestYet), findsWidgets);
    await t.tap(find.text(S.en.levelName(BalanceLevel.hard)));
    await t.tap(find.text(S.en.minutes(3)));
    await t.pump();
    expect(testApp.settings.gameLevel, 2);
    expect(testApp.settings.gameMinutes, 3);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('zeep.gameLevel'), 2);
    expect(p.getInt('zeep.gameMinutes'), 3);

    await t.tap(find.text(S.en.startGame));
    await frames(t, 1);
    expect(find.text('${S.en.levelName(BalanceLevel.hard)} · ${S.en.minutes(3)}'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('Thai results', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src, locale: const Locale('th')));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5 + 61);
    expect(find.text(S.thai.gameComplete), findsOneWidget);
    expect(find.text(S.thai.playAgain), findsOneWidget);
    expect(find.text(S.thai.scoreSummary(100)), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  // ------------------------------------------------------------ leaving (review #1, #4)

  RecordingMusic music() => testApp.music as RecordingMusic;

  /// GM -> start -> countdown done: playing, with GM underneath.
  Future<FakeTilt> fromMenu(WidgetTester t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(wrap(BalanceMenuScreen(app: testApp, source: src, rotationSource: FakeRotation())));
    await t.tap(find.text(S.en.startGame));
    await frames(t, 0.6);
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    expect(find.text(S.en.inCircle), findsOneWidget);
    return src;
  }

  testWidgets('back after 40 s: saved once as stopped, best unchanged, music stopped', (t) async {
    final src = await fromMenu(t);
    await frames(t, 40);
    expect(music().lastWant, isTrue);
    await t.tap(find.byTooltip(S.en.back));
    await frames(t, 1);
    expect(find.text(S.en.startGame), findsOneWidget); // back on GM
    final r = testApp.history.records.single;
    expect(r.completed, isFalse);
    expect(r.score, 100);
    expect(r.seconds, inInclusiveRange(40, 41));
    expect(testApp.settings.gameBest, [0, 0, 0]);
    expect(music().stops, greaterThan(0));
    // nothing more happens after leaving (no finish, no confirm pulse)
    await frames(t, 25);
    expect(testApp.history.records, hasLength(1));
    expect(haptics().fired, isNot(contains(HapticPattern.confirm)));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('back after 10 s: nothing saved', (t) async {
    final src = await fromMenu(t);
    await frames(t, 10);
    await t.tap(find.byTooltip(S.en.back));
    await frames(t, 1);
    expect(testApp.history.records, isEmpty);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('Stop, then Done: saved once, music stopped, back on GM', (t) async {
    final src = await fromMenu(t);
    await frames(t, 35);
    await t.tap(find.text(S.en.stop));
    await frames(t, 0.2);
    final stops = music().stops;
    await t.tap(find.text(S.en.done));
    await frames(t, 1);
    expect(find.text(S.en.startGame), findsOneWidget);
    expect(testApp.history.records, hasLength(1));
    expect(music().stops, greaterThan(stops));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('background: music is stopped at once (no frames on Android)', (t) async {
    final src = await startPlaying(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(music().stops, greaterThan(0));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('sensor stream ends mid-game: no-sensor message, the game stops (review #5)', (t) async {
    final src = await startPlaying(t);
    await src.controller.close();
    await frames(t, 0.2);
    expect(find.text(S.en.noTiltSensor), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
