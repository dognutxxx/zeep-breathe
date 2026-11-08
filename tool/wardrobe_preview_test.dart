// Preview sheet for the wardrobe items (step 1 of feature/zeep-wardrobe).
// Rows: no outfit, each of the 8 items, then 4 items worn together.
// Columns: inhale, hold, exhale, rest. Regenerate with
//   flutter test tool/wardrobe_preview_test.dart --update-goldens

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

const _poses = [
  Pose(breath: 1, armLift: 1, cheekPuff: 0.45, eyeSqueeze: 0.25, mouthOpen: 0, hold: 0, tint: tintInhale),
  Pose(breath: 1, armLift: 1, cheekPuff: 0.7, eyeSqueeze: 0.45, mouthOpen: 0, hold: 1, tint: tintHold),
  Pose(breath: 0.5, armLift: 0.5, cheekPuff: 0.05, eyeSqueeze: 0, mouthOpen: 0.8, hold: 0, tint: tintExhale),
  Pose(breath: 0.02, armLift: 0, cheekPuff: 0.1, eyeSqueeze: 0, mouthOpen: 0, hold: 0, tint: tintInhale),
];

final _rows = <Outfit>[
  Outfit.none,
  for (final i in OutfitItem.values) Outfit.of([i]),
  Outfit.of([OutfitItem.sproutFlower, OutfitItem.roundGlasses, OutfitItem.beanie, OutfitItem.butterfly]),
  Outfit.of([OutfitItem.sproutBow, OutfitItem.sleepCap, OutfitItem.cloud]),
];

const _cellW = 290.0, _cellH = 250.0;

void main() {
  testWidgets('wardrobe preview sheet', (t) async {
    t.view.physicalSize = Size(_cellW * _poses.length * 2, _cellH * _rows.length * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: ColoredBox(
            color: const Color(0xFFF5F9FC),
            child: Column(
              children: [
                for (final o in _rows)
                  Row(
                    children: [
                      for (final pose in _poses)
                        SizedBox(
                          width: _cellW,
                          height: _cellH,
                          child: CustomPaint(
                            // time 0.95: leaves open, float near rest (as on cards)
                            painter: ZeepPainter(pose: pose, time: 0.95, ripples: const [], outfit: o),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('wardrobe/preview.png'));
  });
}
