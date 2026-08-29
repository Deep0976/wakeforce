import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one card treatment in the app. Light gets a soft shadow and no
/// border, dark gets a hairline border and no shadow -- never both, and
/// never a card inside a card, per the single-elevation rule.
class WakeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Tints the card with a colour (the streak card uses the accent), while
  /// keeping the same radius and elevation.
  final Color? tint;

  const WakeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final radius = BorderRadius.circular(AppRadius.card);
    final decoration = BoxDecoration(
      color: tint == null
          ? c.card
          : Color.alphaBlend(tint!.withValues(alpha: 0.10), c.card),
      borderRadius: radius,
      border: c.cardBorder == null ? null : Border.all(color: c.cardBorder!),
      boxShadow: c.cardShadow,
    );

    if (onTap == null) {
      return Container(
        decoration: decoration,
        padding: padding,
        child: child,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: decoration,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Uppercase mono label that sits above a card or section.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final label = Text(text.toUpperCase(), style: sectionLabelStyle(c.textMuted));
    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: label,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      // Both sides flex: a long section label beside a long trailing note
      // (e.g. "+1h 20m vs last week") overflowed the card.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: label),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: trailing!),
        ],
      ),
    );
  }
}
