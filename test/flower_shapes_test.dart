// Garden flowers (fix 2026-11-09): every kind has its own shape, not just its
// own colour, and the tile drawing stays inside its bounds and centred.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/ui/zeep_character.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';

/// What makes the silhouette: the style, and for the radial kinds also the
/// petal shape and how many petals (colours do not count).
String silhouette(FlowerKind f) => f.style == FlowerStyle.radial ? 'radial/${f.shape.name}/${f.petals}' : f.style.name;

void main() {
  test('20 kinds, 20 different silhouettes', () {
    expect(flowerKinds.length, 20);
    final seen = <String, String>{};
    for (final f in flowerKinds) {
      final key = silhouette(f);
      expect(seen[key], isNull, reason: '${f.id} has the same shape as ${seen[key]}');
      seen[key] = f.id;
    }
  });

  test('radial kinds also differ in petal shape (not just petal count)', () {
    final radial = flowerKinds.where((f) => f.style == FlowerStyle.radial).toList();
    final shapes = radial.map((f) => f.shape).toSet();
    // round, oval, notched, toothed and pointed; the two pointed ones (lotus,
    // sunflower) differ by a second petal ring and a much bigger middle
    expect(shapes.length, radial.length - 1);
  });

  test('each kind draws inside bloomBounds (ink stays in the box)', () async {
    for (final f in flowerKinds) {
      final b = bloomBounds(f);
      const k = 8.0;
      final w = (b.width * k).ceil() + 40, h = (b.height * k).ceil() + 40;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final origin = Offset(20 - b.left * k, 20 - b.top * k);
      drawBloom(canvas, f, origin, k);
      final img = await rec.endRecording().toImage(w, h);
      final data = (await img.toByteData())!;
      var minX = w, minY = h, maxX = -1, maxY = -1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (data.getUint8((y * w + x) * 4 + 3) > 40) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      // within one unit (k px) of the declared box on every side
      expect(minX, greaterThanOrEqualTo(20 - k), reason: '${f.id} left');
      expect(minY, greaterThanOrEqualTo(20 - k), reason: '${f.id} top');
      expect(maxX, lessThanOrEqualTo(w - 20 + k), reason: '${f.id} right');
      expect(maxY, lessThanOrEqualTo(h - 20 + k), reason: '${f.id} bottom');
      // and the box is not much bigger than the drawing (so tiles centre it)
      expect((maxX - minX) / (b.width * k), greaterThan(0.8), reason: '${f.id} width');
      expect((maxY - minY) / (b.height * k), greaterThan(0.8), reason: '${f.id} height');
    }
  });
}
