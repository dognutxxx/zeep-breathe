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

Widget app(TiltSource src, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: BalancePrototypeScreen(source: src),
);

Future<void> frames(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await t.pump(const Duration(microseconds: 16667));
  }
}

void main() {
  testWidgets('no readings: shows the no-sensor message instead of crashing', (t) async {
    final src = FakeTilt();
    await t.pumpWidget(app(src));
    await frames(t, 2.5);
    expect(find.text(S.en.noTiltSensor), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    unawaited(src.controller.close());
  });

  testWidgets('sensor error: shows the no-sensor message (Thai)', (t) async {
    await t.pumpWidget(app(ThrowingTilt(), locale: const Locale('th')));
    await frames(t, 0.2);
    expect(find.text(S.thai.noTiltSensor), findsOneWidget);
  });

  testWidgets('countdown, then Zeep follows the tilt', (t) async {
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
}
