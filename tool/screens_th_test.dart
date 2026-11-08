// Thai screenshots: same flow as screens_test.dart with the phone set to
// Thai. Uses Windows' Leelawadee UI font, since Roboto has no Thai glyphs
// (on iPhone the system Thai font is used).
//
//   flutter test tool/screens_th_test.dart --update-goldens

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/sheets.dart';

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

void main() {
  setUpAll(_loadFonts);

  void thai(WidgetTester t) {
    t.platformDispatcher.localesTestValue = const [Locale('th', 'TH')];
    t.platformDispatcher.localeTestValue = const Locale('th', 'TH');
  }

  testWidgets('tabs (th)', (t) async {
    debugDisableShadows = false;
    try {
      thai(t);
      await tabsFlow(t, 'th_', S.thai);
    } finally {
      debugDisableShadows = true;
      t.platformDispatcher.clearAllTestValues();
    }
  });

  testWidgets('game (th)', (t) async {
    debugDisableShadows = false;
    try {
      thai(t);
      await gameFlow(t, 'th_', S.thai);
    } finally {
      debugDisableShadows = true;
      t.platformDispatcher.clearAllTestValues();
    }
  });

  testWidgets('share cards (th)', (t) async {
    debugDisableShadows = false;
    try {
      thai(t);
      await shareFlow(t, 'th_', S.thai);
    } finally {
      debugDisableShadows = true;
      t.platformDispatcher.clearAllTestValues();
    }
  });

  testWidgets('sheets (th)', (t) async {
    debugDisableShadows = false;
    try {
      thai(t);
      phone(t);
      final app = await makeApp();
      await t.pumpWidget(ZeepBreatheApp(controller: app));
      await advance(t, 0.5);
      showSettingsSheet(t.element(find.byType(Scaffold)), app);
      await advance(t, 0.8);
      await shot('screens/th_5_settings.png');
      Navigator.of(t.element(find.byType(Scaffold).first)).pop();
      await advance(t, 0.6);
      showInstructionsSheet(t.element(find.byType(Scaffold)));
      await advance(t, 0.8);
      await shot('screens/th_7_instructions.png');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    } finally {
      debugDisableShadows = true;
      t.platformDispatcher.clearAllTestValues();
    }
  });
}
