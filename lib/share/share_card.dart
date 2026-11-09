// Zeep Community phase 1 (CS): the picture card people share to LINE,
// Instagram, Facebook... through the phone's share sheet. No server, no
// account: the card is drawn here and handed to the system as a PNG.
// Numbers only ever come from the app's own records.

import 'package:flutter/material.dart';

import '../game/balance_game.dart';
import '../friends/characters.dart';
import '../l10n/strings.dart';
import '../ui/friends/character_view.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

/// What a card celebrates.
sealed class ShareAchievement {
  /// The day it happened (shown on the card).
  final DateTime day;
  const ShareAchievement(this.day);
}

/// T3.1: days in a row.
class StreakAchievement extends ShareAchievement {
  final int days;
  final int totalMinutes;
  const StreakAchievement(super.day, {required this.days, required this.totalMinutes});
}

/// S.8: a finished breathing session.
class SessionAchievement extends ShareAchievement {
  final String exerciseName;
  final int minutes;
  final int breaths;
  const SessionAchievement(super.day, {required this.exerciseName, required this.minutes, required this.breaths});
}

/// GR: a finished Zeep Balance game.
class GameAchievement extends ShareAchievement {
  final BalanceLevel level;
  final int score;
  const GameAchievement(super.day, {required this.level, required this.score});
}

/// The three card colours to pick from.
enum ShareCardColor {
  lavender([Color(0xFFFFFFFF), Color(0xFFECE9FB), Color(0xFFE4EFF9)], Color(0xFF5B4FC4), tintHold),
  mint([Color(0xFFFFFFFF), Color(0xFFDDF3EC), Color(0xFFE8F6F2)], Color(0xFF1E6B5A), tintExhale),
  sky([Color(0xFFFFFFFF), Color(0xFFE3EFFB), Color(0xFFD6E7F8)], Color(0xFF3463CC), tintInhale);

  final List<Color> gradient;
  final Color accent;
  final Color zeepTint;
  const ShareCardColor(this.gradient, this.accent, this.zeepTint);

  /// The swatch shown in the colour picker.
  Color get swatch => gradient[1];
}

/// The card at its design size; captured at 3x for a 1080 x 1350 (4:5) image,
/// the shape Instagram and LINE show without cropping.
class ShareCard extends StatelessWidget {
  static const size = Size(360, 450);

  final ShareAchievement achievement;
  final ShareCardColor theme;

  /// Who is on the card (the active character); Zeep by default.
  final Character character;
  const ShareCard({
    super.key,
    required this.achievement,
    this.theme = ShareCardColor.lavender,
    this.character = Character.zeep,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final a = achievement;
    final (big, line) = switch (a) {
      StreakAchievement() => (s.cardDays(a.days), s.cardStreakLine),
      SessionAchievement() => (s.minutes(a.minutes), a.exerciseName),
      GameAchievement() => ('${a.score}%', s.gameEntryName(a.level)),
    };
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // square and opaque: apps fill transparent corners with their own
          // colour (black in dark mode). The preview rounds it with a clip.
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.gradient),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'ZEEP Breathe',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.dayHeading(a.day),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ZeepColors.textSoft),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              CharacterAvatar(character: character, tint: theme.zeepTint, size: 150, breath: 0.75),
              const SizedBox(height: 6),
              Text(
                big,
                maxLines: 1,
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: ZeepColors.text, height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                line,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF3A3F4B)),
              ),
              const SizedBox(height: 10),
              _detail(s, a),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.spa_rounded, size: 16, color: theme.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      s.cardFooter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: ZeepColors.textSoft),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(S s, ShareAchievement a) {
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(color: withAlpha(Colors.white, 0.8), borderRadius: BorderRadius.circular(14)),
      child: Text(
        text,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: theme.accent),
      ),
    );
    return switch (a) {
      StreakAchievement() => chip(s.cardTotal(a.totalMinutes)),
      SessionAchievement() => chip(s.cardBreaths(a.breaths)),
      GameAchievement() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              i < starsFor(a.score) ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 30,
              color: i < starsFor(a.score) ? const Color(0xFFE9B949) : ZeepColors.textFaint,
            ),
        ],
      ),
    };
  }
}
