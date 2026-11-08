// Wardrobe catalog (SYS.10): the 8 items Zeep can wear, the category each
// one belongs to and the streak (in days) that unlocks it. Pure data, no UI.

/// Where an item sits on Zeep. One item per category, so at most 4 at once.
enum OutfitSlot { sprout, face, head, friend }

/// 28 items in unlock order. Approved 2026-11-08 ("Zeep wardrobe" and
/// "Zeep flower garden" decks): unlocked by total days practised (days with
/// at least one saved session, not necessarily in a row).
enum OutfitItem {
  sproutBow(OutfitSlot.sprout, 1),
  roundGlasses(OutfitSlot.face, 3),
  flowerCrown(OutfitSlot.head, 5),
  beanie(OutfitSlot.head, 7),
  butterfly(OutfitSlot.friend, 10),
  ladybug(OutfitSlot.sprout, 14),
  cloud(OutfitSlot.friend, 21),
  sleepCap(OutfitSlot.head, 30),
  heartGlasses(OutfitSlot.face, 35),
  mushroomHat(OutfitSlot.head, 40),
  bee(OutfitSlot.friend, 45),
  dewDrop(OutfitSlot.sprout, 50),
  catEars(OutfitSlot.head, 60),
  starStickers(OutfitSlot.face, 70),
  skyFish(OutfitSlot.friend, 80),
  strawHat(OutfitSlot.head, 90),
  windChime(OutfitSlot.sprout, 100),
  rainbowGlasses(OutfitSlot.face, 120),
  bird(OutfitSlot.friend, 140),
  goldLeafCrown(OutfitSlot.head, 150),
  firefly(OutfitSlot.friend, 180),
  lantern(OutfitSlot.sprout, 200),
  wizardHat(OutfitSlot.head, 220),
  catEyeGlasses(OutfitSlot.face, 240),
  crescentMoon(OutfitSlot.friend, 270),
  rainbowRibbon(OutfitSlot.sprout, 300),
  halo(OutfitSlot.head, 330),
  lotusCrown(OutfitSlot.head, 365);

  final OutfitSlot slot;

  /// Total practice days needed to unlock this item.
  final int unlockDays;
  const OutfitItem(this.slot, this.unlockDays);

  static OutfitItem? byName(String name) {
    for (final i in values) {
      if (i.name == name) return i;
    }
    return null;
  }
}

/// What Zeep is wearing: at most one item per slot.
class Outfit {
  final Map<OutfitSlot, OutfitItem> _items;
  const Outfit._(this._items);

  static const none = Outfit._({});

  factory Outfit.of(Iterable<OutfitItem> items) {
    final m = <OutfitSlot, OutfitItem>{};
    for (final i in items) {
      m[i.slot] = i; // a later item replaces an earlier one in the same slot
    }
    return Outfit._(Map.unmodifiable(m));
  }

  OutfitItem? operator [](OutfitSlot slot) => _items[slot];
  bool wears(OutfitItem item) => _items[item.slot] == item;
  bool get isEmpty => _items.isEmpty;
  Iterable<OutfitItem> get items => _items.values;

  /// Tapping a worn item takes it off; tapping another item swaps it in.
  Outfit toggle(OutfitItem item) {
    final m = Map<OutfitSlot, OutfitItem>.of(_items);
    if (m[item.slot] == item) {
      m.remove(item.slot);
    } else {
      m[item.slot] = item;
    }
    return Outfit._(Map.unmodifiable(m));
  }

  /// "None" for a whole slot.
  Outfit clear(OutfitSlot slot) {
    final m = Map<OutfitSlot, OutfitItem>.of(_items)..remove(slot);
    return Outfit._(Map.unmodifiable(m));
  }

  @override
  bool operator ==(Object other) =>
      other is Outfit &&
      other._items.length == _items.length &&
      _items.entries.every((e) => other._items[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(_items.values);
}
