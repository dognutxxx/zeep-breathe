// Background music. The desktop prototype synthesised its ambience live
// (`app/src/audio.rs`); the mobile build plays seamless loops rendered from the
// same synth (tool/render_audio.py) with just_audio, fading in and out.
// iOS audio session category is "ambient": mixes with other apps and respects
// the silent switch.

import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

const _trackAssets = ['assets/audio/rain.wav', 'assets/audio/ocean.wav', 'assets/audio/hum.wav'];

class MusicService {
  AudioPlayer? _player;
  int _loadedTrack = -1;
  bool _loading = false;
  double _vol = 0;
  double _sentVol = -1;
  bool available = true;

  bool get isAudible => _vol > 0.02;

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      _player = AudioPlayer();
      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(0);
    } catch (_) {
      available = false;
    }
  }

  /// Call every frame. Fades towards playing / silent.
  void update(double dt, bool want, int track) {
    final p = _player;
    if (p == null || !available) return;
    if (want && track != _loadedTrack && !_loading) {
      _load(p, track);
    }
    final target = want ? 0.6 : 0.0;
    _vol += (target - _vol) * (1 - math.exp(-dt * 2.5));
    if ((_vol - _sentVol).abs() > 0.01 || (_vol < 0.005 && _sentVol != 0)) {
      _sentVol = _vol < 0.005 ? 0 : _vol;
      p.setVolume(_sentVol);
    }
    if (want && !p.playing && _loadedTrack == track && !_loading) {
      p.play();
    } else if (!want && p.playing && _vol < 0.005) {
      p.pause();
    }
  }

  Future<void> _load(AudioPlayer p, int track) async {
    _loading = true;
    try {
      await p.setAsset(_trackAssets[track]);
      _loadedTrack = track;
    } catch (_) {
      available = false;
    } finally {
      _loading = false;
    }
  }

  void dispose() => _player?.dispose();
}
