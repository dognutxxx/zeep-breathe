import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

void main() {
  test('8 items over 4 slots, unlocked at 1..30 days', () {
    expect(OutfitItem.values.length, 8);
    expect(OutfitItem.values.map((i) => i.unlockDays), [1, 3, 5, 7, 10, 14, 21, 30]);
    expect(OutfitItem.values.map((i) => i.slot).toSet(), OutfitSlot.values.toSet());
  });

  test('one item per slot, so at most 4', () {
    final o = Outfit.of(OutfitItem.values);
    expect(o.items.length, 4);
    // the later item of each slot wins
    expect(o[OutfitSlot.head], OutfitItem.sleepCap);
    expect(o[OutfitSlot.sprout], OutfitItem.sproutFlower);
  });

  test('toggle wears, swaps within a slot and takes off', () {
    var o = Outfit.none.toggle(OutfitItem.beanie);
    expect(o.wears(OutfitItem.beanie), isTrue);
    o = o.toggle(OutfitItem.flowerCrown);
    expect(o.wears(OutfitItem.beanie), isFalse);
    expect(o[OutfitSlot.head], OutfitItem.flowerCrown);
    o = o.toggle(OutfitItem.flowerCrown);
    expect(o.isEmpty, isTrue);
  });

  test('clear empties one slot only', () {
    final o = Outfit.of([OutfitItem.beanie, OutfitItem.cloud]).clear(OutfitSlot.head);
    expect(o, Outfit.of([OutfitItem.cloud]));
  });

  test('byName round-trips', () {
    for (final i in OutfitItem.values) {
      expect(OutfitItem.byName(i.name), i);
    }
    expect(OutfitItem.byName('nope'), isNull);
  });
}
