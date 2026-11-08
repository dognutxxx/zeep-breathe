import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/wardrobe/flowers.dart';

void main() {
  test('20 flower kinds with unique ids', () {
    expect(flowerKinds.length, 20);
    expect(flowerKinds.map((f) => f.id).toSet().length, 20);
  });

  test('leaves before the bloom: 3 for levels 1-5, 4 for 6-10, 5 from 11', () {
    expect([for (var l = 1; l <= 12; l++) leavesForLevel(l)], [3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5]);
    expect(leavesForLevel(40), 5);
  });

  test('no growth means nothing is drawn', () {
    expect(SproutGrowth.none.isNone, isTrue);
    expect(const SproutGrowth(leaves: 1).isNone, isFalse);
  });
}
