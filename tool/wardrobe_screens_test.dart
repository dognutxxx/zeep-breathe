// Headless screenshots of the wardrobe (W, W.2), the bloom strip (S.9), the
// new-item card (N) and the summary card, in English and Thai. Uses Windows'
// Leelawadee UI font for both, since Roboto has no Thai glyphs.
//   flutter test tool/wardrobe_screens_test.dart --update-goldens

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/wardrobe_cards.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

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

Future<void> _flow(WidgetTester t, String p, S s) async {
  phone(t);
  final app = await makeApp();
  seedHistory(app);
  // 4 levels done and 3 leaves in level 5: the next session blooms
  app.wardrobe.setForTest(steps: 4 * 4 + 3, practiceDays: 23);
  app.wardrobe.markAllSeen();
  for (final i in [OutfitItem.sproutBow, OutfitItem.beanie, OutfitItem.roundGlasses, OutfitItem.butterfly]) {
    app.wardrobe.toggle(i);
  }
  await t.pumpWidget(ZeepBreatheApp(controller: app));
  await advance(t, 0.5);

  // W: outfits tab (top, then locked items further down), then the garden
  await t.tap(find.byTooltip(s.openWardrobe));
  await advance(t, 0.6);
  await shot('screens/${p}25_wardrobe.png');
  await t.drag(find.byType(ListView), const Offset(0, -900));
  await advance(t, 0.4);
  await shot('screens/${p}26_wardrobe_locked.png');
  await t.tap(find.text(s.tabGarden));
  await advance(t, 0.5);
  await shot('screens/${p}27_garden.png');
  await t.tap(find.byTooltip(s.back));
  await advance(t, 0.6);

  // finish a session: the flower blooms and the sleep cap (30 days) unlocks
  app.wardrobe.setForTest(practiceDays: 29);
  app.settings.update((x) => x.sessionMinutes = 1, persist: false);
  app.startSession();
  await advance(t, 0.3);
  app.engine.sessionElapsed = 59.8;
  await advance(t, 0.6);
  expect(app.lastGrowth!.bloomed, isTrue);
  expect(app.lastGrowth!.newItems, [OutfitItem.sleepCap]);
  await shot('screens/${p}28_finished_bloom.png');
  await t.tap(find.text(s.done));
  await advance(t, 0.6);
  await shot('screens/${p}29_new_item.png');
  await t.tap(find.text(s.later));
  await advance(t, 0.4);
  expect(app.wardrobe.unseen, [OutfitItem.sleepCap]);

  // the one-time summary card for people who used the app before
  app.wardrobe.summaryPending = true;
  showSummaryCard(t.element(find.byType(Scaffold).first), app);
  await advance(t, 0.5);
  await shot('screens/${p}30_summary.png');
  await t.tap(find.text(s.later));
  await advance(t, 0.3);
  expect(app.wardrobe.summaryPending, isFalse);

  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(_loadFonts);

  Future<void> run(WidgetTester t, String p, S s, Locale locale) async {
    debugDisableShadows = false;
    try {
      t.platformDispatcher.localesTestValue = [locale];
      t.platformDispatcher.localeTestValue = locale;
      await _flow(t, p, s);
    } finally {
      debugDisableShadows = true;
      t.platformDispatcher.clearAllTestValues();
    }
  }

  testWidgets('wardrobe (en)', (t) => run(t, '', S.en, const Locale('en', 'US')));
  testWidgets('wardrobe (th)', (t) => run(t, 'th_', S.thai, const Locale('th', 'TH')));
}
