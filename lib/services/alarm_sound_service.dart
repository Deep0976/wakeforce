import 'package:audioplayers/audioplayers.dart';

/// Plays a looping alarm tone at full volume from the first frame -- a real
/// alarm has to feel urgent immediately, not build up to it.
class AlarmSoundService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> start({String asset = 'sounds/alarm_default.wav'}) async {
    // Without this, playback defaults to the media/music stream (silenced by
    // a low media volume) and can be suspended once the screen locks --
    // neither of which an alarm can afford.
    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
          stayAwake: true,
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(AssetSource(asset));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
