// Haptic feedback layer. Port of `app/src/haptics.rs`.
//
// Patterns are played natively: iOS Core Haptics (ios/Runner/AppDelegate.swift)
// and Android VibrationEffect (MainActivity.kt) via the `zeep/haptics`
// MethodChannel. If the device has no haptic engine the native side falls back
// to a simple impact, and the app also shows the pulses on screen.

import 'package:flutter/services.dart';

enum HapticPattern {
  inhaleStart,
  holdStart,
  exhaleStart,
  confirm,

  /// Zeep Balance: Zeep left the circle (one soft pulse).
  edgeOut,

  /// Zeep Balance: Zeep is back in the circle (a very short tick).
  edgeIn,

  /// Card L: a flower bloomed (two soft pulses, the second stronger).
  bloom,
}

class Pulse {
  final double at, dur, intensity, sharpness;
  const Pulse(this.at, this.dur, this.intensity, this.sharpness);
}

extension HapticPatternInfo on HapticPattern {
  List<Pulse> get pulses => switch (this) {
    HapticPattern.inhaleStart => const [Pulse(0, 0.09, 0.45, 0.2)],
    HapticPattern.holdStart => const [Pulse(0, 0.04, 0.6, 0.5), Pulse(0.14, 0.04, 0.6, 0.5)],
    HapticPattern.exhaleStart => const [Pulse(0, 0.12, 0.35, 0.1)],
    HapticPattern.confirm => const [Pulse(0, 0.03, 0.4, 0.6)],
    HapticPattern.edgeOut => const [Pulse(0, 0.07, 0.4, 0.15)],
    HapticPattern.edgeIn => const [Pulse(0, 0.015, 0.3, 0.7)],
    HapticPattern.bloom => const [Pulse(0, 0.06, 0.35, 0.2), Pulse(0.16, 0.11, 0.5, 0.25)],
  };

  String get label => switch (this) {
    HapticPattern.inhaleStart => 'inhale pulse',
    HapticPattern.holdStart => 'hold · double pulse',
    HapticPattern.exhaleStart => 'exhale pulse',
    HapticPattern.confirm => 'vibration on',
    HapticPattern.edgeOut => 'left the circle',
    HapticPattern.edgeIn => 'back in the circle',
    HapticPattern.bloom => 'bloom',
  };

  /// Name understood by the native side.
  String get channelName => switch (this) {
    HapticPattern.inhaleStart => 'inhale',
    HapticPattern.holdStart => 'hold',
    HapticPattern.exhaleStart => 'exhale',
    HapticPattern.confirm => 'confirm',
    HapticPattern.edgeOut => 'edgeOut',
    HapticPattern.edgeIn => 'edgeIn',
    HapticPattern.bloom => 'bloom',
  };
}

class HapticEvent {
  final double time;
  final HapticPattern pattern;
  const HapticEvent(this.time, this.pattern);
}

class HapticsService {
  static const _ch = MethodChannel('zeep/haptics');

  bool enabled;
  bool nativeSupported = false;
  final List<HapticEvent> events = [];
  double _lastFire = -10;

  HapticsService({this.enabled = true});

  Future<void> init() async {
    try {
      nativeSupported = await _ch.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      nativeSupported = false;
    }
  }

  /// Fire a pattern at a phase transition. Only discrete events are played -
  /// never continuous vibration. A 250 ms guard stops bursts when durations
  /// are changed rapidly.
  bool fire(HapticPattern p, double now) {
    if (!enabled || now - _lastFire < 0.25) return false;
    _play(p);
    events.add(HapticEvent(now, p));
    events.removeWhere((e) => now - e.time >= 3);
    _lastFire = now;
    return true;
  }

  Future<void> _play(HapticPattern p) async {
    try {
      await _ch.invokeMethod('play', p.channelName);
    } catch (_) {
      // no native channel (tests / unsupported platform): system fallback
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  HapticEvent? get last => events.isEmpty ? null : events.last;

  /// Ages (seconds) of recent pulses, for the on-screen ripples.
  List<double> ripples(double now) {
    final out = <double>[];
    for (final e in events) {
      for (final pulse in e.pattern.pulses) {
        final age = now - e.time - pulse.at;
        if (age >= 0 && age < 0.7) out.add(age);
      }
    }
    return out;
  }
}
