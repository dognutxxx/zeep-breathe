import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
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
    return SafeArea(
      child: Column(children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            _CircleButton(
              icon: Icons.menu_book_rounded,
              tooltip: 'How it works',
              onTap: () => showInstructionsSheet(context),
            ),
            const Expanded(
              child: Text('ZEEP Breathe',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ZeepColors.text)),
            ),
            _CircleButton(
              icon: Icons.settings_rounded,
              tooltip: 'Breathing settings',
              onTap: () => showSettingsSheet(context, app),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _TrackChip(app: app),
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
            child: const Text(
              "Hi, I'm Zeep. Let's fill up slowly like a rising tide, then let it all drift away.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6A6560), height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 10, width: double.infinity, child: CustomPaint(painter: _WavyDivider())),
        const SizedBox(height: 18),
        const Text('How long would you like to breathe?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ZeepColors.text)),
        const SizedBox(height: 4),
        PopupMenuButton<int>(
          tooltip: 'Session length',
          initialValue: s.sessionMinutes,
          onSelected: (m) => s.update((x) => x.sessionMinutes = m),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (_) => [
            for (final m in durationPresets) PopupMenuItem(value: m, child: Text('$m min')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${s.sessionMinutes.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: ZeepColors.text,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Icon(Icons.keyboard_arrow_down_rounded, color: ZeepColors.text),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 52),
          child: ZeepSlider(
            value: s.sessionMinutes,
            min: 1,
            max: 10,
            semanticLabel: 'Minutes',
            onChanged: (v) => s.update((x) => x.sessionMinutes = v, persist: false),
            onChangeEnd: (_) => s.save(),
          ),
        ),
        LinkButton(icon: Icons.menu_book_outlined, label: 'How it works', onTap: () => showInstructionsSheet(context)),
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
              child: const Text('Start', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
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

class _TrackChip extends StatelessWidget {
  final AppController app;
  const _TrackChip({required this.app});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    const fg = Color(0xFF3463CC);
    return PopupMenuButton<int>(
      tooltip: 'Background music',
      initialValue: s.track,
      onSelected: (i) => s.update((x) => x.track = i),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (var i = 0; i < tracks.length; i++) PopupMenuItem(value: i, child: Text(tracks[i])),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: ZeepColors.blueSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.music_note_rounded, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(tracks[s.track], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
        ]),
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
