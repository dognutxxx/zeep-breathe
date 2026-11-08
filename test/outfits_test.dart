import 'package:flutter_test/flutter_test.dart';
import 'package:zeep_breathe/wardrobe/outfits.dart';

void main() {
  test('28 items over 4 slots, unlocked at 1..365 days in order', () {
    expect(OutfitItem.values.length, 28);
    final days = OutfitItem.values.map((i) => i.unlockDays).toList();
    expect(days.first, 1);
    expect(days.last, 365);
    for (var i = 1; i < days.length; i++) {
      expect(days[i], greaterThan(days[i - 1]));
    }
    int count(OutfitSlot s) => OutfitItem.values.where((i) => i.slot == s).length;
    expect(
      [count(OutfitSlot.sprout), count(OutfitSlot.face), count(OutfitSlot.head), count(OutfitSlot.friend)],
      [6, 5, 10, 7],
    );
  });

  test('one item per slot, so at most 4', () {
    final o = Outfit.of(OutfitItem.values);
    expect(o.items.length, 4);
    // the later item of each slot wins
    expect(o[OutfitSlot.head], OutfitItem.lotusCrown);
    expect(o[OutfitSlot.sprout], OutfitItem.rainbowRibbon);
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
