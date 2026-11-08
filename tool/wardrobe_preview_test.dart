// Preview sheets for the wardrobe and the flower garden. Regenerate with
//   flutter test tool/wardrobe_preview_test.dart --update-goldens
//
// items.png  - no outfit, then each of the 28 items (resting pose)
// poses.png  - outfits + leaves/flowers in the inhale, hold, exhale and rest poses
// flowers.png - the 20 flower kinds on their own

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

const _inhale = Pose(breath: 1, armLift: 1, cheekPuff: 0.45, eyeSqueeze: 0.25, mouthOpen: 0, hold: 0, tint: tintInhale);
const _hold = Pose(breath: 1, armLift: 1, cheekPuff: 0.7, eyeSqueeze: 0.45, mouthOpen: 0, hold: 1, tint: tintHold);
const _exhale = Pose(
  breath: 0.5,
  armLift: 0.5,
  cheekPuff: 0.05,
  eyeSqueeze: 0,
  mouthOpen: 0.8,
  hold: 0,
  tint: tintExhale,
);
const _rest = Pose(breath: 0.3, armLift: 0.3, cheekPuff: 0.2, eyeSqueeze: 0, mouthOpen: 0, hold: 0, tint: tintInhale);

typedef _Cell = (Pose, Outfit, SproutGrowth);

Future<void> _sheet(WidgetTester t, String file, List<_Cell> cells, int cols) async {
  const w = 435.0, h = 390.0; // 1.5x the 290 x 260 design box
  final rows = (cells.length / cols).ceil();
  t.view.physicalSize = Size(w * cols, h * rows);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: ColoredBox(
          color: const Color(0xFFF5F9FC),
          child: Wrap(
            children: [
              for (final (pose, outfit, growth) in cells)
                SizedBox(
                  width: w,
                  height: h,
                  child: CustomPaint(
                    // time 0.95: leaves open, float near rest (as on cards)
                    painter: ZeepPainter(pose: pose, time: 0.95, ripples: const [], outfit: outfit, growth: growth),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile(file));
}

void main() {
  testWidgets('every item', (t) async {
    await _sheet(t, 'wardrobe/items.png', [
      (_rest, Outfit.none, SproutGrowth.none),
      for (final i in OutfitItem.values) (_rest, Outfit.of([i]), SproutGrowth.none),
    ], 6);
  });

  testWidgets('poses', (t) async {
    final rows = <(Outfit, SproutGrowth)>[
      (Outfit.none, SproutGrowth.none),
      (
        Outfit.of([OutfitItem.sproutBow, OutfitItem.beanie, OutfitItem.roundGlasses, OutfitItem.butterfly]),
        SproutGrowth(leaves: 2, flower: flowerKinds[1]),
      ),
      (
        Outfit.of([OutfitItem.lantern, OutfitItem.wizardHat, OutfitItem.catEyeGlasses, OutfitItem.crescentMoon]),
        SproutGrowth(leaves: 4, flower: flowerKinds[5]),
      ),
      (
        Outfit.of([OutfitItem.ladybug, OutfitItem.strawHat, OutfitItem.starStickers, OutfitItem.bee]),
        SproutGrowth(leaves: 1, flower: flowerKinds[4]),
      ),
      (
        Outfit.of([OutfitItem.windChime, OutfitItem.lotusCrown, OutfitItem.heartGlasses, OutfitItem.bird]),
        SproutGrowth(leaves: 5, flower: flowerKinds[19]),
      ),
      (
        Outfit.of([OutfitItem.dewDrop, OutfitItem.halo, OutfitItem.rainbowGlasses, OutfitItem.firefly]),
        SproutGrowth(leaves: 3, flower: flowerKinds[3]),
      ),
    ];
    await _sheet(t, 'wardrobe/poses.png', [
      for (final (o, g) in rows)
        for (final pose in const [_inhale, _hold, _exhale, _rest]) (pose, o, g),
    ], 4);
  });

  testWidgets('flowers', (t) async {
    await _sheet(t, 'wardrobe/flowers.png', [
      for (final f in flowerKinds) (_rest, Outfit.none, SproutGrowth(flower: f)),
    ], 5);
  });
}
