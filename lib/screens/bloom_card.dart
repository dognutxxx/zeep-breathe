// Card L: a flower bloomed, so Zeep levelled up. Shown after "Done" on the
// finish card (S.8) or the game results (GR), before any new-item card (N).
// Timing follows Richie's research (research-reports/level-up-bloom-*.md,
// table B0-B9 and the reduce-motion version in 3.6): one calm peak, the bud
// swells like an in-breath, the petals open, then everything rests.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app_controller.dart';
import '../haptics/haptics_service.dart';
import '../l10n/strings.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import '../wardrobe/flowers.dart';
import '../wardrobe/outfits.dart';
import '../wardrobe/wardrobe_controller.dart';

/// What the person picked on card L.
enum BloomChoice { next, garden }

/// Full timeline of the standard version (ms): the sequence ends at 3400,
/// then the flower rocks twice with a 4 s breath and stops at 11400.
const _seqEnd = 3400.0, _rockEnd = 11400.0, _reducedEnd = 700.0;

/// Skipping is allowed from 600 ms; the buttons take taps from 3100 ms.
const skipFromMs = 600.0, buttonsFromMs = 3100.0;

Future<BloomChoice> showBloomCard(BuildContext context, AppController app, GrowthEvent e) async {
  final reduce = MediaQuery.of(context).disableAnimations || app.reduceMotion;
  final r = await Navigator.of(context).push<BloomChoice>(
    PageRouteBuilder<BloomChoice>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: Duration(milliseconds: reduce ? 200 : 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => BloomCard(app: app, event: e, reduceMotion: reduce),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
        child: child,
      ),
    ),
  );
  return r ?? BloomChoice.next;
}

class BloomCard extends StatefulWidget {
  final AppController app;
  final GrowthEvent event;
  final bool reduceMotion;
  const BloomCard({super.key, required this.app, required this.event, this.reduceMotion = false});

  @override
  State<BloomCard> createState() => BloomCardState();
}

