// Preview sheets for Zeep's friends (1.7.0). Regenerate with
//   flutter test tool/friends_preview_test.dart --update-goldens
//
// friends/poses.png   - every friend (Miu, Lumi, Mun, Tuntun, Nuan; Saisai and
//                        Wongwong since 1.9.0) at rest
//                        (lv 0), mid-inhale (0.4, 0.65), full (1) and hold
//                        (lv 1, hold 1), then Reduce Motion (0.6). Mun's rotor
//                        follows the demo breath's spin at the same moment.
// friends/flowers.png - every friend wearing each of the 20 garden flowers
//                        (at a full breath: the flower at its highest)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/friends/characters.dart';
import 'package:zeep_breathe/friends/pinwheel.dart';
import 'package:zeep_breathe/ui/friends/friend_painter.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';

typedef _Cell = (Character, double, double, SproutGrowth);

const _all = [Character.miu, Character.lumi, ...laterFriends];

/// Mun's rotor at the moment of the demo breath with this [lv] and [hold].
double? _spin(Character c, double lv, double hold) {
  if (c != Character.mun) return null;
  if (hold > 0) return demoSpin(5);
  // inhale 0..4 s: lv = breathEase(t / 4); find t
  var t = 0.0;
  while (t < 4 && demoBreath(t).lv < lv) {
    t += 0.01;
  }
  return demoSpin(t);
}

Future<void> _sheet(WidgetTester t, String file, List<_Cell> cells, int cols, {double cell = 300}) async {
  final rows = (cells.length / cols).ceil();
  t.view.physicalSize = Size(cell * cols, cell * rows);
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
              for (final (c, lv, hold, growth) in cells)
                Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E6EC))),
                  child: CustomPaint(
                    painter: FriendPainter(
                      character: c,
                      lv: lv,
                      hold: hold,
                      growth: growth,
                      // Reduce Motion (0.6) is still: no spin
                      spin: lv == 0.6 ? null : _spin(c, lv, hold),
                    ),
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
  testWidgets('poses', (t) async {
    await _sheet(t, 'friends/poses.png', [
      for (final c in _all)
        for (final (lv, hold) in const [(0.0, 0.0), (0.4, 0.0), (0.65, 0.0), (1.0, 0.0), (1.0, 1.0), (0.6, 0.0)])
          (c, lv, hold, SproutGrowth(flower: flowerKinds[1])),
    ], 6);
  });

  testWidgets('flowers', (t) async {
    await _sheet(
      t,
      'friends/flowers.png',
      [
        for (final c in _all)
          for (final f in flowerKinds) (c, 1.0, 1.0, SproutGrowth(flower: f)),
      ],
      10,
      cell: 200,
    );
  });
}
