// Summary card and new-item card (N): on small and normal phones, with normal
// and large text, in Thai and English, the card never overflows and no line
// is left with a lone word (QA 2026-11-09, real iPhone fonts are wider).
// Uses Windows' Leelawadee UI (Thai + Latin); skipped where it is missing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/wardrobe_cards.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/ui/balanced_text.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

const _thaiFont = r'C:\Windows\Fonts\LeelawUI.ttf';

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

Future<void> loadFonts() async {
  Future<ByteData> f(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f(_thaiFont))
        ..addFont(f(r'C:\Windows\Fonts\LeelaUIb.ttf')))
      .load();
}

/// Lines of [text] as laid out at [width] (one entry per hard-break paragraph).
List<List<double>> lineWidths(String text, TextStyle style, double width, TextScaler scaler) => [
  for (final para in text.split('\n'))
    (() {
      final tp = TextPainter(
        text: TextSpan(text: para, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final w = [for (final m in tp.computeLineMetrics()) m.width];
      tp.dispose();
      return w;
    })(),
];

void main() {
  final hasFont = File(_thaiFont).existsSync();
  setUpAll(() async {
    if (hasFont) await loadFonts();
  });

  for (final (lang, _, locale) in [('en', S.en, const Locale('en', 'US')), ('th', S.thai, const Locale('th', 'TH'))]) {
    for (final size in const [Size(393, 852), Size(375, 667), Size(320, 568)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final card in const ['summary', 'newItem']) {
          testWidgets('$card card, $lang, ${size.width.toInt()} px, text x$scale', (t) async {
            t.view.physicalSize = size * 3;
            t.view.devicePixelRatio = 3;
            t.platformDispatcher.localesTestValue = [locale];
            t.platformDispatcher.localeTestValue = locale;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.view.reset);
            addTearDown(t.platformDispatcher.clearAllTestValues);
            SharedPreferences.setMockInitialValues({});
            final settings = SettingsController();
            await settings.load();
            final app = AppController(settings: settings, haptics: HapticsService(), music: QuietMusic());
            app.wardrobe.setForTest(steps: 4 * 4 + 3, practiceDays: 30);
            await t.pumpWidget(ZeepBreatheApp(controller: app));
            await t.pump(const Duration(milliseconds: 300));
            final ctx = t.element(find.byType(Scaffold).first);
            if (card == 'summary') {
              app.wardrobe.summaryPending = true;
              showSummaryCard(ctx, app);
            } else {
              showNewItemCards(ctx, app, [OutfitItem.sleepCap]);
            }
            for (var i = 0; i < 20; i++) {
              await t.pump(const Duration(milliseconds: 20));
            }
            expect(t.takeException(), isNull, reason: 'overflow');

            // every balanced text: no paragraph ends with a lone short line
            for (final e in find.byType(BalancedText).evaluate()) {
              final bt = e.widget as BalancedText;
              final text = find.descendant(of: find.byWidget(bt), matching: find.byType(Text));
              final width = t.getSize(text).width;
              final style = DefaultTextStyle.of(t.element(text)).style.merge(bt.style);
              for (final lines in lineWidths(bt.text, style, width, TextScaler.linear(scale))) {
                if (lines.length < 2) continue;
                final widest = lines.reduce((a, b) => a > b ? a : b);
                expect(lines.last, greaterThan(widest * 0.4), reason: '"${bt.text}" lines $lines');
              }
            }
            await t.pumpWidget(const SizedBox());
            await t.pump(const Duration(seconds: 1));
          }, skip: !hasFont);
        }
      }
    }
  }
}
