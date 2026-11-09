// All user-facing text in Thai and English. The language follows the
// phone's language (Thai -> Thai, anything else -> English).
//
// Usage: `final s = S.of(context); Text(s.start)`.

import 'package:flutter/widgets.dart';

import '../breathing/breathing_engine.dart';
import '../friends/characters.dart';
import '../game/balance_game.dart';
import '../haptics/haptics_service.dart';
import '../share/share_card.dart';
import '../wardrobe/flowers.dart';
import '../wardrobe/outfits.dart';

class S {
  final bool th;
  const S._(this.th);

  static const en = S._(false);
  static const thai = S._(true);

  static const supportedLocales = [Locale('en'), Locale('th')];

  static S of(BuildContext context) => Localizations.localeOf(context).languageCode == 'th' ? thai : en;

  String _(String english, String thaiText) => th ? thaiText : english;

  // ---------------------------------------------------------------- general
  String get appTitle => 'ZEEP Breathe';
  String get betaBanner => _('Zeep beta version', 'Zeep เวอร์ชันเบต้า');
  String get close => _('Close', 'ปิด');
  String get back => _('Back', 'ย้อนกลับ');
  String minutes(int m) => _('$m min', '$m นาที');
  String secs(int n) => _('$n s', '$n วิ');
  String get secUnit => _('s', 'วิ');

  // tabs
  String get tabBreathe => _('Breathe', 'หายใจ');
  String get tabExercises => _('Exercises', 'แบบฝึก');
  String get tabProgress => _('Progress', 'ความคืบหน้า');

  // ---------------------------------------------------------------- phases
  String phase(Phase p) => switch (p) {
    Phase.inhale => _('Inhale', 'หายใจเข้า'),
    Phase.hold => _('Hold', 'กลั้นไว้'),
    Phase.exhale => _('Exhale', 'หายใจออก'),
    Phase.rest => _('Rest', 'พักไว้'),
  };
  String get paused => _('Paused', 'หยุดชั่วคราว');

  // ---------------------------------------------------------------- music
  List<String> get tracks =>
      th ? const ['ฝนพรำ', 'คลื่นทะเล', 'เสียงฮัมอุ่นๆ'] : const ['Soft rain', 'Ocean drift', 'Warm hum'];
  String get backgroundMusic => _('Background music', 'เพลงพื้นหลัง');
  String get audioUnavailable => _('Audio unavailable', 'ไม่สามารถเล่นเสียงได้');
  String playing(String t) => _('Playing · $t', 'กำลังเล่น · $t');
  String playsDuringSessions(String t) => _('$t · plays during sessions', '$t · เล่นระหว่างฝึก');

  // ---------------------------------------------------------------- setup
  String get howItWorks => _('How it works', 'วิธีใช้งาน');
  String get breathingSettings => _('Breathing settings', 'ตั้งค่าการหายใจ');
  String get breathingSettingsLink => _('breathing settings', 'ตั้งค่าการหายใจ');
  String get greeting => _(
    // a no-break space: "away." never sits alone on the last line (QA r2 #2)
    "Hi, I'm Zeep. Let's fill up slowly like a rising tide, then let it all drift away.",
    'สวัสดี ฉันชื่อ Zeep มาค่อยๆ หายใจเข้าให้เต็มเหมือนน้ำขึ้น แล้วปล่อยออกไปช้าๆ ด้วยกันนะ',
  );
  String get howLong => _('How long would you like to breathe?', 'อยากฝึกหายใจนานแค่ไหน?');
  String get sessionLength => _('Session length', 'ระยะเวลาฝึก');
  String get start => _('Start', 'เริ่ม');
  String exerciseChip(String name, String pattern) =>
      _('Exercise $name, $pattern. Change exercise', 'แบบฝึก $name, $pattern แตะเพื่อเปลี่ยน');

