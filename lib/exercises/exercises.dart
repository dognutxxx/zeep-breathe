// Ready-made breathing exercises. Each one is just a set of durations plus a
// suggested session length, so they all run on the same BreathingEngine.

import 'package:flutter/painting.dart';

import '../breathing/breathing_engine.dart';

class Exercise {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final BreathDurations durations;
  final int minutes;
  final Color tint;

  const Exercise({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.durations,
    required this.minutes,
    required this.tint,
  });

  /// "4 · 2 · 6" (rest is shown only when used).
  String get pattern {
    final d = durations;
    String f(double v) => v.round().toString();
    final parts = [f(d.inhale), if (d.hold > 0) f(d.hold), f(d.exhale), if (d.rest > 0) f(d.rest)];
    return parts.join(' · ');
  }
}

const exercises = <Exercise>[
  Exercise(
    id: 'calm',
    name: 'Calm tide',
    tagline: 'Everyday reset',
    description: 'A longer out-breath than in-breath gently slows you down. Zeep\'s default.',
    durations: BreathDurations(4, 2, 6, 0),
    minutes: 3,
    tint: Color(0xFFBDDEF7),
  ),
  Exercise(
    id: 'box',
    name: 'Box breathing',
    tagline: 'Focus & steady',
    description: 'Four equal sides: in, hold, out, hold. Helps you settle before work or a big moment.',
    durations: BreathDurations(4, 4, 4, 4),
    minutes: 4,
    tint: Color(0xFFCCC7F5),
  ),
  Exercise(
    id: 'sleep',
    name: '4-7-8 Sleep',
    tagline: 'Wind down',
    description: 'A long hold and a slow sigh out. Try it in bed with the screen dimmed.',
    durations: BreathDurations(4, 7, 8, 0),
    minutes: 5,
    tint: Color(0xFFC9D3F2),
  ),
  Exercise(
    id: 'balance',
    name: 'Balance',
    tagline: 'Even & coherent',
    description: 'Equal in and out at about six breaths a minute. Calm but awake.',
    durations: BreathDurations(5, 0, 5, 0),
    minutes: 5,
    tint: Color(0xFFBAE6E0),
  ),
  Exercise(
    id: 'wake',
    name: 'Morning wake',
    tagline: 'Gentle energy',
    description: 'Quick, light breaths with a short pause to brighten up in the morning.',
    durations: BreathDurations(3, 1, 3, 0),
    minutes: 2,
    tint: Color(0xFFF6E3B4),
  ),
];

/// The preset matching these durations, or null for a custom pattern.
Exercise? exerciseFor(BreathDurations d) {
  for (final e in exercises) {
    if (e.durations == d) return e;
  }
  return null;
}

String exerciseName(BreathDurations d) => exerciseFor(d)?.name ?? 'Custom';
