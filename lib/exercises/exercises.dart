// Breathing modes. Each one is a set of durations plus texts, so they all run
// on the same BreathingEngine. Content follows the team's spec (belly
// breathing, 4-7-8, box breathing).

import 'package:flutter/painting.dart';

import '../breathing/breathing_engine.dart';
import '../l10n/strings.dart';

class Exercise {
  final String id;
  final String nameEn, nameTh;
  final String descEn, descTh;
  final String tipEn, tipTh;
  final BreathDurations durations;
  final int minutes; // default session length
  final Color tint;

  const Exercise({
    required this.id,
    required this.nameEn,
    required this.nameTh,
    required this.descEn,
    required this.descTh,
    required this.tipEn,
    required this.tipTh,
    required this.durations,
    required this.minutes,
    required this.tint,
  });

  String name(S s) => s.th ? nameTh : nameEn;
  String description(S s) => s.th ? descTh : descEn;
  String tip(S s) => s.th ? tipTh : tipEn;

  /// Phases this mode uses, in order (zero-length phases are skipped).
  List<Phase> get phases => Phase.values.where((p) => durations.of(p) > 0).toList();

  String get pattern => patternOf(durations);
}

/// "4 · 7 · 8" (zero-length phases left out).
String patternOf(BreathDurations d) =>
    Phase.values.where((p) => d.of(p) > 0).map((p) => d.of(p).round().toString()).join(' · ');

const _sleepTipEn = 'Sit comfortably or lie down in bed. Turn off the lights for the best sleep.';
const _sleepTipTh = 'นั่งในท่าที่สบายหรือนอนลงบนเตียง ปิดไฟในห้องเพื่อการนอนที่ดีที่สุด';

const exercises = <Exercise>[
  Exercise(
    id: 'belly',
    nameEn: 'Belly breathing',
    nameTh: 'หายใจด้วยท้อง',
    descEn: 'Expand your belly to activate the parasympathetic nervous system and help your body relax.',
    descTh: 'เน้นขยายหน้าท้องเพื่อกระตุ้นระบบประสาทพาราซิมพาเทติกให้ร่างกายผ่อนคลาย',
    tipEn: _sleepTipEn,
    tipTh: _sleepTipTh,
    durations: BreathDurations(4, 0, 6, 0),
    minutes: 5,
    tint: Color(0xFFBAE6E0),
  ),
  Exercise(
    id: '478',
    nameEn: '4-7-8 breathing',
    nameTh: 'หายใจแบบ 4-7-8',
    descEn: 'A pattern that quiets a racing mind and helps you fall asleep.',
    descTh: 'สูตรที่ช่วยสงบความคิดที่วิ่งวุ่นและช่วยให้หลับ',
    tipEn: _sleepTipEn,
    tipTh: _sleepTipTh,
    durations: BreathDurations(4, 7, 8, 0),
    minutes: 5,
    tint: Color(0xFFCCC7F5),
  ),
  Exercise(
    id: 'box',
    nameEn: 'Box breathing',
    nameTh: 'หายใจสี่เหลี่ยม',
    descEn: 'Builds focus and slows your heart into a steady rhythm.',
    descTh: 'ฝึกสมาธิและทำให้หัวใจเต้นช้าลงเป็นจังหวะสม่ำเสมอ',
    tipEn: _sleepTipEn,
    tipTh: _sleepTipTh,
    durations: BreathDurations(4, 4, 4, 4),
    minutes: 5,
    tint: Color(0xFFF4E4A6),
  ),
];

/// Session lengths offered on a mode's screen.
const modeDurations = [5, 10, 15];

/// The app's default rhythm (inhale 4, hold 2, exhale 6).
const defaultDurations = BreathDurations(4, 2, 6, 0);

/// The preset matching these durations, or null.
Exercise? exerciseFor(BreathDurations d) {
  for (final e in exercises) {
    if (e.durations == d) return e;
  }
  return null;
}

/// Stable id stored in the session history.
String exerciseId(BreathDurations d) => exerciseFor(d)?.id ?? (d == defaultDurations ? 'default' : 'custom');

/// Display name for the current durations.
String exerciseLabel(BreathDurations d, S s) => exerciseDisplayName(exerciseId(d), s);

/// History entries saved before 1.2 stored an English exercise name instead
/// of an id. Names whose rhythm still exists map to it; the rest are custom.
const _legacyNames = {'Calm tide': 'default', 'Box breathing': 'box', '4-7-8 Sleep': '478'};

/// The current exercise id for a value stored in the history: a preset id,
/// 'default' or 'custom'. Old English names are mapped; anything unknown is
/// custom.
String historyExerciseId(String stored) {
  final id = _legacyNames[stored] ?? stored;
  if (id == 'default' || exercises.any((e) => e.id == id)) return id;
  return 'custom';
}

/// Display name for a value stored in the history, in the current language.
String exerciseDisplayName(String stored, S s) {
  final id = historyExerciseId(stored);
  for (final e in exercises) {
    if (e.id == id) return e.name(s);
  }
  return id == 'default' ? s.defaultRhythm : s.customRhythm;
}
