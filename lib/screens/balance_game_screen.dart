// Zeep Balance (T2.3): GP play screen and GR results. Opened from the level
// select (balance_menu_screen.dart). Zeep rolls as the phone tilts; the score
// is the share of time Zeep spends inside the level's circle.
//
// This route covers HomePage, whose ticker then stops, so this screen drives
// the app clock, music and the screen wakelock itself.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_controller.dart';
import '../breathing/breathing_engine.dart';
import '../game/balance_game.dart';
import '../haptics/haptics_service.dart';
import '../l10n/strings.dart';
import '../tilt/tilt_physics.dart';
import '../tilt/tilt_sensor.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

enum _Stage { waiting, countdown, playing, paused, finished, unavailable }

const _ringIn = Color(0xFF5CC3A8);
const _ringOut = Color(0xFFF2A68C);
const _starColor = Color(0xFFE9B949);

class BalanceGameScreen extends StatefulWidget {
  final AppController app;
  final BalanceLevel level;
  final int minutes;
  final TiltSource source;

  /// How the screen is rotated from the device's natural orientation. The
  /// accelerometer reports device axes, so readings are turned into screen
  /// axes with this before they reach the physics.
  final DisplayRotationSource rotationSource;

  /// No reading within this time = treat the device as having no sensor.
  final Duration sensorTimeout;

  const BalanceGameScreen({
    super.key,
    required this.app,
    required this.level,
    required this.minutes,
    this.source = const AccelerometerTiltSource(),
    this.rotationSource = const PlatformDisplayRotation(),
    this.sensorTimeout = const Duration(seconds: 2),
  });

  @override
  State<BalanceGameScreen> createState() => _BalanceGameScreenState();
}

