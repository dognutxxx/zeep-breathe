// Draws Zeep's friends (Miu, Lumi; Mun, Tuntun, Nuan since 1.8.0; Saisai,
// Wongwong since 1.9.0) inside a box, with the user's garden
// flower at each friend's anchor point. Zeep itself is never drawn here: it
// keeps its own painter (drawZeep / ZeepPainter / ZeepAvatar).

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../breathing/breathing_engine.dart' show breathEase;
import '../../friends/characters.dart';
import '../../friends/pinwheel.dart';
import '../../wardrobe/flowers.dart';
import '../zeep_character.dart';
import 'friend_paint_util.dart';
import 'lumi_painter.dart';
import 'miu_painter.dart';
import 'mun_painter.dart';
import 'nuan_painter.dart';
import 'saisai_painter.dart';
import 'tuntun_painter.dart';
import 'wongwong_painter.dart';

/// The SVG art is 200 x 200 units; a margin around it leaves room for the
/// flower on Lumi's ring and Lumi's halo at a full breath.
const _margin = 12.0;
const _box = 200 + 2 * _margin;

/// Static pose with Reduce Motion on (like the doc's reduced-motion stills).
const reducedLv = 0.6;

/// Flower size at an anchor, in SVG units per flower unit.
const _flowerK = 1.4;

/// Haptic ripples (the stand-in for vibration on devices without a haptic
/// engine), in SVG units: rings from the middle of the friend that grow and
/// fade over 0.7 s. The same look as drawZeep's
/// ripples (copied here, not shared: the Zeep files stay as they are), sized
/// so the largest ring stays inside the box.
const rippleCentre = Offset(100, 110);
const rippleStart = 60.0, rippleGrow = 34.0;

void _ripples(Canvas p, List<double> ripples) {
  for (final age in ripples) {
    final u = (age / 0.7).clamp(0.0, 1.0);
    final r = rippleStart + u * rippleGrow;
    p.drawCircle(rippleCentre, r, stroke(withOpacity(const Color(0xFF7FA6F2), (1 - u) * 0.75), 2.5 - 1.5 * u));
  }
}

/// How a friend is placed in its box.
enum FriendFit {
  /// The whole 200-unit art plus a margin fills the box, centred (previews
  /// and the friend_draw tests).
  box,

  /// As tall as Zeep and standing where Zeep stands in a ZeepPainter box
  /// (Breathe tab T1, session).
  stage,

  /// As tall as Zeep and standing where Zeep stands in a ZeepAvatar of the
  /// same box (share cards, picker rows).
  avatar,

  /// As [avatar] for a "roomy" ZeepAvatar that wears an outfit or a flower
  /// (Zeep shrinks to make room); also the cards' friend tiles.
  roomyAvatar,
}

/// Zeep's visual height (opaque pixels, mid breath) is about 136 of its
/// scale units, from the top of the sprout to its feet at 54 units below the
/// body centre (measured from drawZeep; Zeep itself is not changed). Each
/// friend is drawn at its fraction of Zeep's scale to look the same height
/// (test/character_size_test): Miu is about 156 SVG units tall, Lumi 174,
/// Mun 171 (rotor tip to the foot of the stem), Tuntun 131 (shell top to the
/// feet, mid breath) and Nuan 156 (pompom to the bottom of the moon).
/// The 1.9.0 friends were drawn smaller than Zeep on their concept page, so
/// they are fitted up: Saisai is 113 units tall mid breath (bell top to the
/// tentacle tips; it floats, so 118 at rest and 110 at a full breath) and
/// Wongwong 106 (planet top to bottom; 102 to 110 as it swells). Wongwong's
/// ring makes it 168 units wide, so it is matched a little under Zeep's
/// height (about 0.93) to keep the ring inside the cards' tiles; in the
/// small square avatar slots (picker rows, share card) the ring's tips reach
/// a little past the box's sides, into the row's padding.
const _zeepFeet = 54.0;
double friendMatch(Character c) => switch (c) {
  Character.lumi => 0.779,
  Character.mun => 0.81,
  Character.tuntun => 1.03,
  Character.nuan => 0.87,
  Character.saisai => 1.18,
  Character.wongwong => 1.19,
  _ => 0.869,
};

