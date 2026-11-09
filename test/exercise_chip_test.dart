// The rhythm chip ("Default · 4 · 2 · 6") and the music chip on the Breathe
// tab wrap instead of overflowing on a 320 px phone, in English and Thai, at
// 1.0x and 2.0x text. Uses the wide default test font on purpose: the worst
// case. Where lines break: exercise_chip_lines_test.dart (real fonts).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/setup_screen.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

void main() {
  test('chip text: a no-break space before every dot, a normal space after', () {
    expect(chipText('Custom', '12 · 10 · 14 · 11'), 'Custom · 12 · 10 · 14 · 11');
  });

  for (final locale in const [Locale('en'), Locale('th', 'TH')]) {
    for (final scale in const [1.0, 2.0]) {
      for (final (rhythm, d) in const [('default', null), ('custom 12/10/14/11', (12, 10, 14, 11))]) {
        testWidgets('rhythm and music chips fit a 320 px screen ($locale, ${scale}x text, $rhythm)', (t) async {
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
          // both chips stay inside the screen
          for (final icon in [Icons.air_rounded, Icons.music_note_rounded]) {
            final chip = find.byWidgetPredicate((w) => w is Icon && w.icon == icon);
            expect(chip, findsOneWidget);
            final row = t.getRect(find.ancestor(of: chip, matching: find.byType(Row)).first);
            expect(row.left, greaterThanOrEqualTo(0));
            expect(row.right, lessThanOrEqualTo(320));
          }
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
