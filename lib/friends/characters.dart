// Zeep and friends (deck "Zeep และเพื่อน", approved 2026-11-09): who the user
// breathes with. Zeep is always there; more friends come with the total number
// of practice days (the same counter as the wardrobe). Flowers only: there is
// no bond or level per character.
//
// 1.7.0 drew Miu and Lumi (day 3 pick, day 10 the other one). 1.8.0 draws the
// day-30/60/100 friends: Mun (pinwheel), Tuntun (tortoise) and Nuan (moon).

enum Character {
  zeep(0),
  miu(3),
  lumi(3),
  mun(30),
  tuntun(60),
  nuan(100);

  /// Practice days before this character can come (Miu and Lumi: one at day
  /// 3, the other at day 10).
  final int days;
  const Character(this.days);

  /// One of the two day-3 friends.
  bool get isDay3Friend => this == miu || this == lumi;

  /// One of the friends that simply come at their day (30 / 60 / 100).
  bool get isLaterFriend => this == mun || this == tuntun || this == nuan;

  /// The other day-3 friend (Miu <-> Lumi).
  Character get other => this == miu ? lumi : miu;

  static Character? byName(Object? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// The friends that come at 30, 60 and 100 practice days, in order. Before
/// their day they show as a dark silhouette of their own shape.
const laterFriends = [Character.mun, Character.tuntun, Character.nuan];

/// Day 3: the user picks Miu or Lumi; day 10: the other one comes too.
const firstFriendDays = 3;
const secondFriendDays = 10;

/// Whether [c] can be breathed with after [days] practice days, given the
/// day-3 [choice] (null = not chosen yet). Cheap: read every frame.
bool isUnlocked(Character c, int days, Character? choice) {
  if (c == Character.zeep) return true;
  if (c.isDay3Friend) return days >= secondFriendDays || (days >= firstFriendDays && choice == c);
  return days >= c.days;
}

/// Characters the user can breathe with after [days] practice days, given
/// the day-3 [choice] (null = not chosen yet). Zeep always; days 3-9 the
/// chosen one; 10 and up both Miu and Lumi; Mun, Tuntun and Nuan at 30, 60
/// and 100 days.
Set<Character> unlockedCharacters(int days, Character? choice) => {
  for (final c in Character.values)
    if (isUnlocked(c, days, choice)) c,
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

  /// Day 30 / 60 / 100: the friends in [dueLaterFriends] are here (one card,
  /// even when several came at once).
  later,
}

/// The day-30/60/100 friends whose day has come and whose card has not been
/// shown yet ([seen]), in order.
List<Character> dueLaterFriends(int days, Set<Character> seen) => [
  for (final c in laterFriends)
    if (days >= c.days && !seen.contains(c)) c,
];

/// Which friend card is due (pure rule, see WardrobeController). The Miu and
/// Lumi cards keep their 1.7.0 rules and come first (they are due earlier);
/// the 30/60/100 card waits for a later session end, and shows every friend
/// due at that time.
FriendCard? dueFriendCard({
  required int days,
  required Character? choice,
  required bool day3CardShown,
  required bool day10CardSeen,
  Set<Character> laterSeen = const {},
}) {
  if (days >= secondFriendDays && !day10CardSeen) return choice == null ? FriendCard.both : FriendCard.day10;
  if (friendChoicePending(days, choice) && !day3CardShown) return FriendCard.day3;
  if (dueLaterFriends(days, laterSeen).isNotEmpty) return FriendCard.later;
  return null;
}
