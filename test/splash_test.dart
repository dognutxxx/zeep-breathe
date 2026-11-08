// Launch splash (1.6.0): first frame matches the native launch screen, the app
// loads in parallel, waits while loading, tap to skip, Reduce Motion.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/splash_screen.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

Future<AppController> makeApp() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  return AppController(settings: settings, haptics: HapticsService(), music: QuietMusic())
    ..clock = (() => DateTime(2026, 11, 20, 22, 30));
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> frames(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
}


void main() {
  testWidgets('first frame: the logo 180 x 58, centred on the whole screen, on the launch colour', (t) async {
    phone(t);
    final boot = Completer<AppController>();
    final image = await t.runAsync(loadSplashLogo);
    expect(image, isNotNull);
    await t.pumpWidget(ZeepBreatheApp(boot: boot.future, splashLogo: image));
    expect(find.byType(SplashScreen), findsOneWidget);
    // drawn on the very first frame (no asset decode wait)
    final raw = find.byWidgetPredicate((w) => w is RawImage && w.image == image);
    expect(raw, findsOneWidget);
    final r = t.getRect(find.ancestor(of: raw, matching: find.byType(Positioned)).first);
    expect(r.size, splashLogoSize);
    expect(r.center, const Offset(393 / 2, 852 / 2));
    final bg = t.widget<ColoredBox>(
      find.descendant(of: find.byType(SplashScreen), matching: find.byType(ColoredBox)).first,
    );
    expect(bg.color, splashBackground);
    // the friends are not out yet
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image == const AssetImage('assets/splash/miu_0.png')),
      findsOneWidget,
    );
    boot.complete(await makeApp());
    await frames(t, 4.5);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('loaded early: one breath at half speed (about 3.8 s), then the Breathe tab', (t) async {
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(ZeepBreatheApp(boot: Future.value(app)));
    await frames(t, 2.0);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    await frames(t, 2.2);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text(S.en.start), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('still loading: keeps breathing at the hold, no app yet; continues once loaded', (t) async {
    phone(t);
    final boot = Completer<AppController>();
    await t.pumpWidget(ZeepBreatheApp(boot: boot.future));
    await frames(t, 10);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    // tapping does nothing while there is nothing to show
    await t.tap(find.byType(SplashScreen));
    await frames(t, 1);
    expect(find.byType(SplashScreen), findsOneWidget);
    boot.complete(await makeApp());
    // finishes the slow waiting breath (at most 4 s), then the exhale and fade
    await frames(t, 6);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('tap to skip once loaded: the app at once, the splash gone in 0.3 s', (t) async {
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(ZeepBreatheApp(boot: Future.value(app)));
    await frames(t, 1);
    await t.tap(find.byType(SplashScreen));
    await t.pump();
    await t.pump();
    expect(find.byType(HomePage), findsOneWidget);
    await frames(t, 0.4);
    expect(find.byType(SplashScreen), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Reduce Motion: friends fade in place, the splash is gone in about 1 s', (t) async {
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(
      MaterialApp(
        supportedLocales: S.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: LaunchGate(boot: Future.value(app)),
      ),
    );
    await frames(t, 0.4);
    // friends are at their slots already (no drifting): Miu stays put
    final miu = find.ancestor(
      of: find.byWidgetPredicate((w) => w is Image && w.image == const AssetImage('assets/splash/miu_0.png')),
      matching: find.byType(Positioned),
    );
    final before = t.getRect(miu.first);
    await frames(t, 0.15);
    expect(t.getRect(miu.first), before);
    await frames(t, 0.7);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
