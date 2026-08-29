import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/alarm.dart';
import '../models/mission_type.dart';
import '../services/alarm_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/day_labels.dart';
import '../widgets/subject_icon.dart';
import '../widgets/time_wheel.dart';
import '../widgets/wake_card.dart';

class EditAlarmScreen extends StatefulWidget {
  final Alarm? alarm;

  const EditAlarmScreen({super.key, this.alarm});

  bool get isEditing => alarm != null;

  @override
  State<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends State<EditAlarmScreen> {
  late TimeOfDay _time;
  late Set<int> _repeatDays;
  late MissionType _missionType;
  late MissionDifficulty _difficulty;
  late TextEditingController _labelController;
  String? _referencePhotoPath;
  final _picker = ImagePicker();
  bool _pickingReferencePhoto = false;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    _time = alarm == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    _repeatDays = {...(alarm?.repeatDays ?? {})};
    _missionType = alarm?.missionType ?? MissionType.math;
    _difficulty = alarm?.difficulty ?? MissionDifficulty.easy;
    _labelController = TextEditingController(text: alarm?.label ?? '');
    _referencePhotoPath = alarm?.referencePhotoPath;
  }

  Future<void> _pickReferencePhoto(ImageSource source) async {
    setState(() => _pickingReferencePhoto = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final docsDir = await getApplicationDocumentsDirectory();
      final refDir = Directory('${docsDir.path}/reference_photos');
      if (!await refDir.exists()) await refDir.create(recursive: true);
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(picked.path).copy('${refDir.path}/$filename');
      if (!mounted) return;
      setState(() => _referencePhotoPath = saved.path);
    } finally {
      if (mounted) setState(() => _pickingReferencePhoto = false);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _onWheelChanged(int minutesSinceMidnight) {
    setState(() => _time = TimeOfDay(
          hour: minutesSinceMidnight ~/ 60,
          minute: minutesSinceMidnight % 60,
        ));
  }

  void _toggleDay(int day) {
    setState(() {
      if (_repeatDays.contains(day)) {
        _repeatDays.remove(day);
      } else {
        _repeatDays.add(day);
      }
    });
  }

  Future<void> _save() async {
    if (_missionType == MissionType.photo && _referencePhotoPath == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Add a reference photo of your notes for the Photo Mission first'),
        ),
      );
      return;
    }

    final provider = context.read<AlarmProvider>();
    final alarm = Alarm(
      id: widget.alarm?.id ?? '',
      hour: _time.hour,
      minute: _time.minute,
      repeatDays: _repeatDays,
      missionType: _missionType,
      difficulty: _difficulty,
      label: _labelController.text.trim(),
      enabled: widget.alarm?.enabled ?? true,
      referencePhotoPath:
          _missionType == MissionType.photo ? _referencePhotoPath : null,
    );

    final exact = widget.isEditing
        ? await provider.updateAlarm(alarm)
        : await provider.addAlarm(alarm);

    // Tracks which mission type/difficulty students choose at setup time,
    // independent of whether the alarm ever actually fires or gets
    // completed -- mission_completed alone only reflects finished missions.
    await FirebaseAnalytics.instance.logEvent(
      name: 'alarm_saved',
      parameters: {
        'mission_type': _missionType.name,
        'difficulty': _difficulty.name,
        'is_new': (!widget.isEditing).toString(),
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!exact) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: const Text(
            'Alarm saved, but exact timing needs a permission that isn\'t granted yet — it may fire a few minutes late.',
          ),
          action: SnackBarAction(
            label: 'Fix it',
            onPressed: () => NotificationService.instance.requestExactPermission(),
          ),
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (widget.alarm == null) return;
    await context.read<AlarmProvider>().deleteAlarm(widget.alarm!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.wake;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit alarm' : 'New alarm'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.gap,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        children: [
          WakeCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TimeWheel(
                  initialMinutes: _time.hour * 60 + _time.minute,
                  onChanged: _onWheelChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gapWide),
          Text('Repeat', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.gapTight),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = _repeatDays.contains(day);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _DayPill(
                    label: weekdayShortLabels[i],
                    selected: selected,
                    onTap: () => _toggleDay(day),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.gapWide),
          TextField(
            controller: _labelController,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Label — optional',
            ),
          ),
          const SizedBox(height: 24),
          Text('Mission', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.gapTight),
          // 2x2 grid so difficulty and Save stay on screen without scrolling
          // past the picker.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.gapTight,
            mainAxisSpacing: AppSpacing.gapTight,
            childAspectRatio: 2.5,
            children: kSelectableMissions.map((type) {
              final selected = _missionType == type;
              final accent = type.accentColor(c);
              return Material(
                color: selected ? accent.withValues(alpha: 0.12) : c.card,
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  onTap: () => setState(() => _missionType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(
                        color: selected ? accent : c.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                          ),
                          child: missionGlyph(type, size: 16, color: accent),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            type.shortLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_missionType.description, style: theme.textTheme.bodySmall),
          if (_missionType == MissionType.photo) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'At wake-up you\'ll retake this photo — it must match to stop the alarm',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_referencePhotoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_referencePhotoPath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.image_outlined,
                    size: 40, color: theme.colorScheme.outline),
              ),
            const SizedBox(height: 8),
            // Camera-only: the wake-time confirmation is always a fresh
            // camera shot, so the reference must go through the same
            // capture pipeline (resolution/compression/lighting behavior) --
            // a gallery photo (different crop, edited, screenshotted, taken
            // another day) matches a live retake far less reliably.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickingReferencePhoto
                    ? null
                    : () => _pickReferencePhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
          ],
          if (_missionType != MissionType.photo) ...[
            const SizedBox(height: 16),
            Text('Difficulty', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<MissionDifficulty>(
              segments: const [
                ButtonSegment(
                    value: MissionDifficulty.easy, label: Text('Easy')),
                ButtonSegment(
                    value: MissionDifficulty.medium, label: Text('Medium')),
                ButtonSegment(
                    value: MissionDifficulty.hard, label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (value) =>
                  setState(() => _difficulty = value.first),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Save Alarm'),
          ),
        ],
      ),
    );
  }
}

/// One circular weekday toggle. Circular rather than a chip so the seven of
/// them fit the screen width without wrapping.
class _DayPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: Container(
        // No fixed width: seven 38px pills need 266px, which does not fit
        // inside the card on a 320dp screen. They divide the row instead.
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? c.accent.withValues(alpha: 0.16) : c.card,
          border: Border.all(color: selected ? c.accent : c.divider),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? c.accentInk : c.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
        ),
      ),
    );
  }
}
