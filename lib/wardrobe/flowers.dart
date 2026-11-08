// Flower garden (approved 2026-11-08, deck "Zeep flower garden"): every
// completed session grows one leaf on Zeep's sprout; once the level's leaves are all
// there, the next session blooms a new flower kind and the level goes up.

import 'dart:ui' show Color;

enum PetalShape { round, oval, pointed, notched }

enum FlowerStyle { radial, tulip, lavender, rose, hydrangea }

class FlowerKind {
  final String id, nameTh, nameEn;
  final FlowerStyle style;
  final int petals;
  final PetalShape shape;
  final Color petal, center;
  final Color? inner; // second, smaller petal ring
  final double size;
  const FlowerKind(
    this.id,
    this.nameTh,
    this.nameEn, {
    this.style = FlowerStyle.radial,
    this.petals = 5,
    this.shape = PetalShape.round,
    required this.petal,
    this.center = const Color(0xFFFFE08A),
    this.inner,
    this.size = 1,
  });
}

/// One new kind per level, in unlock order (level 2 gives the first one).
const flowerKinds = <FlowerKind>[
  FlowerKind('daisy', 'เดซี่', 'Daisy', petals: 10, shape: PetalShape.oval, petal: Color(0xFFFFFFFF)),
  FlowerKind(
    'sakura',
    'ซากุระ',
    'Sakura',
    shape: PetalShape.notched,
    petal: Color(0xFFFFC7D6),
    center: Color(0xFFF59AB5),
  ),
  FlowerKind('tulip', 'ทิวลิป', 'Tulip', style: FlowerStyle.tulip, petal: Color(0xFFF59A9A), size: 1.3),
  FlowerKind(
    'lotus',
    'ดอกบัว',
    'Lotus',
    petals: 8,
    shape: PetalShape.pointed,
    petal: Color(0xFFF7B8CF),
    inner: Color(0xFFFCE1EA),
    size: 1.1,
  ),
  FlowerKind(
    'sunflower',
    'ทานตะวัน',
    'Sunflower',
    petals: 14,
    shape: PetalShape.pointed,
    petal: Color(0xFFFFD34F),
    center: Color(0xFFA9774A),
    size: 1.15,
  ),
  FlowerKind('lavender', 'ลาเวนเดอร์', 'Lavender', style: FlowerStyle.lavender, petal: Color(0xFFB9A3F0)),
  FlowerKind('rose', 'กุหลาบ', 'Rose', style: FlowerStyle.rose, petal: Color(0xFFF27D8C)),
  FlowerKind(
    'marigold',
    'ดาวเรือง',
    'Marigold',
    petals: 12,
    petal: Color(0xFFFFB347),
    inner: Color(0xFFFFCF70),
    center: Color(0xFFE08A1E),
  ),
  FlowerKind(
    'jasmine',
    'มะลิ',
    'Jasmine',
    shape: PetalShape.pointed,
    petal: Color(0xFFFFFFFF),
    center: Color(0xFFFFF2B0),
    size: 0.85,
  ),
  FlowerKind('hydrangea', 'ไฮเดรนเยีย', 'Hydrangea', style: FlowerStyle.hydrangea, petal: Color(0xFFA9C6F5)),
  FlowerKind(
    'lily',
    'ลิลลี่',
    'Lily',
    petals: 6,
    shape: PetalShape.pointed,
    petal: Color(0xFFFFB38A),
    center: Color(0xFFD46A4A),
  ),
  FlowerKind('violet', 'ไวโอเลต', 'Violet', petal: Color(0xFF9C7CE0)),
  FlowerKind('hibiscus', 'ชบา', 'Hibiscus', petal: Color(0xFFE8505B), center: Color(0xFFFFE08A), size: 1.15),
  FlowerKind(
    'frangipani',
    'ลีลาวดี',
    'Frangipani',
    shape: PetalShape.oval,
    petal: Color(0xFFFFFFFF),
    inner: Color(0xFFFFE08A),
  ),
  FlowerKind('camellia', 'คาเมลเลีย', 'Camellia', petals: 8, petal: Color(0xFFF48FA6), inner: Color(0xFFF9C1CF)),
  FlowerKind(
    'gardenia',
    'พุดซ้อน',
    'Gardenia',
    petals: 8,
    shape: PetalShape.oval,
    petal: Color(0xFFFFFCF2),
    inner: Color(0xFFFFF4D6),
  ),
  FlowerKind('cosmos', 'คอสมอส', 'Cosmos', petals: 8, shape: PetalShape.notched, petal: Color(0xFFFF9CC0)),
  FlowerKind('bluebell', 'ดอกระฆัง', 'Bluebell', style: FlowerStyle.tulip, petal: Color(0xFF8FB0F0), size: 1.3),
  FlowerKind(
    'carnation',
    'คาร์เนชั่น',
    'Carnation',
    petals: 10,
    shape: PetalShape.notched,
    petal: Color(0xFFF7A1B5),
    inner: Color(0xFFFBC8D4),
  ),
  FlowerKind(
    'goldlotus',
    'บัวทอง',
    'Golden lotus',
    petals: 8,
    shape: PetalShape.pointed,
    petal: Color(0xFFF5C969),
    inner: Color(0xFFFBE3A6),
    size: 1.2,
  ),
];

/// Leaves needed before the bloom, by level: 1-5 -> 3, 6-10 -> 4, 11+ -> 5.
int leavesForLevel(int level) => level <= 5 ? 3 : (level <= 10 ? 4 : 5);

/// What grows on the sprout right now.
class SproutGrowth {
  /// Extra leaves on the stem (0 = Zeep exactly as today).
  final int leaves;

  /// The flower Zeep wears on the sprout tip, if any.
  final FlowerKind? flower;

  /// Bloom animation on card L only: 0 = a closed grey bud, 1 = open.
  final double open;

  /// 0 = petals still grey, 1 = the flower's own colours.
  final double colour;

  /// Size of the bud before it opens (it swells like an in-breath).
  final double budScale;

  /// Gentle rock of the flower around its stalk, in radians.
  final double rock;
  const SproutGrowth({this.leaves = 0, this.flower, this.open = 1, this.colour = 1, this.budScale = 1, this.rock = 0});
  static const none = SproutGrowth();
  bool get isNone => leaves == 0 && flower == null;
}
