import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../exercises/exercises.dart';
import '../l10n/strings.dart';
import '../settings/settings_controller.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import 'sheets.dart';

class SetupScreen extends StatelessWidget {
  final AppController app;
  const SetupScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final l = S.of(context);
    return SafeArea(
      top: !app.bannerVisible,
      child: Column(
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.menu_book_rounded,
                  tooltip: l.howItWorks,
                  onTap: () => showInstructionsSheet(context),
                ),
                Expanded(
                  child: Text(
                    l.appTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ZeepColors.text),
                  ),
                ),
                _CircleButton(
                  icon: Icons.settings_rounded,
                  tooltip: l.breathingSettings,
                  onTap: () => showSettingsSheet(context, app),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ExerciseChip(app: app),
              _TrackChip(app: app),
            ],
          ),
          // character (idle)
          Expanded(
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
          // speech bubble
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF3EFEA), borderRadius: BorderRadius.circular(18)),
              child: Text(
                l.greeting,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6A6560), height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            height: 10,
            width: double.infinity,
            child: CustomPaint(painter: _WavyDivider()),
          ),
          const SizedBox(height: 18),
          Text(
            l.howLong,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ZeepColors.text),
          ),
          const SizedBox(height: 4),
          PopupMenuButton<int>(
            tooltip: l.sessionLength,
            initialValue: s.sessionMinutes,
            onSelected: (m) => s.update((x) => x.sessionMinutes = m),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [for (final m in durationPresets) PopupMenuItem(value: m, child: Text(l.minutes(m)))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${s.sessionMinutes.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: ZeepColors.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: ZeepColors.text),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: ZeepSlider(
              value: s.sessionMinutes,
              min: 1,
              max: maxSessionMinutes,
              semanticLabel: l.sessionLength,
              onChanged: (v) => s.update((x) => x.sessionMinutes = v, persist: false),
              onChangeEnd: (_) => s.save(),
            ),
          ),
          LinkButton(icon: Icons.menu_book_outlined, label: l.howItWorks, onTap: () => showInstructionsSheet(context)),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE9ECEF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: app.startSession,
                style: FilledButton.styleFrom(
                  backgroundColor: ZeepColors.mint,
                  foregroundColor: ZeepColors.mintDark,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: Text(l.start, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: withAlpha(Colors.black, 0.2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: ZeepColors.text, size: 22),
      ),
    );
  }
}

/// Current rhythm; tap to open the Exercises tab.
class _ExerciseChip extends StatelessWidget {
  final AppController app;
  const _ExerciseChip({required this.app});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final d = app.settings.durations;
    final name = exerciseLabel(d, l);
    final pattern = patternOf(d);
    const fg = ZeepColors.mintDark;
    return Semantics(
      button: true,
      label: l.exerciseChip(name, pattern),
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFFDDF3EC),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => app.setTab(HomeTab.exercises),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.air_rounded, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  '$name · $pattern',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  final AppController app;
  const _TrackChip({required this.app});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final l = S.of(context);
    const fg = Color(0xFF3463CC);
    return PopupMenuButton<int>(
      tooltip: l.backgroundMusic,
      initialValue: s.track,
      onSelected: (i) => s.update((x) => x.track = i),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [for (var i = 0; i < trackCount; i++) PopupMenuItem(value: i, child: Text(l.tracks[i]))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: ZeepColors.blueSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note_rounded, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              l.tracks[s.track],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

class _WavyDivider extends CustomPainter {
  const _WavyDivider();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2DDD8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var k = 0; k < 2; k++) {
      final y = 2 + k * 5.0;
      final path = Path();
      for (var i = 0; i <= 80; i++) {
        final x = 40 + (size.width - 80) * i / 80;
        final yy = y + math.sin(i * 0.9) * 1.6;
        i == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
