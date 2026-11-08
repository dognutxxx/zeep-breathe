// Wiring between engine, animator, haptics, music and settings.
// Port of the `ZeepApp::update` loop in `app/src/app.rs`: one ticker drives
// everything, so character, progress bar, label and haptics read the same
// engine state in the same frame.

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/music_service.dart';
import 'breathing/breathing_engine.dart';
import 'exercises/exercises.dart';
import 'game/balance_game.dart';
import 'haptics/haptics_service.dart';
import 'history/session_history.dart';
import 'settings/settings_controller.dart';
import 'ui/zeep_character.dart';

enum Screen { setup, session }

/// Bottom tabs shown outside a session.
enum HomeTab { breathe, exercises, progress }

class AppController extends ChangeNotifier {
  final SettingsController settings;
  final HapticsService haptics;
  final MusicService music;
  final SessionHistory history;
  late final BreathingEngine engine;
  final Animator anim = Animator();

  Screen screen = Screen.setup;
  HomeTab tab = HomeTab.breathe;

  /// Current time. Tests replace it so dates in screenshots are fixed.
  DateTime Function() clock = DateTime.now;

  /// Month and day picked in the Progress tab; kept while the app is open.
  DateTime? progressMonth;
  DateTime? progressDay;
  bool bannerVisible = true;
  DateTime _sessionStart = DateTime.now();
  bool _logged = false;

  /// Streak right after the last finished session (for the finish card).
  int lastStreak = 0;
  double time = 0;
  bool reduceMotion = false;
  bool _wakelock = false;

  AppController({required this.settings, required this.haptics, required this.music, SessionHistory? history})
    : history = history ?? SessionHistory() {
    engine = BreathingEngine(settings.durations, settings.sessionMinutes * 60.0);
    haptics.enabled = settings.vibration;
    settings.addListener(_onSettingsChanged);
  }

  /// When the current / last session started (its history record's time).
  DateTime get sessionStart => _sessionStart;

  bool get finished => screen == Screen.session && engine.state == RunState.finished;

  void startSession() {
    engine.durations = settings.durations;
    engine.sessionLength = settings.sessionMinutes * 60.0;
    final ev = engine.start();
    _sessionStart = clock();
    _logged = false;
    screen = Screen.session;
    _handle(ev);
    notifyListeners();
  }

  void stopSession() {
    if (engine.isActive) _log(completed: false);
    engine.stop();
    screen = Screen.setup;
    notifyListeners();
  }

  void togglePause() {
    switch (engine.state) {
      case RunState.running:
        engine.pause();
      case RunState.paused:
        engine.resume();
      case RunState.finished:
      case RunState.ready:
        startSession();
    }
    notifyListeners();
  }

  /// Called when the app goes to the background.
  void pauseIfRunning() {
    if (engine.state == RunState.running) {
      engine.pause();
      notifyListeners();
    }
  }

  void hideBanner() {
    bannerVisible = false;
    notifyListeners();
  }

  void setTab(HomeTab t) {
    tab = t;
    notifyListeners();
  }

  /// Apply a breathing mode's rhythm and session length.
  void applyExercise(Exercise e, {int? minutes}) {
    settings.update((s) {
      s.inhale = e.durations.inhale.round();
      s.hold = e.durations.hold.round();
      s.exhale = e.durations.exhale.round();
      s.rest = e.durations.rest.round();
      s.sessionMinutes = minutes ?? e.minutes;
    });
  }

  /// "Start breathing" on a mode's screen.
  void startExercise(Exercise e, int minutes) {
    applyExercise(e, minutes: minutes);
    tab = HomeTab.breathe;
    startSession();
  }

  void _log({required bool completed}) {
    if (_logged) return;
    _logged = true;
    final saved = history.add(
      SessionRecord(
        start: _sessionStart,
        seconds: engine.sessionElapsed.round(),
        breaths: engine.breaths,
        exercise: exerciseId(engine.durations),
        completed: completed,
      ),
    );
    lastStreak = history.stats(clock()).currentStreak;
    // a session was just saved: the Progress tab should show it, so the
    // calendar goes back to today. Short sessions are not saved, so a picked
    // day stays.
    if (saved) {
      progressDay = null;
      progressMonth = null;
    }
  }

  /// Saves a Zeep Balance game to the history (counts toward the streak like
  /// a breathing session) and keeps the best score of a finished game.
  /// Returns true if it was saved (games under 30 s are not).
  bool logGame({
    required BalanceLevel level,
    required DateTime start,
    required int seconds,
    required int score,
    required bool completed,
  }) {
    if (completed && score > settings.gameBest[level.index]) {
      settings.update((s) => s.gameBest = [...s.gameBest]..[level.index] = score);
    }
    final saved = history.add(
      SessionRecord(
        start: start,
        seconds: seconds,
        breaths: 0,
        exercise: gameHistoryId(level),
        completed: completed,
        score: score,
      ),
    );
    lastStreak = history.stats(clock()).currentStreak;
    if (saved) {
      progressDay = null;
      progressMonth = null;
    }
    return saved;
  }

  void toggleMusic() => settings.update((s) => s.music = !s.music);

  void toggleVibration() => setVibration(!settings.vibration);

  void setVibration(bool on) {
    settings.update((s) => s.vibration = on);
    haptics.enabled = on;
    if (on) haptics.fire(HapticPattern.confirm, time);
  }

  void _onSettingsChanged() {
    haptics.enabled = settings.vibration;
    if (settings.durations != engine.durations) {
      _handle(engine.setDurations(settings.durations));
    }
    if (!engine.isActive && engine.state != RunState.finished) {
      engine.sessionLength = settings.sessionMinutes * 60.0;
    }
  }

  void _handle(List<EngineEvent> evs) {
    for (final e in evs) {
      if (e is SessionFinished) _log(completed: true);
      if (e is PhaseStarted && engine.state == RunState.running) {
        final pat = switch (e.phase) {
          Phase.inhale => HapticPattern.inhaleStart,
          Phase.hold => HapticPattern.holdStart,
          Phase.exhale => HapticPattern.exhaleStart,
          Phase.rest => null,
        };
        if (pat != null) haptics.fire(pat, time);
      }
    }
  }

  void tick(double dt) {
    dt = dt.clamp(0.0, 0.1);
    time += dt;
    _handle(engine.update(dt));

    final st = (screen == Screen.session && engine.isActive)
        ? switch (engine.phase) {
            Phase.inhale => AnimState.inhale,
            Phase.hold => AnimState.hold,
            Phase.exhale => AnimState.exhale,
            Phase.rest => AnimState.rest,
          }
        : AnimState.idle;
    anim.setState(st);
    anim.update(dt, engine.level, engine.phaseProgress, engine.state == RunState.paused);

    final wantMusic = settings.music && screen == Screen.session && engine.state == RunState.running;
    music.update(dt, wantMusic, settings.track);

    // keep the screen on while a session is active
    final wantWake = screen == Screen.session && engine.isActive;
    if (wantWake != _wakelock) {
      _wakelock = wantWake;
      WakelockPlus.toggle(enable: wantWake).catchError((_) {});
    }

    notifyListeners();
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    music.dispose();
    super.dispose();
  }
}
