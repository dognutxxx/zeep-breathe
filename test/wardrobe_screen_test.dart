// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  testWidgets('a locked flower shows the level Zeep reaches when it blooms (QA B3)', (t) async {
    await open(t, tab: 1); // 2 blooms: level 3, the tulip opens at the end of it
    expect(find.text(s.levelN(4)), findsOneWidget);
    expect(find.text(s.levelN(21)), findsOneWidget); // the golden lotus
  });

  for (final lang in [S.en, S.thai]) {
    testWidgets('text at 2x: names and days left read in full (QA B2, ${lang.th ? 'th' : 'en'})', (t) async {
      t.view.physicalSize = const Size(1179, 30000);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      for (final tab in [0, 1]) {
        await t.pumpWidget(
          MaterialApp(
            locale: lang.th ? const Locale('th') : const Locale('en'),
            supportedLocales: S.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: WardrobeScreen(app: app, initialTab: tab),
          ),
        );
        await t.pump(const Duration(milliseconds: 100));
        expect(t.takeException(), isNull); // no overflow
      }
      await t.pumpWidget(
        MaterialApp(
          locale: lang.th ? const Locale('th') : const Locale('en'),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WardrobeScreen(app: app),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      final lotus = OutfitItem.lotusCrown;
      expect(find.textContaining(lang.daysLeft(app.wardrobe.daysLeft(lotus))), findsOneWidget);
      expect(find.text(lang.itemName(lotus)), findsOneWidget);
    });
  }
}
