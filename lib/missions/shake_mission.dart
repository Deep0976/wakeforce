import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/alarm.dart';

class ShakeMission extends StatefulWidget {
  final MissionDifficulty difficulty;
  final VoidCallback onComplete;

  const ShakeMission({
    super.key,
    required this.difficulty,
    required this.onComplete,
  });

  @override
  State<ShakeMission> createState() => _ShakeMissionState();
}

class _ShakeMissionState extends State<ShakeMission> {
  // UserAccelerometerEvent already has gravity filtered out by the platform,
  // so this only needs to clear actual shake motion -- unlike the raw
  // accelerometer (which includes ~9.8 m/s^2 of gravity at rest and made the
  // old threshold unreliable across device orientations).
  static const _shakeThreshold = 10.0;
  static const _cooldown = Duration(milliseconds: 300);

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  int _shakeCount = 0;
  late int _targetShakes;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _targetShakes = switch (widget.difficulty) {
      MissionDifficulty.easy => 12,
      MissionDifficulty.medium => 25,
      MissionDifficulty.hard => 45,
      MissionDifficulty.advanced => 60,
    };
    _subscription =
        userAccelerometerEventStream().listen(_handleAccelerometerEvent);
  }

  void _handleAccelerometerEvent(UserAccelerometerEvent event) {
    if (_completed) return;
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();
    if (magnitude > _shakeThreshold &&
        now.difference(_lastShake) > _cooldown) {
      _lastShake = now;
      setState(() => _shakeCount++);
      if (_shakeCount >= _targetShakes) {
        _completed = true;
        widget.onComplete();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final progress = (_shakeCount / _targetShakes).clamp(0.0, 1.0);
    // Theme colours, not white: the mission screen follows the app theme, so
    // hardcoded white was invisible against the light background.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.vibration, size: 64, color: c.personal),
        const SizedBox(height: 16),
        Text(
          'Shake your phone!',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 16,
              backgroundColor: c.divider,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_shakeCount / $_targetShakes',
          style: numberStyle(fontSize: 16, color: c.textSecondary),
        ),
      ],
    );
  }
}
