// Friend painters (Miu and Lumi 1.7.0; Mun, Tuntun and Nuan 1.8.0; Saisai and
// Wongwong 1.9.0): they stay
// inside their box at every lung level with every flower, breathe the way the
// doc says, wear the flower at their anchor, and the Breathe tab / session
// still draw Zeep with ZeepPainter.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math' as math;
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
import 'package:zeep_breathe/ui/friends/mun_painter.dart';
import 'package:zeep_breathe/ui/friends/nuan_painter.dart';
import 'package:zeep_breathe/ui/friends/saisai_painter.dart';
import 'package:zeep_breathe/ui/friends/tuntun_painter.dart';
import 'package:zeep_breathe/ui/friends/wongwong_painter.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';

const _margin = 30;

const _all = [Character.miu, Character.lumi, ...laterFriends];

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
      for (final c in _all) {
        for (final (lv, hold) in const [(0.0, 0.0), (0.5, 0.0), (1.0, 0.0), (1.0, 1.0)]) {
          for (final (i, f) in [null, ...flowerKinds].indexed) {
            // haptic rings too, at their largest (just started and nearly gone)
            final ripples = i.isEven ? const <double>[] : const [0.0, 0.35, 0.69];
            final r = await render(
              FriendPainter(
                character: c,
                lv: lv,
                hold: hold,
                growth: SproutGrowth(flower: f),
                ripples: ripples,
                // Mun's rotor at every angle the blades can show (90 degree symmetry)
                spin: c == Character.mun ? i * 9.0 % 90 : null,
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

  test('haptic pulses show as rings around a friend, inside the box (Pim #1)', () async {
    const size = Size(224, 224);
    for (final c in _all) {
      final still = await render(FriendPainter(character: c, lv: 0.5), size);
      for (final age in const [0.0, 0.3, 0.5]) {
        final pulsed = await render(FriendPainter(character: c, lv: 0.5, ripples: [age]), size);
        final d = diffBounds(still, pulsed);
        expect(d, isNotNull, reason: '${c.name} age $age');
        // a ring around the friend: wider than the body (x 38..162 SVG units)
        expect(d!.left, lessThan(toBox(const Offset(40, 0), size).dx), reason: '${c.name} age $age');
        expect(d.right, greaterThan(toBox(const Offset(160, 0), size).dx), reason: '${c.name} age $age');
        final b = inkBounds(pulsed.$1, pulsed.$2, pulsed.$3)!;
        expect(b.left >= 0 && b.top >= 0 && b.right <= size.width && b.bottom <= size.height, isTrue, reason: '$b');
      }
      // gone after 0.7 s
      final old = await render(FriendPainter(character: c, lv: 0.5, ripples: const [0.7]), size);
      expect(diffBounds(still, old), isNull);
    }
    // repaint when the rings move or any growth field changes (Pim #2)
    expect(
      FriendPainter(
        character: Character.miu,
        lv: 0,
        ripples: const [0.1],
      ).shouldRepaint(FriendPainter(character: Character.miu, lv: 0, ripples: const [0.2])),
      isTrue,
    );
    expect(
      FriendPainter(
        character: Character.miu,
        lv: 0,
        growth: SproutGrowth(flower: flowerKinds[0], colour: 0.5),
      ).shouldRepaint(
        FriendPainter(
          character: Character.miu,
          lv: 0,
          growth: SproutGrowth(flower: flowerKinds[0]),
        ),
      ),
      isTrue,
    );
    expect(
      FriendPainter(
        character: Character.miu,
        lv: 0,
        ripples: const [0.1],
      ).shouldRepaint(FriendPainter(character: Character.miu, lv: 0, ripples: const [0.1])),
      isFalse,
    );
  });

  test('a friend on T1 gets the haptic ripples of the app', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    final app = AppController(settings: settings, haptics: HapticsService(), music: MusicService()..available = true);
    app.wardrobe.setForTest(practiceDays: 12);
    app.wardrobe.selectCharacter(Character.lumi);
    app.time = 1;
    app.haptics.fire(HapticPattern.inhaleStart, 1);
    app.time = 1.2;
    final p = activeCharacterPainter(app) as FriendPainter;
    expect(p.ripples, isNotEmpty);
    expect(p.ripples, app.haptics.ripples(1.2));
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
    for (final (c, at) in [
      (Character.miu, miuAnchorAt),
      (Character.lumi, lumiAnchorAt),
      (Character.mun, munAnchorAt),
      (Character.tuntun, tuntunAnchorAt),
      (Character.nuan, nuanAnchorAt),
      (Character.saisai, saisaiAnchorAt),
      (Character.wongwong, wongwongAnchorAt),
    ]) {
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
    // 1.8.0: the ribbon on Mun's stem, the top of Tuntun's shell (lifts 3),
    // Nuan's nightcap (floats 4)
    expect(munAnchorAt(0), const Offset(100, 128));
    expect(munAnchorAt(1), const Offset(100, 128));
    expect(tuntunAnchorAt(0), const Offset(100, 46));
    expect(tuntunAnchorAt(1), const Offset(100, 43));
    expect(nuanAnchorAt(0), const Offset(64, 76));
    expect(nuanAnchorAt(1), const Offset(64, 72));
    // 1.9.0: the left top of Saisai's bell (floats 8) and of Wongwong (floats 5)
    expect(saisaiAnchorAt(0), const Offset(86, 60));
    expect(saisaiAnchorAt(1), const Offset(86, 52));
    expect(wongwongAnchorAt(0), const Offset(76, 64));
    expect(wongwongAnchorAt(1), const Offset(76, 59));
  });

  int alphaAt((ByteData, int, int) r, Offset p) =>
      r.$1.getUint8(((p.dy.round() + _margin) * r.$2 + p.dx.round() + _margin) * 4 + 3);
  (int, int, int) rgbAt((ByteData, int, int) r, Offset p) {
    final i = ((p.dy.round() + _margin) * r.$2 + p.dx.round() + _margin) * 4;
    return (r.$1.getUint8(i), r.$1.getUint8(i + 1), r.$1.getUint8(i + 2));
  }

  test('Mun: the rotor turns, the face does not; wind with lv, a sparkle on hold (1.8.0 #1)', () async {
    const size = Size(224, 224); // 1 px per SVG unit
    final a = await render(FriendPainter(character: Character.mun, lv: 0.5, spin: 0), size);
    final b = await render(FriendPainter(character: Character.mun, lv: 0.5, spin: 30), size);
    final d = diffBounds(a, b)!;
    // the blades move, around the hub at (100, 86), up to 62 units out
    expect(d.top, lessThan(toBox(const Offset(0, 40), size).dy));
    expect(d.bottom, lessThan(toBox(const Offset(0, 152), size).dy));
    // a quarter turn: the same shape, the colours move round
    final q = await render(FriendPainter(character: Character.mun, lv: 0.5, spin: 90), size);
    expect(diffBounds(a, q), isNotNull);
    // the face on the hub stays: the eye ink is in the same place
    for (final spin in const [0.0, 30.0, 90.0]) {
      final r = await render(FriendPainter(character: Character.mun, lv: 0.5, spin: spin), size);
      final (red, _, _) = rgbAt(r, toBox(const Offset(90.5, 88), size));
      expect(red, lessThan(120), reason: 'eye ink at spin $spin');
    }
    // still (no spin given): the SVG's own lv x 45 degrees
    final still = await render(FriendPainter(character: Character.mun, lv: 0.5), size);
    final at225 = await render(FriendPainter(character: Character.mun, lv: 0.5, spin: 22.5), size);
    expect(diffBounds(still, at225), isNull);
    expect(munStillAngle(0.6), closeTo(27, 1e-9));
    // wind lines (x 2..30 on the left) only with breath
    final empty = await render(FriendPainter(character: Character.mun, lv: 0, spin: 0), size);
    final full = await render(FriendPainter(character: Character.mun, lv: 1, spin: 0), size);
    expect(alphaAt(empty, toBox(const Offset(14, 117), size)), 0);
    expect(alphaAt(full, toBox(const Offset(14, 117), size)), greaterThan(150));
    // the sparkle (top right) only on hold
    final held = await render(FriendPainter(character: Character.mun, lv: 1, hold: 1, spin: 0), size);
    final sd = diffBounds(full, held)!;
    expect(sd.left, greaterThan(toBox(const Offset(158, 0), size).dx));
    expect(sd.bottom, lessThan(toBox(const Offset(0, 47), size).dy));
  });

  test('Tuntun: the head comes out, the legs spread, the shell lifts, the shine on hold (1.8.0 #1)', () async {
    const size = Size(224, 224);
    final rest = await render(FriendPainter(character: Character.tuntun, lv: 0), size);
    final full = await render(FriendPainter(character: Character.tuntun, lv: 1), size);
    // the head: tucked 10 units up at rest, out at a full breath (its chin at 180)
    final chin = toBox(const Offset(100, 178), size);
    expect(alphaAt(rest, chin), lessThan(10));
    expect(alphaAt(full, chin), 255);
    // the top of the shell goes up 3 units
    final a = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 200)!;
    final b = inkBounds(full.$1, full.$2, full.$3, minAlpha: 200)!;
    expect(a.top - b.top, closeTo(3, 1));
    // the legs step out 7 units each way (and down 7): below the rim, just
    // outside the legs at rest
    for (final x in const [32.0, 168.0]) {
      final p = toBox(Offset(x, 168), size);
      expect(alphaAt(rest, p), lessThan(10), reason: 'x $x');
      expect(alphaAt(full, p), 255, reason: 'x $x');
    }
    // the shine on the shell is brighter on hold, nothing else changes
    final held = await render(FriendPainter(character: Character.tuntun, lv: 1, hold: 1), size);
    final d = diffBounds(full, held)!;
    expect(d.left, greaterThan(toBox(const Offset(40, 0), size).dx));
    expect(d.right, lessThan(toBox(const Offset(80, 0), size).dx));
    expect(d.bottom, lessThan(toBox(const Offset(0, 100), size).dy));
  });

  test('Nuan: the shadow slides off to a full moon, floats 4 units, stars on hold (1.8.0 #1)', () async {
    const size = Size(224, 224);
    final rest = await render(FriendPainter(character: Character.nuan, lv: 0), size);
    final half = await render(FriendPainter(character: Character.nuan, lv: 0.5), size);
    final full = await render(FriendPainter(character: Character.nuan, lv: 1), size);
    // the right side of the moon is in shadow (lilac, bluer) at rest and lit
    // (yellow) at a full breath; its left edge is always lit
    int blue((ByteData, int, int) r, Offset p) => rgbAt(r, toBox(p, size)).$3;
    expect(blue(rest, const Offset(140, 112)), greaterThan(blue(full, const Offset(140, 108)) + 20));
    expect(blue(half, const Offset(150, 110)), greaterThan(blue(full, const Offset(150, 108)) + 20));
    expect(blue(half, const Offset(100, 100)), closeTo(blue(full, const Offset(100, 98)), 6));
    expect(blue(rest, const Offset(50, 112)), closeTo(blue(full, const Offset(50, 108)), 6));
    // the shadow never leaves the moon (clipped): only the float differs outside it
    final a = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 200)!;
    final b = inkBounds(full.$1, full.$2, full.$3, minAlpha: 200)!;
    expect(a.top - b.top, closeTo(4, 1));
    expect(b.width, closeTo(a.width, 1));
    // two stars, left and right of the moon, on hold only
    final held = await render(FriendPainter(character: Character.nuan, lv: 1, hold: 1), size);
    final d = diffBounds(full, held)!;
    expect(d.left, lessThan(toBox(const Offset(36, 0), size).dx));
    expect(d.right, greaterThan(toBox(const Offset(170, 0), size).dx));
  });

  test('a silhouette is the shape of the friend itself, one dark shade, no flower (1.8.0 #4)', () async {
    const size = Size(224, 224);
    for (final c in laterFriends) {
      final shadow = await render(FriendSilhouettePainter(c, fit: FriendFit.box), size);
      final body = await render(FriendPainter(character: c, lv: 0.55), size);
      final sb = inkBounds(shadow.$1, shadow.$2, shadow.$3, minAlpha: 100)!;
      final bb = inkBounds(body.$1, body.$2, body.$3, minAlpha: 100)!;
      expect(
        (sb.left - bb.left).abs() + (sb.top - bb.top).abs() + (sb.bottom - bb.bottom).abs(),
        lessThan(3),
        reason: '${c.name}: $sb vs $bb',
      );
      // dark where it is drawn
      final (r, g, bl) = rgbAt(shadow, toBox(const Offset(100, 100), size));
      expect(r + g + bl, lessThan(3 * 100), reason: c.name);
    }
    // the shapes differ
    final m = await render(const FriendSilhouettePainter(Character.mun, fit: FriendFit.box), size);
    final n = await render(const FriendSilhouettePainter(Character.nuan, fit: FriendFit.box), size);
    expect(diffBounds(m, n), isNotNull);
  });

  test('Saisai: the bell swells and rises, the tentacles shorten, the centre brightens (1.9.0 #1)', () async {
    const size = Size(224, 224); // 1 px per SVG unit
    final rest = await render(FriendPainter(character: Character.saisai, lv: 0), size);
    final full = await render(FriendPainter(character: Character.saisai, lv: 1), size);
    final a = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 200)!;
    final b = inkBounds(full.$1, full.$2, full.$3, minAlpha: 200)!;
    // the bell top: up 8 (float) and 3.8 more (it swells by 0.1 from y 106)
    expect(a.top - b.top, closeTo(8 + 0.1 * (106 - 68), 1.5));
    // the bell is wider (x 1.06)
    expect(b.width, greaterThan(a.width + 4));
    // the tentacle tips: 74 x 1.06 below y 104 at rest, 74 x 0.90 (and 8 up) at a full breath
    expect(a.bottom - b.bottom, closeTo(74 * 0.16 + 8, 2.5));
    expect(saisaiTentacleScale(0), closeTo(1.06, 1e-9));
    expect(saisaiTentacleScale(1), closeTo(0.90, 1e-9));
    // the light in the middle of the bell: warmer (less blue) at a full breath
    int blueAt((ByteData, int, int) r, Offset p) => rgbAt(r, toBox(p, size)).$3;
    expect(blueAt(full, const Offset(100, 74)), lessThan(blueAt(rest, const Offset(100, 82)) - 8));
    // the self-glow: much wider than the body at a full breath
    final ha = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 2)!;
    final hb = inkBounds(full.$1, full.$2, full.$3, minAlpha: 2)!;
    expect(hb.width, greaterThan(ha.width + 25));
    expect(hb.width, greaterThan(b.width + 40));
  });

  test('Saisai on hold: the tentacle tips glow and three sparkles show (1.9.0 #1)', () async {
    const size = Size(224, 224);
    final full = await render(FriendPainter(character: Character.saisai, lv: 1), size);
    final held = await render(FriendPainter(character: Character.saisai, lv: 1, hold: 1), size);
    final d = diffBounds(full, held)!;
    // sparkles left (x 29) and right (x 173) of the bell; the tips below it
    expect(d.left, lessThan(toBox(const Offset(32, 0), size).dx));
    expect(d.right, greaterThan(toBox(const Offset(170, 0), size).dx));
    expect(d.bottom, greaterThan(toBox(const Offset(0, 150), size).dy));
    // a tip (x 88, y 104 + 74 x 0.90 - 8) is brighter
    final tip = toBox(Offset(88, 104 + 74 * saisaiTentacleScale(1) - 8), size);
    expect(alphaAt(held, tip), greaterThan(alphaAt(full, tip)));
    // the sparkle at (36, 67) only on hold (without it, only the faint halo)
    expect(alphaAt(full, toBox(const Offset(36, 67), size)), lessThan(60));
    expect(alphaAt(held, toBox(const Offset(36, 67), size)), greaterThan(200));
  });

  test(
    'Wongwong: swells, the ring opens, the moon rises; the moon glows and sparkles show on hold (1.9.0 #1)',
    () async {
      const size = Size(224, 224);
      final rest = await render(FriendPainter(character: Character.wongwong, lv: 0), size);
      final full = await render(FriendPainter(character: Character.wongwong, lv: 1), size);
      final a = inkBounds(rest.$1, rest.$2, rest.$3, minAlpha: 200)!;
      final b = inkBounds(full.$1, full.$2, full.$3, minAlpha: 200)!;
      // the planet top: up 5 (float) and 3.5 (x 1.07 of radius 50)
      expect(a.top - b.top, closeTo(5 + 0.07 * 50, 1.5));
      expect(wongwongRingOpen(0), closeTo(0.2, 1e-9));
      expect(wongwongRingOpen(1), closeTo(0.36, 1e-9));
      // the ring opens: below the planet's bottom-right, the front of the ring
      // is lower at a full breath. On the ring's axis 70 units right of the
      // centre (tilted -14 degrees), the white ring is at 74 x open below it
      Offset onRing(double lv, double along, double out) {
        final c = wongwongCentre.translate(0, -wongwongFloat * lv);
        final cs = math.cos(wongwongTilt), sn = math.sin(wongwongTilt);
        return c + Offset(along * cs - out * sn, along * sn + out * cs);
      }

      double ringY(double lv) {
        final o = wongwongRingOpen(lv);
        // the lowest point of the inner ring ellipse near x = 30 along the axis
        return 74 * o * math.sqrt(1 - (30 / 74) * (30 / 74));
      }

      for (final lv in const [0.0, 1.0]) {
        final r = lv == 0 ? rest : full;
        final p = toBox(onRing(lv, 30, ringY(lv)), size);
        final (red, green, blue) = rgbAt(r, p);
        // white (the front ring passes over the body)
        expect(red + green + blue, greaterThan(3 * 225), reason: 'lv $lv at $p');
      }
      // where the open ring is, the flat one is not
      final openSpot = toBox(onRing(1, 30, ringY(1)), size);
      final (r0, g0, b0) = rgbAt(rest, openSpot);
      expect(r0 + g0 + b0, lessThan(3 * 225));
      // the moon rises 14 (and 5 with the body) and moves 10 right
      expect(wongwongMoonAt(1) - wongwongMoonAt(0), const Offset(10, -14));
      expect(alphaAt(rest, toBox(const Offset(30, 132), size)), 255);
      expect(alphaAt(full, toBox(const Offset(40, 113), size)), 255);
      expect(alphaAt(full, toBox(const Offset(24, 140), size)), lessThan(150));
      // hold: the moon's glow and the sparkles (left x 34, right x 177, low y 172)
      final held = await render(FriendPainter(character: Character.wongwong, lv: 1, hold: 1), size);
      final d = diffBounds(full, held)!;
      expect(d.left, lessThan(toBox(const Offset(36, 0), size).dx));
      expect(d.right, greaterThan(toBox(const Offset(174, 0), size).dx));
      expect(d.bottom, greaterThan(toBox(const Offset(0, 168), size).dy));
      final glow = toBox(const Offset(40 - 12, 113), size); // inside the moon's glow, outside the moon
      expect(alphaAt(held, glow), greaterThan(alphaAt(full, glow)));
    },
  );

  test("Wongwong's ring: the back half behind the body, the front half over it, even strokes (1.9.0 #1)", () async {
    const size = Size(224, 224);
    final r = await render(FriendPainter(character: Character.wongwong, lv: 0.5), size);
    final open = wongwongRingOpen(0.5);
    final c = wongwongCentre.translate(0, -wongwongFloat * 0.5);
    Offset at(double along, double out) {
      final cs = math.cos(wongwongTilt), sn = math.sin(wongwongTilt);
      return c + Offset(along * cs - out * sn, along * sn + out * cs);
    }

    // the inner ring's top and bottom 40 units right of the middle, above and
    // below the axis. The top is behind the body (lilac planet, no white
    // ring); the bottom passes over it (white)
    final y40 = 74 * open * math.sqrt(1 - (40 / 74) * (40 / 74));
    final top = rgbAt(r, toBox(at(40, -y40), size));
    final bottom = rgbAt(r, toBox(at(40, y40), size));
    expect(bottom.$1 + bottom.$2 + bottom.$3, greaterThan(3 * 235));
    expect(top.$1 + top.$2 + top.$3, lessThan(bottom.$1 + bottom.$2 + bottom.$3 - 20));
    // outside the body, the back half shows (the ring's tips)
    final tip = rgbAt(r, toBox(at(-74, 0), size));
    expect(tip.$1 + tip.$2 + tip.$3, greaterThan(3 * 220));
    // the stroke keeps its 7 units where the ring is flattest (a scaled
    // circle would be 7 x open = 2 units there): the white run across the
    // bottom of the ring
    int run(Offset from, Offset dir) {
      var n = 0;
      for (var i = -8; i <= 8; i++) {
        final (red, green, blue) = rgbAt(r, toBox(from + dir * i.toDouble(), size));
        if (red > 240 && green > 238 && blue > 232 && (red - blue).abs() < 12) n++;
      }
      return n;
    }

    final cs = math.cos(wongwongTilt), sn = math.sin(wongwongTilt);
    final across = run(at(0, 74 * open), Offset(-sn, cs));
    expect(across, inInclusiveRange(6, 8));
  });

  test('Saisai and Wongwong: Reduce Motion is the lv 0.6 pose; a silhouette has no glow (1.9.0 #1, #4)', () async {
    const size = Size(224, 224);
    for (final c in const [Character.saisai, Character.wongwong]) {
      final still = await render(FriendPainter(character: c, lv: reducedLv), size);
      final b = inkBounds(still.$1, still.$2, still.$3)!;
      expect(b.left >= 0 && b.top >= 0 && b.right <= size.width && b.bottom <= size.height, isTrue);
      // the silhouette: the body's shape, without the wide halo
      final shadow = await render(FriendSilhouettePainter(c, fit: FriendFit.box), size);
      final sb = inkBounds(shadow.$1, shadow.$2, shadow.$3, minAlpha: 2)!;
      final body = await render(FriendPainter(character: c, lv: 0.55), size);
      final halo = inkBounds(body.$1, body.$2, body.$3, minAlpha: 2)!;
      expect(sb.top, greaterThan(halo.top + 10), reason: c.name);
      expect(reducedLv, 0.6);
    }
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

    test('the rotor of Mun follows the spin keyframes; still with Reduce Motion (1.8.0 #1)', () {
      app.wardrobe.setForTest(practiceDays: 30);
      app.wardrobe.selectCharacter(Character.mun);
      app.settings.update((s) {
        s.inhale = 4;
        s.hold = 2;
        s.exhale = 6;
        s.rest = 0;
      }, persist: false);
      double spinAfter(double secs) {
        for (var i = 0; i < (secs * 60).round(); i++) {
          app.tick(1 / 60);
        }
        return (activeCharacterPainter(app) as FriendPainter).spin!;
      }

      app.startSession();
      final s0 = spinAfter(1 / 60);
      final in2 = spinAfter(2); // 2 s into the inhale: ease-in, a slow start
      final in4 = spinAfter(2); // the end of the inhale
      final h = spinAfter(2); // hold: +30
      final ex = spinAfter(6); // exhale: +150
      double turned(double a, double b) => (b - a) % 360;
      expect(turned(s0, in2), inInclusiveRange(40, 150));
      expect(turned(in2, in4), greaterThan(200)); // fastest at the top of the breath
      expect(turned(in4, h), closeTo(30, 5));
      expect(turned(h, ex), closeTo(150, 8));
      // one whole breath: 540 degrees, a multiple of the blades' 90
      final whole = turned(s0, ex) % 90;
      expect(whole < 6 || whole > 84, isTrue, reason: '$whole');
      app.stopSession();

      app.reduceMotion = true;
      app.startSession();
      app.tick(1 / 60);
      final p = activeCharacterPainter(app) as FriendPainter;
      expect(p.spin, isNull);
      expect(p.lv, 0.6);
      expect(p.hold, 0);
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
