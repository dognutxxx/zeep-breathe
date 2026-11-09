// Launch splash (1.9.0): "Zeep breathes under the night sky" (design A,
// `specs/splash-dark-1.9.0.md`, deck https://claude.ai/artifact/YZvhgx4DFhADag26PcU5cz).
//
// Always dark, whatever the system light/dark mode. The first frame matches
// the native launch screen: the Soft Paper zeep logo (180 x 58) centred on the
// whole window, on Midnight. Then one breath, about 3.9 s in real time:
//   0-400 ms     faint Lavender stars fade in
//   400-1600     inhale: Zeep fades in and rises (0.96 -> 1.04), a Rest Violet
//                glow grows behind him (0.8 -> 1.0, 60 % at most), the logo
//                slides down below him
//   1600-2400    hold: the glow at its brightest. Not loaded yet: stay here and
//                breathe slowly, 4 s a cycle, until the app is ready
//   2400-3400    exhale: the glow dims, Zeep 1.04 -> 0.98
//   3400-3900    fade out into the Breathe tab
// Zeep is drawn by `drawZeep`, unchanged. Tap to skip once loaded (300 ms
// fade). No sound, no haptics. Reduce Motion: nothing moves; fade in 300 ms,
// hold, fade out 300 ms.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ui/brand_colors.dart';
import '../ui/zeep_character.dart';

/// Launch background, the same colour as the native launch screens
/// (android res/values/colors.xml, iOS LaunchScreen.storyboard).
const splashBackground = BrandColors.background;

/// The logo's size on screen; the native launch images are made at this size.
const splashLogoSize = Size(180, 58);

/// Where Zeep and the glow sit, as a fraction of the screen height.
const splashZeepY = 0.42;

/// How far the logo slides down on a 393 x 852 phone (scaled to the screen).
const splashLogoDrop = 120.0;

/// Decodes the logo before the first frame, so the splash's first frame shows
/// it (an asset image would appear a frame or two late: a flicker right after
/// the native launch screen). Null if it can't be loaded. The asset is the
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
  static const _inhaleStart = 400.0, _holdStart = 1600.0, _holdEnd = 2400.0;
  static const _fadeStart = 3400.0, _end = 3900.0;
  static const _skipFade = 300.0; // real ms
  // Reduce Motion: fade in, hold, fade out
  static const _rmIn = 300.0, _rmHoldEnd = 900.0, _rmEnd = 1200.0;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0; // timeline ms
  double _clock = 0; // real seconds since the splash appeared (Zeep's float)
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
    _clock += dt / 1000;
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

  /// Zeep's pose along the breath (the same shapes the Breathe tab uses).
  Pose _pose(double t, double w) {
    final kIn = _seg(t, _inhaleStart, _holdStart, Curves.easeInOutSine);
    Pose inhale(double level) => Pose(
      breath: level,
      armLift: level,
      cheekPuff: 0.15 + 0.3 * level,
      eyeSqueeze: 0.25 * level,
      mouthOpen: 0,
      hold: 0,
      tint: tintInhale,
    );
    if (t < _holdStart) return inhale(kIn);
    // waiting for the app: the hold breathes out a little and back, 4 s a cycle
    final hold = Pose(
      breath: 1 - 0.3 * w,
      armLift: 1 - 0.3 * w,
      cheekPuff: 0.7 - 0.3 * w,
      eyeSqueeze: 0.45,
      mouthOpen: 0,
      hold: 1 - 0.4 * w,
      tint: tintHold,
    );
    if (t <= _holdEnd) return Pose.lerp(inhale(1), hold, _seg(t, _holdStart, _holdStart + 350, Curves.easeInOutSine));
    final pt = ((t - _holdEnd) / (_fadeStart - _holdEnd)).clamp(0.0, 1.0);
    final level = 1 - Curves.easeInOutCubic.transform(pt);
    final exhale = Pose(
      breath: level,
      armLift: level,
      cheekPuff: 0.1 * level,
      eyeSqueeze: 0,
      mouthOpen: (math.pow(math.sin(pt * math.pi), 0.5) * (1 - pt * 0.35)).toDouble(),
      hold: 0,
      tint: tintExhale,
    );
    return Pose.lerp(hold, exhale, _seg(t, _holdEnd, _holdEnd + 350, Curves.easeInOutSine));
  }

  static const _restPose = Pose(
    breath: 0.3,
    armLift: 0.15,
    cheekPuff: 0.12,
    eyeSqueeze: 0,
    mouthOpen: 0,
    hold: 0,
    tint: tintInhale,
  );

  @override
  Widget build(BuildContext context) {
    final t = _t, w = _wobble, reduce = _reduce;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // light status / navigation icons on the dark splash
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
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
                final k = splashScale(size);
                final cx = size.width / 2, cy = size.height / 2;
                final SplashPainter painter;
                double logoDy, logoOpacity = 1, lowLogoOpacity = 0;
                if (reduce) {
                  // nothing moves: the centred logo hands over to the lower one
                  final f = _seg(t, 0, _rmIn, Curves.easeOut);
                  painter = SplashPainter(
                    stars: f,
                    glowOpacity: 0.6 * f,
                    glowScale: 1,
                    zeepOpacity: f,
                    zeepScale: 1,
                    zeepRise: 0,
                    pose: _restPose,
                    time: 0,
                    reduceMotion: true,
                  );
                  logoDy = 0;
                  logoOpacity = 1 - f;
                  lowLogoOpacity = f;
                } else {
                  final kIn = _seg(t, _inhaleStart, _holdStart, Curves.easeInOutSine);
                  final kEx = _seg(t, _holdEnd, _fadeStart, Curves.easeInOutCubic);
                  final scale = t <= _holdEnd ? _lerp(0.96, 1.04, kIn) - 0.03 * w : _lerp(1.04, 0.98, kEx);
                  painter = SplashPainter(
                    stars: _seg(t, 0, _inhaleStart, Curves.easeInOutSine),
                    glowOpacity: 0.6 * kIn * (1 - 0.7 * kEx) * (1 - 0.3 * w),
                    glowScale: _lerp(0.8, 1, kIn),
                    zeepOpacity: _seg(t, _inhaleStart, _inhaleStart + 600, Curves.easeOut),
                    zeepScale: scale,
                    zeepRise: 1 - kIn,
                    pose: _pose(t, w),
                    time: _clock,
                  );
                  logoDy = splashLogoDrop * k * kIn;
                }
                Widget logo(double dy, double opacity) => Positioned(
                  left: cx - splashLogoSize.width / 2,
                  top: cy + dy - splashLogoSize.height / 2,
                  width: splashLogoSize.width,
                  height: splashLogoSize.height,
                  child: widget.logo != null
                      ? RawImage(
                          image: widget.logo,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          color: BrandColors.onDark,
                          colorBlendMode: BlendMode.srcIn,
                          opacity: AlwaysStoppedAnimation(opacity),
                        )
                      : Image.asset(
                          'assets/splash/logo.png',
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          color: BrandColors.onDark,
                          colorBlendMode: BlendMode.srcIn,
                          opacity: AlwaysStoppedAnimation(opacity),
                        ),
                );
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: painter)),
                    // the logo: same size and place as the native launch screen
                    if (logoOpacity > 0) logo(logoDy, logoOpacity),
                    if (lowLogoOpacity > 0) logo(splashLogoDrop * k, lowLogoOpacity),
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

