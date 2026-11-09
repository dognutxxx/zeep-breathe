// The Breathe tab on very short screens scrolls instead of overflowing
// (JJ 1.6.0 #5: 360 x 640 Android phone with a 48 dp navigation bar).

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
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

/// The real Roboto: the default test font is much wider than any real one.
Future<void> loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\User\flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String n) async => ByteData.sublistView(await File('$dir/$n').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f('roboto-regular.ttf'))
        ..addFont(f('roboto-medium.ttf'))
        ..addFont(f('roboto-bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'))).load();
}

void main() {
  setUpAll(loadFonts);

  for (final (name, size, top, bottom) in [
    ('Android 360x640, 48 dp nav bar', const Size(360, 640), 24.0, 48.0),
    ('iPhone SE 375x667', const Size(375, 667), 20.0, 0.0),
    ('320x568', const Size(320, 568), 20.0, 0.0),
    ('iPhone 15 393x852', const Size(393, 852), 59.0, 34.0),
  ]) {
    testWidgets('Breathe tab fits or scrolls on $name (no overflow)', (t) async {
      t.view.physicalSize = size * 2;
      t.view.devicePixelRatio = 2;
      t.view.padding = FakeViewPadding(top: top * 2, bottom: bottom * 2);
      t.view.viewPadding = FakeViewPadding(top: top * 2, bottom: bottom * 2);
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsController();
      await settings.load();
      final app = AppController(settings: settings, haptics: HapticsService(), music: QuietMusic());
      await t.pumpWidget(ZeepBreatheApp(controller: app));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(t.takeException(), isNull);
      // Zeep is really drawn: full width, at least 150 high (1.6.0 gave it 0 px)
      final zeep = t.getSize(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ZeepPainter).first);
      expect(zeep.width, size.width, reason: 'Zeep area width');
      expect(zeep.height, greaterThanOrEqualTo(150));
      // Start is reachable (scroll to it if needed) and Zeep keeps some room
      await t.scrollUntilVisible(find.text(S.en.start), 80, scrollable: find.byType(Scrollable).first);
      expect(find.text(S.en.start).hitTestable(), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
