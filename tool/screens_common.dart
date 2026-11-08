// Shared helpers for the headless screenshot tests (screens_test.dart for
// English, screens_th_test.dart for Thai).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/exercises/exercises.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

Future<AppController> makeApp() async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  final music = MusicService()..available = true; // not initialised: silent in tests
  return AppController(settings: settings, haptics: HapticsService(), music: music);
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
  final now = DateTime.now();
  DateTime ago(int d, int h) => DateTime(now.year, now.month, now.day - d, h, 15);
  // ignore: invalid_use_of_visible_for_testing_member
  app.history.seed([
    for (final (d, secs, ex) in [
      (16, 180, 'default'),
      (15, 240, 'box'),
      (14, 300, 'belly'),
      (13, 180, 'default'),
      (9, 120, 'custom'),
      (6, 600, '478'),
      (4, 300, 'belly'),
      (3, 420, 'box'),
      (2, 300, 'belly'),
      (1, 600, '478'),
      (0, 300, 'box'),
    ])
      SessionRecord(
        start: ago(d, d.isEven ? 7 : 22),
        seconds: secs,
        breaths: secs ~/ 12,
        exercise: ex,
        completed: d != 9,
      ),
  ]);
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
  await t.drag(find.byType(ListView), const Offset(0, -600));
  await advance(t, 0.5);
  await shot('screens/${p}12_progress_scrolled.png');

  // finish a 1-minute session -> streak badge on the finish card
  app.settings.update((x) => x.sessionMinutes = 1, persist: false);
  app.setTab(HomeTab.breathe);
  app.startSession();
  await advance(t, 0.3);
  app.engine.sessionElapsed = 59.8;
  await advance(t, 0.6);
  await shot('screens/${p}13_finished_streak.png');
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}
