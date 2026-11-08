// All user-facing text in Thai and English. The language follows the
// phone's language (Thai -> Thai, anything else -> English).
//
// Usage: `final s = S.of(context); Text(s.start)`.

import 'package:flutter/widgets.dart';

import '../breathing/breathing_engine.dart';
import '../haptics/haptics_service.dart';

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
    "Hi, I'm Zeep. Let's fill up slowly like a rising tide, then let it all drift away.",
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
    'This device has no haptic engine, so pulses show as ripples around Zeep.',
    'เครื่องนี้ไม่มีมอเตอร์สั่น จึงแสดงเป็นวงกระเพื่อมรอบ Zeep แทน',
  );

  // ---------------------------------------------------------------- instructions sheet
  List<(String, String)> get instructionSteps => th
      ? const [
          ('หายใจเข้า', 'Zeep พองตัวและเติมน้ำ หายใจเข้าทางจมูก'),
          ('กลั้นไว้', 'Zeep เรืองแสงเบาๆ กลั้นไว้สบายๆ ไม่ต้องเกร็ง'),
          ('หายใจออก', 'Zeep หดตัวและถอนหายใจ ค่อยๆ ปล่อยลมออกช้าๆ'),
        ]
      : const [
          ('Inhale', 'Zeep fills up and grows. Breathe in through your nose.'),
          ('Hold', 'Zeep glows softly. Keep the breath gently, no strain.'),
          ('Exhale', 'Zeep shrinks and sighs. Let the air drift out slowly.'),
        ];
  List<String> get instructionBullets => th
      ? const [
          'แถบใต้ Zeep เต็มตามลมหายใจ เส้นบางๆ ด้านล่างบอกว่าเฟสนี้ผ่านไปเท่าไหร่แล้ว',
          'ปรับเวลาแต่ละเฟสได้ใน "ตั้งค่าการหายใจ" แม้ระหว่างฝึก Zeep จะปรับตามอย่างนุ่มนวล',
          'โทรศัพท์สั่นเบาๆ ตอนเริ่มหายใจเข้าและหายใจออก และสั่น 2 ครั้งสั้นๆ ตอนกลั้น',
          'หน้าจอจะไม่ดับระหว่างฝึก ถ้าออกจากแอป การฝึกจะหยุดชั่วคราว',
        ]
      : const [
          'The bar under Zeep fills with your breath; the thin line under it shows how far into the current step you are.',
          "Change each step's length in Breathing settings, even mid-session. Zeep adjusts smoothly.",
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

  // ---------------------------------------------------------------- progress
  String get progressTitle => _('Progress', 'ความคืบหน้า');
  String get currentStreak => _('Current streak', 'ฝึกต่อเนื่องตอนนี้');
  String dayUnit(int n) => th ? 'วัน' : (n == 1 ? 'day' : 'days');
  String get streakStart => _('Start a session today to begin a streak.', 'เริ่มฝึกวันนี้เพื่อเริ่มนับวันต่อเนื่อง');
  String get streakToday => _('Lovely. You breathed with Zeep today.', 'เยี่ยมมาก วันนี้คุณหายใจกับ Zeep แล้ว');
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
  String get noSessionsToday => _("You haven't breathed with Zeep today yet.", 'วันนี้ยังไม่ได้ฝึกกับ Zeep');
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
}
