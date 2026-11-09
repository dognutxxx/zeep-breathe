// Miu and Lumi painters (1.7.0): they stay inside their box at every lung
// level with every flower, breathe the way the doc says, wear the flower at
// their anchor, and the Breathe tab / session still draw Zeep with ZeepPainter.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';
import 'package:zeep_breathe/ui/friends/character_view.dart';
import 'package:zeep_breathe/ui/friends/friend_painter.dart';
import 'package:zeep_breathe/ui/friends/lumi_painter.dart';
import 'package:zeep_breathe/ui/friends/miu_painter.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';

const _margin = 30;

/// Paints into a [size] box with a margin around it; returns the RGBA bytes
/// of the whole picture (box at [_margin], [_margin]).
Future<(ByteData, int, int)> render(CustomPainter p, Size size) async {
  final w = size.width.ceil() + 2 * _margin, h = size.height.ceil() + 2 * _margin;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..translate(_margin.toDouble(), _margin.toDouble());
  p.paint(c, size);
  final img = await rec.endRecording().toImage(w, h);
  final data = (await img.toByteData())!;
  img.dispose();
  return (data, w, h);
}

/// Bounding box of everything drawn (alpha > [minAlpha]), in box coordinates.
Rect? inkBounds(ByteData d, int w, int h, {int minAlpha = 8}) {
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (d.getUint8((y * w + x) * 4 + 3) > minAlpha) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return Rect.fromLTRB(
    (minX - _margin).toDouble(),
    (minY - _margin).toDouble(),
    (maxX + 1 - _margin).toDouble(),
    (maxY + 1 - _margin).toDouble(),
  );
}

/// Bounding box of the pixels that differ between two renders.
Rect? diffBounds((ByteData, int, int) a, (ByteData, int, int) b) {
  final (da, w, h) = a;
  final (db, _, _) = b;
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      var diff = 0;
      for (var k = 0; k < 4; k++) {
        diff += (da.getUint8(i + k) - db.getUint8(i + k)).abs();
      }
      if (diff > 30) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return Rect.fromLTRB(
    (minX - _margin).toDouble(),
    (minY - _margin).toDouble(),
    (maxX + 1 - _margin).toDouble(),
    (maxY + 1 - _margin).toDouble(),
  );
}

/// Box size to SVG units: the painter fits a 224-unit box (200 + 12 margin).
Offset toBox(Offset svg, Size size) {
  final k = size.shortestSide / 224;
  return Offset(size.width / 2 + (svg.dx - 100) * k, size.height / 2 + (svg.dy - 100) * k);
}