  // ---------------------------------------------------------------- session
  String timeRemaining(String t) => _('Time remaining $t', 'เหลือเวลา $t');
  String get pause => _('Pause', 'หยุดชั่วคราว');
  String get play => _('Play', 'เล่น');
  String get stop => _('Stop', 'หยุด');
  String get musicOn => _('Music on', 'เปิดเพลง');
  String get musicOff => _('Music off', 'ปิดเพลง');
  String get vibrationOn => _('Vibration on', 'เปิดการสั่น');
  String get vibrationOff => _('Vibration off', 'ปิดการสั่น');
  String hapticBadge(HapticPattern p) => '${_('Haptic', 'การสั่น')} · ${haptic(p)}';
  String haptic(HapticPattern p) => switch (p) {
    HapticPattern.inhaleStart => _('inhale pulse', 'หายใจเข้า'),
    HapticPattern.holdStart => _('hold · double pulse', 'กลั้น · 2 ครั้ง'),
    HapticPattern.exhaleStart => _('exhale pulse', 'หายใจออก'),
    HapticPattern.confirm => _('vibration on', 'เปิดการสั่น'),
    HapticPattern.edgeOut => _('left the circle', 'ออกนอกวง'),
    HapticPattern.edgeIn => _('back in the circle', 'กลับเข้าวง'),
    HapticPattern.bloom => _('bloom', 'ดอกบาน'),
  };
  String get sessionComplete => _('Session complete', 'ฝึกครบแล้ว');
  String sessionSummary(int breaths, int mins) =>
      _('$breaths full breaths · $mins min', 'หายใจครบ $breaths รอบ · $mins นาที');
  String streakBadge(int n) =>
      n == 1 ? _('Day 1 of your streak', 'วันแรกของการฝึกต่อเนื่อง') : _('$n-day streak', 'ฝึกต่อเนื่อง $n วัน');
  String get again => _('Again', 'อีกครั้ง');
  String get done => _('Done', 'เสร็จสิ้น');

  // ---------------------------------------------------------------- settings sheet
  String get inhaleSeconds => _('Inhale seconds', 'หายใจเข้า (วินาที)');
  String get holdSeconds => _('Hold seconds', 'กลั้นไว้ (วินาที)');
  String get exhaleSeconds => _('Exhale seconds', 'หายใจออก (วินาที)');
  String get restSeconds => _('Rest after exhale', 'พักหลังหายใจออก');
  String get resetToDefault => _('Reset to default', 'คืนค่าเริ่มต้น');
  String get resetHint => _('Inhale 4s · Hold 2s · Exhale 6s', 'เข้า 4 วิ · กลั้น 2 วิ · ออก 6 วิ');
  String cycleSummary(int cycle, int per, int mins) => _(
    'One breath = ${cycle}s · about $per breaths in $mins min',
    'หายใจ 1 รอบ = $cycle วิ · ประมาณ $per รอบใน $mins นาที',
  );
  String get phoneVibration => _('Phone vibration', 'การสั่นของโทรศัพท์');
  String get vibrationHint =>
      _('Pulse at inhale, hold (×2) and exhale', 'สั่นตอนหายใจเข้า กลั้น (2 ครั้ง) และหายใจออก');
  String get noHapticEngine => _(
    'This device has no haptic engine, so pulses show as ripples around your friend.',
    'เครื่องนี้ไม่มีมอเตอร์สั่น จึงแสดงเป็นวงกระเพื่อมรอบตัวละครแทน',
  );

  // ---------------------------------------------------------------- instructions sheet
  // neutral wording (1.7.1): the breathing character may be Zeep, Miu or Lumi
  List<(String, String)> get instructionSteps => th
      ? const [
          ('หายใจเข้า', 'ตัวละครค่อยๆ เติมลมไปพร้อมคุณ หายใจเข้าทางจมูก'),
          ('กลั้นไว้', 'ตัวละครนิ่งไปพร้อมคุณ กลั้นไว้สบายๆ ไม่ต้องเกร็ง'),
          ('หายใจออก', 'ตัวละครค่อยๆ ผ่อนลง ปล่อยลมออกช้าๆ'),
        ]
      : const [
          ('Inhale', 'Your friend fills up with you. Breathe in through your nose.'),
          ('Hold', 'Your friend stays still with you. Keep the breath gently, no strain.'),
          ('Exhale', 'Your friend settles down. Let the air drift out slowly.'),
        ];
  List<String> get instructionBullets => th
      ? const [
          'แถบใต้ตัวละครเต็มตามลมหายใจ เส้นบางๆ ด้านล่างบอกว่าเฟสนี้ผ่านไปเท่าไหร่แล้ว',
          'ปรับเวลาแต่ละเฟสได้ใน "ตั้งค่าการหายใจ" แม้ระหว่างฝึก ตัวละครจะปรับตามอย่างนุ่มนวล',
          'โทรศัพท์สั่นเบาๆ ตอนเริ่มหายใจเข้าและหายใจออก และสั่น 2 ครั้งสั้นๆ ตอนกลั้น',
          'หน้าจอจะไม่ดับระหว่างฝึก ถ้าออกจากแอป การฝึกจะหยุดชั่วคราว',
        ]
      : const [
          'The bar under your friend fills with your breath; the thin line under it shows how far into the current step you are.',
          "Change each step's length in Breathing settings, even mid-session. Your friend adjusts smoothly.",
          'Your phone gives a gentle pulse when inhale and exhale start, and two short pulses for hold.',
          'The screen stays on during a session. Leaving the app pauses it.',
        ];

