// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/screens/wardrobe_screen.dart';
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
    app.wardrobe.setForTest(steps: 4 + 4, practiceDays: 7);
  });

  Future<void> open(WidgetTester t, {int tab = 0}) async {
    // a tall window so every tile is on screen without scrolling
    t.view.physicalSize = const Size(1179, 9000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: WardrobeScreen(app: app, initialTab: tab),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('tapping an item wears it, the tile and "None" update, tapping again takes it off', (t) async {
    await open(t);
    final beanie = s.itemName(OutfitItem.beanie);
    expect(find.bySemanticsLabel('$beanie, ${s.wearing}'), findsNothing);

    await t.tap(find.text(beanie));
    await t.pump(const Duration(milliseconds: 100));
    expect(app.wardrobe.outfit.wears(OutfitItem.beanie), isTrue);
    expect(find.bySemanticsLabel('$beanie, ${s.wearing}'), findsOneWidget);
    // the head slot's "None" chip is no longer selected (the other slots' still are)
    final unselectedNone = find.byWidgetPredicate((w) => w is ChoiceChip && !w.selected);
    expect(unselectedNone, findsOneWidget);

    await t.tap(find.text(beanie));
    await t.pump(const Duration(milliseconds: 100));
    expect(app.wardrobe.outfit.isEmpty, isTrue);
    expect(find.bySemanticsLabel('$beanie, ${s.wearing}'), findsNothing);
    expect(unselectedNone, findsNothing);
  });

  testWidgets('a locked item cannot be worn', (t) async {
    await open(t);
    final cap = s.itemName(OutfitItem.sleepCap);
    await t.tap(find.text(cap));
    await t.pump(const Duration(milliseconds: 100));
    expect(app.wardrobe.outfit.isEmpty, isTrue);
  });

  testWidgets('tapping a bloomed flower makes Zeep wear it; "No flower" takes it off', (t) async {
    await open(t, tab: 1);
    final daisy = s.flowerName(flowerKinds[0]);
    await t.tap(find.text(daisy));
    await t.pump(const Duration(milliseconds: 100));
    expect(app.wardrobe.wornFlower, flowerKinds[0]);
    expect(find.bySemanticsLabel('$daisy, ${s.wearing}'), findsOneWidget);
    await t.tap(find.text(s.noFlower));
    await t.pump(const Duration(milliseconds: 100));
    expect(app.wardrobe.wornFlower, isNull);
    expect(find.bySemanticsLabel('$daisy, ${s.wearing}'), findsNothing);
  });
}
