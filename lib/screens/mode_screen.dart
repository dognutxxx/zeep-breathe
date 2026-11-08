// Detail screen for one breathing mode: description, rhythm, session length
// (5 / 10 / 15 min), a tip, and "Start breathing".

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../breathing/breathing_engine.dart';
import '../exercises/exercises.dart';
import '../l10n/strings.dart';
import '../ui/beta_banner.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

IconData phaseIcon(Phase p) => switch (p) {
  Phase.inhale => Icons.arrow_upward_rounded,
  Phase.hold => Icons.pause_rounded,
  Phase.exhale => Icons.arrow_downward_rounded,
  Phase.rest => Icons.more_horiz_rounded,
};

Color phaseTint(Phase p) => switch (p) {
  Phase.inhale => tintInhale,
  Phase.hold => tintHold,
  Phase.exhale => tintExhale,
  Phase.rest => const Color(0xFFDCE3EC),
};

class ModeScreen extends StatefulWidget {
  final AppController app;
  final Exercise exercise;
  const ModeScreen({super.key, required this.app, required this.exercise});

  @override
  State<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<ModeScreen> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    final already = exerciseFor(s.durations)?.id == widget.exercise.id && modeDurations.contains(s.sessionMinutes);
    _minutes = already ? s.sessionMinutes : widget.exercise.minutes;
  }

  void _start() {
    final app = widget.app;
    final e = widget.exercise;
    Navigator.of(context).pop();
    app.startExercise(e, _minutes);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final e = widget.exercise;
    return ListenableBuilder(listenable: widget.app, builder: (context, _) => _page(context, s, e));
  }

  Widget _page(BuildContext context, S s, Exercise e) {
    return Scaffold(
      body: ZeepBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                BetaBanner(app: widget.app),
                Expanded(
                  child: SafeArea(
                    top: !widget.app.bannerVisible,
                    child: Column(
                      children: [
                        // header
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
                                child: Text(
                                  e.name(s),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ZeepColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.description(s),
                                      style: const TextStyle(fontSize: 16.5, color: ZeepColors.textSoft, height: 1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ZeepAvatar(tint: e.tint, size: 84),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _RhythmCard(exercise: e),
                              const SizedBox(height: 22),
                              Text(
                                s.chooseDuration,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: ZeepColors.textSoft,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  for (final (i, m) in modeDurations.indexed) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    Expanded(
                                      child: _DurationChip(
                                        label: s.minutes(m),
                                        selected: _minutes == m,
                                        onTap: () => setState(() => _minutes = m),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                                decoration: BoxDecoration(
                                  color: ZeepColors.blueSoft,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCFE0F5)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF3463CC)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        e.tip(s),
                                        style: const TextStyle(fontSize: 14.5, color: Color(0xFF34507F), height: 1.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: _start,
                              style: FilledButton.styleFrom(
                                backgroundColor: ZeepColors.mint,
                                foregroundColor: ZeepColors.mintDark,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.startBreathing,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),
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
    );
  }
}

class _RhythmCard extends StatelessWidget {
  final Exercise exercise;
  const _RhythmCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final phases = exercise.phases;
    final d = exercise.durations;
    Widget tile(Phase p, {required bool compact}) =>
        _PhaseTile(phase: p, label: s.phase(p), value: s.secs(d.of(p).round()), compact: compact);

    final Widget body;
    if (phases.length == 4) {
      // 2 x 2: label left, value right
      body = Column(
        children: [
          for (var r = 0; r < 2; r++) ...[
            if (r > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: tile(phases[r * 2], compact: true)),
                const SizedBox(width: 10),
                Expanded(child: tile(phases[r * 2 + 1], compact: true)),
              ],
            ),
          ],
        ],
      );
    } else {
      body = Row(
        children: [
          for (final (i, p) in phases.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: tile(p, compact: false)),
          ],
        ],
      );
    }

    return Semantics(
      label: '${s.rhythmTitle}: ${phases.map((p) => '${s.phase(p)} ${s.secs(d.of(p).round())}').join(', ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6EBF1)),
          boxShadow: [BoxShadow(color: withAlpha(Colors.black, 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.rhythmTitle,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ZeepColors.textSoft),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  final Phase phase;
  final String label, value;
  final bool compact;
  const _PhaseTile({required this.phase, required this.label, required this.value, required this.compact});

  @override
  Widget build(BuildContext context) {
    final tint = phaseTint(phase);
    final head = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(phaseIcon(phase), size: 18, color: ZeepColors.text),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, color: ZeepColors.text),
          ),
        ),
      ],
    );
    final val = Text(
      value,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: ZeepColors.text,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
          : const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mix(tint, const Color(0xFF8FA3BF), 0.25)),
        // soft glow in the corner, like a light under frosted glass
        gradient: RadialGradient(
          center: const Alignment(0.9, 0.8),
          radius: 1.1,
          colors: [withAlpha(tint, 0.75), withAlpha(tint, 0.18), Colors.white],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: compact
          ? Row(
              children: [
                Expanded(child: head),
                val,
              ],
            )
          // narrow tiles (3 in a row): shrink the label to fit rather than cut it
          : Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(phaseIcon(phase), size: 18, color: ZeepColors.text),
                      const SizedBox(width: 5),
                      Text(label, style: const TextStyle(fontSize: 14.5, color: ZeepColors.text)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                val,
              ],
            ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DurationChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : ZeepColors.text;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? ZeepColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: selected ? 2 : 0,
        shadowColor: withAlpha(ZeepColors.blue, 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? ZeepColors.blue : const Color(0xFFE2E7EE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 19, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
