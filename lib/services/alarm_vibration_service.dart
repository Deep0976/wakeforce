import 'package:vibration/vibration.dart';

/// Vibrates in a repeating pulse while the alarm rings, alongside the sound.
class AlarmVibrationService {
  // More "on" than "off" per cycle so it reads as closer to continuous
  // rather than a pulse with a noticeable gap.
  static const _pattern = [0, 1000, 200];
  static const _maxAmplitude = 255;

  Future<void> start() async {
    if (!(await Vibration.hasVibrator())) return;
    final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
    await Vibration.vibrate(
      pattern: _pattern,
      repeat: 0,
      amplitude: hasAmplitudeControl ? _maxAmplitude : -1,
    );
  }

  Future<void> stop() async {
    await Vibration.cancel();
  }
}
