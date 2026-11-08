import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../exercises/exercises.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

class ExercisesScreen extends StatelessWidget {
  final AppController app;
  const ExercisesScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final current = exerciseFor(app.settings.durations);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const Text(
            'Exercises',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ZeepColors.text),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick a rhythm. You can still fine-tune it in breathing settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: ZeepColors.textSoft),
          ),
          const SizedBox(height: 18),
          for (final e in exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExerciseCard(e: e, selected: current?.id == e.id, onTap: () => app.chooseExercise(e)),
            ),
          if (current == null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ZeepColors.blueSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(
                'You are using a custom rhythm (${app.settings.durations.inhale.round()} · '
                '${app.settings.durations.hold.round()} · ${app.settings.durations.exhale.round()}'
                '${app.settings.rest > 0 ? ' · ${app.settings.rest}' : ''}). Pick a card to switch.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF3463CC)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise e;
  final bool selected;
  final VoidCallback onTap;
  const _ExerciseCard({required this.e, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${e.name}, ${e.tagline}, pattern ${e.pattern}, ${e.minutes} minutes',
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
            padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: withAlpha(e.tint, 0.35), borderRadius: BorderRadius.circular(16)),
                  child: ZeepAvatar(tint: e.tint, size: 76, hold: e.id == 'sleep' ? 0.6 : 0),
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
                              e.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZeepColors.text),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded, size: 18, color: ZeepColors.blue),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(e.tagline, style: const TextStyle(fontSize: 12.5, color: ZeepColors.textSoft)),
                      const SizedBox(height: 6),
                      Text(
                        e.description,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A4E58), height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Pill(icon: Icons.air_rounded, text: e.pattern),
                          const SizedBox(width: 6),
                          _Pill(icon: Icons.schedule_rounded, text: '${e.minutes} min'),
                        ],
                      ),
                    ],
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: ZeepColors.btnBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ZeepColors.textSoft),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZeepColors.text),
          ),
        ],
      ),
    );
  }
}