void main() {
  test('every friend, flower and lung level stays inside the box (A7)', () async {
    for (final size in const [Size(224, 224), Size(390, 300), Size(160, 260)]) {
      for (final c in const [Character.miu, Character.lumi]) {
        for (final (lv, hold) in const [(0.0, 0.0), (0.5, 0.0), (1.0, 0.0), (1.0, 1.0)]) {
          for (final f in [null, ...flowerKinds]) {
            final r = await render(
              FriendPainter(
                character: c,
                lv: lv,
                hold: hold,
                growth: SproutGrowth(flower: f),
              ),
              size,
            );
            final b = inkBounds(r.$1, r.$2, r.$3)!;
            final why = '${c.name} lv $lv hold $hold ${f?.id} in $size: $b';
            expect(b.left, greaterThanOrEqualTo(0), reason: why);
            expect(b.top, greaterThanOrEqualTo(0), reason: why);
            expect(b.right, lessThanOrEqualTo(size.width), reason: why);
            expect(b.bottom, lessThanOrEqualTo(size.height), reason: why);
          }
        }
      }
    }
  });

  test('an empty box draws nothing and does not throw', () async {
    for (final c in Character.values) {
      final r = await render(FriendPainter(character: c, lv: 1, hold: 1), Size.zero);
      expect(inkBounds(r.$1, r.$2, r.$3), isNull);
    }
  });

  test('Miu grows taller with the breath, from the floor (A4)', () async {
    const size = Size(224, 224);
    final rest = await render(FriendPainter(character: Character.miu, lv: 0), size);
    final full = await render(FriendPainter(character: Character.miu, lv: 1), size);
    final a = inkBounds(rest.$1, rest.$2, rest.$3)!, b = inkBounds(full.$1, full.$2, full.$3)!;
    // the ear tips go up by about 0.11 x (182 - 43) units; the floor stays
    expect(a.top - b.top, closeTo(0.11 * (182 - 43), 2.5));
    expect(b.bottom, closeTo(a.bottom, 1));
    // a little wider too (1 + 0.035 lv)
    expect(b.width, greaterThan(a.width + 2));
  });

  test('Miu tilts her ears and Lumi shows sparkles only on hold (A4)', () async {
    const size = Size(224, 224);
    for (final c in const [Character.miu, Character.lumi]) {
      final full = await render(FriendPainter(character: c, lv: 1), size);
      final held = await render(FriendPainter(character: c, lv: 1, hold: 1), size);
      final d = diffBounds(full, held);
      expect(d, isNotNull, reason: c.name);
      if (c == Character.lumi) {
        // the sparkles are outside the lantern body (x 42..158)
        expect(d!.left, lessThan(toBox(const Offset(44, 0), size).dx));
        expect(d.right, greaterThan(toBox(const Offset(156, 0), size).dx));
      } else {
        // only the ears change (above the head top, y < 94)
        expect(d!.bottom, lessThan(toBox(const Offset(0, 96), size).dy));
      }
    }
  });

  test('Lumi floats up 7 units, glows and swings its tassel with the breath (A4)', () async {
    const size = Size(224, 224); // 1 px per SVG unit
    final rest = await render(FriendPainter(character: Character.lumi, lv: 0), size);
    final full = await render(FriendPainter(character: Character.lumi, lv: 1), size);
    // the ring's top: 22 - 7
    final a = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 200)!;
    final b = inkBounds(full.$1, full.$2, full.$3, minAlpha: 200)!;
    expect(a.top - b.top, closeTo(7, 1));
    // the halo makes the drawing much wider at a full breath
    final ha = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 2)!;
    final hb = inkBounds(full.$1, full.$2, full.$3, minAlpha: 2)!;
    expect(hb.width, greaterThan(ha.width + 30));
    // the light inside the lantern: the body centre gets warmer (less blue)
    int blueAt((ByteData, int, int) r, Offset p) =>
        r.$1.getUint8(((p.dy.round() + _margin) * r.$2 + p.dx.round() + _margin) * 4 + 2);
    final centre = toBox(const Offset(100, 125), size);
    expect(blueAt(full, centre), lessThan(blueAt(rest, centre) - 40));
  });

  test('the garden flower sits at the anchor and moves with the body (A6)', () async {
    const size = Size(224, 224);
    for (final (c, at) in [(Character.miu, miuAnchorAt), (Character.lumi, lumiAnchorAt)]) {
      for (final lv in const [0.0, 1.0]) {
        final bare = await render(FriendPainter(character: c, lv: lv), size);
        final dressed = await render(
          FriendPainter(
            character: c,
            lv: lv,
            growth: SproutGrowth(flower: flowerKinds[0]),
          ),
          size,
        );
        final d = diffBounds(bare, dressed)!;
        final anchor = toBox(at(lv), size);
        expect((d.center - anchor).distance, lessThan(3), reason: '${c.name} lv $lv: $d vs $anchor');
      }
    }
    expect(miuAnchorAt(0), const Offset(74, 70));
    expect(lumiAnchorAt(0), const Offset(114, 22));
    expect(lumiAnchorAt(1), const Offset(114, 15));
    expect(miuAnchorAt(1).dy, lessThan(60));
  });

  test('the demo breath on cards: inhale 0 -> 1, hold at 1, exhale 1 -> 0', () {
    expect(demoBreath(0).lv, 0);
    expect(demoBreath(2).lv, closeTo(0.5, 1e-9));
    expect(demoBreath(5), (lv: 1.0, hold: 1.0));
    expect(demoBreath(9).lv, closeTo(0.5, 1e-9));
    expect(demoBreath(9).hold, 0);
    expect(demoBreath(12).lv, 0);
  });

  group('the active character on T1 and in sessions (E1, A4, A5)', () {
    late AppController app;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsController();
      await settings.load();
      app = AppController(settings: settings, haptics: HapticsService(), music: MusicService()..available = true);
    });

    test('Zeep still goes through ZeepPainter', () {
      expect(activeCharacterPainter(app), isA<ZeepPainter>());
    });

    test('a friend follows the engine: inhale 0 -> 1, hold 1, exhale 1 -> 0, rest 0', () {
      app.wardrobe.setForTest(practiceDays: 12);
      app.wardrobe.selectCharacter(Character.lumi);
      app.settings.update((s) {
        s.inhale = 4;
        s.hold = 2;
        s.exhale = 4;
        s.rest = 2;
      }, persist: false);
      app.startSession();
      FriendPainter at(double secs) {
        for (var i = 0; i < (secs * 60).round(); i++) {
          app.tick(1 / 60);
        }
        return activeCharacterPainter(app) as FriendPainter;
      }

      expect(at(0.5).character, Character.lumi);
      final mid = at(1.6); // 2.1 s into the inhale
      expect(mid.lv, inInclusiveRange(0.3, 0.8));
      expect(mid.hold, lessThan(0.05));
      final hold = at(2.9); // 5 s: hold
      expect(hold.lv, closeTo(1, 0.03));
      expect(hold.hold, closeTo(1, 0.02));
      final exhale = at(3.0); // 8 s: middle of the exhale (6-10 s)
      expect(exhale.lv, inInclusiveRange(0.3, 0.8));
      expect(exhale.hold, lessThan(0.05));
      final rest = at(2.9); // 10.9 s: rest (10-12 s)
      expect(rest.lv, lessThan(0.08));
    });

    test('Reduce Motion: a still pose (lv 0.6, hold 0) even on hold (A5)', () {
      app.wardrobe.setForTest(practiceDays: 12);
      app.wardrobe.selectCharacter(Character.miu);
      app.reduceMotion = true;
      app.startSession();
      for (var i = 0; i < 60 * 5; i++) {
        app.tick(1 / 60);
      }
      final p = activeCharacterPainter(app) as FriendPainter;
      expect(p.character, Character.miu);
      expect(p.lv, 0.6);
      expect(p.hold, 0);
    });
  });
}