  // ---------------------------------------------------------------- exercises
  String get exercisesTitle => _('Exercises', 'แบบฝึกหายใจ');
  String get exercisesSubtitle => _('Choose a breathing mode', 'เลือกโหมดการหายใจที่เหมาะกับคุณ');
  String get defaultRhythm => _('Default', 'ค่าเริ่มต้น');
  String get customRhythm => _('Custom', 'กำหนดเอง');
  String usingCustom(String pattern) => _(
    'You are using your own rhythm ($pattern). Pick a mode to switch.',
    'ตอนนี้ใช้จังหวะที่ตั้งเอง ($pattern) แตะโหมดด้านบนเพื่อเปลี่ยน',
  );
  String get rhythmTitle => _('Breathing rhythm (seconds)', 'จังหวะการหายใจ (วินาที)');
  String get chooseDuration => _('Session length', 'เลือกเวลาการฝึก');
  String get startBreathing => _('Start breathing', 'เริ่มฝึกหายใจ');

  // ---------------------------------------------------------------- Zeep Balance game (T2.3, GP)
  String get gameName => _('Zeep Balance', 'Zeep ทรงตัว');
  String get gameCardDesc =>
      _('Tilt to guide Zeep into the circle, then hold still', 'เอียงเครื่องพา Zeep เข้าวง แล้วนิ่งไว้');
  String get tiltHint => _('Tilt your phone gently to roll Zeep', 'เอียงเครื่องเบาๆ เพื่อให้ Zeep กลิ้ง');
  String get holdComfortably => _('Hold your phone comfortably', 'ถือเครื่องในท่าที่สบาย');
  String get calibratingHint => _('This position becomes level for the game', 'ท่านี้จะเป็นระนาบของเกม');
  String get resetCentre => _('Reset centre', 'ตั้งศูนย์ใหม่');
  String get waitingForSensor => _('Starting the tilt sensor…', 'กำลังเปิดเซ็นเซอร์เอียง…');
  String get noTiltSensor => _(
    "This device has no tilt sensor, so the game isn't available.",
    'เครื่องนี้ไม่มีเซ็นเซอร์เอียง จึงเล่นเกมนี้ไม่ได้',
  );
  // GM: level select
  String get chooseLevel => _('Choose a level', 'เลือกด่าน');
  String levelName(BalanceLevel l) => switch (l) {
    BalanceLevel.easy => _('Easy', 'ง่าย'),
    BalanceLevel.medium => _('Medium', 'กลาง'),
    BalanceLevel.hard => _('Hard', 'ยาก'),
  };
  String levelDesc(BalanceLevel l) => switch (l) {
    BalanceLevel.easy => _('A big circle that stays still', 'วงใหญ่ อยู่นิ่งกับที่'),
    BalanceLevel.medium => _(
      'The circle breathes with your rhythm: bigger on inhale, smaller on exhale',
      'วงหายใจตามจังหวะของคุณ ขยายตอนหายใจเข้า หดตอนหายใจออก',
    ),
    BalanceLevel.hard => _('A small circle that drifts slowly', 'วงเล็ก ลอยเคลื่อนช้าๆ'),
  };
  String get gameLength => _('Game length', 'เวลาเล่น');
  String get startGame => _('Start game', 'เริ่มเล่น');
  String bestScore(int p) => _('Best $p%', 'ดีที่สุด $p%');
  String get noBestYet => _('No best score yet', 'ยังไม่มีสถิติ');
  String get gameHowTo => _(
    'Keep Zeep inside the circle. The more time inside, the higher your score.',
    'ประคอง Zeep ให้อยู่ในวง ยิ่งอยู่ในวงนาน คะแนนยิ่งสูง',
  );
  // GP: playing
  String get keepInCircle => _('Keep Zeep in the circle', 'ประคอง Zeep ให้อยู่ในวง');
  String get inCircle => _('In the circle', 'อยู่ในวง');
  String get outOfCircle => _('Outside, tilt back gently', 'ออกนอกวง เอียงกลับเบาๆ');
  String get scoreLabel => _('Score', 'คะแนน');
  String get timeLeftLabel => _('Time left', 'เหลือเวลา');
  String get resume => _('Resume', 'เล่นต่อ');
  // GR: results
  String get gameComplete => _('Well balanced!', 'ทรงตัวได้ดีมาก!');
  String get gameStopped => _('Game stopped', 'หยุดเกมแล้ว');
  String scoreSummary(int p) => _('$p% of the time in the circle', 'อยู่ในวง $p% ของเวลา');
  String starsLabel(int n) => _('$n of 3 stars', '$n จาก 3 ดาว');
  String get newBest => _('New best!', 'สถิติใหม่!');
  String get playAgain => _('Play again', 'เล่นอีกครั้ง');
  String get gameNotSaved => _('Games under 30 seconds are not saved.', 'เกมที่สั้นกว่า 30 วินาทีจะไม่ถูกบันทึก');
  // T3.4 timeline
  String gameEntryName(BalanceLevel l) => '$gameName · ${levelName(l)}';
  String scoreEntry(int p) => _('Score $p%', 'คะแนน $p%');

