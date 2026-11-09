// Miu and Lumi look as tall as Zeep in every slot where they stand in for
// Zeep (1.7.1, QA #4): the Breathe tab (T1) and the session on phones and
// iPads, the share cards, the picker rows, and the cards' friend tiles.
// Heights are measured from the painted (opaque) pixels, not the box.
// Zeep itself is drawn by the unchanged ZeepPainter / ZeepAvatar.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/main.dart';
import 'package:zeep_breathe/ui/friends/character_view.dart';
import 'package:zeep_breathe/ui/friends/friend_painter.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';

import 'friends_ui_test.dart' show makeApp, frames, openPicker;

/// Opaque pixels only: the body, not shadows, glows or halos.
const _opaque = 230;

Rect? _bounds(ByteData d, int w, int h) {
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (d.getUint8((y * w + x) * 4 + 3) > _opaque) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  return Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0);
}

/// Painted bounds of [p] in a [size] box (box coordinates).
Future<Rect> paintedBy(CustomPainter p, Size size) async {
  const m = 40.0;
  final w = (size.width + 2 * m).ceil(), h = (size.height + 2 * m).ceil();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..translate(m, m);
  p.paint(c, size);
  final img = await rec.endRecording().toImage(w, h);
  final d = (await img.toByteData())!;
  img.dispose();
  return _bounds(d, w, h)!.shift(const Offset(-m, -m));
}

