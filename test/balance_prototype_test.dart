import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/screens/balance_prototype_screen.dart';
import 'package:zeep_breathe/tilt/tilt_physics.dart';
import 'package:zeep_breathe/tilt/tilt_sensor.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';

class FakeTilt implements TiltSource {
  final controller = StreamController<Vec3>();
  @override
  Stream<Vec3> readings() => controller.stream;
}

class ThrowingTilt implements TiltSource {
  @override
  Stream<Vec3> readings() => Stream.error(UnsupportedError('no sensor'));
}

Widget app(TiltSource src, {Locale locale = const Locale('en'), bool upsideDownCheck = true}) => MaterialApp(
  locale: locale,
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: BalancePrototypeScreen(source: src, detectUpsideDown: upsideDownCheck),
);

void landscape(WidgetTester t) {
  t.view.physicalSize = const Size(2556, 1179);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// A phone-sized portrait view (the default test view is 800×600 landscape).
void portrait(WidgetTester t) {
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
  testWidgets('no readings: shows the no-sensor message instead of crashing', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    await frames(t, 2.5);
    expect(find.text(S.en.noTiltSensor), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('sensor error: shows the no-sensor message (Thai)', (t) async {
    portrait(t);
    await t.pumpWidget(app(ThrowingTilt(), locale: const Locale('th')));
    await frames(t, 0.2);
    expect(find.text(S.thai.noTiltSensor), findsOneWidget);
  });

  testWidgets('countdown, then Zeep follows the tilt', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 0.2);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await frames(t, 3.2);
    expect(find.text(S.en.holdComfortably), findsNothing);
    final start = t.getTopLeft(find.byType(ZeepAvatar));

    // held still: Zeep does not move
    await frames(t, 1.0);
    expect(t.getTopLeft(find.byType(ZeepAvatar)), start);

    // lower the right edge: Zeep rolls right
    src.controller.add(const Vec3(-2.5, 0, 9.5));
    await frames(t, 0.6);
    expect(t.getTopLeft(find.byType(ZeepAvatar)).dx, greaterThan(start.dx + 20));
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('sensor fails mid-game: shows the no-sensor message', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    expect(find.text(S.en.resetCentre), findsOneWidget);
    src.controller.addError(StateError('sensor lost'));
    await frames(t, 0.1);
    expect(find.text(S.en.noTiltSensor), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  for (final (locale, text) in [(const Locale('en'), S.en.turnUpright), (const Locale('th'), S.thai.turnUpright)]) {
    testWidgets('landscape (${locale.languageCode}): asks to turn upright, Zeep ignores tilt', (t) async {
      landscape(t);
      final src = FakeTilt();
      await t.pumpWidget(app(src, locale: locale));
      src.controller.add(const Vec3(0, 0, 9.81));
      await frames(t, 4);
      expect(find.text(text), findsOneWidget);
      final start = t.getTopLeft(find.byType(ZeepAvatar));
      for (var i = 0; i < 30; i++) {
        src.controller.add(const Vec3(-4, 2, 8.7));
        await frames(t, 0.05);
      }
      expect(t.getTopLeft(find.byType(ZeepAvatar)), start);
      await t.pumpWidget(const SizedBox());
      unawaited(src.controller.close());
    });
  }

  testWidgets('rotating mid-game pauses, then upright again counts 3-2-1 and re-centres', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 0, 9.81));
    await frames(t, 3.5);
    expect(find.text(S.en.resetCentre), findsOneWidget);
    expect(find.text(S.en.turnUpright), findsNothing);

    landscape(t);
    await frames(t, 0.2);
    expect(find.text(S.en.turnUpright), findsOneWidget);

    portrait(t);
    await frames(t, 0.2);
    expect(find.text(S.en.turnUpright), findsNothing);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    await frames(t, 3.2);
    expect(find.text(S.en.holdComfortably), findsNothing);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('held upside down (Android): asks to turn upright until righted', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    src.controller.add(const Vec3(0, 9.81, 0));
    await frames(t, 3.5);
    final start = t.getTopLeft(find.byType(ZeepAvatar));
    src.controller.add(const Vec3(0, -9.81, 0));
    await frames(t, 0.2);
    expect(find.text(S.en.turnUpright), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      src.controller.add(const Vec3(-3, -9.3, 0));
      await frames(t, 0.05);
    }
    expect(t.getTopLeft(find.byType(ZeepAvatar)), start);
    src.controller.add(const Vec3(0, 9.81, 0));
    await frames(t, 0.2);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('upside-down check off (iOS): gravity alone never pauses', (t) async {
    portrait(t);
    final src = FakeTilt();
    await t.pumpWidget(app(src, upsideDownCheck: false));
    src.controller.add(const Vec3(0, -9.81, 0));
    await frames(t, 0.2);
    expect(find.text(S.en.turnUpright), findsNothing);
    expect(find.text(S.en.holdComfortably), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });
}