  // ---------------------------------------------------------------- share card (Community phase 1, CS)
  String get share => _('Share', 'แชร์');
  String get shareScore => _('Share score', 'แชร์คะแนน');
  String get shareStreak => _('Share your streak', 'แชร์วันฝึกต่อเนื่อง');
  String get shareTitle => _('Share card', 'การ์ดแชร์');
  String get cardColour => _('Card colour', 'สีการ์ด');
  String cardThemeName(ShareCardColor t) => switch (t) {
    ShareCardColor.lavender => _('Lavender', 'ม่วงลาเวนเดอร์'),
    ShareCardColor.mint => _('Mint', 'เขียวมิ้นต์'),
    ShareCardColor.sky => _('Sky', 'ฟ้า'),
  };
  String cardDays(int n) => _(n == 1 ? '1 day' : '$n days', '$n วัน');
  String get cardStreakLine => _('breathing in a row', 'ฝึกหายใจต่อเนื่อง');
  String cardTotal(int minutes) => _('$minutes min in total', 'รวม $minutes นาที');
  String cardBreaths(int n) => _('$n full breaths', 'หายใจครบ $n รอบ');

  /// The card's mode line for the default or a custom rhythm ("Default"
  /// alone reads oddly to someone else): "Breathing · 4 · 2 · 6".
  String cardRhythm(String pattern) => _('Breathing · $pattern', 'ฝึกหายใจ · $pattern');
  String get cardFooter => _('Come breathe with me', 'มาหายใจด้วยกันนะ');

  /// The text sent with a share card; [name] is the character on the card.
  String shareText(String name) =>
      _('Breathing with $name · ZEEP Breathe', 'หายใจไปกับ${_latin(name) ? ' ' : ''}$name · ZEEP Breathe');

  /// Thai puts a space before a Latin name ("กับ Zeep") but not a Thai one
  /// ("กับหมิว").
  static bool _latin(String name) => name.isNotEmpty && name.codeUnitAt(0) < 0x80;
  String get shareFailed => _("Couldn't open sharing. Please try again.", 'เปิดเมนูแชร์ไม่ได้ ลองอีกครั้งนะ');

  // ---------------------------------------------------------------- progress
  String get progressTitle => _('Progress', 'ความคืบหน้า');
  String get currentStreak => _('Current streak', 'ฝึกต่อเนื่องตอนนี้');
  String dayUnit(int n) => th ? 'วัน' : (n == 1 ? 'day' : 'days');
  String get streakStart => _('Start a session today to begin a streak.', 'เริ่มฝึกวันนี้เพื่อเริ่มนับวันต่อเนื่อง');
  String get streakToday => _('Lovely. You breathed today.', 'เยี่ยมมาก วันนี้คุณฝึกหายใจแล้ว');
  String get streakKeep => _('Breathe today to keep it going.', 'ฝึกวันนี้เพื่อรักษาความต่อเนื่อง');
  String streakSemantics(int n, String msg) => _('$n day streak. $msg', 'ฝึกต่อเนื่อง $n วัน $msg');
  String get totalMin => _('total min', 'นาทีรวม');
  String get sessionsLabel => _('sessions', 'ครั้ง');
  String get bestStreak => _('best streak', 'ต่อเนื่องสูงสุด');
  String get prevMonth => _('Previous month', 'เดือนก่อน');
  String get nextMonth => _('Next month', 'เดือนถัดไป');
  String lastSevenDays(int m) => _('$m min in the last 7 days', '$m นาทีใน 7 วันที่ผ่านมา');
  String get today => _('Today', 'วันนี้');
  // day timeline (Progress tab)
  List<String> get weekdayNames => th
      ? const ['วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์']
      : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// "วันเสาร์ที่ 8 พ.ย." / "Saturday 8 Nov" (DateTime.weekday: Monday = 1).
  String dayHeading(DateTime d) => th
      ? '${weekdayNames[d.weekday - 1]}ที่ ${d.day} ${monthShort[d.month - 1]}'
      : '${weekdayNames[d.weekday - 1]} ${d.day} ${monthShort[d.month - 1]}';
  String daySummary(int sessions, int seconds) => _(
    '$sessions ${sessions == 1 ? 'session' : 'sessions'} · ${duration(seconds)}',
    '$sessions ครั้ง · ${duration(seconds)}',
  );
  String get completedLabel => _('Completed', 'ฝึกจนจบ');
  String get stoppedEarly => _('Stopped early', 'หยุดก่อนจบ');
  String get noSessionsThisDay => _('No breathing sessions on this day.', 'ไม่มีการฝึกในวันนั้น');
  String get noSessionsToday => _("You haven't breathed today yet.", 'วันนี้ยังไม่ได้ฝึกหายใจ');
  String get breatheNow => _('Breathe now', 'ไปฝึกหายใจ');
  String get dayTimelineHint =>
      _('Tap a day in the calendar to see its sessions.', 'แตะวันในปฏิทินเพื่อดูการฝึกของวันนั้น');
  String daySemantics(int day, String month, int? mins, bool selected) =>
      '$day $month${mins != null ? ', ${minutes(mins)}' : ''}${selected ? _(', selected', ', เลือกอยู่') : ''}';

