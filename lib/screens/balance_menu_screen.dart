// Zeep Balance (T2.3): GM level select. Remembers the last level and length.

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game/balance_game.dart';
import '../l10n/strings.dart';
import '../settings/settings_controller.dart';
import '../tilt/tilt_sensor.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import 'balance_game_screen.dart';

class BalanceMenuScreen extends StatelessWidget {
  final AppController app;

  /// Passed through to the game (tests use fakes).
  final TiltSource source;
  final DisplayRotationSource rotationSource;

  const BalanceMenuScreen({
    super.key,
    required this.app,
    this.source = const AccelerometerTiltSource(),
    this.rotationSource = const PlatformDisplayRotation(),
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: ZeepBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: app.settings,
            builder: (context, _) {
              final st = app.settings;
              final level = BalanceLevel.values[st.gameLevel];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  // the Start button stays pinned at the bottom; the rest scrolls
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: s.back,
                                  onPressed: () => Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.chevron_left_rounded, size: 32, color: ZeepColors.text),
                                ),
                                Expanded(
                                  child: Text(
                                    s.gameName,
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
                            const SizedBox(height: 6),
                            Center(
                              child: ZeepAvatar(
                                tint: ZeepColors.mint,
                                size: 96,
                                outfit: app.wardrobe.outfit,
                                growth: app.wardrobe.growth,
                                roomy: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.gameHowTo,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14.5, color: ZeepColors.textSoft, height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            _Heading(s.chooseLevel),
                            for (final l in BalanceLevel.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _LevelCard(
                                  level: l,
                                  best: st.gameBest[l.index],
                                  selected: l == level,
                                  onTap: () => st.update((x) => x.gameLevel = l.index),
                                ),
                              ),
                            const SizedBox(height: 8),
                            _Heading(s.gameLength),
                            Row(
                              children: [
                                for (final m in gameDurations)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: _Chip(
                                        label: s.minutes(m),
                                        selected: st.gameMinutes == m,
                                        onTap: () => st.update((x) => x.gameMinutes = m),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BalanceGameScreen(
                                app: app,
                                level: level,
                                minutes: st.gameMinutes,
                                source: source,
                                rotationSource: rotationSource,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(s.startGame, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: ZeepColors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZeepColors.text),
    ),
  );
}

class _LevelCard extends StatelessWidget {
  final BalanceLevel level;
  final int best;
  final bool selected;
  final VoidCallback onTap;
  const _LevelCard({required this.level, required this.best, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stars = starsFor(best);
    return Semantics(
      selected: selected,
      button: true,
      label: '${s.levelName(level)}. ${s.levelDesc(level)}. ${best > 0 ? s.bestScore(best) : s.noBestYet}',
      excludeSemantics: true,
      child: Material(
        color: selected ? ZeepColors.blueSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? ZeepColors.blue : const Color(0xFFE3E8EE), width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                SizedBox(width: 52, height: 52, child: CustomPaint(painter: _LevelIcon(level))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.levelName(level),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZeepColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(s.levelDesc(level), style: const TextStyle(fontSize: 13, color: ZeepColors.textSoft)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Icon(
                              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 15,
                              color: i < stars ? const Color(0xFFE9B949) : ZeepColors.textFaint,
                            ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              best > 0 ? s.bestScore(best) : s.noBestYet,
                              style: const TextStyle(fontSize: 12, color: ZeepColors.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? ZeepColors.blue : ZeepColors.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small picture of the level's circle.
class _LevelIcon extends CustomPainter {
  final BalanceLevel level;
  _LevelIcon(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()..color = withAlpha(ZeepColors.mint, 0.35),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF5CC3A8);
    final c = rect.center;
    switch (level) {
      case BalanceLevel.easy:
        canvas.drawCircle(c, size.width * 0.36, ring);
      case BalanceLevel.medium:
        canvas.drawCircle(c, size.width * 0.34, ring);
        canvas.drawCircle(c, size.width * 0.2, ring..color = withAlpha(const Color(0xFF5CC3A8), 0.5));
      case BalanceLevel.hard:
        canvas.drawCircle(c + Offset(size.width * 0.12, -size.height * 0.1), size.width * 0.17, ring);
    }
    canvas.drawCircle(c, size.width * 0.07, Paint()..color = const Color(0xFF6F8FBF));
  }

  @override
  bool shouldRepaint(_LevelIcon old) => old.level != level;
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? ZeepColors.blue : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? ZeepColors.blue : const Color(0xFFE3E8EE))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : ZeepColors.text,
            ),
          ),
        ),
      ),
    ),
  );
}
