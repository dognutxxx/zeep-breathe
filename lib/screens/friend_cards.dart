// New-friend cards (Zeep and friends, 1.7.0), shown after "Done" in the same
// flow as cards L and N, at most one per session end:
// - day 3: pick Miu or Lumi (also opened from the picker's "choose" row)
// - day 10: the one not picked comes too
// - day 10 with no day-3 pick: both come at once
// - day 30 / 60 / 100 (1.8.0): "<name> is here", or one card for several
//   friends due at once (e.g. 65 days after updating); pick one to switch to

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../friends/characters.dart';
import '../l10n/strings.dart';
import '../ui/friends/friend_painter.dart';
import '../ui/zeep_colors.dart';
import '../wardrobe/flowers.dart';
import 'wardrobe_cards.dart';

/// Shows the friend card that is due, if any.
Future<void> showFriendCard(BuildContext context, AppController app) async {
  final w = app.wardrobe;
  final card = w.dueFriendCard;
  if (card == null) return;
  final later = card == FriendCard.later ? w.dueLaterFriends : const <Character>[];
  // shown once, whatever is tapped (and even if the app closes now)
  w.markFriendCardShown(card, shown: later);
  await _show(context, app, card, later: later);
}

/// The day-3 card from the picker's "choose a new friend" row.
Future<void> showChooseFriendCard(BuildContext context, AppController app) async {
  if (!app.wardrobe.friendChoicePending) return;
  app.wardrobe.markFriendCardShown(FriendCard.day3);
  await _show(context, app, FriendCard.day3);
}

Future<void> _show(BuildContext context, AppController app, FriendCard card, {List<Character> later = const []}) async {
  final w = app.wardrobe;
  final picked = await showDialog<Character>(
    context: context,
    builder: (_) => FriendCardDialog(card: card, chosen: w.day3Choice, later: later, growth: w.growth),
  );
  if (picked == null) return;
  if (card == FriendCard.day3) {
    w.chooseFirstFriend(picked);
  } else {
    w.selectCharacter(picked);
  }
}

class FriendCardDialog extends StatefulWidget {
  final FriendCard card;

  /// The day-3 pick (for the day-10 card: the other one is shown).
  final Character? chosen;

  /// The day-30/60/100 friends on a [FriendCard.later] card.
  final List<Character> later;

  /// The garden flower: it travels with every friend.
  final SproutGrowth growth;
  const FriendCardDialog({
    super.key,
    required this.card,
    this.chosen,
    this.later = const [],
    this.growth = SproutGrowth.none,
  });

  @override
  State<FriendCardDialog> createState() => _FriendCardDialogState();
}

class _FriendCardDialogState extends State<FriendCardDialog> {
  late final List<Character> _friends = switch (widget.card) {
    FriendCard.day10 => [(widget.chosen ?? Character.lumi).other],
    FriendCard.later => widget.later.isEmpty ? const [Character.mun] : widget.later,
    _ => const [Character.miu, Character.lumi],
  };
  late Character _selected = _friends.first;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final name = l.characterName(_selected);
    final several = _friends.length > 1;
    final (title, primary) = switch (widget.card) {
      FriendCard.day3 => (l.newFriendTitle, l.chooseFriend(name)),
      FriendCard.day10 => (l.friendArrived(name), l.breatheWith(name)),
      FriendCard.both => (l.newFriendsTitle(2), l.breatheWith(name)),
      // Miu and Lumi always came before: "N more friends", so it never reads
      // like the Miu + Lumi card again (QA r2 #3)
      FriendCard.later => (several ? l.moreFriendsTitle(_friends.length) : l.friendArrived(name), l.breatheWith(name)),
    };
    return ZeepDialog(
      art: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, c) in _friends.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Flexible(
                child: _FriendTile(
                  character: c,
                  selected: _friends.length > 1 && c == _selected,
                  single: _friends.length == 1,
                  growth: widget.growth,
                  onTap: _friends.length > 1 ? () => setState(() => _selected = c) : null,
                ),
              ),
            ],
          ],
        ),
      ),
      title: title,
      body: widget.card != FriendCard.day3 && several ? l.pickOneNow : l.characterTagline(_selected),
      note: widget.card == FriendCard.day3 ? l.otherFriendLater : null,
      primary: primary,
      secondary: l.later,
      onPrimary: () => Navigator.of(context).pop(_selected),
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}

/// One friend breathing live, with its name; tap to select it.
class _FriendTile extends StatelessWidget {
  final Character character;
  final bool selected, single;
  final SproutGrowth growth;
  final VoidCallback? onTap;
  const _FriendTile({
    required this.character,
    required this.selected,
    required this.single,
    required this.growth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final name = l.characterName(character);
    final label = '$name, ${l.characterTagline(character)}${selected ? ', ${l.selectedLabel}' : ''}';
    final style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: selected || single ? ZeepColors.mintDark : ZeepColors.text,
    );
    return Semantics(
      container: true,
      button: onTap != null,
      selected: onTap != null ? selected : null,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: single ? 150 : 120),
        child: Material(
          color: selected ? const Color(0xFFEAF7F2) : const Color(0xFFF7F4F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: selected ? ZeepColors.mintDark : const Color(0x00000000), width: 2.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, box) => LiveFriend(
                      character: character,
                      growth: growth,
                      size: box.maxWidth.clamp(40.0, single ? 130.0 : 100.0),
                    ),
                  ),
                  // one line, shrunk to fit if needed ("หมุนหมุน" in bold on a
                  // 320 px screen). The hidden full-size copy keeps the line
                  // height, so every tile is the same height (QA r2 #1).
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(opacity: 0, child: Text(name, maxLines: 1, softWrap: false, style: style)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(name, maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: style),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