  /// "1 min 35 s" / "1 นาที 35 วิ"; whole minutes stay "5 min".
  String duration(int seconds) {
    if (seconds < 60) return secs(seconds);
    final m = seconds ~/ 60, r = seconds % 60;
    return r == 0 ? minutes(m) : _('$m min $r s', '$m นาที $r วิ');
  }

  String get loggingRule =>
      _('Sessions of 30 seconds or more are saved here.', 'การฝึกตั้งแต่ 30 วินาทีขึ้นไปจะถูกบันทึกไว้ที่นี่');

  List<String> get monthNames => th
      ? const [
          'มกราคม',
          'กุมภาพันธ์',
          'มีนาคม',
          'เมษายน',
          'พฤษภาคม',
          'มิถุนายน',
          'กรกฎาคม',
          'สิงหาคม',
          'กันยายน',
          'ตุลาคม',
          'พฤศจิกายน',
          'ธันวาคม',
        ]
      : const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
  List<String> get monthShort => th
      ? const ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']
      : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Sunday-first weekday initials.
  List<String> get weekdayHeads =>
      th ? const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'] : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  /// Thai shows the Buddhist-era year (2026 -> 2569).
  String monthYear(DateTime m) => '${monthNames[m.month - 1]} ${th ? m.year + 543 : m.year}';