/// The friend's feet (bottom of the opaque art, mid breath) in SVG units.
double _friendFeet(Character c) => switch (c) {
  Character.lumi => 194,
  Character.mun => 192,
  Character.tuntun => 177,
  Character.nuan => 165,
  Character.saisai => 175,
  Character.wongwong => 158.5,
  _ => 191,
};

/// Paints [character] (any friend) at lung level [lv] and [hold], wearing
/// [growth]'s flower, with haptic [ripples] (ages in seconds), placed by
/// [fit]. [spin] is Mun's rotor angle in degrees (null: still, at lv x 45).
/// [glow] false leaves out the self-glow of Saisai and Wongwong
/// (silhouettes). Draws nothing for Zeep.
void drawFriend(
  Canvas canvas,
  Size size,
  Character character,
  double lv,
  double hold,
  SproutGrowth growth, {
  List<double> ripples = const [],
  FriendFit fit = FriendFit.box,
  double? spin,
  bool glow = true,
}) {
  if (character == Character.zeep) return;
  final double k;
  final Offset origin;
  if (fit == FriendFit.box) {
    k = math.min(size.width, size.height) / _box;
    origin = Offset(size.width / 2 - 100 * k, size.height / 2 - 100 * k);
  } else {
    // Zeep's scale and body centre in the same box: ZeepPainter (stage) or
    // ZeepAvatar (avatar), copied from zeep_character.dart
    final s = switch (fit) {
      FriendFit.stage => math.min(size.width / 290, size.height / 225),
      FriendFit.avatar => size.shortestSide / 160,
      _ => size.shortestSide / 200,
    };
    k = s * friendMatch(character);
    // the friend's feet on Zeep's feet line
    final feet = size.height * 0.52 + _zeepFeet * s;
    origin = Offset(size.width / 2 - 100 * k, feet - _friendFeet(character) * k);
  }
  if (!(k > 0) || !k.isFinite) return;
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.scale(k);
  // the box in SVG units (the self-glows stay inside it)
  final room = Rect.fromLTWH(-origin.dx / k, -origin.dy / k, size.width / k, size.height / k);
  final f = growth.flower;
  void flower(Canvas p, Offset at) {
    if (f == null) return;
    final fk = _flowerK * f.size;
    // the middle of what is drawn sits on the anchor
    final c = at - bloomBounds(f).center * fk;
    if (growth.open >= 1 && growth.colour >= 1 && growth.rock == 0) {
      drawBloom(p, f, c, fk);
    } else {
      drawGrowingBloom(p, f, c, fk, growth);
    }
  }

  switch (character) {
    case Character.miu:
      drawMiu(canvas, lv, hold, flower: flower);
    case Character.lumi:
      drawLumi(canvas, lv, hold, flower: flower);
    case Character.mun:
      drawMun(canvas, lv, hold, angle: spin, flower: flower);
    case Character.tuntun:
      drawTuntun(canvas, lv, hold, flower: flower);
    case Character.nuan:
      drawNuan(canvas, lv, hold, flower: flower);
    case Character.saisai:
      drawSaisai(canvas, lv, hold, flower: flower, glow: glow, room: room);
    case Character.wongwong:
      drawWongwong(canvas, lv, hold, flower: flower, glow: glow, room: room);
    case Character.zeep:
      break;
  }
  // on top: unlike Zeep's round body, the friends are too big for rings that
  // start outside them and still fit the box, so the rings cross the edges
  _ripples(canvas, ripples);
  canvas.restore();
}

/// Every field the friend painters read from a [SproutGrowth].
bool sameGrowth(SproutGrowth a, SproutGrowth b) =>
    identical(a, b) ||
    (a.flower == b.flower &&
        a.leaves == b.leaves &&
        a.open == b.open &&
        a.colour == b.colour &&
        a.budScale == b.budScale &&
        a.rock == b.rock);

