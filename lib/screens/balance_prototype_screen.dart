// Zeep Balance, step 1 prototype (GP): Zeep rolls on an empty board as the
// phone tilts. Opened from the T2.3 card on the Exercises tab. The circle,
// levels, score, music and haptics come in step 2.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/strings.dart';
import '../tilt/tilt_physics.dart';
import '../tilt/tilt_sensor.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

enum _Stage { waiting, countdown, playing, unavailable }

class BalancePrototypeScreen extends StatefulWidget {
  final TiltSource source;

  /// No reading within this time = treat the device as having no sensor.
  final Duration sensorTimeout;

  const BalancePrototypeScreen({
    super.key,
    this.source = const AccelerometerTiltSource(),
    this.sensorTimeout = const Duration(seconds: 2),
  });

  @override
  State<BalancePrototypeScreen> createState() => _BalancePrototypeScreenState();
}

class _BalancePrototypeScreenState extends State<BalancePrototypeScreen> with SingleTickerProviderStateMixin {
  static const _countdownSeconds = 3.0;
  static const _zeepSize = 112.0;

  final _tilt = TiltController();
  late final Ticker _ticker;
  StreamSubscription<Vec3>? _sub;
  Timer? _timeout;
  Duration _last = Duration.zero;
  _Stage _stage = _Stage.waiting;
  double _countdown = _countdownSeconds;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    try {
      _sub = widget.source.readings().listen(_onReading, onError: (_) => _unavailable(), cancelOnError: true);
    } catch (_) {
      _stage = _Stage.unavailable;
    }
    _timeout = Timer(widget.sensorTimeout, () {
      if (!_tilt.hasReading) _unavailable();
    });
  }

  void _onReading(Vec3 g) {
    _tilt.onReading(g);
    if (_stage == _Stage.waiting) setState(_startCountdown);
  }

  void _unavailable() {
    if (!mounted || _tilt.hasReading) return;
    _sub?.cancel();
    setState(() => _stage = _Stage.unavailable);
  }

  void _startCountdown() {
    _stage = _Stage.countdown;
    _countdown = _countdownSeconds;
  }

  void _onTick(Duration elapsed) {
    // cap the step: after a pause or a hitch Zeep must not jump
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    switch (_stage) {
      case _Stage.countdown:
        _countdown -= dt;
        if (_countdown <= 0) {
          _stage = _tilt.calibrate() ? _Stage.playing : _Stage.waiting;
        }
        setState(() {});
      case _Stage.playing:
        _tilt.update(dt);
        setState(() {});
      case _Stage.waiting:
      case _Stage.unavailable:
        break;
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: ZeepBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: s.back,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.chevron_left_rounded, size: 32, color: ZeepColors.text),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  s.gameName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ZeepColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Badge(s.prototypeBadge),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(child: _stage == _Stage.unavailable ? _noSensor(s) : _board(s)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noSensor(S s) {
    return Center(
      child: Padding(
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

  Widget _board(S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        children: [
          Text(
            s.tiltHint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, color: ZeepColors.textSoft),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                // Zeep's body spans ~70 % of its avatar box: keep that inside
                const r = _zeepSize * 0.36;
                _tilt.ball.setBounds(box.maxWidth / 2 - r - 6, box.maxHeight / 2 - r - 6);
                final p = _tilt.ball.pos;
                return Container(
                  decoration: BoxDecoration(
                    color: withAlpha(Colors.white, 0.7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: withAlpha(ZeepColors.blue, 0.15), width: 2),
                  ),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: box.maxWidth / 2 + p.x - _zeepSize / 2,
                        top: box.maxHeight / 2 + p.y - _zeepSize / 2,
                        child: const ZeepAvatar(tint: tintInhale, size: _zeepSize),
                      ),
                      if (_stage != _Stage.playing) Positioned.fill(child: _overlay(s)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _stage == _Stage.playing ? () => setState(_startCountdown) : null,
            icon: const Icon(Icons.center_focus_strong_rounded),
            label: Text(s.resetCentre),
            style: OutlinedButton.styleFrom(
              foregroundColor: ZeepColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlay(S s) {
    final counting = _stage == _Stage.countdown;
    return Container(
      decoration: BoxDecoration(color: withAlpha(ZeepColors.bgTop, 0.82), borderRadius: BorderRadius.circular(28)),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            counting ? s.holdComfortably : s.waitingForSensor,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZeepColors.text),
          ),
          if (counting) ...[
            const SizedBox(height: 8),
            Text(
              '${_countdown.ceil().clamp(1, 3)}',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: ZeepColors.blue),
            ),
            Text(
              s.calibratingHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFFFF1D2), borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8A5A00)),
      ),
    );
  }
}
