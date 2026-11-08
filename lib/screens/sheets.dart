import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../breathing/breathing_engine.dart';
import '../l10n/strings.dart';
import '../settings/settings_controller.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

Future<void> _showSheet(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: withAlpha(const Color(0xFF1E2430), 0.30),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: builder,
  );
}

class _SheetHeader extends StatelessWidget {
  final String title;
  const _SheetHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 8),
      child: Row(
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF2F0EE),
              foregroundColor: ZeepColors.text,
              shape: const StadiumBorder(),
            ),
            child: Text(S.of(context).close, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400)),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ZeepColors.textSoft),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- settings sheet

/// Opening the sheet does NOT pause the session: it edits the same engine
/// live, and the row of the phase playing right now is highlighted.
Future<void> showSettingsSheet(BuildContext context, AppController app) {
  return _showSheet(
    context,
    (ctx) => ListenableBuilder(
      listenable: app,
      builder: (ctx, _) => _SettingsContent(app: app),
    ),
  );
}

class _SettingsContent extends StatelessWidget {
  final AppController app;
  const _SettingsContent({required this.app});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final e = app.engine;
    final l = S.of(context);
    final rows = <(String, AnimState, Phase, int, int, int, void Function(SettingsController, int))>[
      (l.inhaleSeconds, AnimState.inhale, Phase.inhale, s.inhale, 1, 15, (x, v) => x.inhale = v),
      (l.holdSeconds, AnimState.hold, Phase.hold, s.hold, 0, 15, (x, v) => x.hold = v),
      (l.exhaleSeconds, AnimState.exhale, Phase.exhale, s.exhale, 1, 15, (x, v) => x.exhale = v),
      (l.restSeconds, AnimState.rest, Phase.rest, s.rest, 0, 15, (x, v) => x.rest = v),
    ];
    final cyc = s.durations.cycle;
    final per = (s.sessionMinutes * 60 / cyc).floor();
    final trackName = l.tracks[s.track];
    final musicSub = !app.music.available
        ? l.audioUnavailable
        : app.music.isAudible
        ? l.playing(trackName)
        : l.playsDuringSessions(trackName);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(l.breathingSettings),
            for (final (label, kind, phase, value, min, max, set) in rows)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                decoration: BoxDecoration(
                  color: e.isActive && e.phase == phase ? withAlpha(app.anim.pose.tint, 0.5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 26, height: 26, child: CustomPaint(painter: MiniFacePainter(kind))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3E)),
                          ),
                        ),
                        Text(
                          '$value',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ZeepColors.text),
                        ),
                        const SizedBox(width: 3),
                        Text(l.secUnit, style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft)),
                      ],
                    ),
                    ZeepSlider(
                      value: value,
                      min: min,
                      max: max,
                      semanticLabel: label,
                      onChanged: (v) => s.update((x) => set(x, v), persist: false),
                      onChangeEnd: (_) => s.save(),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: OutlinedButton(
                onPressed: s.resetBreathing,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: const BorderSide(color: Color(0xFFEAE6E2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: ZeepColors.text,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.resetToDefault, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(l.resetHint, style: const TextStyle(fontSize: 12, color: ZeepColors.textSoft)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l.cycleSummary(cyc.round(), per, s.sessionMinutes),
                style: const TextStyle(fontSize: 12, color: ZeepColors.textFaint),
              ),
            ),
            _ToggleRow(
              title: l.backgroundMusic,
              subtitle: musicSub,
              value: s.music,
              onChanged: (v) => s.update((x) => x.music = v),
            ),
            _ToggleRow(
              title: l.phoneVibration,
              subtitle: l.vibrationHint,
              value: s.vibration,
              onChanged: app.setVibration,
            ),
            if (!app.haptics.nativeSupported)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF2F6FD), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.vibration_rounded, size: 16, color: Color(0xFF6D88C4)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.noHapticEngine, style: const TextStyle(fontSize: 12, color: Color(0xFF56698F))),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3E)),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: ZeepColors.textFaint)),
                ],
              ),
            ),
            CupertinoSwitch(value: value, activeTrackColor: ZeepColors.blue, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------- instructions sheet

Future<void> showInstructionsSheet(BuildContext context) => _showSheet(context, (_) => const _Instructions());

class _Instructions extends StatelessWidget {
  const _Instructions();

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    const kinds = [AnimState.inhale, AnimState.hold, AnimState.exhale];
    final steps = [for (final (i, (t, b)) in l.instructionSteps.indexed) (kinds[i], t, b)];
    final bullets = l.instructionBullets;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(l.howItWorks),
            const SizedBox(height: 8),
            for (final (kind, title, body) in steps)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 30, height: 30, child: CustomPaint(painter: MiniFacePainter(kind))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZeepColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(body, style: const TextStyle(fontSize: 13, color: ZeepColors.textSoft, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 13.5, color: Color(0xFF4A4E58))),
                    Expanded(
                      child: Text(b, style: const TextStyle(fontSize: 13.5, color: Color(0xFF4A4E58), height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
