import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../breathing/breathing_engine.dart';
import '../exercises/exercises.dart';
import '../l10n/strings.dart';
import '../share/share_card.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import 'share_screen.dart';
import 'sheets.dart';

String fmtClock(double secs) {
  final s = math.max(0, secs.ceil());
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class SessionScreen extends StatelessWidget {
  final AppController app;
  const SessionScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final e = app.engine;
    final l = S.of(context);
    final remaining = e.state == RunState.ready ? e.sessionLength : e.sessionRemaining;
    final label = switch (e.state) {
      RunState.paused => l.paused,
      RunState.finished => '',
      _ => l.phase(e.phase),
    };

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 36),
              Semantics(
                label: l.timeRemaining(fmtClock(remaining)),
                excludeSemantics: true,
                child: Text(
                  fmtClock(remaining),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: ZeepColors.text,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: Center(child: _HapticBadge(app: app)),
              ),
              Expanded(
                flex: 5,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: ZeepPainter(
                      pose: app.anim.pose,
                      time: app.anim.time,
                      ripples: app.haptics.ripples(app.time),
                      reduceMotion: app.reduceMotion,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: SizedBox(width: 190, height: 26, child: CustomPaint(painter: _BreathBar(app))),
              ),
              const SizedBox(height: 10),
              // instruction label with cross-fade
              Semantics(
                liveRegion: true,
                label: label,
                excludeSemantics: true,
                child: SizedBox(
                  height: 26,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ZeepColors.label),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 20,
                child: e.isActive
                    ? Text(
                        '${math.max(1, e.phaseRemaining.ceil())}',
                        style: TextStyle(fontSize: 13.5, color: withAlpha(ZeepColors.textFaint, 0.9)),
                      )
                    : null,
              ),
              const Spacer(flex: 2),
              // playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ControlButton(
                    tooltip: e.state == RunState.running ? l.pause : l.play,
                    onTap: app.togglePause,
                    icon: Icon(
                      e.state == RunState.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: const Color(0xFF4E4A48),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ControlButton(
                    tooltip: l.stop,
                    onTap: app.stopSession,
                    icon: const Icon(Icons.stop_rounded, color: Color(0xFF4E4A48), size: 28),
                  ),
                  const SizedBox(width: 16),
                  ControlButton(
                    tooltip: app.settings.music ? l.musicOn : l.musicOff,
                    onTap: app.toggleMusic,
                    icon: SlashedIcon(
                      icon: Icons.music_note_rounded,
                      on: app.settings.music,
                      color: app.settings.music ? const Color(0xFF4E4A48) : ZeepColors.textFaint,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ControlButton(
                    tooltip: app.settings.vibration ? l.vibrationOn : l.vibrationOff,
                    onTap: app.toggleVibration,
                    icon: Transform.translate(
                      offset: Offset(_shake(app), 0),
                      child: SlashedIcon(
                        icon: Icons.vibration_rounded,
                        on: app.settings.vibration,
                        color: app.settings.vibration ? const Color(0xFF4E4A48) : ZeepColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinkButton(
                icon: Icons.settings_rounded,
                label: l.breathingSettingsLink,
                onTap: () => showSettingsSheet(context, app),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (app.finished) _FinishedCard(app: app),
      ],
    );
  }

  /// Shake the vibration icon when a haptic fires.
  static double _shake(AppController app) {
    final last = app.haptics.last;
    if (last == null) return 0;
    final age = app.time - last.time;
    if (age >= 0.3) return 0;
    return math.sin(age * 90) * 1.8 * (1 - age / 0.3);
  }
}

/// "Haptic · inhale pulse" badge. Only shown when the device has no haptic
/// engine (simulator, iPad, older devices), mirroring the desktop preview.
class _HapticBadge extends StatelessWidget {
  final AppController app;
  const _HapticBadge({required this.app});

  @override
  Widget build(BuildContext context) {
    final last = app.haptics.last;
    if (app.haptics.nativeSupported || last == null) return const SizedBox.shrink();
    final age = app.time - last.time;
    if (age >= 1.6) return const SizedBox.shrink();
    final a = ((1 - math.max(0, age - 1.1) / 0.5).clamp(0.0, 1.0) * smoothstep(age / 0.12)).toDouble();
    const fg = Color(0xFF3D63B8);
    return Opacity(
      opacity: a,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFE2ECFC), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vibration_rounded, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              S.of(context).hapticBadge(last.pattern),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress pill that grows from the centre with the breath, plus a thin
/// marker showing progress through the current phase.
class _BreathBar extends CustomPainter {
  final AppController app;
  _BreathBar(this.app);

  @override
  void paint(Canvas canvas, Size size) {
    const bh = 16.0;
    final bw = size.width;
    final center = Offset(size.width / 2, bh / 2);
    final track = Rect.fromCenter(center: center, width: bw, height: bh);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(bh / 2)),
      Paint()..color = const Color(0xFFE4EFF9),
    );
    final pose = app.anim.pose;
    final lvl = pose.breath.clamp(0.0, 1.0);
    final fw = bh + (bw - bh) * lvl;
    final fill = Rect.fromCenter(center: center, width: fw, height: bh);
    final tint = pose.tint;
    if (pose.hold > 0.05) {
      final pulse = 0.5 + 0.5 * math.sin(app.anim.time * math.pi * 2 * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill.inflate(2.5 * pulse), const Radius.circular(bh / 2 + 2)),
        Paint()..color = withAlpha(const Color(0xFFB9AEF0), 0.25 * pose.hold),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, const Radius.circular(bh / 2)),
      Paint()..color = mix(tint, const Color(0xFF7FA9E8), 0.30),
    );
    if (app.engine.isActive) {
      final mw = (bw - 12) * app.engine.phaseProgress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(6, bh + 6, math.max(0, mw), 2.2), const Radius.circular(1)),
        Paint()..color = withAlpha(mix(tint, const Color(0xFF6F9FD8), 0.5), 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FinishedCard extends StatelessWidget {
  final AppController app;
  const _FinishedCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final mins = (app.engine.sessionLength / 60).round();
    final l = S.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: withAlpha(const Color(0xFF1E2430), 0.12),
        child: Align(
          alignment: const Alignment(0, 0.35),
          child: Container(
            width: 310,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: withAlpha(Colors.black, 0.14), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.sessionComplete,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ZeepColors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  l.sessionSummary(app.engine.breaths, mins),
                  style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft),
                ),
                if (app.lastStreak > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFE6E1FA), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFF5B4FC4)),
                        const SizedBox(width: 6),
                        Text(
                          l.streakBadge(app.lastStreak),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5B4FC4)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Community phase 1: share this session as a picture card
                TextButton.icon(
                  onPressed: () {
                    // HomePage's ticker stops under the new route: end the fade now
                    app.music.stopNow();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ShareScreen(
                          achievement: SessionAchievement(
                            app.sessionStart,
                            exerciseName: exerciseLabel(app.engine.durations, l),
                            minutes: mins,
                            breaths: app.engine.breaths,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(l.share, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(foregroundColor: ZeepColors.blue),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: app.startSession,
                        style: FilledButton.styleFrom(
                          backgroundColor: ZeepColors.btnBg,
                          foregroundColor: ZeepColors.text,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: Text(l.again, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: app.stopSession,
                        style: FilledButton.styleFrom(
                          backgroundColor: ZeepColors.mint,
                          foregroundColor: ZeepColors.mintDark,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: Text(l.done, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
