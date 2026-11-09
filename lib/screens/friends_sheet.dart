// "เพื่อนของฉัน" / My friends (1.7.0): who to breathe with. Opened by tapping
// the character or the "Friends" chip on the Breathe tab (T1). Flowers only:
// no level or bond bar per character. Switching is free and immediate.

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../friends/characters.dart';
import '../l10n/strings.dart';
import '../ui/friends/friend_painter.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import '../wardrobe/flowers.dart';
import 'friend_cards.dart';

/// Opens the picker as a bottom sheet.
Future<void> openFriends(BuildContext context, AppController app) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ListenableBuilder(
      listenable: app.wardrobe,
      builder: (context, _) => FriendsSheet(app: app),
    ),
  );
}

class FriendsSheet extends StatelessWidget {
  final AppController app;
  const FriendsSheet({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final w = app.wardrobe;
    final days = w.practiceDays;
    final active = w.activeCharacter;
    final growth = w.growth;
    final unlocked = w.unlockedCharacters;

    Widget friendRow(Character c) {
      if (unlocked.contains(c)) {
        final isActive = c == active;
        return _Row(
          art: _art(c, growth),
          title: l.characterName(c),
          subtitle: l.characterTagline(c),
          status: isActive ? l.inUse : l.tapToSwitch,
          active: isActive,
          onTap: isActive
              ? null
              : () {
                  w.selectCharacter(c);
                  Navigator.of(context).pop();
                },
        );
      }
      // the one not picked on day 3: greyed until day 10
      return _Row(
        art: _Greyed(child: _art(c, SproutGrowth.none)),
        title: l.characterName(c),
        subtitle: l.characterTagline(c),
        status: l.friendIn(secondFriendDays - days),
        dim: true,
      );
    }

    final rows = <Widget>[
      friendRow(Character.zeep),
      if (days < firstFriendDays)
        // before day 3: Miu or Lumi, one of them comes on day 3
        _Row(
          art: const _Greyed(child: _Pair()),
          title: l.miuOrLumi,
          subtitle: l.chooseNewFriend,
          status: l.friendIn(firstFriendDays - days),
          dim: true,
        )
      else if (w.friendChoicePending)
        _Row(
          art: const _Pair(),
          title: l.chooseNewFriend,
          subtitle: l.miuOrLumi,
          status: l.newFriendTitle,
          highlight: true,
          onTap: () => showChooseFriendCard(context, app),
        )
      else ...[
        // the chosen one first, then the other one
        for (final c in [w.day3Choice ?? Character.miu, (w.day3Choice ?? Character.miu).other]) friendRow(c),
      ],
      for (final c in mysteryFriends)
        _Row(
          art: const CustomPaint(painter: MysteryFriendPainter()),
          title: l.mysteryFriend,
          subtitle: days >= c.days ? l.mysteryOnTheWay : l.mysteryWhen(c.days),
          dim: true,
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDCD6D0), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              l.friendsTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ZeepColors.text),
            ),
          ),
          const SizedBox(height: 12),
          for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 10), child: r),
          const SizedBox(height: 4),
          Text(
            l.practiceDays(days),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: ZeepColors.textSoft),
          ),
        ],
      ),
    );
  }

  Widget _art(Character c, SproutGrowth growth) {
    if (c == Character.zeep) {
      return ZeepAvatar(
        tint: tintInhale,
        size: 64,
        outfit: app.wardrobe.outfit,
        growth: app.wardrobe.growth,
        roomy: true,
      );
    }
    return CustomPaint(
      painter: FriendPainter(character: c, lv: 0.55, growth: growth),
    );
  }
}

/// Miu and Lumi side by side (the "choose" row).
class _Pair extends StatelessWidget {
  const _Pair();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 10,
          width: 40,
          height: 40,
          child: CustomPaint(painter: FriendPainter(character: Character.miu, lv: 0.55)),
        ),
        Positioned(
          right: 0,
          top: 10,
          width: 40,
          height: 40,
          child: CustomPaint(painter: FriendPainter(character: Character.lumi, lv: 0.55)),
        ),
      ],
    );
  }
}

/// Grey and faded: a friend who has not come yet.
class _Greyed extends StatelessWidget {
  final Widget child;
  const _Greyed({required this.child});

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.45, 0,
  ]);

  @override
  Widget build(BuildContext context) => ColorFiltered(colorFilter: _grey, child: child);
}

class _Row extends StatelessWidget {
  final Widget art;
  final String title, subtitle;
  final String? status;
  final bool active, dim, highlight;
  final VoidCallback? onTap;
  const _Row({
    required this.art,
    required this.title,
    required this.subtitle,
    this.status,
    this.active = false,
    this.dim = false,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = active
        ? ZeepColors.mintDark
        : highlight
        ? const Color(0xFFE9B949)
        : const Color(0xFFECE7E2);
    final bg = active
        ? const Color(0xFFEAF7F2)
        : highlight
        ? const Color(0xFFFFF6DE)
        : dim
        ? const Color(0xFFF6F4F2)
        : Colors.white;
    final st = status;
    return Semantics(
      container: true,
      button: onTap != null,
      selected: active,
      label: [title, subtitle, ?st].join(', '),
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: active || highlight ? 2.5 : 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            child: Row(
              children: [
                SizedBox.square(dimension: 60, child: art),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: dim ? ZeepColors.textSoft : ZeepColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: dim ? ZeepColors.textFaint : ZeepColors.textSoft),
                      ),
                      if (st != null) ...[
                        const SizedBox(height: 4),
                        _Status(text: st, active: active, highlight: highlight, dim: dim),
                      ],
                    ],
                  ),
                ),
                if (onTap != null && !active)
                  const Icon(Icons.chevron_right_rounded, color: ZeepColors.textFaint)
                else if (active)
                  const Icon(Icons.check_circle_rounded, color: ZeepColors.mintDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final String text;
  final bool active, highlight, dim;
  const _Status({required this.text, required this.active, required this.highlight, required this.dim});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = active
        ? (ZeepColors.mint, ZeepColors.mintDark)
        : highlight
        ? (const Color(0xFFFFE6A8), const Color(0xFF6B4500))
        : dim
        ? (const Color(0xFFEDEAE6), ZeepColors.textSoft)
        : (ZeepColors.blueSoft, const Color(0xFF3463CC));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
