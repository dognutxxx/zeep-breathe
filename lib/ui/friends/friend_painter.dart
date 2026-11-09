// Draws Zeep's friends (Miu, Lumi) inside a box, with the user's garden
// flower at each friend's anchor point. Zeep itself is never drawn here: it
// keeps its own painter (drawZeep / ZeepPainter / ZeepAvatar).

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../breathing/breathing_engine.dart' show breathEase;
import '../../friends/characters.dart';
import '../../wardrobe/flowers.dart';
import '../zeep_character.dart';
import 'friend_paint_util.dart';
import 'lumi_painter.dart';
import 'miu_painter.dart';

/// The SVG art is 200 x 200 units; a margin around it leaves room for the
/// flower on Lumi's ring and Lumi's halo at a full breath.
const _margin = 12.0;
const _box = 200 + 2 * _margin;

/// Static pose with Reduce Motion on (like the doc's reduced-motion stills).
const reducedLv = 0.6;

/// Flower size at an anchor, in SVG units per flower unit.
const _flowerK = 1.4;

/// Paints [character] (Miu or Lumi) at lung level [lv] and [hold], wearing
/// [growth]'s flower. Draws nothing for Zeep or the mystery friends.
void drawFriend(Canvas canvas, Size size, Character character, double lv, double hold, SproutGrowth growth) {
  final k = math.min(size.width, size.height) / _box;
  if (!(k > 0) || !k.isFinite) return;
  canvas.save();
  canvas.translate(size.width / 2 - 100 * k, size.height / 2 - 100 * k);
  canvas.scale(k);
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
    default:
      break;
  }
  canvas.restore();
}

class FriendPainter extends CustomPainter {
  final Character character;
  final double lv, hold;
  final SproutGrowth growth;
  FriendPainter({required this.character, required this.lv, this.hold = 0, this.growth = SproutGrowth.none});

  @override
  void paint(Canvas canvas, Size size) => drawFriend(canvas, size, character, lv, hold, growth);

  @override
  bool shouldRepaint(covariant FriendPainter old) =>
      old.character != character ||
      old.lv != lv ||
      old.hold != hold ||
      old.growth.flower != growth.flower ||
      old.growth.open != growth.open;
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
/// driving anything). Still at [reducedLv] with Reduce Motion on.
class LiveFriend extends StatefulWidget {
  final Character character;
  final double size;
  final SproutGrowth growth;
  const LiveFriend({super.key, required this.character, this.size = 96, this.growth = SproutGrowth.none});

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
      child: CustomPaint(painter: _LivePainter(widget.character, widget.growth, still ? null : _time)),
    );
  }
}

class _LivePainter extends CustomPainter {
  final Character character;
  final SproutGrowth growth;
  final ValueNotifier<double>? time;
  _LivePainter(this.character, this.growth, this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time;
    if (t == null) {
      drawFriend(canvas, size, character, reducedLv, 0, growth);
    } else {
      final b = demoBreath(t.value);
      drawFriend(canvas, size, character, b.lv, b.hold, growth);
    }
  }

  @override
  bool shouldRepaint(covariant _LivePainter old) =>
      old.character != character || old.time != time || old.growth.flower != growth.flower;
}

/// A dark, generic silhouette for a friend who has not come yet (not a
/// redraw of anyone): a soft round shape with a question mark.
class MysteryFriendPainter extends CustomPainter {
  const MysteryFriendPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width, size.height) / _box;
    if (!(k > 0) || !k.isFinite) return;
    canvas.save();
    canvas.translate(size.width / 2 - 100 * k, size.height / 2 - 100 * k);
    canvas.scale(k);
    const shade = Color(0xFF4A4250);
    ellipse(canvas, const Offset(100, 186), 50, 6, fill(withOpacity(friendInk, 0.12)));
    final blob = Path()
      ..moveTo(44, 170)
      ..cubicTo(30, 120, 52, 60, 100, 58)
      ..cubicTo(148, 60, 170, 120, 156, 170)
      ..quadraticBezierTo(152, 180, 140, 180)
      ..lineTo(60, 180)
      ..quadraticBezierTo(48, 180, 44, 170)
      ..close();
    canvas.drawPath(blob, fill(withOpacity(shade, 0.85)));
    // question mark
    final q = Path()
      ..moveTo(84, 100)
      ..quadraticBezierTo(84, 82, 100, 82)
      ..quadraticBezierTo(116, 82, 116, 98)
      ..quadraticBezierTo(116, 108, 104, 114)
      ..quadraticBezierTo(100, 117, 100, 126);
    canvas.drawPath(q, stroke(const Color(0xFFF1ECF6), 9));
    canvas.drawCircle(const Offset(100, 146), 6, fill(const Color(0xFFF1ECF6)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MysteryFriendPainter old) => false;
}