class BloomCardState extends State<BloomCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _nextFocus = FocusNode();
  bool _bloomFired = false, _inhaleFired = false, _confirmFired = false;

  bool get _reduce => widget.reduceMotion;
  double get _end => _reduce ? _reducedEnd : _rockEnd;

  /// Elapsed time on the card's timeline, in ms.
  double get ms => _c.value * _end;

  @override
  void initState() {
    super.initState();
    _c =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: _end.round()),
          )
          ..addListener(_onTick)
          ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = S.of(context);
      final e = widget.event;
      // tell screen readers straight away and put focus on "Next"
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${l.bloomedTitle} ${l.bloomedDetail(e.after.level, l.flowerName(e.newFlower!))}',
        Directionality.of(context),
      );
      _nextFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _nextFocus.dispose();
    super.dispose();
  }

  void _fire(HapticPattern p) {
    final h = widget.app.haptics;
    // the app's clock stands still under this card: add our own time to it,
    // so the 250 ms guard keeps working
    h.fire(p, widget.app.time + (_c.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6);
  }

  void _onTick() {
    final t = ms;
    if (_reduce) {
      if (!_bloomFired && t >= 200) _fireBloom();
    } else {
      if (!_inhaleFired && t >= 1100) {
        _inhaleFired = true;
        _fire(HapticPattern.inhaleStart);
      }
      if (!_bloomFired && t >= 1900) _fireBloom();
      if (!_confirmFired && t >= 2640) {
        _confirmFired = true;
        _fire(HapticPattern.confirm);
      }
    }
  }

  void _fireBloom() {
    _bloomFired = true;
    _fire(HapticPattern.bloom);
  }

  /// Tap anywhere from 600 ms: jump to the resting end of the sequence.
  void skip() {
    if (_reduce || ms < skipFromMs || ms >= _seqEnd) return;
    if (!_bloomFired) {
      // skipped before the bloom: one bloom pulse only, no inhale or tick
      _inhaleFired = _confirmFired = true;
      _fireBloom();
    } else {
      _confirmFired = true;
    }
    _c.value = _seqEnd / _end;
    _c.forward();
  }

  void _close(BloomChoice c) => Navigator.of(context).pop(c);

  // ---------------------------------------------------------------- timing

  /// 0..1 between [a] and [b] ms, eased.
  double _iv(double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((ms - a) / (b - a)).clamp(0.0, 1.0));

  static const _easeOutQuint = Cubic(0.22, 1, 0.36, 1);
  static const _petalCurve = Cubic(0.34, 1.25, 0.64, 1);

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final e = widget.event;
    final kind = e.newFlower!;
    final level = e.after.level;
    final repeat = e.after.bloomCounts[flowerKinds.indexOf(kind)];
    final w = widget.app.wardrobe;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final reduce = _reduce;
        // B0: the cream backdrop
        final backdrop = reduce ? 1.0 : _iv(0, 280, Curves.easeOutCubic);
        // B1: Zeep floats up
        final zIn = reduce ? 1.0 : _iv(200, 800, _easeOutQuint);
        // B3: the bud swells; B4: petals open and colour in
        final bud = reduce ? 1.0 : 0.85 + 0.23 * _iv(1100, 1900, Curves.easeInOutSine) - 0.08 * _iv(1900, 2600);
        final open = reduce ? 1.0 : _iv(1900, 2420, _petalCurve);
        final colour = reduce ? _iv(200, 600, Curves.easeOut) : _iv(1900, 2500, Curves.easeOut);
        final glow = reduce ? 0.0 : _iv(1100, 1900, Curves.easeInOutSine) * (1 - _iv(2600, 3400));
        final ring = reduce ? -1.0 : (ms >= 1900 ? _iv(1900, 2800, Curves.easeOutCubic) : -1.0);
        final pollen = reduce ? -1.0 : (ms >= 1900 ? ms - 1900 : -1.0);
        // B9: two slow rocks with a 4 s breath, then still
        final rock = reduce || ms < _seqEnd || ms >= _rockEnd
            ? 0.0
            : math.sin((ms - _seqEnd) / 4000 * 2 * math.pi) * 2.5 * math.pi / 180;
        // B6-B8 (reduce motion: everything fades in at 400-700)
        final pill = reduce ? _iv(400, 700) : _iv(2400, 2700, Curves.easeOutCubic);
        final digit = reduce ? 1.0 : _iv(2480, 2800, Curves.easeInOutCubic);
        final name = reduce ? _iv(400, 700) : _iv(2750, 3050, Curves.easeOutCubic);
        final sub = reduce ? _iv(400, 700) : _iv(2870, 3170, Curves.easeOutCubic);
        final buttons = reduce ? _iv(400, 700) : _iv(3100, 3400, Curves.easeOut);
        final canTap = reduce ? ms >= 400 : ms >= buttonsFromMs;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: skip,
          child: Material(
            color: withAlpha(const Color(0xFFFFF7EE), 0.96 * backdrop),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: zIn,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - zIn)),
                            child: Transform.scale(
                              scale: 0.94 + 0.06 * zIn,
                              child: SizedBox(
                                width: 240,
                                height: 260,
                                child: CustomPaint(
                                  painter: _BloomScenePainter(
                                    outfit: w.outfit,
                                    growth: SproutGrowth(
                                      leaves: 0,
                                      flower: kind,
                                      open: open,
                                      colour: colour,
                                      budScale: bud,
                                      rock: rock,
                                    ),
                                    glow: glow,
                                    ring: ring,
                                    pollenMs: pollen,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // B6: "Level N", the number slides from N-1 to N
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: pill,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - pill)),
                            child: _LevelPill(label: l.levelN(level), from: l.levelN(level - 1), t: digit),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: name,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - name)),
                          child: Text(
                            l.flowerTitle(kind),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ZeepColors.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: sub,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - sub)),
                          child: Text(
                            repeat > 1 ? l.flowerAgain(kind, repeat) : l.flowerNew,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: buttons,
                        child: IgnorePointer(
                          ignoring: !canTap,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: () => _close(BloomChoice.garden),
                                style: FilledButton.styleFrom(
                                  backgroundColor: ZeepColors.mint,
                                  foregroundColor: ZeepColors.mintDark,
                                  minimumSize: const Size(132, 48),
                                ),
                                child: Text(l.seeGarden, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              OutlinedButton(
                                focusNode: _nextFocus,
                                onPressed: () => _close(BloomChoice.next),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ZeepColors.text,
                                  minimumSize: const Size(112, 48),
                                ),
                                child: Text(l.next),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelPill extends StatelessWidget {
  final String label, from;
  final double t;
  const _LevelPill({required this.label, required this.from, required this.t});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZeepColors.mintDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: withAlpha(ZeepColors.mint, 0.55), borderRadius: BorderRadius.circular(16)),
      child: ClipRect(
        child: SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // the old level slides up and out, the new one slides up in
              if (t < 1)
                FractionalTranslation(
                  translation: Offset(0, -t),
                  child: Opacity(
                    opacity: 1 - t,
                    child: Text(from, style: style),
                  ),
                ),
              FractionalTranslation(
                translation: Offset(0, 1 - t),
                child: Opacity(
                  opacity: t,
                  child: Text(label, style: style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zeep (the app's own drawing, never redrawn) with the opening flower, plus
/// the glow, one ring and six pollen dots around the flower.
class _BloomScenePainter extends CustomPainter {
  final Outfit outfit;
  final SproutGrowth growth;
  final double glow, ring, pollenMs;
  _BloomScenePainter({
    required this.outfit,
    required this.growth,
    required this.glow,
    required this.ring,
    required this.pollenMs,
  });

  static const _pose = Pose(
    breath: 0.3,
    armLift: 0.3,
    cheekPuff: 0.2,
    eyeSqueeze: 0,
    mouthOpen: 0,
    hold: 0,
    tint: tintInhale,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 175;
    final c = Offset(size.width / 2, size.height * 0.66);
    final a = flowerAnchor(c, s, _pose, growth);
    final petal = growth.flower!.petal;
    if (glow > 0) {
      final r = 56.0 * glow;
      canvas.drawCircle(
        a.centre,
        r + 18,
        Paint()
          ..color = withAlpha(petal, 0.28 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    drawZeep(canvas, c, s, _pose, 0.95, c.dy + 64 * s, const [], reduceMotion: true, outfit: outfit, growth: growth);
    if (ring >= 0 && ring < 1) {
      canvas.drawCircle(
        a.centre,
        24 + 86 * ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 - ring
          ..color = withAlpha(Color.lerp(petal, ZeepColors.ink, 0.25)!, 0.35 * (1 - ring)),
      );
    }
    if (pollenMs >= 0) {
      for (var i = 0; i < 6; i++) {
        final u = ((pollenMs - i * 40) / 800).clamp(0.0, 1.0);
        if (u <= 0 || u >= 1) continue;
        final e = Curves.easeOutQuad.transform(u);
        final ang = -math.pi / 2 + (i - 2.5) * 0.55;
        final dist = 28 + 16 * ((i * 37) % 7) / 6;
        final pos = a.centre + Offset.fromDirection(ang, dist * e) + Offset(0, -6 * e);
        canvas.drawCircle(pos, 2 + (i % 3).toDouble(), Paint()..color = withAlpha(petal, 1 - u));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
