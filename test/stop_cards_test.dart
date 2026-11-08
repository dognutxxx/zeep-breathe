// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

void main() {
  testWidgets('stopping a saved session shows card N at once, not after the next one (QA B4)', (t) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    final app = AppController(settings: settings, haptics: HapticsService(), music: MusicService()..available = true);
    app.wardrobe.setForTest(practiceDays: 2); // today is day 3: the round glasses
    t.view.physicalSize = const Size(1179, 2556);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await t.pump(const Duration(milliseconds: 100));

    app.startSession();
    await t.pump(const Duration(milliseconds: 100));
    app.engine.sessionElapsed = 40; // long enough to be saved
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byTooltip(S.en.stop));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(app.history.records.single.completed, isFalse);
    expect(find.text(S.en.newItemTitle), findsOneWidget);
    expect(find.textContaining(S.en.itemName(OutfitItem.roundGlasses)), findsOneWidget);
    expect(app.wardrobe.takePendingNewItems(), isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
