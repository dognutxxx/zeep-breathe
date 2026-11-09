// Where the rhythm chip on the Breathe tab wraps (JJ splash-dark round 3 #2):
// a wrapped line never starts with "·" ("Custom · 12 · 10 ·" / "14 · 11").
// Needs a real proportional font: the default test font is so wide that
// it breaks inside words. Uses Windows' Leelawadee UI (Latin + Thai, as in
// tool/screens_th_test.dart); without it (e.g. Codemagic's Mac) English runs
// with Flutter's Roboto and Thai is skipped.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

const _leelawadee = [r'C:\Windows\Fonts\LeelawUI.ttf', r'C:\Windows\Fonts\LeelaUIb.ttf'];
final _hasThaiFont = _leelawadee.every((f) => File(f).existsSync());

Future<void> _loadFonts() async {
  Future<ByteData> f(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\User\flutter'}/bin/cache/artifacts/material_fonts';
  final files = _hasThaiFont
      ? _leelawadee
      : ['$dir/roboto-regular.ttf', '$dir/roboto-medium.ttf', '$dir/roboto-bold.ttf'];
  final roboto = FontLoader('Roboto');
  for (final file in files) {
    roboto.addFont(f(file));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(f('$dir/materialicons-regular.otf'))).load();
}

/// The text of each line of [p], laid out again the same way (text, scale,
/// alignment, width) with a TextPainter, which can report line boundaries.
List<String> lines(RenderParagraph p) {
  final tp = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textAlign: p.textAlign,
    textScaler: p.textScaler,
    locale: p.locale,
  )..layout(maxWidth: p.size.width);
  final text = p.text.toPlainText();
  final out = <String>[];
  var i = 0;
  while (i < text.length) {
    final b = tp.getLineBoundary(TextPosition(offset: i));
    final end = b.end > i ? b.end : i + 1;
    out.add(text.substring(i, end));
    i = end;
  }
  tp.dispose();
  return out;
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('en'), Locale('th', 'TH')]) {
    for (final scale in const [1.0, 2.0]) {
      for (final (rhythm, d) in const [('default', null), ('custom 12/10/14/11', (12, 10, 14, 11))]) {
        testWidgets(
          'rhythm chip on 320 px: no line starts with "·" ($locale, ${scale}x text, $rhythm)',
          skip: locale.languageCode == 'th' && !_hasThaiFont,
          (t) async {
            t.view.physicalSize = const Size(320, 568) * 2;
            t.view.devicePixelRatio = 2;
            t.platformDispatcher.localeTestValue = locale;
            t.platformDispatcher.localesTestValue = [locale];
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.view.reset);
            addTearDown(t.platformDispatcher.clearAllTestValues);
            SharedPreferences.setMockInitialValues({});
            final settings = SettingsController();
            await settings.load();
            if (d != null) {
              settings.update((s) {
                s.inhale = d.$1;
                s.hold = d.$2;
                s.exhale = d.$3;
                s.rest = d.$4;
              }, persist: false);
            }
            final app = AppController(settings: settings, haptics: HapticsService(), music: QuietMusic());
            await t.pumpWidget(ZeepBreatheApp(controller: app));
            for (var i = 0; i < 30; i++) {
              await t.pump(const Duration(milliseconds: 16));
            }
            expect(t.takeException(), isNull);
            final row = find.ancestor(
              of: find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.air_rounded),
              matching: find.byType(Row),
            );
            final para = t.renderObject<RenderParagraph>(
              find.descendant(
                of: row.first,
                matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('·')),
              ),
            );
            final ls = lines(para);
            // the long custom rhythm does wrap at 2.0x, so the rule is exercised
            if (d != null && scale == 2.0) expect(ls.length, greaterThan(1), reason: '$ls');
            for (final l in ls) {
              expect(l.trimLeft().startsWith('·'), isFalse, reason: '$ls');
            }
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
