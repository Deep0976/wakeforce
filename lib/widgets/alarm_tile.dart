import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/mission_type.dart';
import '../theme/app_theme.dart';
import 'subject_icon.dart';
import '../utils/day_labels.dart';

/// A wake alarm as a card: mission-coloured tile, mono time, days, mission
/// name in the mission's own colour, and the enable switch.
class AlarmTile extends StatelessWidget {
  final Alarm alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback? onTestRing;

  const AlarmTile({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onTap,
    this.onTestRing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final active = alarm.enabled;
    final accent = alarm.missionType.accentColor(c);

    // A disabled alarm keeps its layout but drops to muted ink, so the list
    // still scans as rows rather than going blank.
    final timeColor = active ? c.textPrimary : c.textMuted;
    final missionColor = active ? accent : c.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gapTight),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: c.cardBorder == null
                  ? null
                  : Border.all(color: c.cardBorder!),
              boxShadow: c.cardShadow,
            ),
            padding: const EdgeInsets.all(AppSpacing.cardTight),
            child: Row(
              children: [
                _MissionTile(
                  missionType: alarm.missionType,
                  color: accent,
                  enabled: active,
                ),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alarm.timeLabel,
                        style: numberStyle(fontSize: 22, color: timeColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        repeatSummary(alarm.repeatDays),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: active ? c.textMuted : c.textFaint,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        alarm.label.isEmpty
                            ? alarm.missionType.label
                            : '${alarm.missionType.label} · ${alarm.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: missionColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTestRing != null)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, size: 20),
                    color: c.textMuted,
                    tooltip: 'Test ring',
                    onPressed: onTestRing,
                  ),
                Switch(value: alarm.enabled, onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rounded colour tile that carries the mission's hue.
class _MissionTile extends StatelessWidget {
  final MissionType missionType;
  final Color color;
  final bool enabled;

  const _MissionTile({
    required this.missionType,
    required this.color,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: enabled ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      alignment: Alignment.center,
      child: missionGlyph(
        missionType,
        size: 20,
        color: color.withValues(alpha: enabled ? 1 : 0.45),
      ),
    );
  }
}