  // ---------------------------------------------------------------- wardrobe (W, N, S.9)
  String get wardrobe => _("Zeep's wardrobe", 'ตู้เสื้อผ้า Zeep');
  String get openWardrobe => _('Open wardrobe', 'เปิดตู้เสื้อผ้า');
  String get tabOutfits => _('Outfits', 'ของแต่งตัว');
  String get tabGarden => _('Flower garden', 'สวนดอกไม้');
  String get wearNone => _('None', 'ไม่ใส่');
  String get noFlower => _('No flower', 'ไม่ใส่ดอก');
  String get wearing => _('wearing', 'ใส่อยู่');
  String get locked => _('locked', 'ยังล็อก');
  String get newItem => _('new', 'ใหม่');
  String daysLeft(int n) => _(n == 1 ? '1 more day' : '$n more days', 'อีก $n วัน');
  String practiceDays(int n) => _(n == 1 ? 'Practised on 1 day' : 'Practised on $n days', 'ฝึกมาแล้ว $n วัน');
  String get outfitsHint =>
      _('A new item unlocks as your practice days add up.', 'ฝึกครบจำนวนวันแล้วได้ของใหม่ ไม่ต้องฝึกติดกัน');
  String slotName(OutfitSlot s) => switch (s) {
    OutfitSlot.sprout => _('Sprout', 'ต้นอ่อน'),
    OutfitSlot.face => _('Face', 'หน้า'),
    OutfitSlot.head => _('Head', 'หัว'),
    OutfitSlot.friend => _('Friend', 'เพื่อน'),
  };
  String itemName(OutfitItem i) => switch (i) {
    OutfitItem.sproutBow => _('Sprout bow', 'โบว์ผูกก้าน'),
    OutfitItem.roundGlasses => _('Round glasses', 'แว่นกลม'),
    OutfitItem.flowerCrown => _('Flower crown', 'มงกุฎดอกไม้'),
    OutfitItem.beanie => _('Beanie', 'หมวกไหมพรม'),
    OutfitItem.butterfly => _('Butterfly', 'ผีเสื้อ'),
    OutfitItem.ladybug => _('Ladybug', 'เต่าทองบนใบ'),
    OutfitItem.cloud => _('Little cloud', 'เมฆน้อย'),
    OutfitItem.sleepCap => _('Sleep cap', 'หมวกนอน'),
    OutfitItem.heartGlasses => _('Heart glasses', 'แว่นหัวใจ'),
    OutfitItem.mushroomHat => _('Mushroom hat', 'หมวกเห็ด'),
    OutfitItem.bee => _('Little bee', 'ผึ้งน้อย'),
    OutfitItem.dewDrop => _('Dewdrop', 'หยดน้ำค้าง'),
    OutfitItem.catEars => _('Cat ears', 'ที่คาดผมหูแมว'),
    OutfitItem.starStickers => _('Star stickers', 'สติกเกอร์ดาวที่แก้ม'),
    OutfitItem.skyFish => _('Sky fish', 'ปลาลอยฟ้า'),
    OutfitItem.strawHat => _('Straw hat', 'หมวกฟาง'),
    OutfitItem.windChime => _('Wind chime', 'กระดิ่งลม'),
    OutfitItem.rainbowGlasses => _('Rainbow glasses', 'แว่นสายรุ้ง'),
    OutfitItem.bird => _('Little bird', 'นกน้อย'),
    OutfitItem.goldLeafCrown => _('Gold leaf crown', 'มงกุฎใบไม้ทอง'),
    OutfitItem.firefly => _('Firefly', 'หิ่งห้อย'),
    OutfitItem.lantern => _('Tiny lantern', 'โคมไฟจิ๋ว'),
    OutfitItem.wizardHat => _('Star wizard hat', 'หมวกพ่อมดดาว'),
    OutfitItem.catEyeGlasses => _('Cat-eye glasses', 'แว่นตาแมว'),
    OutfitItem.crescentMoon => _('Crescent moon', 'ดวงจันทร์เสี้ยว'),
    OutfitItem.rainbowRibbon => _('Rainbow ribbon', 'ริบบิ้นสายรุ้ง'),
    OutfitItem.halo => _('Halo', 'วงแสงฮาโล'),
    OutfitItem.lotusCrown => _('Golden lotus crown', 'มงกุฎบัวทองคำ'),
  };
  String flowerName(FlowerKind f) => th ? f.nameTh : f.nameEn;
  String levelLeaves(int level, int leaves, int need) =>
      _('Level $level · leaves $leaves/$need', 'เลเวล $level · ใบ $leaves/$need');
  String stepsToBloom(int n) => n == 1
      ? _('One more session and it blooms', 'ฝึกอีก 1 ครั้ง ดอกจะบาน')
      : _('$n more sessions to bloom', 'ฝึกอีก $n ครั้ง ดอกจะบาน');
  String get gardenHint => _(
    'Each finished session grows a leaf (up to 3 a day). Tap a flower for your friend to wear.',
    // (the bracket stays on one line: word joiners and a no-break space)
    'ฝึกจนจบ 1 ครั้ง ใบงอก 1 ใบ (วันละ⁠ไม่⁠เกิน 3) แตะดอกที่บานแล้วเพื่อให้ตัวละครใส่',
  );
  String levelN(int n) => _('Level $n', 'เลเวล $n');
  String bloomCount(int n) => '×$n';
  String get leafGrew => _('A new leaf grew', 'ใบใหม่งอกแล้ว');
  String get bloomedTitle => _('It bloomed!', 'ดอกบานแล้ว!');
  String bloomedDetail(int level, String flower) =>
      _('Level $level · you got a $flower', 'ขึ้นเลเวล $level · ได้${_withDok(flower)}');

  /// Thai flower names read "ดอก…"; some already start with it (ดอกบัว).
  String _withDok(String name) => !th || name.startsWith('ดอก') ? name : 'ดอก$name';

