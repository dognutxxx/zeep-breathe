// Zeep and friends (deck "Zeep และเพื่อน", approved 2026-11-09): who the user
// breathes with. Zeep is always there; more friends come with the total number
// of practice days (the same counter as the wardrobe). Flowers only: there is
// no bond or level per character.
//
// 1.7.0 draws Miu and Lumi. The 30/60/100-day friends are only locked
// "mystery friend" rows for now.

enum Character {
  zeep(0),
  miu(3),
  lumi(3),
  friend30(30),
  friend60(60),
  friend100(100);

  /// Practice days before this character can come (Miu and Lumi: one at day
  /// 3, the other at day 10).
  final int days;
  const Character(this.days);

  /// Drawn and selectable in this version.
  bool get playable => this == zeep || this == miu || this == lumi;

  /// One of the two day-3 friends.
  bool get isDay3Friend => this == miu || this == lumi;

  /// The other day-3 friend (Miu <-> Lumi).
  Character get other => this == miu ? lumi : miu;

  static Character? byName(Object? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// The locked "mystery friend" slots, in order.
const mysteryFriends = [Character.friend30, Character.friend60, Character.friend100];

/// Day 3: the user picks Miu or Lumi; day 10: the other one comes too.
const firstFriendDays = 3;
const secondFriendDays = 10;

/// Characters the user can breathe with after [days] practice days, given
/// the day-3 [choice] (null = not chosen yet). Zeep always; days 3-9 the
/// chosen one; 10 and up both Miu and Lumi; the mystery friends never (1.7.0).
Set<Character> unlockedCharacters(int days, Character? choice) => {
  Character.zeep,
  if (days >= secondFriendDays) ...[Character.miu, Character.lumi],
  if (days >= firstFriendDays && choice != null && choice.isDay3Friend) choice,
};

/// Days 3-9 with no choice yet: neither Miu nor Lumi until the user picks.
bool friendChoicePending(int days, Character? choice) =>
    days >= firstFriendDays && days < secondFriendDays && choice == null;

/// The one friend card to show after a session ends, if any.
enum FriendCard {
  /// Day 3: pick Miu or Lumi.
  day3,

  /// Day 10: the friend not picked on day 3 comes too.
  day10,

  /// Day 10 without a day-3 pick: both come at once.
  both,
}

/// Which friend card is due (pure rule, see WardrobeController).
FriendCard? dueFriendCard({
  required int days,
  required Character? choice,
  required bool day3CardShown,
  required bool day10CardSeen,
}) {
  if (days >= secondFriendDays && !day10CardSeen) return choice == null ? FriendCard.both : FriendCard.day10;
  if (friendChoicePending(days, choice) && !day3CardShown) return FriendCard.day3;
  return null;
}
