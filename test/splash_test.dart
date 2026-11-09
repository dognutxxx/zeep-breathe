// Launch splash (1.9.0, dark, Zeep only): first frame matches the native launch
// screen, one real-time breath, waits while loading, tap to skip, Reduce Motion.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:zeep_breathe/ui/brand_colors.dart';

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

SplashPainter painter(WidgetTester t) =>
    t.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SplashPainter)).painter
        as SplashPainter;

/// The logo's rect(s) on screen.
List<Rect> logoRects(WidgetTester t) => [
  for (final e in find.byType(RawImage).evaluate())
    t.getRect(find.ancestor(of: find.byWidget(e.widget), matching: find.byType(Positioned)).first),
];

Widget reduced(Widget home) => MaterialApp(
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  home: home,
);

void main() {
  testWidgets('first frame: the Soft Paper logo 180 x 58 centred on Midnight; no Zeep, glow or stars yet', (t) async {
    phone(t);
    final boot = Completer<AppController>();
    final image = await t.runAsync(loadSplashLogo);
    expect(image, isNotNull);
    await t.pumpWidget(ZeepBreatheApp(boot: boot.future, splashLogo: image));
    expect(find.byType(SplashScreen), findsOneWidget);
    // drawn on the very first frame (no asset decode wait), tinted Soft Paper
    final raw = find.byWidgetPredicate((w) => w is RawImage && w.image == image);
    expect(raw, findsOneWidget);
    final img = t.widget<RawImage>(raw);
    expect(img.color, BrandColors.onDark);
    expect(img.colorBlendMode, BlendMode.srcIn);
    final r = t.getRect(find.ancestor(of: raw, matching: find.byType(Positioned)).first);
    expect(r.size, splashLogoSize);
    expect(r.center, const Offset(393 / 2, 852 / 2));
    expect(splashBackground, const Color(0xFF14213D));
    final p = painter(t);
    expect(p.stars, 0);
    expect(p.glowOpacity, 0);
    expect(p.zeepOpacity, 0);
    // only Zeep: no friend images anywhere
    expect(find.byType(Image), findsNothing);
    // light bar icons on the dark splash
    final region = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(of: find.byType(SplashScreen), matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>)),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(find.bySemanticsLabel('ZEEP Breathe'), findsOneWidget);
    boot.complete(await makeApp());
    await frames(t, 4.5);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('one breath in real time: stars, inhale, hold, exhale', (t) async {
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(ZeepBreatheApp(boot: Future.value(app)));
    final logo0 = logoRects(t).single;
    // 0.2 s: stars coming in, Zeep not yet
    await frames(t, 0.2);
    var p = painter(t);
    expect(p.stars, inInclusiveRange(0.2, 0.8));
    expect(p.zeepOpacity, 0);
    expect(logoRects(t).single, logo0);
    // 0.8 s: mid-inhale, Zeep fading in and rising, the glow growing
    await frames(t, 0.6);
    p = painter(t);
    expect(p.stars, 1);
    expect(p.zeepOpacity, inExclusiveRange(0.5, 1));
    expect(p.zeepScale, inExclusiveRange(0.96, 1.04));
    expect(p.glowOpacity, inExclusiveRange(0.1, 0.6));
    expect(p.zeepRise, inExclusiveRange(0, 1));
    // 1.6 s: inhale peak, the logo 120 px lower
    await frames(t, 0.8);
    p = painter(t);
    expect(p.zeepOpacity, 1);
    expect(p.zeepScale, closeTo(1.04, 0.002));
    expect(p.glowScale, closeTo(1, 0.002));
    expect(p.glowOpacity, closeTo(0.6, 0.01));
    expect(p.zeepRise, closeTo(0, 0.002));
    expect(logoRects(t).single.center.dy - logo0.center.dy, closeTo(splashLogoDrop, 0.5));
    // 2.0 s: hold, the glow at its brightest; Zeep holds his breath
    await frames(t, 0.4);
    p = painter(t);
    expect(p.glowOpacity, closeTo(0.6, 0.01));
    expect(p.pose.hold, greaterThan(0.9));
    // 3.4 s: breathed out, the glow dimmed, Zeep 0.98
    await frames(t, 1.4);
    p = painter(t);
    expect(p.zeepScale, closeTo(0.98, 0.003));
    expect(p.glowOpacity, lessThan(0.25));
    expect(p.pose.breath, lessThan(0.05));
    expect(find.byType(SplashScreen), findsOneWidget);
    await frames(t, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('loaded early: one breath (about 3.9 s), then the Breathe tab', (t) async {
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(ZeepBreatheApp(boot: Future.value(app)));
    await frames(t, 3.3);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    await frames(t, 0.7);
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
    // the slow waiting breath: Zeep changes size at the hold
    final a = painter(t).zeepScale;
    await frames(t, 1.5);
    final b = painter(t).zeepScale;
    expect((a - b).abs(), greaterThan(0.005));
    expect(b, inInclusiveRange(1.01, 1.04));
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
    // dark bar icons for the app again
    final region = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.ancestor(of: find.byType(HomePage), matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>)).first,
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Reduce Motion: nothing moves; fade in 0.3 s, hold, fade out 0.3 s', (t) async {
    phone(t);
    final app = await makeApp();
    await t.pumpWidget(reduced(LaunchGate(boot: Future.value(app))));
    // first frame still matches the native launch screen
    expect(logoRects(t).single.center, const Offset(393 / 2, 852 / 2));
    await frames(t, 0.15);
    var p = painter(t);
    expect(p.zeepOpacity, inExclusiveRange(0, 1));
    expect(p.reduceMotion, isTrue);
    // the centred logo hands over to the lower one in place (no sliding)
    final rects = logoRects(t);
    expect(rects, hasLength(2));
    expect(rects.map((r) => r.center.dy), containsAll([852 / 2, 852 / 2 + splashLogoDrop]));
    await frames(t, 0.25);
    p = painter(t);
    expect(p.zeepOpacity, 1);
    expect(p.zeepScale, 1);
    expect(p.zeepRise, 0);
    expect(p.glowScale, 1);
    final pose = p.pose;
    expect(logoRects(t).single.center.dy, closeTo(852 / 2 + splashLogoDrop, 0.5));
    await frames(t, 0.3);
    expect(painter(t).pose, same(pose));
    expect(painter(t).zeepScale, 1);
    await frames(t, 0.6);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Zeep, the glow and the logo fit: 320 px phone and iPad landscape', (t) async {
    addTearDown(t.view.reset);
    for (final (size, dpr) in [(const Size(640, 1136), 2.0), (const Size(2732, 2048), 2.0)]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = dpr;
      final screen = size / dpr;
      final boot = Completer<AppController>();
      await t.pumpWidget(ZeepBreatheApp(boot: boot.future));
      await frames(t, 2);
      final k = splashScale(screen);
      final c = SplashPainter.zeepCentre(screen, 0);
      final logo = logoRects(t).single;
      // the logo is below Zeep's floor shadow and on screen
      expect(logo.top, greaterThan(c.dy + 64 * k * 1.04), reason: '$screen');
      expect(logo.bottom, lessThan(screen.height), reason: '$screen');
      expect(logo.left, greaterThanOrEqualTo(0), reason: '$screen');
      // Zeep (about 75 px above his centre at the inhale peak) is on screen
      expect(c.dy - 90 * k, greaterThan(0), reason: '$screen');
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the one-off summary card waits until the splash is gone', (t) async {
    phone(t);
    final app = await makeApp();
    app.wardrobe.summaryPending = true;
    await t.pumpWidget(ZeepBreatheApp(boot: Future.value(app)));
    await frames(t, 3.6); // fading: the app is underneath now
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text(S.en.summaryTitle), findsNothing);
    await frames(t, 0.6);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text(S.en.summaryTitle), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
