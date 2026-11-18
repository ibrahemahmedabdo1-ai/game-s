import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Wraps sound, music and haptics. All calls are safe no-ops on failure so
/// audio problems never crash gameplay.
class AudioManager {
  AudioManager({this.sound = true, this.music = true, this.haptics = true});
  bool sound, music, haptics;

  static const _base = 'packages/shared_audio/assets/sounds/';
  AudioPlayer? _sfx;
  AudioPlayer? _bgm;
  bool _bgmStarted = false;

  /// With [silent] true no platform players are created (used by tests).
  Future<void> init({bool silent = false}) async {
    if (silent) return;
    try {
      _sfx = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      _bgm = AudioPlayer();
      _sfx!.audioCache = AudioCache(prefix: '');
      _bgm!.audioCache = AudioCache(prefix: '');
      await _bgm!.setReleaseMode(ReleaseMode.loop);
      await _bgm!.setVolume(0.35);
    } catch (_) {}
  }

  Future<void> play(String name) async {
    if (!sound || _sfx == null) return;
    try {
      await _sfx!.stop();
      await _sfx!.play(AssetSource('$_base$name.wav'));
    } catch (_) {}
  }

  Future<void> syncMusic() async {
    if (_bgm == null) return;
    try {
      if (music && !_bgmStarted) {
        _bgmStarted = true;
        await _bgm!.play(AssetSource('${_base}music.wav'));
      } else if (!music && _bgmStarted) {
        _bgmStarted = false;
        await _bgm!.stop();
      }
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try {
      if (_bgmStarted) await _bgm?.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    try {
      if (music && _bgmStarted) await _bgm?.resume();
    } catch (_) {}
  }

  void tap() {
    if (haptics) HapticFeedback.selectionClick();
  }

  void buzz() {
    if (haptics) HapticFeedback.mediumImpact();
  }

  Future<void> dispose() async {
    try {
      await _sfx?.dispose();
      await _bgm?.dispose();
    } catch (_) {}
    _sfx = null;
    _bgm = null;
    _bgmStarted = false;
  }
}
