import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/focus_session.dart';
import '../models/routine_block.dart';
import '../services/focus_dnd_service.dart';
import '../services/shield_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';
import 'focus_running_screen.dart';
import 'shield_picker_screen.dart';

/// Design 4i -- "What are you sitting down for?", then the guard state you
/// are committing to before the session starts.
class FocusSetupScreen extends StatefulWidget {
  final String? initialSubject;

  /// Set when Focus was entered from a routine block, so the running screen
  /// can show "ROUTINE BLOCK · 08:00 – 10:00" and stay block-aware.
  final RoutineBlock? block;

  const FocusSetupScreen({super.key, this.initialSubject, this.block});

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen>
    with WidgetsBindingObserver {
  static const _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Revision'];

  late String _subject;
  FocusMode _mode = FocusMode.goal;
  int _goalMinutes = 90;

  bool _dndGranted = false;
  bool _usageGranted = false;
  bool _overlayGranted = false;

  /// Read from the OS, never set by us -- airplane mode has no API.
  bool _airplane = false;

  /// Granted != wanted. Rebuilding 4i collapsed the two together, so once the
  /// permission existed the guard could never be switched back off. These are
  /// the student's choice for this session.
  bool _dndOn = true;
  bool _shieldOn = true;

  @override
  void initState() {
    super.initState();
    final incoming = widget.initialSubject?.trim();
    _subject =
        (incoming == null || incoming.isEmpty) ? _subjects.first : incoming;
    final block = widget.block;
    if (block != null && block.durationMinutes > 0) {
      _goalMinutes = block.durationMinutes;
    }
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Every one of these is granted on an OS screen in another app, so the
    // only reliable moment to re-read them is coming back to the foreground.
    // didChangeDependencies does NOT fire on resume -- relying on it left the
    // rows stuck on "ALLOW" after the student had already granted them,
    // which read as the whole feature being broken.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final dnd = await FocusDndService.instance.isGranted();
    final usage = await FocusDndService.instance.hasUsageAccess();
    final overlay = await FocusDndService.instance.hasOverlay();
    final airplane = await FocusDndService.instance.isAirplaneOn();
    if (!mounted) return;
    setState(() {
      _dndGranted = dnd;
      _usageGranted = usage;
      _overlayGranted = overlay;
      _airplane = airplane;
    });
  }


  bool get _shieldReady => _usageGranted && _overlayGranted;

  /// The shield needs two separate grants on two separate OS screens, so ask
  /// for whichever is still missing rather than sending them to both.
  Future<void> _askShield() async {
    if (!_usageGranted) {
      await FocusDndService.instance.requestUsageAccess();
    } else if (!_overlayGranted) {
      await FocusDndService.instance.requestOverlay();
    }
  }

  Future<void> _askDnd() async {
    await FocusDndService.instance.requestPermission();
    await _refreshPermissions();
  }


  void _start() {
    final shield = context.read<ShieldProvider>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FocusRunningScreen(
          subject: _subject,
          mode: _mode,
          goalMinutes: _mode == FocusMode.goal ? _goalMinutes : 0,
          block: widget.block,
          silence: _dndGranted && _dndOn,
          shieldPackages: (_shieldReady && _shieldOn)
              ? shield.shielded.toList()
              : const <String>[],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final shield = context.watch<ShieldProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.gap,
                  AppSpacing.screen,
                  AppSpacing.gap,
                ),
                children: [
                  Text('FOCUS SESSION', style: sectionLabelStyle(c.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    'What are you sitting down for?',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final s in _subjects)
                        _Chip(
                          label: s,
                          selected: _subject == s,
                          onTap: () => setState(() => _subject = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gapWide),

                  // --- Mode ---
                  WakeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MODE', style: sectionLabelStyle(c.textMuted)),
                        const SizedBox(height: AppSpacing.gapTight),
                        // No CrossAxisAlignment.stretch here: inside a
                        // ListView the height is unbounded, so stretch asks
                        // the cards to fill infinity and takes the whole
                        // scroll view down with it. The cards even themselves
                        // up via their own minHeight instead.
                        Row(
                          children: [
                            Expanded(
                              child: _ModeCard(
                                title: 'Goal',
                                subtitle: '$_goalMinutes min, 5 min breaks',
                                selected: _mode == FocusMode.goal,
                                onTap: () =>
                                    setState(() => _mode = FocusMode.goal),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _ModeCard(
                                title: 'Open',
                                subtitle: 'Count up, stop when done',
                                selected: _mode == FocusMode.open,
                                onTap: () =>
                                    setState(() => _mode = FocusMode.open),
                              ),
                            ),
                          ],
                        ),
                        if (_mode == FocusMode.goal) ...[
                          const SizedBox(height: AppSpacing.gapTight),
                          // One horizontal line, as designed. Expanded rather
                          // than intrinsic widths: the four chips divide
                          // whatever width there is, so they can never
                          // overflow the card on a narrow screen.
                          Row(
                            children: [
                              for (final m in const [25, 50, 90, 120]) ...[
                                Expanded(
                                  child: _Chip(
                                    label: '${m}m',
                                    selected: _goalMinutes == m,
                                    compact: true,
                                    onTap: () =>
                                        setState(() => _goalMinutes = m),
                                  ),
                                ),
                                if (m != 120) const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapWide),

                  // --- Distraction guard ---
                  WakeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISTRACTION GUARD',
                            style: sectionLabelStyle(c.textMuted)),
                        const SizedBox(height: AppSpacing.gapTight),
                        _GuardRow(
                          label: 'Do Not Disturb',
                          granted: _dndGranted,
                          on: _dndOn,
                          onToggle: () => setState(() => _dndOn = !_dndOn),
                          onAllow: _askDnd,
                        ),
                        Divider(height: AppSpacing.gap, color: c.divider),
                        _GuardRow(
                          label: _shieldReady
                              ? 'Shield ${shield.count} apps'
                              : 'Shield apps',
                          granted: _shieldReady,
                          on: _shieldOn,
                          onToggle: () => setState(() => _shieldOn = !_shieldOn),
                          onAllow: _askShield,
                          onEdit: _shieldReady
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ShieldPickerScreen(),
                                    ),
                                  )
                              : null,
                        ),
                        Divider(height: AppSpacing.gap, color: c.divider),
                        _GuardRow(
                          label: 'Airplane mode',
                          // Nothing to grant and nothing we can set: this row
                          // only ever reports what the OS says.
                          granted: true,
                          on: _airplane,
                          onToggle: FocusDndService.instance.openAirplaneSettings,
                          onAllow: FocusDndService.instance.openAirplaneSettings,
                          offLabel: 'ASK ME',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _shieldReady
                          ? 'Shielded apps are covered until the session ends. '
                              'A repeat call from the same number still rings, '
                              'so an emergency gets through.'
                          : 'Shielding needs usage access and permission to '
                              'draw over other apps. Without them Focus still '
                              'silences the phone, but cannot cover apps.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.gapTight,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _start,
                  child: const Text('Start Focus'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A guard line: a square on/off box, the label, and a right-hand action.
///
/// The box is the switch and the right-hand text is the action, because they
/// are genuinely two different things: whether the student wants this guard
/// for this session, and whether the OS has let us have it at all.
class _GuardRow extends StatelessWidget {
  final String label;

  /// Whether the OS permission exists. Without it the row can only ask.
  final bool granted;

  /// Whether the student wants this guard on for this session.
  final bool on;

  final VoidCallback onToggle;
  final VoidCallback onAllow;
  final VoidCallback? onEdit;

  /// What the action reads when the guard is off. "OFF" for guards we drive,
  /// "ASK ME" for airplane mode, which the student has to set themselves.
  final String offLabel;

  const _GuardRow({
    required this.label,
    required this.granted,
    required this.on,
    required this.onToggle,
    required this.onAllow,
    this.onEdit,
    this.offLabel = 'OFF',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final active = granted && on;

    final String action;
    final Color actionColor;
    if (!granted) {
      action = 'ALLOW';
      actionColor = c.accentInk;
    } else if (on) {
      action = 'ON';
      actionColor = c.done;
    } else {
      action = offLabel;
      actionColor = c.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // The box toggles; it never asks for permission. Tapping a switch
          // should not launch you into Settings.
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: granted ? onToggle : onAllow,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: active ? c.done : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active
                        ? c.done
                        : (granted ? c.textFaint : c.accent),
                    width: 1.6,
                  ),
                ),
                child: active
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: granted ? onToggle : onAllow,
              behavior: HitTestBehavior.opaque,
              child: Text(label, style: theme.textTheme.titleMedium),
            ),
          ),
          if (onEdit != null) ...[
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text('EDIT', style: sectionLabelStyle(c.accentInk)),
            ),
            const SizedBox(width: 2),
          ],
          GestureDetector(
            onTap: granted ? onToggle : onAllow,
            behavior: HitTestBehavior.opaque,
            child: Text(action, style: sectionLabelStyle(actionColor)),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(AppSpacing.cardTight),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.12) : c.bg,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: selected ? c.accent : c.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: selected ? c.accentInk : c.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Tighter side padding for chips that sit in a divided row and have to
  /// share the width rather than size to their own text.
  final bool compact;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.14) : c.card,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected ? c.accent : c.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? c.accentInk : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}