class _BalanceGameScreenState extends State<BalanceGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _countdownSeconds = 3.0;

  /// A 180-degree turn (landscape left to right) may not change the window
  /// size, so nothing in Flutter rebuilds: poll the real rotation while open.
  static const _rotationPoll = Duration(milliseconds: 500);

  final _tilt = TiltController();
  final _score = BalanceScore();
  final _edge = EdgeHaptics();
  late final BreathingEngine _breath;
  late final Ticker _ticker;
  StreamSubscription<Vec3>? _sub;
  Timer? _timeout;
  Timer? _rotationTimer;
  Duration _last = Duration.zero;
  _Stage _stage = _Stage.waiting;
  double _countdown = _countdownSeconds;
  int _rotation = 0;

  /// Seconds of actual play (countdowns and pauses don't count).
  double _played = 0;
  DateTime? _startedAt;
  bool _logged = false, _saved = false, _newBest = false;
  bool _inside = true;

  /// Popped (back button, swipe or Done): the route animates out, nothing
  /// more may happen.
  bool _leaving = false;
  GameCircle _circle = const GameCircle(Vec2.zero, 0);

  AppController get app => widget.app;
  double get _length => widget.minutes * 60.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _breath = BreathingEngine(app.settings.durations, double.infinity);
    _ticker = createTicker(_onTick)..start();
    try {
      _sub = widget.source.readings().listen(
        _onReading,
        onError: (_) => _unavailable(),
        onDone: _unavailable,
        cancelOnError: true,
      );
    } catch (_) {
      _stage = _Stage.unavailable;
    }
    _timeout = Timer(widget.sensorTimeout, () {
      if (!_tilt.hasReading) _unavailable();
    });
    _rotationTimer = Timer.periodic(_rotationPoll, (_) => _readRotation());
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // depend on the window size: when it changes the screen may have rotated
    MediaQuery.sizeOf(context);
    _readRotation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
      // Android draws no frames in the background, so the ticker can't fade
      app.music.stopNow();
    }
  }

  Future<void> _readRotation() async {
    final r = await widget.rotationSource.rotation();
    if (!mounted || r == _rotation) return;
    setState(() {
      _rotation = r;
      // the level pose was taken in the old screen axes: count 3-2-1 again
      if (_stage == _Stage.countdown || _stage == _Stage.playing) _startCountdown();
    });
  }

  void _onReading(Vec3 g) {
    _tilt.onReading(remapTilt(g, _rotation));
    if (_stage == _Stage.waiting) setState(_startCountdown);
  }

  /// No sensor, or the sensor failed (also mid-game): stop and say so.
  void _unavailable() {
    if (!mounted || _stage == _Stage.unavailable) return;
    _timeout?.cancel();
    _rotationTimer?.cancel();
    _sub?.cancel();
    _log(completed: false);
    setState(() => _stage = _Stage.unavailable);
  }

  void _startCountdown() {
    _stage = _Stage.countdown;
    _countdown = _countdownSeconds;
    _edge.reset();
  }

  void _pause() {
    if (_stage != _Stage.playing && _stage != _Stage.countdown) return;
    setState(() => _stage = _Stage.paused);
  }

  /// Resuming counts 3-2-1 again: the player may be holding the phone
  /// differently after a pause.
  void _resume() {
    if (_stage == _Stage.paused) setState(_startCountdown);
  }

  void _playAgain() {
    setState(() {
      _played = 0;
      _startedAt = null;
      _logged = _saved = _newBest = false;
      _score.reset();
      _breath.stop();
      _startCountdown();
    });
  }

  /// Saves the game once (stopped games too, if 30 s or longer).
  void _log({required bool completed}) {
    if (_logged || _startedAt == null || _played <= 0) return;
    _logged = true;
    final best = app.settings.gameBest[widget.level.index];
    final score = _score.percent;
    _newBest = completed && score > best;
    _saved = app.logGame(
      level: widget.level,
      start: _startedAt!,
      seconds: _played.round(),
      score: score,
      completed: completed,
    );
  }

  void _finish({required bool completed}) {
    _log(completed: completed);
    if (completed) app.haptics.fire(HapticPattern.confirm, app.time);
    setState(() => _stage = _Stage.finished);
  }

  void _onTick(Duration elapsed) {
    // cap the step: after a pause or a hitch Zeep must not jump
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    if (_leaving) return;
    // HomePage's ticker is stopped while this route covers it
    app.time += dt;
    app.music.update(dt, app.settings.music && _stage == _Stage.playing, app.settings.track);
    switch (_stage) {
      case _Stage.countdown:
        _tilt.tick(dt); // times the calibration average
        _countdown -= dt;
        if (_countdown <= 0) {
          if (_tilt.calibrate()) {
            _stage = _Stage.playing;
            _startedAt ??= app.clock();
            if (widget.level == BalanceLevel.medium && !_breath.isActive) _phaseHaptic(_breath.start());
          } else {
            _stage = _Stage.waiting;
          }
        }
        setState(() {});
      case _Stage.playing:
        _play(dt);
        setState(() {});
      case _Stage.waiting:
      case _Stage.paused:
      case _Stage.finished:
      case _Stage.unavailable:
        break;
    }
  }

  void _play(double dt) {
    _tilt.update(dt);
    if (widget.level == BalanceLevel.medium) _phaseHaptic(_breath.update(dt));
    _played += dt;
    _inside = _circle.contains(_tilt.ball.pos);
    _score.add(dt, _inside);
    final edge = switch (_edge.update(_inside, _played)) {
      EdgeEvent.left => HapticPattern.edgeOut,
      EdgeEvent.entered => HapticPattern.edgeIn,
      null => null,
    };
    // the service skips a pulse right after another (e.g. a medium-level
    // phase pulse): then try again after the guard
    if (edge != null && !app.haptics.fire(edge, app.time) && app.haptics.enabled) _edge.dropped();
    if (_played >= _length) _finish(completed: true);
  }

  /// Medium level: the same pulses as a breathing session (1 / 2 / 1).
  void _phaseHaptic(List<EngineEvent> evs) {
    for (final e in evs) {
      if (e is! PhaseStarted) continue;
      final p = switch (e.phase) {
        Phase.inhale => HapticPattern.inhaleStart,
        Phase.hold => HapticPattern.holdStart,
        Phase.exhale => HapticPattern.exhaleStart,
        Phase.rest => null,
      };
      if (p != null) app.haptics.fire(p, app.time);
    }
  }

  @override
  void dispose() {
    app.music.stopNow(); // no ticker drives the fade once this screen is gone
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _rotationTimer?.cancel();
    _sub?.cancel();
    _ticker.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // leaving mid-game (back button / swipe): save it as stopped, and
        // stop playing during the pop animation (no score, pulses or finish)
        _log(completed: false);
        _leaving = true;
        app.music.stopNow();
      },
      child: Scaffold(
        body: ZeepBackground(
          child: SafeArea(
            child: AnimatedBuilder(
              animation: app.settings,
              builder: (context, _) =>
                  LayoutBuilder(builder: (context, c) => c.maxWidth > c.maxHeight ? _landscape(s, c) : _portrait(s)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _portrait(S s) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                children: [
                  _backButton(s),
                  Expanded(child: _title(s, center: true)),
                  _musicButton(s),
                ],
              ),
            ),
            if (_showsGame) ...[
              Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 10), child: _stats(s)),
              Expanded(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _board(s)),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: _controls(s)),
            ] else
              Expanded(child: _stage == _Stage.unavailable ? _noSensor(s) : _results(s)),
          ],
        ),
      ),
    );
  }

  Widget _landscape(S s, BoxConstraints c) {
    if (!_showsGame) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: _backButton(s)),
          Expanded(child: _stage == _Stage.unavailable ? _noSensor(s) : _results(s)),
          const SizedBox(width: 48),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Padding(padding: const EdgeInsets.fromLTRB(12, 12, 8, 12), child: _board(s)),
        ),
        SizedBox(
          width: 230,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _backButton(s),
                    Expanded(child: _title(s, center: false)),
                    _musicButton(s),
                  ],
                ),
                const SizedBox(height: 10),
                _stats(s),
                const SizedBox(height: 14),
                _controls(s, vertical: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool get _showsGame => _stage != _Stage.finished && _stage != _Stage.unavailable;

  Widget _backButton(S s) => IconButton(
    tooltip: s.back,
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.chevron_left_rounded, size: 32, color: ZeepColors.text),
  );

  Widget _title(S s, {required bool center}) => Column(
    crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    children: [
      Text(
        s.gameName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ZeepColors.text),
      ),
      Text(
        '${s.levelName(widget.level)} · ${s.minutes(widget.minutes)}',
        style: const TextStyle(fontSize: 12.5, color: ZeepColors.textSoft),
      ),
    ],
  );

  Widget _musicButton(S s) {
    final on = app.settings.music;
    return IconButton(
      tooltip: on ? s.musicOn : s.musicOff,
      onPressed: app.toggleMusic,
      icon: Icon(
        on ? Icons.music_note_rounded : Icons.music_off_rounded,
        color: on ? ZeepColors.blue : ZeepColors.textFaint,
      ),
    );
  }

  Widget _stats(S s) {
    final left = (_length - _played).clamp(0.0, _length).ceil();
    final time = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    Widget stat(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: withAlpha(Colors.white, 0.75), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: ZeepColors.textSoft)),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ZeepColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [stat(s.scoreLabel, '${_score.percent}%'), const SizedBox(width: 10), stat(s.timeLeftLabel, time)],
    );
  }

  Widget _controls(S s, {bool vertical = false}) {
    final paused = _stage == _Stage.paused;
    final canPause = _stage == _Stage.playing || _stage == _Stage.countdown;
    final buttons = <Widget>[
      FilledButton.icon(
        onPressed: paused ? _resume : (canPause ? _pause : null),
        icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        label: Text(paused ? s.resume : s.pause),
        style: FilledButton.styleFrom(
          backgroundColor: ZeepColors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _stage == _Stage.playing ? () => setState(_startCountdown) : null,
        icon: const Icon(Icons.center_focus_strong_rounded),
        label: Text(s.resetCentre),
        style: _outlined,
      ),
      OutlinedButton.icon(
        onPressed: _startedAt != null ? () => _finish(completed: false) : null,
        icon: const Icon(Icons.stop_rounded),
        label: Text(s.stop),
        style: _outlined,
      ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b)],
      );
    }
    return Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: buttons);
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: ZeepColors.text,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: const StadiumBorder(),
  );

  Widget _board(S s) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final zeep = (w < h ? w : h * 1.0).clamp(0.0, double.infinity) * 0.2;
        final zeepSize = zeep.clamp(56.0, 112.0);
        // Zeep's body spans ~70 % of its avatar box: keep that inside
        final r = zeepSize * 0.36;
        _tilt.ball.setBounds(w / 2 - r - 6, h / 2 - r - 6);
        _circle = circleFor(
          widget.level,
          halfW: w / 2,
          halfH: h / 2,
          breath: _breath.isActive ? _breath.level : 0,
          time: _played,
        );
        final p = _tilt.ball.pos;
        final playing = _stage == _Stage.playing;
        final ringColor = !playing || _inside ? _ringIn : _ringOut;
        return Container(
          decoration: BoxDecoration(
            color: withAlpha(Colors.white, 0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: withAlpha(ZeepColors.blue, 0.15), width: 2),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: CustomPaint(painter: _CirclePainter(_circle, ringColor))),
              if (widget.level == BalanceLevel.medium && _breath.isActive)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    s.phase(_breath.phase),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZeepColors.textSoft),
                  ),
                ),
              if (playing)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    _inside ? s.inCircle : s.outOfCircle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: _inside ? ZeepColors.mintDark : const Color(0xFFB0573A)),
                  ),
                ),
              Positioned(
                left: w / 2 + p.x - zeepSize / 2,
                top: h / 2 + p.y - zeepSize / 2,
                child: ZeepAvatar(
                  tint: playing && !_inside ? tintInhale : tintExhale,
                  size: zeepSize,
                  breath: _breath.isActive ? 0.3 + 0.5 * _breath.level : 0.55,
                ),
              ),
              if (!playing) Positioned.fill(child: _overlay(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _overlay(S s) {
    final counting = _stage == _Stage.countdown;
    final paused = _stage == _Stage.paused;
    return Container(
      decoration: BoxDecoration(color: withAlpha(ZeepColors.bgTop, 0.84), borderRadius: BorderRadius.circular(28)),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              counting
                  ? s.holdComfortably
                  : paused
                  ? s.paused
                  : s.waitingForSensor,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZeepColors.text),
            ),
            if (counting) ...[
              Text(
                '${_countdown.ceil().clamp(1, 3)}',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: ZeepColors.blue),
              ),
              Text(
                s.calibratingHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft),
              ),
              if (_startedAt == null) ...[
                const SizedBox(height: 6),
                Text(
                  s.keepInCircle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: ZeepColors.mintDark),
                ),
              ],
            ],
            if (paused) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _resume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(s.resume),
                style: FilledButton.styleFrom(backgroundColor: ZeepColors.blue, shape: const StadiumBorder()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noSensor(S s) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZeepAvatar(tint: tintHold, size: 110, breath: 0.3),
            const SizedBox(height: 18),
            Text(
              s.noTiltSensor,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: ZeepColors.textSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(S s) {
    final completed = _played >= _length;
    final score = _score.percent;
    final stars = completed ? starsFor(score) : 0;
    final best = app.settings.gameBest[widget.level.index];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ZeepAvatar(tint: tintExhale, size: 104, breath: 0.7),
              const SizedBox(height: 8),
              Text(
                completed ? s.gameComplete : s.gameStopped,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ZeepColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                '$score%',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: ZeepColors.blue),
              ),
              if (completed)
                Semantics(
                  label: s.starsLabel(stars),
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Icon(
                          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 36,
                          color: i < stars ? _starColor : ZeepColors.textFaint,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                s.scoreSummary(score),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: ZeepColors.textSoft),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_newBest) _Pill(s.newBest, const Color(0xFFFFF1D2), const Color(0xFF8A5A00)),
                  _Pill(
                    '${s.levelName(widget.level)} · ${best > 0 ? s.bestScore(best) : s.noBestYet}',
                    ZeepColors.blueSoft,
                    const Color(0xFF3463CC),
                  ),
                  if (_saved)
                    _Pill(s.streakBadge(app.lastStreak), withAlpha(ZeepColors.mint, 0.4), ZeepColors.mintDark),
                ],
              ),
              if (!_saved) ...[
                const SizedBox(height: 8),
                Text(
                  s.gameNotSaved,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: ZeepColors.textFaint),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(onPressed: _playAgain, style: _outlined, child: Text(s.playAgain)),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: ZeepColors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(s.done),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Pill(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

class _CirclePainter extends CustomPainter {
  final GameCircle circle;
  final Color color;
  _CirclePainter(this.circle, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (circle.radius <= 0) return;
    final c = Offset(size.width / 2 + circle.centre.x, size.height / 2 + circle.centre.y);
    canvas.drawCircle(c, circle.radius, Paint()..color = withAlpha(color, 0.16));
    canvas.drawCircle(
      c,
      circle.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = withAlpha(color, 0.8),
    );
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.circle.radius != circle.radius ||
      old.circle.centre.x != circle.centre.x ||
      old.circle.centre.y != circle.centre.y ||
      old.color != color;
}