/// A faint star: its place as a fraction of the screen, radius and opacity.
class _Star {
  final double x, y, r, a;
  const _Star(this.x, this.y, this.r, this.a);
}

// kept clear of Zeep, the glow's bright middle and the logo
const _stars = [
  _Star(0.12, 0.08, 1.2, 0.45),
  _Star(0.31, 0.15, 0.9, 0.3),
  _Star(0.58, 0.06, 1.0, 0.35),
  _Star(0.86, 0.13, 1.4, 0.4),
  _Star(0.07, 0.29, 0.9, 0.25),
  _Star(0.93, 0.33, 1.0, 0.3),
  _Star(0.18, 0.62, 1.1, 0.3),
  _Star(0.84, 0.70, 0.9, 0.25),
  _Star(0.10, 0.80, 1.3, 0.35),
  _Star(0.62, 0.86, 1.0, 0.3),
  _Star(0.90, 0.92, 1.2, 0.35),
  _Star(0.36, 0.94, 0.9, 0.25),
];

// the two four-point sparkles
const _sparkles = [_Star(0.78, 0.21, 7, 0.4), _Star(0.20, 0.47, 5, 0.3)];

/// Draws the night sky, the glow and Zeep; public for tests.
class SplashPainter extends CustomPainter {
  /// Stars' fade (0..1).
  final double stars;
  final double glowOpacity, glowScale;
  final double zeepOpacity, zeepScale;

  /// 1 = Zeep still low (before the inhale), 0 = risen.
  final double zeepRise;
  final Pose pose;
  final double time;
  final bool reduceMotion;

  const SplashPainter({
    required this.stars,
    required this.glowOpacity,
    required this.glowScale,
    required this.zeepOpacity,
    required this.zeepScale,
    required this.zeepRise,
    required this.pose,
    required this.time,
    this.reduceMotion = false,
  });

  /// Zeep's resting centre on a screen of [size].
  static Offset zeepCentre(Size size, double rise) =>
      Offset(size.width / 2, size.height * splashZeepY + 18 * splashScale(size) * rise);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final k = splashScale(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = BrandColors.background);
    if (stars > 0) {
      final dot = Paint()..isAntiAlias = true;
      for (final s in _stars) {
        dot.color = BrandColors.accent.withValues(alpha: s.a * stars);
        canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r * k, dot);
      }
      for (final s in _sparkles) {
        dot.color = BrandColors.accent.withValues(alpha: s.a * stars);
        _sparkle(canvas, Offset(s.x * size.width, s.y * size.height), s.r * k, dot);
      }
    }
    final glowCentre = Offset(size.width / 2, size.height * splashZeepY);
    if (glowOpacity > 0) {
      final r = 180 * k * glowScale;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: BrandColors.glow,
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(Rect.fromCircle(center: glowCentre, radius: r))
        ..color = Color.fromRGBO(0, 0, 0, glowOpacity.clamp(0.0, 1.0));
      canvas.drawCircle(glowCentre, r, paint);
    }
    if (zeepOpacity > 0) {
      final c = zeepCentre(size, zeepRise);
      final s = k * zeepScale;
      final fading = zeepOpacity < 1;
      if (fading) {
        canvas.saveLayer(
          Rect.fromCircle(center: c, radius: 160 * s),
          Paint()..color = Color.fromRGBO(0, 0, 0, zeepOpacity),
        );
      }
      drawZeep(canvas, c, s, pose, time, c.dy + 64 * s, const [], reduceMotion: reduceMotion);
      if (fading) canvas.restore();
    }
  }

  static void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final n = r * 0.22;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + n, c.dy - n, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + n, c.dy + n, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - n, c.dy + n, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - n, c.dy - n, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SplashPainter old) => true;
}
