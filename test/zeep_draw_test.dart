import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

void main() {
  const pose = Pose(breath: 0.5, armLift: 0.5, cheekPuff: 0.3, eyeSqueeze: 0, mouthOpen: 0, hold: 0, tint: tintInhale);
  final dressed = Outfit.of([OutfitItem.strawHat, OutfitItem.sproutBow, OutfitItem.starStickers, OutfitItem.bee]);
  final growth = SproutGrowth(leaves: 3, flower: flowerKinds[3]);

  test('an empty box (scale 0, NaN or negative) draws nothing and returns (QA B8)', () {
    for (final s in [0.0, -1.0, double.nan, double.infinity]) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      drawZeep(canvas, Offset.zero, s, pose, 1, 0, const [0.1], outfit: dressed, growth: growth);
      drawBloom(canvas, flowerKinds[0], Offset.zero, s);
      rec.endRecording().dispose();
    }
  });

  testWidgets('Zeep painters in a zero-height box do not hang (QA B8)', (t) async {
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            SizedBox(
              width: 300,
              height: 0,
              child: CustomPaint(
                painter: ZeepPainter(pose: pose, time: 1, ripples: const [], outfit: dressed, growth: growth),
              ),
            ),
            ZeepAvatar(tint: tintInhale, size: 0, outfit: dressed, growth: growth, roomy: true),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