class FriendPainter extends CustomPainter {
  final Character character;
  final double lv, hold;
  final SproutGrowth growth;

  /// Ages (s) of haptic pulses to show as rings, as around Zeep.
  final List<double> ripples;

  /// Where in the box the friend is drawn.
  final FriendFit fit;

  /// Mun's rotor angle in degrees; null = still (lv x 45, as the SVG).
  final double? spin;
  FriendPainter({
    required this.character,
    required this.lv,
    this.hold = 0,
    this.growth = SproutGrowth.none,
    this.ripples = const [],
    this.fit = FriendFit.box,
    this.spin,
  });

  @override
  void paint(Canvas canvas, Size size) =>
      drawFriend(canvas, size, character, lv, hold, growth, ripples: ripples, fit: fit, spin: spin);

  @override
  bool shouldRepaint(covariant FriendPainter old) =>
      old.character != character ||
      old.lv != lv ||
      old.hold != hold ||
      old.fit != fit ||
      old.spin != spin ||
      !sameGrowth(old.growth, growth) ||
      !listEquals(old.ripples, ripples);
}

/// Lung level and hold for a 12 s demo breath (inhale 4 s, hold 2 s, exhale
/// 6 s), the doc's `breath` keyframes. [t] in seconds.
({double lv, double hold}) demoBreath(double t) {
  final u = t % 12;
  if (u < 4) return (lv: breathEase(u / 4), hold: 0);
  if (u < 6) return (lv: 1, hold: 1);
  return (lv: 1 - breathEase((u - 6) / 6), hold: 0);
}

/// A friend breathing on its own (cards, where the app's ticker is not
/// driving anything). Still at [reducedLv] with Reduce Motion on. Placed
/// like a roomy ZeepAvatar by default, so Miu and Lumi side by side look the
/// same height.
class LiveFriend extends StatefulWidget {
  final Character character;
  final double size;
  final SproutGrowth growth;
  final FriendFit fit;
  const LiveFriend({
    super.key,
    required this.character,
    this.size = 96,
    this.growth = SproutGrowth.none,
    this.fit = FriendFit.roomyAvatar,
  });

  @override
  State<LiveFriend> createState() => _LiveFriendState();
}

class _LiveFriendState extends State<LiveFriend> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _LivePainter(widget.character, widget.growth, widget.fit, still ? null : _time)),
    );
  }
}

class _LivePainter extends CustomPainter {
  final Character character;
  final SproutGrowth growth;
  final FriendFit fit;
  final ValueNotifier<double>? time;
  _LivePainter(this.character, this.growth, this.fit, this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time;
    if (t == null) {
      drawFriend(canvas, size, character, reducedLv, 0, growth, fit: fit);
    } else {
      final b = demoBreath(t.value);
      drawFriend(canvas, size, character, b.lv, b.hold, growth, fit: fit, spin: demoSpin(t.value));
    }
  }

  @override
  bool shouldRepaint(covariant _LivePainter old) =>
      old.character != character || old.fit != fit || old.time != time || !sameGrowth(old.growth, growth);
}

/// A friend who has not come yet: a dark silhouette of the friend's own
/// shape (keeps the surprise), still at mid breath, placed like the other
/// rows' friends ([fit]). No flower.
class FriendSilhouettePainter extends CustomPainter {
  final Character character;
  final FriendFit fit;
  const FriendSilhouettePainter(this.character, {this.fit = FriendFit.avatar});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // everything drawn takes the shade, keeping its own coverage
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..colorFilter = const ColorFilter.mode(Color(0xD94A4250), BlendMode.srcIn),
    );
    // no self-glow: only the body's own shape
    drawFriend(canvas, size, character, 0.55, 0, SproutGrowth.none, fit: fit, glow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FriendSilhouettePainter old) => old.character != character || old.fit != fit;
}
