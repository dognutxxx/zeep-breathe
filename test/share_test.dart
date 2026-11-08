import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/game/balance_game.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/screens/share_screen.dart';
import 'package:zeep_breathe/share/share_card.dart';

Widget wrap(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: S.supportedLocales,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

final day = DateTime(2026, 11, 20, 22, 30);

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// Width and height from a PNG's IHDR chunk.
(int, int) pngSize(Uint8List png) {
  final b = ByteData.sublistView(png);
  return (b.getUint32(16), b.getUint32(20));
}

void main() {
  testWidgets('streak card: days, line, total; three colours to pick', (t) async {
    phone(t);
    await t.pumpWidget(
      wrap(ShareScreen(achievement: StreakAchievement(day, days: 7, totalMinutes: 52), sharer: (_, _, _) async {})),
    );
    expect(find.text(S.en.cardDays(7)), findsOneWidget);
    expect(find.text(S.en.cardStreakLine), findsOneWidget);
    expect(find.text(S.en.cardTotal(52)), findsOneWidget);
    expect(find.text(S.en.dayHeading(day)), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget); // lavender picked
    await t.tap(find.byTooltip(S.en.cardThemeName(ShareCardColor.mint)));
    await t.pump();
    final picked = t.widget<ShareCard>(find.byType(ShareCard));
    expect(picked.theme, ShareCardColor.mint);
  });

  testWidgets('session and game cards (Thai)', (t) async {
    phone(t);
    await t.pumpWidget(
      wrap(
        ShareScreen(
          achievement: SessionAchievement(day, exerciseName: 'หายใจแบบ 4-7-8', minutes: 15, breaths: 47),
          sharer: (_, _, _) async {},
        ),
        locale: const Locale('th'),
      ),
    );
    expect(find.text(S.thai.minutes(15)), findsOneWidget);
    expect(find.text('หายใจแบบ 4-7-8'), findsOneWidget);
    expect(find.text(S.thai.cardBreaths(47)), findsOneWidget);
    expect(find.text(S.thai.cardFooter), findsOneWidget);

    await t.pumpWidget(
      wrap(
        ShareScreen(
          achievement: GameAchievement(day, level: BalanceLevel.hard, score: 96),
          sharer: (_, _, _) async {},
        ),
        locale: const Locale('th'),
      ),
    );
    expect(find.text('96%'), findsOneWidget);
    expect(find.text(S.thai.gameEntryName(BalanceLevel.hard)), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
  });

  testWidgets('Share hands a 1080 x 1350 PNG and the text to the share sheet', (t) async {
    phone(t);
    Uint8List? png;
    String? text;
    Rect? origin;
    await t.pumpWidget(
      wrap(
        ShareScreen(
          achievement: GameAchievement(day, level: BalanceLevel.easy, score: 88),
          sharer: (p, tx, o) async {
            png = p;
            text = tx;
            origin = o;
          },
        ),
      ),
    );
    await t.runAsync(() async {
      await t.tap(find.text(S.en.share));
      for (var i = 0; i < 50 && png == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(png, isNotNull);
    expect(pngSize(png!), (1080, 1350));
    expect(text, S.en.shareText);
    expect(origin, isNotNull); // iPad needs an anchor for the popover
  });

  testWidgets('sharing fails: a message, no crash, the button works again', (t) async {
    phone(t);
    var calls = 0;
    await t.pumpWidget(
      wrap(
        ShareScreen(
          achievement: StreakAchievement(day, days: 3, totalMinutes: 12),
          sharer: (_, _, _) async {
            calls++;
            throw StateError('no share sheet');
          },
        ),
      ),
    );
    await t.runAsync(() async {
      await t.tap(find.text(S.en.share));
      for (var i = 0; i < 50 && calls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await t.pump();
    expect(find.text(S.en.shareFailed), findsOneWidget);
    final button = t.widget<FilledButton>(
      find.ancestor(of: find.text(S.en.share), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNotNull);
  });
}