  // ---------------------------------------------------------------- card L (bloom = level up)
  String flowerTitle(FlowerKind f) => th ? _withDok(f.nameTh) : f.nameEn;
  String get flowerNew => _("A new flower in Zeep's garden", 'ดอกใหม่ในสวนของ Zeep');
  String flowerAgain(FlowerKind f, int n) =>
      _('${f.nameEn} number $n in the garden', '${_withDok(f.nameTh)}ดอกที่ $n ในสวน');
  String get next => _('Next', 'ต่อไป');
  String get seeGarden => _('See the garden', 'ดูในสวน');
  String get dailyLimit =>
      _('The sprout grew 3 times today. More tomorrow!', 'วันนี้ต้นอ่อนโตครบ 3 ครั้งแล้ว พรุ่งนี้มาต่อนะ');
  String get newItemTitle => _('Something new for Zeep!', 'Zeep ได้ของใหม่!');
  String newItemBody(String item, int days) => _(
    // a no-break space (U+00A0) keeps each number with its unit on one line
    days == 1 ? '$item · unlocked after 1 day of practice' : '$item · unlocked after $days days of practice',
    '$item · ปลดล็อกเมื่อฝึกครบ $days วัน',
  );
  String get tryItOn => _('Try it on', 'ลองใส่เลย');
  String get later => _('Later', 'ไว้ทีหลัง');
  String get summaryTitle => _('Zeep has gifts for you', 'Zeep มีของรอคุณอยู่');
  String summaryBody(int level, int items) => _(
    // two short lines, broken by hand; no-break spaces (U+00A0) keep numbers with their
    // units, and a word joiner (U+2060) keeps ปลดล็อก in one piece
    'From your practice so far:\nlevel $level · $items ${items == 1 ? 'item' : 'items'} unlocked',
    'จากที่ฝึกมาแล้ว\nได้เลเวล $level · ปลด⁠ล็อกของ $items ชิ้น',
  );

  // ---------------------------------------------------------------- Zeep and friends (1.7.0)
  String characterName(Character c) => switch (c) {
    Character.zeep => 'Zeep',
    Character.miu => _('Miu', 'หมิว'),
    Character.lumi => _('Lumi', 'ลูมิ'),
    Character.mun => _('Mun', 'หมุนหมุน'),
    Character.tuntun => _('Tuntun', 'ตุ่นตุ่น'),
    Character.nuan => _('Nuan', 'นวล'),
    // word joiners (U+2060) keep Thai words whole when a line wraps (QA
    // 1.9.0 #4): never "ใส / ใส", "วง / วง"
    Character.saisai => _('Saisai', 'ใส\u2060ใส'),
    Character.wongwong => _('Wongwong', 'วง\u2060วง'),
  };
  String characterTagline(Character c) => switch (c) {
    Character.zeep => _('Fills with water as you breathe', 'เติมน้ำตามลมหายใจ'),
    Character.miu => _('Belly rises as you breathe', 'ท้องป่องตามลมหายใจ'),
    Character.lumi => _('Glows brighter as you breathe', 'ไฟสว่างตามลมหายใจ'),
    Character.mun => _('Spins with your breath', 'ใบพัดหมุนตามลมหายใจ'),
    Character.tuntun => _('Peeks out as you breathe in', 'โผล่หัวออกมาตามลมหายใจ'),
    Character.nuan => _('Grows full as you breathe in', 'เต็มดวงตามลมหายใจ'),
    Character.saisai => _('Floats up as you breathe in', 'ลอย\u2060ฟูตามลม\u2060หายใจ'),
    Character.wongwong => _('Its ring opens as you breathe in', 'วง\u2060แหวนกางตามลม\u2060หายใจ'),
  };

