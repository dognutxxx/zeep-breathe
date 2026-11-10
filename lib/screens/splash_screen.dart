// Launch splash (1.9.1): only the zeep wordmark, centred (`specs/splash-logo-1.9.1.md`).
//
// Always dark, whatever the system light/dark mode. The first frame matches
// the native launch screen: the Soft Paper zeep wordmark (180 x 58) at the
// exact centre of the whole window, on Midnight. Then one gentle breath, about
// 2.9 s in real time:
//   0-200 ms     static, as the native launch screen
//   200-1200     inhale: the wordmark 1.00 -> 1.06 (easeInOutSine), a Rest
//                Violet glow behind it grows to 45 %
//   1200-1600    hold at the peak. Not loaded yet: stay here and breathe
//                slowly, 4 s a cycle, until the app is ready
//   1600-2400    exhale: back to 1.00, the glow fades (easeInOutCubic)
//   2400-2900    fade out into the Breathe tab (easeOutCubic)
// No character, no stars. Tap to skip once loaded (300 ms fade). No sound, no
// haptics. Reduce Motion: no scale and no glow; the still wordmark for 0.9 s
// (300 ms in and the hold), then a 300 ms fade out.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ui/brand_colors.dart';

/// Launch background, the same colour as the native launch screens
/// (android res/values/colors.xml, iOS LaunchScreen.storyboard).
const splashBackground = BrandColors.background;

/// The wordmark's size on screen; the native launch images are made at this size.
const splashLogoSize = Size(180, 58);

/// Light status / navigation bar icons on the dark splash. `main()` sets it
/// before the first frame too (no dark-icon blink after the native launch
/// screen); the launch gate puts the app's dark icons back afterwards.
const splashBarsStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// The wordmark's size at the inhale peak.
const splashPeakScale = 1.06;

/// The glow's opacity at the inhale peak.
const splashPeakGlow = 0.45;

/// Decodes the wordmark before the first frame, so the splash's first frame
/// shows it (an asset image would appear a frame or two late: a flicker right
/// after the native launch screen). Null if it can't be loaded. The asset is the
/// blue brand logo; the splash tints it Soft Paper.
Future<ui.Image?> loadSplashLogo() async {
  try {
    final data = await rootBundle.load('assets/splash/logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

/// Drops the splash logo from the image cache; the splash is shown once per run.
void evictSplashImages() {
  const AssetImage('assets/splash/logo.png').evict();
}

double _seg(double t, double a, double b, Curve c) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
double _lerp(double a, double b, double k) => a + (b - a) * k;

/// The splash's scale: 1 on a 393 x 852 phone.
double splashScale(Size size) => math.min(size.width / 393, size.height / 852).clamp(0.7, 1.6);

class SplashScreen extends StatefulWidget {
  /// Completes when the app has loaded.
  final Future<void> ready;

  /// The splash starts fading out: put the app underneath now.
  final VoidCallback onReveal;

  /// The splash has faded out: remove it.
  final VoidCallback onDone;

  /// 1 = real time (the approved timing); tests may speed it up.
  final double speed;

  /// The logo decoded before the first frame ([loadSplashLogo]).
  final ui.Image? logo;

  const SplashScreen({
    super.key,
    required this.ready,
    required this.onReveal,
    required this.onDone,
    this.speed = 1,
    this.logo,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // timeline in real ms (at speed 1)
  static const _inhaleStart = 200.0, _holdStart = 1200.0, _holdEnd = 1600.0;
  static const _fadeStart = 2400.0, _end = 2900.0;
  static const _skipFade = 300.0; // real ms
  // Reduce Motion: the first 300 ms (the "fade in") and the hold are the
  // still wordmark, which is already on screen (no flash after the native
  // launch screen); then a 300 ms fade out
  static const _rmHoldEnd = 900.0, _rmEnd = 1200.0;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0; // timeline ms
  double _waited = 0; // real ms spent breathing at the hold
  bool _ready = false, _revealed = false, _done = false, _skip = false;
  double _skipT = 0; // real ms into the skip fade
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    widget.ready.then(
      (_) {
        if (mounted) _ready = true;
      },
      onError: (Object _) {}, // reported by the launch gate
    );
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (widget.logo == null) precacheImage(const AssetImage('assets/splash/logo.png'), context);
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
      _t = math.min(_t + dt, _ready ? _rmEnd : _rmHoldEnd);
      if (_t >= _rmHoldEnd) _reveal();
      if (_t >= _rmEnd) _finish();
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
    var o = _reduce
        ? 1 - _seg(_t, _rmHoldEnd, _rmEnd, Curves.easeOut)
        : 1 - _seg(_t, _fadeStart, _end, Curves.easeOutCubic);
    if (_skip) o *= 1 - (_skipT / _skipFade).clamp(0.0, 1.0);
    return o;
  }

  /// How far into the breath (0 = rest, 1 = inhale peak) at timeline [t];
  /// [w] is the slow waiting breath at the hold.
  static double _level(double t, double w) {
    if (t <= _holdEnd) return _seg(t, _inhaleStart, _holdStart, Curves.easeInOutSine) * (1 - 0.5 * w);
    return 1 - _seg(t, _holdEnd, _fadeStart, Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion: nothing moves and no glow; only the fades
    final level = _reduce ? 0.0 : _level(_t, _wobble);
    final scale = _lerp(1, splashPeakScale, level);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // light status / navigation icons on the dark splash
      value: splashBarsStyle,
      child: Semantics(
        label: 'ZEEP Breathe',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Opacity(
            opacity: _opacity.clamp(0.0, 1.0),
            child: LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: SplashPainter(glowOpacity: splashPeakGlow * level)),
                    ),
                    // the wordmark: same size and place as the native launch screen
                    Positioned(
                      left: size.width / 2 - splashLogoSize.width / 2,
                      top: size.height / 2 - splashLogoSize.height / 2,
                      width: splashLogoSize.width,
                      height: splashLogoSize.height,
                      child: Transform.scale(
                        scale: scale,
                        child: widget.logo != null
                            ? RawImage(
                                image: widget.logo,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                color: BrandColors.onDark,
                                colorBlendMode: BlendMode.srcIn,
                              )
                            : Image.asset(
                                'assets/splash/logo.png',
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                color: BrandColors.onDark,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the Midnight background and the glow behind the wordmark; public for
/// tests.
class SplashPainter extends CustomPainter {
  /// 0 = no glow; [splashPeakGlow] at the inhale peak.
  final double glowOpacity;

  const SplashPainter({required this.glowOpacity});

  /// The glow's radius on a screen of [size].
  static double glowRadius(Size size) => 180 * splashScale(size);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = BrandColors.background);
    if (glowOpacity <= 0) return;
    final centre = size.center(Offset.zero);
    final r = glowRadius(size);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: BrandColors.glow,
        stops: const [0, 0.35, 0.7, 1],
      ).createShader(Rect.fromCircle(center: centre, radius: r))
      ..color = Color.fromRGBO(0, 0, 0, glowOpacity.clamp(0.0, 1.0));
    canvas.drawCircle(centre, r, paint);
  }

  @override
  bool shouldRepaint(SplashPainter old) => old.glowOpacity != glowOpacity;
}
