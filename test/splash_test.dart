// Launch splash (1.9.1, dark, the zeep wordmark only): first frame matches the
// native launch screen, one gentle real-time breath, waits while loading, tap to
// skip, Reduce Motion, no character drawn.

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

Finder get wordmark => find.descendant(of: find.byType(SplashScreen), matching: find.byType(RawImage));

/// The wordmark's rect on screen, its breathing scale included.
Rect wordmarkRect(WidgetTester t) => t.getRect(wordmark);

/// The wordmark's breathing scale.
double wordmarkScale(WidgetTester t) => wordmarkRect(t).width / splashLogoSize.width;

const centre = Offset(393 / 2, 852 / 2);

void expectCentred(WidgetTester t) {
  final r = wordmarkRect(t);
  expect(r.center.dx, closeTo(centre.dx, 0.01));
  expect(r.center.dy, closeTo(centre.dy, 0.01));
}

/// Starts the app with the splash, the wordmark decoded first as `main()` does.
Future<void> launch(WidgetTester t, Future<AppController> boot) async {
  final logo = await t.runAsync(loadSplashLogo);
  await t.pumpWidget(ZeepBreatheApp(boot: boot, splashLogo: logo));
}

Widget reduced(Widget home) => MaterialApp(
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  home: home,
);

/// Only the background, at most one glow circle and the wordmark image: no
/// character (drawZeep draws paths, ovals and more circles).
void expectNoCharacter(WidgetTester t, {required int circles}) {
  final splash = t.renderObject(find.byType(SplashScreen));
  expect(splash, paintsExactlyCountTimes(#drawPath, 0));
  expect(splash, paintsExactlyCountTimes(#drawOval, 0));
  expect(splash, paintsExactlyCountTimes(#drawRRect, 0));
  expect(splash, paintsExactlyCountTimes(#drawDRRect, 0));
  expect(splash, paintsExactlyCountTimes(#drawArc, 0));
  expect(splash, paintsExactlyCountTimes(#drawLine, 0));
  expect(splash, paintsExactlyCountTimes(#drawCircle, circles));
  expect(splash, paintsExactlyCountTimes(#drawRect, 1));
  expect(splash, paintsExactlyCountTimes(#drawImageRect, 1));
}

void main() {
  testWidgets('first frame: the Soft Paper wordmark 180 x 58 at the exact centre on Midnight; no glow', (t) async {
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
    expect(wordmarkRect(t).size, splashLogoSize);
    expectCentred(t);
    expect(splashBackground, const Color(0xFF14213D));
    expect(painter(t).glowOpacity, 0);
    expectNoCharacter(t, circles: 0);
    // the wordmark only: no other images
    expect(find.byType(Image), findsNothing);
    // light bar icons on the dark splash
    final region = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(of: find.byType(SplashScreen), matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>)),
    );
    expect(region.value, splashBarsStyle);
    expect(region.value.statusBarIconBrightness, Brightness.light);
    await t.pump();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    expect(find.bySemanticsLabel('ZEEP Breathe'), findsOneWidget);
    boot.complete(await makeApp());
    await frames(t, 3.5);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('one gentle breath in real time: static, inhale, hold, exhale; always centred', (t) async {
    phone(t);
    await launch(t, makeApp());
    // 0.15 s: still static, as the native launch screen
    await frames(t, 0.15);
    expect(wordmarkScale(t), closeTo(1, 1e-9));
    expect(painter(t).glowOpacity, 0);
    expectCentred(t);
    // 0.7 s: mid-inhale (easeInOutSine half way), the glow growing
    await frames(t, 0.55);
    expect(wordmarkScale(t), closeTo(1.03, 0.003));
    expect(painter(t).glowOpacity, closeTo(splashPeakGlow / 2, 0.02));
    expectCentred(t);
    // 1.2 s: inhale peak
    await frames(t, 0.5);
    expect(wordmarkScale(t), closeTo(splashPeakScale, 0.001));
    expect(splashPeakScale, 1.06);
    expect(painter(t).glowOpacity, closeTo(0.45, 0.005));
    expectCentred(t);
    expectNoCharacter(t, circles: 1);
    // 1.5 s: hold, at the peak
    await frames(t, 0.3);
    expect(wordmarkScale(t), closeTo(1.06, 1e-6));
    expect(painter(t).glowOpacity, closeTo(0.45, 1e-6));
    // 2.0 s: mid-exhale (easeInOutCubic half way)
    await frames(t, 0.5);
    expect(wordmarkScale(t), closeTo(1.03, 0.003));
    expect(painter(t).glowOpacity, closeTo(splashPeakGlow / 2, 0.02));
    expectCentred(t);
    // 2.4 s: breathed out, the fade begins
    await frames(t, 0.4);
    expect(wordmarkScale(t), closeTo(1, 0.001));
    expect(painter(t).glowOpacity, closeTo(0, 0.005));
    expect(find.byType(SplashScreen), findsOneWidget);
    await frames(t, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('loaded early: one breath (about 2.9 s), then the Breathe tab', (t) async {
    phone(t);
    await launch(t, makeApp());
    await frames(t, 2.3);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    // fading out: the app goes underneath
    await frames(t, 0.3);
    expect(find.byType(HomePage), findsOneWidget);
    final fading = t.widget<Opacity>(
      find.descendant(of: find.byType(SplashScreen), matching: find.byType(Opacity)).first,
    );
    expect(fading.opacity, inExclusiveRange(0, 1));
    await frames(t, 0.4);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text(S.en.start), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('still loading: keeps breathing slowly at the hold, no app yet; continues once loaded', (t) async {
    phone(t);
    final boot = Completer<AppController>();
    await launch(t, boot.future);
    await frames(t, 10);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    // the slow waiting breath: the wordmark and the glow change at the hold
    final a = wordmarkScale(t), ga = painter(t).glowOpacity;
    await frames(t, 1.5);
    final b = wordmarkScale(t), gb = painter(t).glowOpacity;
    expect((a - b).abs(), greaterThan(0.005));
    expect((ga - gb).abs(), greaterThan(0.02));
    expect(b, inInclusiveRange(1.029, 1.06));
    expectCentred(t);
    // tapping does nothing while there is nothing to show
    await t.tap(find.byType(SplashScreen));
    await frames(t, 1);
    expect(find.byType(SplashScreen), findsOneWidget);
    boot.complete(await makeApp());
    // finishes the slow waiting breath (at most 4 s), then the exhale and fade
    await frames(t, 5.5);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('loaded while waiting: leaves the hold only at the top of the slow breath (no jump)', (t) async {
    phone(t);
    final boot = Completer<AppController>();
    await launch(t, boot.future);
    await frames(t, 3.6); // 2 s into the wait: the slow breath at its lowest
    expect(wordmarkScale(t), closeTo(1.03, 0.002));
    boot.complete(await makeApp());
    await t.pump();
    var last = wordmarkScale(t);
    var peak = last;
    // the wordmark goes back up to 1.06 before the exhale begins, smoothly
    for (var i = 0; i < 60 * 3; i++) {
      await t.pump(const Duration(microseconds: 16667));
      if (find.byType(SplashScreen).evaluate().isEmpty) break;
      final s = wordmarkScale(t);
      expect((s - last).abs(), lessThan(0.004));
      peak = s > peak ? s : peak;
      last = s;
    }
    expect(peak, greaterThan(1.059));
    await frames(t, 3);
    expect(find.byType(SplashScreen), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('tap to skip once loaded: the app at once, the splash gone in 0.3 s', (t) async {
    phone(t);
    await launch(t, makeApp());
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
    // and the system really got them (main() starts with the splash's light ones)
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Reduce Motion: no scale, no glow; still for 0.9 s, fade out 0.3 s', (t) async {
    phone(t);
    final app = await makeApp();
    final logo = await t.runAsync(loadSplashLogo);
    await t.pumpWidget(reduced(LaunchGate(boot: Future.value(app), logo: logo)));
    // first frame still matches the native launch screen
    expectCentred(t);
    for (final step in [0.15, 0.25, 0.3, 0.15]) {
      await frames(t, step);
      expect(wordmarkScale(t), 1);
      expect(painter(t).glowOpacity, 0);
      expectCentred(t);
      expectNoCharacter(t, circles: 0);
    }
    // 0.85 s: not fading yet; 1.05 s: fading, the app underneath
    expect(find.byType(HomePage), findsNothing);
    await frames(t, 0.2);
    expect(find.byType(HomePage), findsOneWidget);
    await frames(t, 0.2);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the wordmark and the glow fit: 320 px phone and iPad landscape, centred', (t) async {
    addTearDown(t.view.reset);
    for (final (size, dpr) in [(const Size(640, 1136), 2.0), (const Size(2732, 2048), 2.0)]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = dpr;
      final screen = size / dpr;
      final boot = Completer<AppController>();
      await launch(t, boot.future);
      await frames(t, 1.3);
      final r = wordmarkRect(t);
      expect(r.center.dx, closeTo(screen.width / 2, 0.01), reason: '$screen');
      expect(r.center.dy, closeTo(screen.height / 2, 0.01), reason: '$screen');
      expect(r.width, closeTo(180 * 1.06, 0.2), reason: '$screen');
      // the glow is on screen and wider than the breathing wordmark
      final g = SplashPainter.glowRadius(screen);
      expect(g * 2, lessThanOrEqualTo(screen.width), reason: '$screen');
      expect(g, greaterThan(r.width / 2), reason: '$screen');
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the one-off summary card waits until the splash is gone', (t) async {
    phone(t);
    final app = await makeApp();
    app.wardrobe.summaryPending = true;
    await launch(t, Future.value(app));
    await frames(t, 2.6); // fading: the app is underneath now
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text(S.en.summaryTitle), findsNothing);
    await frames(t, 0.6);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text(S.en.summaryTitle), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
