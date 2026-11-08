// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/history/session_history.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/screens/bloom_card.dart';
import 'package:zeep_breathe/screens/wardrobe_cards.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

void main() {
  late AppController app;
  const s = S.en;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    app = AppController(settings: settings, haptics: HapticsService(), music: MusicService()..available = true);
    // 3 leaves on level 1 and 2 practice days: the next session blooms the
    // daisy and its 3rd practice day unlocks the round glasses
    app.wardrobe.setForTest(steps: 3, practiceDays: 2);
    app.wardrobe.onSessionSaved(
      SessionRecord(start: DateTime(2026, 11, 20, 7), seconds: 300, breaths: 20, exercise: 'box', completed: true),
    );
  });

  Future<void> start(WidgetTester t, {bool reduceMotion = false}) async {
    t.view.physicalSize = const Size(1179, 2556);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showGrowthCards(context, app), child: const Text('done')),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('done'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
  }

  // the Breathe tab keeps ticking under card L: so does the app here
  Future<void> wait(WidgetTester t, int ms) async {
    for (var i = 0; i < ms ~/ 16; i++) {
      app.tick(0.016);
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  bool nextFocused() =>
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<OutlinedButton>() != null;

  List<HapticPattern> fired() => [for (final e in app.haptics.events) e.pattern];

  testWidgets('card L comes first, then card N; "Next" moves on', (t) async {
    await start(t);
    expect(find.byType(BloomCard), findsOneWidget);
    expect(find.text(s.newItemTitle), findsNothing);
    await wait(t, 1000);
    expect(nextFocused(), isFalse); // hidden buttons take no focus
    await wait(t, 2500);
    expect(nextFocused(), isTrue);
    expect(find.text(s.flowerTitle(flowerKinds[0])), findsOneWidget);
    expect(find.text(s.levelN(2)), findsOneWidget);
    expect(fired(), [HapticPattern.inhaleStart, HapticPattern.bloom, HapticPattern.confirm]);
    // pulses are timed on the app's own clock, never ahead of it
    expect(app.haptics.events.last.time, lessThanOrEqualTo(app.time));
    await t.tap(find.text(s.next));
    await wait(t, 400);
    expect(find.byType(BloomCard), findsNothing);
    expect(find.text(s.newItemTitle), findsOneWidget);
    expect(find.textContaining(s.itemName(OutfitItem.roundGlasses)), findsOneWidget);
    // shown once only
    expect(app.wardrobe.takePendingBloom(), isNull);
    expect(app.wardrobe.takePendingNewItems(), isEmpty);
  });

  testWidgets('buttons wait until 3.1 s; a tap from 0.6 s skips to the end with one bloom pulse', (t) async {
    await start(t);
    await wait(t, 300);
    await t.tap(find.byType(BloomCard));
    await t.pump();
    final state = t.state<BloomCardState>(find.byType(BloomCard));
    expect(state.ms, lessThan(skipFromMs)); // too early: nothing happens
    await wait(t, 500);
    // "Next" cannot be pressed yet
    await t.tap(find.text(s.next), warnIfMissed: false);
    await t.pump();
    expect(find.byType(BloomCard), findsOneWidget);
    await t.tap(find.byType(BloomCard));
    await wait(t, 250); // 200 ms crossfade to the end
    expect(state.ms, greaterThanOrEqualTo(3400));
    expect(fired(), [HapticPattern.bloom]);
    await t.tap(find.text(s.next));
    await wait(t, 400);
    expect(find.byType(BloomCard), findsNothing);
  });

  testWidgets('reduce motion: about 0.7 s, colour only, the bloom pulse still plays', (t) async {
    await start(t, reduceMotion: true);
    final state = t.state<BloomCardState>(find.byType(BloomCard));
    expect(state.widget.reduceMotion, isTrue);
    await wait(t, 800);
    expect(state.ms, closeTo(700, 1));
    expect(fired(), [HapticPattern.bloom]);
    await t.tap(find.text(s.seeGarden));
    await wait(t, 500);
    expect(find.byType(BloomCard), findsNothing);
    expect(find.text(s.tabGarden), findsOneWidget); // the wardrobe opened on the garden
  });

  testWidgets('"See the garden" opens the garden; card N follows when it closes', (t) async {
    await start(t);
    await wait(t, 3500);
    await t.tap(find.text(s.seeGarden));
    await wait(t, 600);
    expect(find.byType(BloomCard), findsNothing);
    expect(find.text(s.tabGarden), findsOneWidget);
    expect(find.text(s.newItemTitle), findsNothing);
    await t.tap(find.byTooltip(s.back));
    await wait(t, 600);
    expect(find.text(s.newItemTitle), findsOneWidget);
    expect(find.textContaining(s.itemName(OutfitItem.roundGlasses)), findsOneWidget);
  });
}
