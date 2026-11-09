// The active character on the Breathe tab (T1), in sessions and on share
// cards. Zeep goes through exactly the same painter calls as before 1.7.0;
// only Miu and Lumi use the friend painters.

import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../friends/characters.dart';
import '../zeep_character.dart';
import 'friend_painter.dart';

/// The painter for the active character, driven by the app's one ticker:
/// the friend's lung level is Zeep's breath (inhale 0 -> 1, hold 1 with
/// hold = 1, exhale 1 -> 0, rest 0). Reduce Motion: a still pose.
CustomPainter activeCharacterPainter(AppController app) {
  final c = app.wardrobe.activeCharacter;
  if (c == Character.zeep) {
    return ZeepPainter(
      pose: app.anim.pose,
      time: app.anim.time,
      ripples: app.haptics.ripples(app.time),
      reduceMotion: app.reduceMotion,
      outfit: app.wardrobe.outfit,
      growth: app.wardrobe.growth,
    );
  }
  final pose = app.anim.pose;
  // no outfit on friends (wardrobe items are Zeep's); the flower travels
  // along (the friend painters use only the growth's flower, not its leaves)
  return FriendPainter(
    character: c,
    lv: app.reduceMotion ? reducedLv : pose.breath.clamp(0.0, 1.0),
    hold: app.reduceMotion ? 0 : pose.hold.clamp(0.0, 1.0),
    growth: app.wardrobe.growth,
    // vibration shown as rings on devices without a haptic engine, as for Zeep
    ripples: app.haptics.ripples(app.time),
    // as tall as Zeep, where Zeep stands (QA #4)
    fit: FriendFit.stage,
  );
}

/// A still character for cards (share card). Zeep is the same ZeepAvatar as
/// before; friends are drawn at the same lung level, as tall as Zeep.
class CharacterAvatar extends StatelessWidget {
  final Character character;
  final Color tint;
  final double size, breath;
  const CharacterAvatar({super.key, required this.character, required this.tint, this.size = 64, this.breath = 0.55});

  @override
  Widget build(BuildContext context) {
    if (!character.playable || character == Character.zeep) {
      return ZeepAvatar(tint: tint, size: size, breath: breath);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: FriendPainter(character: character, lv: breath, fit: FriendFit.avatar),
        ),
      ),
    );
  }
}