  /// The speech bubble on the Breathe tab, in the active character's voice.
  String greetingOf(Character c) => switch (c) {
    Character.miu => _(
      "Hi, I'm Miu. Breathe in until your belly is round, then let it out slowly with me.",
      'สวัสดี ฉันชื่อหมิว หายใจเข้าให้ท้องป่องๆ แล้วค่อยๆ ปล่อยออกไปช้าๆ ด้วยกันนะ',
    ),
    Character.lumi => _(
      "Hi, I'm Lumi. My light grows as you breathe in and softens as you breathe out.",
      'สวัสดี ฉันชื่อลูมิ หายใจเข้าแล้วไฟจะสว่างขึ้น หายใจออกแล้วไฟจะค่อยๆ หรี่ลงนะ',
    ),
    Character.mun => _(
      "Hi, I'm Mun. Breathe in and my blades spin fast, then slow down with me as you breathe out.",
      'สวัสดี ฉันชื่อหมุนหมุน หายใจเข้าแล้วใบพัดจะหมุนเร็ว หายใจออกแล้วค่อยๆ หมุนช้าลงด้วยกันนะ',
    ),
    Character.tuntun => _(
      "Hi, I'm Tuntun. I peek out as you breathe in and tuck back into my shell as you breathe out. Little by little.",
      'สวัสดี ฉันชื่อตุ่นตุ่น หายใจเข้าแล้วฉันจะโผล่หัวออกมา หายใจออกแล้วค่อยๆ หดกลับเข้ากระดอง ไปทีละนิดก็ถึงนะ',
    ),
    Character.nuan => _(
      "Hi, I'm Nuan. Breathe in and I grow full, breathe out and I become a soft crescent again.",
      'สวัสดี ฉันชื่อนวล หายใจเข้าแล้วฉันจะค่อยๆ เต็มดวง หายใจออกแล้วกลับเป็นเสี้ยวบางๆ นะ',
    ),
    Character.saisai => _(
      "Hi, I'm Saisai. Breathe in and I float up soft and round, breathe out and I drift slowly down with you.",
      // word joiners: "พองฟู", "ลอยขึ้น", "ลอยลง" stay whole (QA 1.9.0 #4)
      'สวัสดี ฉันชื่อใส\u2060ใส หายใจเข้าแล้วฉันจะพอง\u2060ฟู\u200Bลอย\u2060ขึ้น '
          'หายใจออกแล้วค่อยๆ ลอย\u2060ลงช้าๆ ไปด้วยกันนะ',
    ),
    Character.wongwong => _(
      "Hi, I'm Wongwong. Breathe in and my ring opens wide, breathe out and it settles flat again.",
      // word joiners: "วงแหวน", "กางออก", "แบนลง", "เหมือนเดิม" stay whole
      'สวัสดี ฉันชื่อวง\u2060วง หายใจเข้าแล้ววง\u2060แหวนจะกาง\u2060ออก '
          'หายใจออกแล้วค่อยๆ แบน\u2060ลง\u200Bเหมือน\u2060เดิมนะ',
    ),
    Character.zeep => greeting,
  };
  String get friendsTitle => _('My friends', 'เพื่อนของฉัน');
  String get friendsChip => _('Friends', 'เพื่อน');
  String get openFriends => _('My friends: choose who to breathe with', 'เพื่อนของฉัน เลือกเพื่อนที่จะหายใจด้วย');
  String get inUse => _('In use', 'ใช้อยู่');
  String get tapToSwitch => _('Tap to switch', 'แตะเพื่อสลับ');
  String get chooseNewFriend => _('Choose a new friend', 'เลือกเพื่อนใหม่');
  String get miuOrLumi => _('Miu or Lumi', 'หมิว หรือ ลูมิ');

  /// The greyed "Miu or Lumi" row before day 3: when they come, no action.
  String firstFriendWhen(int at, int left) =>
      _('Arrives at $at practice days · $left more', 'มาหาเมื่อฝึกครบ $at วัน · อีก $left วัน');
  String friendIn(int n) => _(n == 1 ? 'Comes in 1 more day' : 'Comes in $n more days', 'มาหาอีก $n วัน');
  String get mysteryFriend => _('Mystery friend', 'เพื่อนลึกลับ');
  String mysteryWhen(int n) => _('Comes at $n practice days', 'มาหาเมื่อฝึกครบ $n วัน');
  String get newFriendTitle => _('A new friend is here!', 'มีเพื่อนใหม่มาหาแล้ว!');
  String chooseFriend(String name) => _('Choose $name', 'เลือก$name');
  String get otherFriendLater =>
      _('The other one comes when you reach 10 practice days', 'อีกตัวจะมาหาเมื่อฝึกครบ 10 วัน');
  // "มาหาแล้ว" in one piece: never "ใสใส มา / หาแล้ว" (QA 1.9.0 #4)
  String friendArrived(String name) => _('$name is here', '$name มา\u2060หา\u2060แล้ว');
  String breatheWith(String name) => _('Breathe with $name', 'ฝึกกับ$name');

  /// Several friends at once: "Two new friends are here" (day 10 without a
  /// pick), or the later friends (30 to 200 days) after a long break or an update.
  String newFriendsTitle(int n) => _(
    switch (n) {
      2 => 'Two new friends are here',
      3 => 'Three new friends are here',
      4 => 'Four new friends are here',
      5 => 'Five new friends are here',
      _ => '$n\u00A0new friends are here',
    },
    // a no-break space and a word joiner keep "3 ตัว" together (QA r2 #1)
    'เพื่อนใหม่ $n\u00A0ตัว\u2060มาหาแล้ว',
  );

  /// The later friends' card (30 to 200 days) with several friends: Miu and Lumi came before,
  /// so these are "more" (QA r2 #3).
  String moreFriendsTitle(int n) => _(switch (n) {
    2 => 'Two more friends have arrived',
    3 => 'Three more friends have arrived',
    4 => 'Four more friends have arrived',
    5 => 'Five more friends have arrived',
    _ => '$n\u00A0more friends have arrived',
  }, 'เพื่อน\u2060ใหม่มา\u2060เพิ่มอีก $n\u00A0ตัว');
  String get pickOneNow => _('Pick one to breathe with now', 'เลือกตัวที่จะฝึกด้วยตอนนี้');
  String get selectedLabel => _('selected', 'เลือกอยู่');
}
