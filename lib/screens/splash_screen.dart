// Launch splash (1.6.0): "one breath before the app".
//
// The zeep logo sits in the middle of the screen exactly where the native
// launch screen drew it (180 x 58, centred on the whole window, on #F7FBFD).
// On the inhale the 13 friends drift out from behind the logo, nearest first;
// they breathe once with their own pose, drift back on the exhale, and the
// splash fades into the Breathe tab. Approved preview:
// https://claude.ai/artifact/KvJ8pyTSXYt7SLwYw2EkS7 (option B at half speed).
//
// The app loads in parallel. If it isn't ready when the breath reaches its
// hold, the splash keeps breathing slowly until it is. Tap to skip. No sound,
// no haptics. Reduce Motion: the friends fade in place, then the splash fades.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Launch background, the same colour as the native launch screens
/// (android res/values/colors.xml, iOS LaunchScreen.storyboard).
const splashBackground = Color(0xFFF7FBFD);

/// The logo's size on screen; the native launch images are made at this size.
const splashLogoSize = Size(180, 58);

/// A friend on the splash: its slot on a 360 x 740 reference screen (x and y
/// scale with the screen's width and height, so edge friends keep peeking in
/// from the edges) and its size there.
class SplashFriend {
  final String name;
  final double x, y, size, tilt;
  const SplashFriend(this.name, this.x, this.y, this.size, this.tilt);
}

const splashFriends = [
  SplashFriend('miu', 92, 240, 96, 3),
  SplashFriend('nguang', 276, 236, 78, -3),
  SplashFriend('tuntun', 96, 506, 84, -3),
  SplashFriend('fufu', 284, 506, 90, 3),
  SplashFriend('pliw', 180, 112, 82, 0),
  SplashFriend('ok', 50, 296, 48, -4),
  SplashFriend('prakai', 308, 446, 52, 4),
  SplashFriend('lumi', 28, 46, 96, 4),
  SplashFriend('mun', 334, 50, 100, -3),
  SplashFriend('nuan', 14, 618, 92, 3),
  SplashFriend('kring', 346, 610, 86, -3),
  SplashFriend('toom', 250, 640, 66, 2),
  SplashFriend('panpan', 180, 728, 110, 0),
];

