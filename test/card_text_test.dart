// Summary card, new-item card (N), the friend cards and the friends picker
// (1.7.0): on small and normal phones, with normal
// and large text, in Thai and English, the card never overflows and no line
// is left with a lone word (QA 2026-11-09, real iPhone fonts are wider).
// Uses Windows' Leelawadee UI (Thai + Latin); skipped where it is missing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/l10n/strings.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/screens/friend_cards.dart';
import 'package:zeep_breathe/screens/friends_sheet.dart';
import 'package:zeep_breathe/screens/wardrobe_screen.dart';
import 'package:zeep_breathe/screens/wardrobe_cards.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/ui/balanced_text.dart';
import 'package:zeep_breathe/ui/friends/friend_painter.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

const _thaiFont = r'C:\Windows\Fonts\LeelawUI.ttf';

class QuietMusic extends MusicService {
  @override
  void update(double dt, bool want, int track) {}
  @override
  void stopNow() {}
}

Future<void> loadFonts() async {
  Future<ByteData> f(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f(_thaiFont))
        ..addFont(f(r'C:\Windows\Fonts\LeelaUIb.ttf')))
      .load();
}

/// Lines of [text] as laid out at [width] (one entry per hard-break paragraph).
List<List<double>> lineWidths(String text, TextStyle style, double width, TextScaler scaler) => [
  for (final para in text.split('\n'))
    (() {
      final tp = TextPainter(
        text: TextSpan(text: para, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final w = [for (final m in tp.computeLineMetrics()) m.width];
      tp.dispose();
      return w;
    })(),
];

void main() {
  final hasFont = File(_thaiFont).existsSync();
  setUpAll(() async {
    if (hasFont) await loadFonts();
  });

  test('balanced widths are cached: a rebuild every frame does no new layout (Pim r2 #1)', () {
    const style = TextStyle(fontSize: 14);
    const text = 'Hi, I am a greeting that wraps onto two lines in a narrow bubble.';
    final before = balancedLayouts;
    final a = balancedWidth(text, style, 180, TextScaler.noScaling, TextDirection.ltr);
    expect(balancedLayouts, before + 1);
    for (var i = 0; i < 60; i++) {
      expect(balancedWidth(text, style, 180, TextScaler.noScaling, TextDirection.ltr), a);
    }
    expect(balancedLayouts, before + 1);
    // any change in the key works it out again
    balancedWidth(text, style, 200, TextScaler.noScaling, TextDirection.ltr);
    balancedWidth(text, style, 180, const TextScaler.linear(1.3), TextDirection.ltr);
    balancedWidth(text, style.copyWith(fontSize: 15), 180, TextScaler.noScaling, TextDirection.ltr);
    balancedWidth(text, style, 180, TextScaler.noScaling, TextDirection.ltr, hug: true);
    balancedWidth('$text!', style, 180, TextScaler.noScaling, TextDirection.ltr);
    expect(balancedLayouts, before + 6);
  });

  test('a hugging balanced text (picker badge) is as wide as its one line', () {
    const style = TextStyle(fontSize: 12.5);
    const scaler = TextScaler.noScaling;
    final one = balancedWidth('In use', style, 300, scaler, TextDirection.ltr, hug: true);
    expect(one, lessThan(100));
    expect(balancedWidth('In use', style, 300, scaler, TextDirection.ltr), 300);
    // two lines: the same balanced width with or without hug
    const long = 'A new friend is here, come and say hello to them!';
    expect(
      balancedWidth(long, style, 150, scaler, TextDirection.ltr, hug: true),
      balancedWidth(long, style, 150, scaler, TextDirection.ltr),
    );
  });

  for (final (lang, _, locale) in [('en', S.en, const Locale('en', 'US')), ('th', S.thai, const Locale('th', 'TH'))]) {
    for (final size in const [Size(393, 852), Size(375, 667), Size(320, 568)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final card in const [
          'summary',
          'newItem',
          'friend3',
          'friend10',
          'friendsBoth',
          'friendLater1',
          'friendLater3',
          'picker',
          'pickerDay100',
          'garden',
          'greetMun',
          'greetTuntun',
          'greetNuan',
          'pickerDay0',
          'pickerDay5',
          // 1.9.0: Saisai and Wongwong
          'friendLater2',
          'pickerDay160',
          'pickerDay210',
          'greetSaisai',
          'greetWongwong',
          // round 3: the single cards of the 1.9.0 friends
          'friendSaisai',
          'friendWongwong',
        ]) {
          testWidgets('$card card, $lang, ${size.width.toInt()} px, text x$scale', (t) async {
            t.view.physicalSize = size * 3;
            t.view.devicePixelRatio = 3;
            t.platformDispatcher.localesTestValue = [locale];
            t.platformDispatcher.localeTestValue = locale;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.view.reset);
            addTearDown(t.platformDispatcher.clearAllTestValues);
            SharedPreferences.setMockInitialValues({});
            final settings = SettingsController();
            await settings.load();
            final app = AppController(settings: settings, haptics: HapticsService(), music: QuietMusic());
            // the picker also before day 3 ("Miu or Lumi" row) and at day 5 with
            // no pick yet (the highlighted "choose a new friend" row)
            final days = switch (card) {
              'pickerDay0' => 0,
              'pickerDay5' => 5,
              'pickerDay100' || 'greetMun' || 'greetTuntun' || 'greetNuan' => 120,
              'pickerDay160' => 160,
              'pickerDay210' || 'greetSaisai' || 'greetWongwong' => 210,
              _ => 30,
            };
            app.wardrobe.setForTest(steps: 4 * 4 + 3, practiceDays: days);
            await t.pumpWidget(ZeepBreatheApp(controller: app));
            await t.pump(const Duration(milliseconds: 300));
            final ctx = t.element(find.byType(Scaffold).first);
            switch (card) {
              case 'summary':
                app.wardrobe.summaryPending = true;
                showSummaryCard(ctx, app);
              case 'newItem':
                showNewItemCards(ctx, app, [OutfitItem.sleepCap]);
              case 'greetMun' || 'greetTuntun' || 'greetNuan' || 'greetSaisai' || 'greetWongwong':
                // the T1 greeting bubble of each new friend (QA r2 #2)
                app.wardrobe.selectCharacter(switch (card) {
                  'greetMun' => Character.mun,
                  'greetTuntun' => Character.tuntun,
                  'greetSaisai' => Character.saisai,
                  'greetWongwong' => Character.wongwong,
                  _ => Character.nuan,
                });
              case 'garden':
                // the garden tab's hint (1.8.0 #8)
                openWardrobe(ctx, app, tab: 1);
              case 'pickerDay0' || 'pickerDay5':
                expect(app.wardrobe.friendChoicePending, card == 'pickerDay5');
                openFriends(ctx, app);
              case 'picker' || 'pickerDay100' || 'pickerDay160' || 'pickerDay210':
                app.wardrobe.chooseFirstFriend(Character.lumi);
                openFriends(ctx, app);
              default:
                // the friend cards (1.7.0): day 3, day 10, both at once;
                // 1.8.0: day 30/60/100, one friend or several at once (all
                // five later friends: rows of three); 1.9.0: Saisai and Wongwong
                final kind = switch (card) {
                  'friend3' => FriendCard.day3,
                  'friend10' => FriendCard.day10,
                  'friendLater1' ||
                  'friendLater2' ||
                  'friendLater3' ||
                  'friendSaisai' ||
                  'friendWongwong' => FriendCard.later,
                  _ => FriendCard.both,
                };
                showDialog<Character>(
                  context: ctx,
                  builder: (_) => FriendCardDialog(
                    card: kind,
                    chosen: Character.miu,
                    later: switch (card) {
                      'friendLater1' => const [Character.tuntun],
                      'friendLater2' => const [Character.saisai, Character.wongwong],
                      'friendSaisai' => const [Character.saisai],
                      'friendWongwong' => const [Character.wongwong],
                      _ => laterFriends,
                    },
                  ),
                );
            }
            for (var i = 0; i < 20; i++) {
              await t.pump(const Duration(milliseconds: 20));
            }
            expect(t.takeException(), isNull, reason: 'overflow');
            final l = lang == 'th' ? S.thai : S.en;
            if (card.startsWith('greet')) {
              final c = app.wardrobe.activeCharacter;
              expect(c, isNot(Character.zeep));
              // balanced, so the loop below checks it for a lone last word
              expect(find.widgetWithText(BalancedText, l.greetingOf(c)), findsOneWidget);
            }
            if (card.startsWith('friend')) {
              final dialog = find.byType(FriendCardDialog);
              // every tile the same height, its name on one line (QA r2 #1)
              final tiles = find.descendant(of: dialog, matching: find.byType(LiveFriend));
              final heights = {
                for (final e in tiles.evaluate())
                  t.getSize(find.ancestor(of: find.byWidget(e.widget), matching: find.byType(Material)).first).height,
              };
              expect(heights.length, 1, reason: 'tile heights $heights');
              for (final e in find.descendant(of: dialog, matching: find.byType(FittedBox)).evaluate()) {
                final text = find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text));
                expect(t.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse);
              }
              // the number in the title stays with its word ("3 ตัว", "3 more")
              final title = find.descendant(of: dialog, matching: find.byType(BalancedText)).first;
              final text = find.descendant(of: title, matching: find.byType(Text));
              final para = t.renderObject<RenderParagraph>(text);
              final str = (t.widget<Text>(text)).data!;
              final digit = str.indexOf(RegExp(r'[0-9]'));
              if (digit >= 0) {
                // the number, the space and the next word ("3 ตัว", "3 more"):
                // one line, so every box has the same top
                final end = str.indexOf(RegExp(r'[ ⁠]|$'), digit + 2);
                final boxes = para.getBoxesForSelection(TextSelection(baseOffset: digit, extentOffset: end));
                expect(boxes.map((b) => b.top).toSet(), hasLength(1), reason: '"$str" splits after the number');
              }
            }
            if (card == 'garden') {
              // balanced, so the loop below checks it for a lone word
              await t.scrollUntilVisible(find.text(l.gardenHint), 200, scrollable: find.byType(Scrollable).last);
              expect(find.widgetWithText(BalancedText, l.gardenHint), findsOneWidget);
            }
            if (card == 'pickerDay5') {
              // the badge "มีเพื่อนใหม่มาหาแล้ว!" is balanced, checked below (QA #2)
              expect(find.widgetWithText(BalancedText, l.newFriendTitle), findsOneWidget);
            }
            if (card == 'pickerDay0') {
              // the grey row shows the wait, not "choose" (QA #3)
              expect(find.text(l.firstFriendWhen(3, 3)), findsOneWidget);
              // balanced, so the loop below checks it for a lone word (QA r2 #1)
              expect(find.widgetWithText(BalancedText, l.firstFriendWhen(3, 3)), findsOneWidget);
              expect(find.text(l.chooseNewFriend), findsNothing);
            }

            // no Thai word splits across lines: a word joiner (U+2060) holds the
            // letters on both sides on one line ("ลอย⁠ขึ้น", "กาง⁠ออก", "มา⁠หา⁠แล้ว",
            // QA 1.9.0 #4). Every text on screen: greetings, card titles,
            // taglines, names
            for (final e in find.byType(RichText).evaluate()) {
              final para = e.renderObject! as RenderParagraph;
              final str = para.text.toPlainText();
              if (!str.contains('\u2060')) continue;
              // the same layout as on screen
              final tp = TextPainter(
                text: para.text,
                textDirection: para.textDirection,
                textAlign: para.textAlign,
                textScaler: para.textScaler,
              )..layout(maxWidth: para.constraints.maxWidth);
              for (var i = 1; i < str.length - 1; i++) {
                if (str.codeUnitAt(i) != 0x2060) continue;
                // the line the letters on both sides of the joiner are on
                int line(int at) => tp.getLineBoundary(TextPosition(offset: at)).start;
                expect(line(i - 1), line(i + 1), reason: '"$str" splits a word at $i');
              }
              tp.dispose();
            }

            // every balanced text: no paragraph ends with a lone short line
            for (final e in find.byType(BalancedText).evaluate()) {
              final bt = e.widget as BalancedText;
              final text = find.descendant(of: find.byWidget(bt), matching: find.byType(Text));
              final width = t.getSize(text).width;
              final style = DefaultTextStyle.of(t.element(text)).style.merge(bt.style);
              for (final lines in lineWidths(bt.text, style, width, TextScaler.linear(scale))) {
                if (lines.length < 2) continue;
                final widest = lines.reduce((a, b) => a > b ? a : b);
                expect(lines.last, greaterThan(widest * 0.4), reason: '"${bt.text}" lines $lines');
              }
            }
            // short badges that fit stay on one line (the hug width is never
            // a hair too narrow, Pim r2 #1)
            for (final short in [l.inUse, l.tapToSwitch]) {
              for (final e in find.widgetWithText(BalancedText, short).evaluate()) {
                final text = find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text));
                final para = t.renderObject<RenderParagraph>(text);
                // room the badge has: the row's text column less its padding
                final room = t.getSize(find.ancestor(of: text, matching: find.byType(Column)).first).width - 18;
                final style = DefaultTextStyle.of(t.element(text)).style.merge((e.widget as BalancedText).style);
                if (lineWidths(short, style, room, TextScaler.linear(scale)).first.length > 1) continue;
                expect(
                  para
                      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: short.length))
                      .map((b) => b.top)
                      .toSet()
                      .length,
                  1,
                  reason: '"$short" wraps',
                );
              }
            }
            await t.pumpWidget(const SizedBox());
            await t.pump(const Duration(seconds: 1));
          }, skip: !hasFont);
        }
      }
    }
  }
}
