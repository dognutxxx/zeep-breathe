// Renders the app headlessly at iPhone 15 size and writes screenshots to
// tool/screens/, plus the 1024 px app icon to assets/icon/icon.png.
//
//   flutter test tool/screens_test.dart --update-goldens
//
// Used to check the UI on Windows, where the iOS simulator is not available.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/sheets.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

import 'screens_common.dart';

import 'package:zeep_breathe/ui/zeep_character.dart';

Future<void> _loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\User\flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String n) async => ByteData.sublistView(await File('$dir/$n').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f('roboto-regular.ttf'))
        ..addFont(f('roboto-medium.ttf'))
        ..addFont(f('roboto-bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'))).load();
}

Future<AppController> _makeApp() async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  final music = MusicService()..available = true; // not initialised: silent in tests
  return AppController(settings: settings, haptics: HapticsService(), music: music);
}

Future<void> _advance(WidgetTester t, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('screens', (t) async {
    // flutter_test replaces elevation shadows with black outlines by default;
    // must be restored before the test body ends.
    debugDisableShadows = false;
    try {
      await _screens(t);
    } finally {
      debugDisableShadows = true;
    }
  });

  for (final (name, size) in const [('ipad_portrait', Size(2048, 2732)), ('ipad_landscape', Size(2732, 2048))]) {
    testWidgets(name, (t) async {
      debugDisableShadows = false;
      try {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 2;
        t.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
        t.view.viewPadding = const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
        final app = await _makeApp();
        await t.pumpWidget(ZeepBreatheApp(controller: app));
        await _advance(t, 1.0);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/${name}_setup.png'));
        app.startSession();
        await _advance(t, 5.0);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/${name}_hold.png'));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  testWidgets('tabs', (t) async {
    debugDisableShadows = false;
    try {
      await tabsFlow(t, '', S.en);
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('game', (t) async {
    debugDisableShadows = false;
    try {
      await gameFlow(t, '', S.en);
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('app icon', (t) async {
    await _icon(t);
  });
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  t.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  t.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
}

Future<void> _screens(WidgetTester t) async {
  {
    phone(t);
    final app = await _makeApp();
    await t.pumpWidget(ZeepBreatheApp(controller: app));
    await _advance(t, 1.2);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/1_setup.png'));

    app.startSession();
    await _advance(t, 2.0);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/2_inhale.png'));
    await _advance(t, 2.8);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/3_hold.png'));
    await _advance(t, 3.0);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/4_exhale.png'));

    final ctx = t.element(find.byType(Scaffold));
    showSettingsSheet(ctx, app);
    await _advance(t, 0.8);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/5_settings.png'));
    Navigator.of(ctx).pop();
    await _advance(t, 0.6);

    app.engine.sessionElapsed = app.engine.sessionLength - 0.2;
    await _advance(t, 0.5);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/6_finished.png'));
    app.stopSession();
    await _advance(t, 0.3);

    showInstructionsSheet(t.element(find.byType(Scaffold)));
    await _advance(t, 0.8);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/7_instructions.png'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> _icon(WidgetTester t) async {
  {
    await t.runAsync(() async {
      const size = 1024.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F3FC), Color(0xFFCFE6F7)],
          ).createShader(const Rect.fromLTWH(0, 0, size, size)),
      );
      final pose = Pose(
        breath: 0.75,
        armLift: 0.75,
        cheekPuff: 0.45,
        eyeSqueeze: 0.1,
        mouthOpen: 0,
        hold: 0,
        tint: tintInhale,
      );
      // time 0.95 s: float near the middle of its bob, leaves open
      drawZeep(c, const Offset(size / 2, size * 0.53), 4.6, pose, 0.95, size * 0.53 + 92 * 4.6, const []);
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final out = File('assets/icon/icon.png')..createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}
