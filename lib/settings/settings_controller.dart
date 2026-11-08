// Persisted user settings. Port of `app/src/settings.rs` using
// shared_preferences (NSUserDefaults on iOS).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../breathing/breathing_engine.dart';

const defaultInhale = 4, defaultHold = 2, defaultExhale = 6, defaultRest = 0;

/// Number of background tracks (names are localised in S.tracks).
const trackCount = 3;
const durationPresets = [1, 2, 3, 5, 10, 15];
const maxSessionMinutes = 15;

/// Zeep Balance game lengths (minutes).
const gameDurations = [1, 2, 3];

class SettingsController extends ChangeNotifier {
  SharedPreferences? _prefs;

  int inhale = defaultInhale;
  int hold = defaultHold;
  int exhale = defaultExhale;
  int rest = defaultRest;
  bool music = true;
  bool vibration = true;
  int sessionMinutes = 3;
  int track = 0;

  /// Zeep Balance: last level (0 easy, 1 medium, 2 hard) and length, and the
  /// best score (0-100) per level.
  int gameLevel = 0;
  int gameMinutes = 1;
  List<int> gameBest = [0, 0, 0];

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      inhale = (p.getInt('zeep.inhale') ?? inhale).clamp(1, 15);
      hold = (p.getInt('zeep.hold') ?? hold).clamp(0, 15);
      exhale = (p.getInt('zeep.exhale') ?? exhale).clamp(1, 15);
      rest = (p.getInt('zeep.rest') ?? rest).clamp(0, 15);
      music = p.getBool('zeep.music') ?? music;
      vibration = p.getBool('zeep.vibration') ?? vibration;
      sessionMinutes = (p.getInt('zeep.sessionMinutes') ?? sessionMinutes).clamp(1, maxSessionMinutes);
      track = (p.getInt('zeep.track') ?? track).clamp(0, trackCount - 1);
      gameLevel = (p.getInt('zeep.gameLevel') ?? gameLevel).clamp(0, 2);
      gameMinutes = (p.getInt('zeep.gameMinutes') ?? gameMinutes).clamp(1, 3);
      gameBest = [for (var i = 0; i < 3; i++) (p.getInt('zeep.gameBest$i') ?? 0).clamp(0, 100)];
    } catch (_) {
      // storage unavailable: run with defaults
    }
  }

  Future<void> save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('zeep.inhale', inhale);
    await p.setInt('zeep.hold', hold);
    await p.setInt('zeep.exhale', exhale);
    await p.setInt('zeep.rest', rest);
    await p.setBool('zeep.music', music);
    await p.setBool('zeep.vibration', vibration);
    await p.setInt('zeep.sessionMinutes', sessionMinutes);
    await p.setInt('zeep.track', track);
    await p.setInt('zeep.gameLevel', gameLevel);
    await p.setInt('zeep.gameMinutes', gameMinutes);
    for (var i = 0; i < 3; i++) {
      await p.setInt('zeep.gameBest$i', gameBest[i]);
    }
  }

  BreathDurations get durations =>
      BreathDurations(inhale.toDouble(), hold.toDouble(), exhale.toDouble(), rest.toDouble());

  void update(void Function(SettingsController s) change, {bool persist = true}) {
    change(this);
    inhale = inhale.clamp(1, 15);
    hold = hold.clamp(0, 15);
    exhale = exhale.clamp(1, 15);
    rest = rest.clamp(0, 15);
    sessionMinutes = sessionMinutes.clamp(1, maxSessionMinutes);
    track = track.clamp(0, trackCount - 1);
    gameLevel = gameLevel.clamp(0, 2);
    gameMinutes = gameMinutes.clamp(1, 3);
    notifyListeners();
    if (persist) save();
  }

  void resetBreathing() => update((s) {
    s.inhale = defaultInhale;
    s.hold = defaultHold;
    s.exhale = defaultExhale;
    s.rest = defaultRest;
  });
}
