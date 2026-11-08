import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../exercises/exercises.dart';
import '../l10n/strings.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import 'balance_prototype_screen.dart';
import 'mode_screen.dart';

class ExercisesScreen extends StatelessWidget {
  final AppController app;
  const ExercisesScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = app.settings.durations;
    final current = exerciseFor(d);
    return SafeArea(
      top: !app.bannerVisible,
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(
            s.exercisesTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZeepColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            s.exercisesSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft),
          ),
          const SizedBox(height: 18),
          for (final e in exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModeCard(
                e: e,
                selected: current?.id == e.id,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModeScreen(app: app, exercise: e),
                  ),
                ),
              ),
            ),
          if (current == null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ZeepColors.blueSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(
                s.usingCustom(patternOf(d)),
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF3463CC)),
              ),
            ),
          // T2.3: Zeep Balance game (step 1: tilt prototype)
          Padding(
            padding: EdgeInsets.only(top: current == null ? 12 : 0),
            child: _GameCard(
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BalancePrototypeScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GameCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: '${s.gameName}. ${s.gameCardDesc}. ${s.prototypeBadge}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: withAlpha(Colors.black, 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: withAlpha(ZeepColors.mint, 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const ZeepAvatar(tint: ZeepColors.mint, size: 76),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.gameName,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: ZeepColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1D2),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              s.prototypeBadge,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A5A00),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(s.gameCardDesc, style: const TextStyle(fontSize: 13, color: Color(0xFF4A4E58), height: 1.4)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: ZeepColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final Exercise e;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.e, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${e.name(s)}. ${e.description(s)}. ${e.pattern}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        elevation: selected ? 3 : 1,
        shadowColor: withAlpha(Colors.black, 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? ZeepColors.blue : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: withAlpha(e.tint, 0.35), borderRadius: BorderRadius.circular(16)),
                  child: ZeepAvatar(tint: e.tint, size: 76, hold: e.id == '478' ? 0.6 : 0),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              e.name(s),
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: ZeepColors.text,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded, size: 18, color: ZeepColors.blue),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.description(s),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF4A4E58), height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final p in e.phases)
                            _PhasePill(icon: phaseIcon(p), text: s.secs(e.durations.of(p).round()), tint: phaseTint(p)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: ZeepColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color tint;
  const _PhasePill({required this.icon, required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: withAlpha(tint, 0.55), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ZeepColors.text),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZeepColors.text),
          ),
        ],
      ),
    );
  }
}