/// Painted bounds of a widget laid out in a [size] box (with room around it
/// for anything drawn outside the box).
Future<Rect> paintedWidget(WidgetTester t, Widget child, Size size) async {
  const m = 40.0;
  final key = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: size.width + 2 * m,
            height: size.height + 2 * m,
            child: Center(
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final r = await t.runAsync(() async {
    final img = await ro.toImage();
    final d = (await img.toByteData())!;
    final b = _bounds(d, img.width, img.height);
    img.dispose();
    return b;
  });
  return r!.shift(const Offset(-m, -m));
}

Pose _pose(double b) =>
    Pose(breath: b, armLift: b, cheekPuff: 0.3, eyeSqueeze: 0.1, mouthOpen: 0, hold: 0, tint: tintInhale);

const _friends = [Character.miu, Character.lumi];

void _sameHeight(Rect friend, Rect zeep, String why) {
  final ratio = friend.height / zeep.height;
  expect(ratio, inInclusiveRange(0.9, 1.1), reason: '$why: ${friend.height} vs Zeep ${zeep.height}');
}

void main() {
  // T1 and the session: the real box sizes on each screen
  for (final (name, physical, dpr) in [
    ('iPhone 393x852', const Size(1179, 2556), 3.0),
    ('iPhone SE 375x667', const Size(750, 1334), 2.0),
    ('iPad landscape 1366x1024', const Size(2732, 2048), 2.0),
    ('iPad portrait 1024x1366', const Size(2048, 2732), 2.0),
    ('Android 360x640', const Size(1080, 1920), 3.0),
  ]) {
    testWidgets('T1 and session on $name: friends as tall as Zeep, inside the box', (t) async {
      final app = await makeApp(days: 12);
      t.view.physicalSize = physical;
      t.view.devicePixelRatio = dpr;
      addTearDown(t.view.reset);
      await t.pumpWidget(ZeepBreatheApp(controller: app));
      await frames(t, app, 5);
      final zeepPaint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ZeepPainter);
      final boxes = {'T1': t.getSize(zeepPaint.first)};
      app.startSession();
      await frames(t, app, 5);
      boxes['session'] = t.getSize(zeepPaint.last);
      app.stopSession();
      await frames(t, app, 5);

      // the app draws the friend with the stage fit
      app.wardrobe.chooseFirstFriend(Character.lumi);
      await frames(t, app, 2);
      final friendPaint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FriendPainter);
      expect((t.widget<CustomPaint>(friendPaint.first).painter! as FriendPainter).fit, FriendFit.stage);

      await t.runAsync(() async {
        for (final MapEntry(key: slot, value: box) in boxes.entries) {
          for (final b in const [0.0, 0.55, 1.0]) {
            final zeep = await paintedBy(
              ZeepPainter(pose: _pose(b), time: 0, ripples: const [], reduceMotion: true),
              box,
            );
            for (final c in _friends) {
              final why = '$name $slot $box ${c.name} breath $b';
              final f = await paintedBy(FriendPainter(character: c, lv: b, fit: FriendFit.stage), box);
              _sameHeight(f, zeep, why);
              // standing on Zeep's feet line, in the middle (Miu's tail makes her a little wider on one side)
              expect(f.bottom, closeTo(zeep.bottom, zeep.height * 0.06), reason: why);
              expect(f.center.dx, closeTo(zeep.center.dx, zeep.width * 0.1), reason: why);
              // whole body (and the hold glow and haptic rings) inside the box
              final held = await paintedBy(
                FriendPainter(character: c, lv: b, hold: 1, fit: FriendFit.stage, ripples: const [0.69]),
                box,
              );
              expect(held.top >= 0 && held.bottom <= box.height, isTrue, reason: '$why: $held');
            }
          }
        }
      });
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('share cards: friends as tall as Zeep (CharacterAvatar 150, breath 0.75)', (t) async {
    const size = Size(150, 150);
    Widget avatar(Character c) => CharacterAvatar(character: c, tint: tintInhale, size: 150, breath: 0.75);
    final zeep = await paintedWidget(t, avatar(Character.zeep), size);
    for (final c in _friends) {
      final f = await paintedWidget(t, avatar(c), size);
      _sameHeight(f, zeep, 'share ${c.name}');
      expect(f.bottom, closeTo(zeep.bottom, zeep.height * 0.06), reason: c.name);
    }
  });

  testWidgets('picker rows: friends as tall as Zeep, plain or dressed', (t) async {
    const size = Size(60, 60);
    for (final dressed in [false, true]) {
      // a dressed Zeep shrinks ("roomy"); its friends shrink with it. Measured
      // undressed, at the same scale (60 * 160 / 200 = 48), so a hat or a
      // flower does not count as height
      final zeep = await paintedWidget(
        t,
        ZeepAvatar(tint: tintInhale, size: dressed ? 48 : 60),
        dressed ? const Size(48, 48) : size,
      );
      for (final c in _friends) {
        final f = await paintedWidget(
          t,
          CustomPaint(
            painter: FriendPainter(character: c, lv: 0.55, fit: dressed ? FriendFit.roomyAvatar : FriendFit.avatar),
          ),
          size,
        );
        _sameHeight(f, zeep, 'picker ${c.name} dressed $dressed');
      }
    }
  });

  testWidgets('the picker draws friends with the avatar fit (roomy when Zeep wears a flower)', (t) async {
    for (final flower in [false, true]) {
      final app = await makeApp(days: 12);
      app.wardrobe.setForTest(steps: flower ? 7 : 0, practiceDays: 12);
      app.wardrobe.chooseFirstFriend(Character.miu);
      app.wardrobe.markFriendCardShown(FriendCard.day10);
      app.wardrobe.selectCharacter(Character.zeep);
      t.view.physicalSize = const Size(1179, 2556);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(ZeepBreatheApp(controller: app));
      await frames(t, app, 5);
      await openPicker(t, app);
      final painters = t
          .widgetList<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FriendPainter))
          .map((w) => w.painter! as FriendPainter)
          .toList();
      expect(painters.map((p) => p.character).toSet(), {Character.miu, Character.lumi});
      final dressed = !app.wardrobe.outfit.isEmpty || !app.wardrobe.growth.isNone;
      expect(dressed, flower);
      for (final p in painters) {
        expect(p.fit, flower ? FriendFit.roomyAvatar : FriendFit.avatar);
      }
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('card tiles and the picker pair: Miu and Lumi the same height', (t) async {
    for (final s in const [40.0, 60.0, 100.0, 130.0]) {
      final size = Size(s, s);
      final zeep = await paintedWidget(t, ZeepAvatar(tint: tintInhale, size: s * 160 / 200), size * 0.8);
      final heights = <double>[];
      for (final c in _friends) {
        final f = await paintedWidget(
          t,
          // a still tile (Reduce Motion), as LiveFriend paints it
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: LiveFriend(character: c, size: s),
          ),
          size,
        );
        heights.add(f.height);
        _sameHeight(f, zeep, 'tile ${c.name} $s');
        expect(f.top >= -1 && f.bottom <= s + 1, isTrue, reason: 'tile ${c.name} $s: $f');
      }
      expect(heights[0] / heights[1], inInclusiveRange(0.9, 1.1));
    }
  });
}