/// Decodes the logo before the first frame, so the splash's first frame shows
/// it (an asset image would appear a frame or two late: a flicker right after
/// the native launch screen). Null if it can't be loaded.
Future<ui.Image?> loadSplashLogo() async {
  try {
    final data = await rootBundle.load('assets/splash/logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

double _seg(double t, double a, double b, Curve c) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
double _lerp(double a, double b, double k) => a + (b - a) * k;

class SplashScreen extends StatefulWidget {
  /// Completes when the app has loaded.
  final Future<void> ready;

  /// The splash starts fading out: put the app underneath now.
  final VoidCallback onReveal;

  /// The splash has faded out: remove it.
  final VoidCallback onDone;

  /// 0.5 = the approved half speed.
  final double speed;

  /// The logo decoded before the first frame ([loadSplashLogo]).
  final ui.Image? logo;

  const SplashScreen({
    super.key,
    required this.ready,
    required this.onReveal,
    required this.onDone,
    this.speed = 0.5,
    this.logo,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // design timeline in ms (preview at speed 1); the hold ends at 1300
  static const _holdEnd = 1300.0, _fadeStart = 1500.0, _end = 1900.0;
  static const _skipFade = 300.0; // real ms

  late final Ticker _ticker;
  late final List<int> _rank; // emerge order: nearest to the logo first
  Duration _last = Duration.zero;
  double _t = 0; // design time
  double _waited = 0; // real ms spent breathing at the hold
  bool _ready = false, _revealed = false, _done = false, _skip = false;
  double _skipT = 0; // real ms into the skip fade
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    final order = List.generate(splashFriends.length, (i) => i)
      ..sort((a, b) => _dist(splashFriends[a]).compareTo(_dist(splashFriends[b])));
    _rank = List.filled(splashFriends.length, 0);
    for (var r = 0; r < order.length; r++) {
      _rank[order[r]] = r;
    }
    widget.ready.then((_) {
      if (mounted) _ready = true;
    });
    _ticker = createTicker(_tick)..start();
  }

  static double _dist(SplashFriend f) => math.sqrt(math.pow(f.x - 180, 2) + math.pow(f.y - 370, 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    for (final f in splashFriends) {
      precacheImage(AssetImage('assets/splash/${f.name}_0.png'), context);
      precacheImage(AssetImage('assets/splash/${f.name}_1.png'), context);
    }
    precacheImage(const AssetImage('assets/splash/logo.png'), context);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    if (_done) return;
    if (_skip) {
      _skipT += dt;
      if (_skipT >= _skipFade) _finish();
      setState(() {});
      return;
    }
    if (_reduce) {
      // fade in 200-500, hold until ready, fade out 300 ms
      final limit = _ready ? 900.0 : 600.0;
      _t = math.min(_t + dt, limit);
      if (_t >= 600) _reveal();
      if (_t >= 900) _finish();
      setState(() {});
      return;
    }
    final step = dt * widget.speed;
    // past the hold only when loaded and, if it had to wait, once the slow
    // waiting breath is back at its start (no jump)
    final go = _ready && (_waited == 0 || _wobble < 0.02);
    _t = go ? _t + step : math.min(_t + step, _holdEnd);
    if (_t >= _holdEnd && !go) _waited += dt;
    if (_t >= _fadeStart) _reveal();
    if (_t >= _end) _finish();
    setState(() {});
  }

  void _reveal() {
    if (_revealed) return;
    _revealed = true;
    widget.onReveal();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _reveal();
    widget.onDone();
  }

  void _onTap() {
    if (_skip || _done) return;
    if (!_ready) return; // nothing to show yet: keep breathing
    _skip = true;
    _reveal();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 0..1..0 every 4 s while waiting at the hold.
  double get _wobble => _waited <= 0 ? 0 : 0.5 - 0.5 * math.cos(_waited / 4000 * 2 * math.pi);

  double get _opacity {
    double o;
    if (_reduce) {
      o = 1 - _seg(_t, 600, 900, Curves.easeOut);
    } else {
      o = 1 - _seg(_t, _fadeStart, _end, Curves.easeOutCubic);
    }
    if (_skip) o *= 1 - (_skipT / _skipFade).clamp(0.0, 1.0);
    return o;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t, w = _wobble, reduce = _reduce;
    return Semantics(
      label: 'ZEEP Breathe',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Opacity(
          opacity: _opacity.clamp(0.0, 1.0),
          child: LayoutBuilder(
            builder: (context, box) {
              final sw = box.maxWidth, sh = box.maxHeight;
              final cx = sw / 2, cy = sh / 2;
              final k = math.min(sw / 360, sh / 740).clamp(0.8, 1.6);
              final bgK = reduce ? 1.0 : _seg(t, 0, 400, Curves.easeInOutSine);
              final glowK = reduce ? 0.7 : bgK * (1 - _seg(t, 1300, 1750, Curves.easeInOutCubic));
              var logoScale = reduce
                  ? 1.0
                  : t < 400
                  ? _lerp(1, 1.04, _seg(t, 0, 400, Curves.easeInOutSine))
                  : t < _holdEnd
                  ? 1.04
                  : _lerp(1.04, 0.96, _seg(t, 1300, 1750, Curves.easeInOutCubic));
              if (!reduce && t <= _holdEnd && _waited > 0) logoScale = 1.04 - 0.03 * w;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned.fill(child: ColoredBox(color: splashBackground)),
                  Positioned.fill(
                    child: Opacity(
                      opacity: bgK,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [splashBackground, Color(0xFFEDF4FA)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // soft mint glow behind the logo (30 % at most)
                  Positioned(
                    left: cx - 130 * k,
                    top: cy - 130 * k,
                    width: 260 * k,
                    height: 260 * k,
                    child: Opacity(
                      opacity: (0.3 * glowK * (1 - 0.4 * w)).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _lerp(0.8, 1, bgK),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [Color(0xFF9FE0CF), Color(0x009FE0CF)], stops: [0, 0.7]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < splashFriends.length; i++) _friend(i, t, w, sw, sh, cx, cy, k),
                  // the logo: same size and place as the native launch screen
                  Positioned(
                    left: cx - splashLogoSize.width / 2,
                    top: cy - splashLogoSize.height / 2,
                    width: splashLogoSize.width,
                    height: splashLogoSize.height,
                    child: Transform.scale(
                      scale: logoScale,
                      child: widget.logo != null
                          ? RawImage(image: widget.logo, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
                          : Image.asset('assets/splash/logo.png', fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _friend(int i, double t, double w, double sw, double sh, double cx, double cy, double k) {
    final f = splashFriends[i];
    final size = f.size * k;
    final box = size * 1.2; // the art is 200 units inside a 240-unit image
    final sx = f.x / 360 * sw, sy = f.y / 740 * sh;
    double px, py, scale, opacity, lv, tilt;
    if (_reduce) {
      px = sx;
      py = sy;
      scale = 1;
      tilt = 0;
      lv = 0.5;
      opacity = _seg(t, 200, 500, Curves.easeOut);
    } else {
      final a = 200.0 + _rank[i] * 40;
      final kOut = _seg(t, a, a + 550, Curves.easeOutCubic);
      final kFade = _seg(t, a, a + 250, Curves.easeOut);
      final kHold = _seg(t, 1000, _holdEnd, Curves.easeInOutSine);
      final r = splashFriends.length - 1 - _rank[i];
      final kBack = _seg(t, 1300 + r * 25.0, 1700 + r * 25.0, Curves.easeInOutCubic);
      final waiting = t <= _holdEnd && _waited > 0;
      final dx = sx - cx, dy = sy - cy, len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final drift = (3 * kHold + (waiting ? 3 * w : 0)) * k;
      px = _lerp(cx, sx, kOut) + dx / len * drift;
      py = _lerp(cy, sy, kOut) + dy / len * drift;
      px = _lerp(px, _lerp(cx, sx, 0.5), kBack);
      py = _lerp(py, _lerp(cy, sy, 0.5), kBack);
      scale = _lerp(0.5, 1, kOut) * _lerp(1, 0.8, kBack);
      opacity = kFade * (1 - kBack);
      lv = waiting ? 0.5 + 0.5 * w : 0.5 * kHold * (1 - kBack);
      tilt = f.tilt * kOut;
    }
    return Positioned(
      left: px - box / 2,
      top: py - box / 2,
      width: box,
      height: box,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: tilt * math.pi / 180,
          child: Transform.scale(
            scale: scale,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/splash/${f.name}_0.png', gaplessPlayback: true),
                // its own breath: blend towards the "breathed in" pose
                Opacity(
                  opacity: lv.clamp(0.0, 1.0),
                  child: Image.asset('assets/splash/${f.name}_1.png', gaplessPlayback: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
