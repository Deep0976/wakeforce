import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'alarms_screen.dart';
import 'focus_setup_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav shell shown once the user is signed in. Tabs stay alive via
/// IndexedStack so switching doesn't lose scroll position or re-trigger
/// provider loads.
///
/// Five slots, with Focus raised at the centre: it is a *mode you enter*
/// rather than a page you browse, so it pushes full-screen instead of
/// swapping the body.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    AlarmsScreen(),
    SizedBox.shrink(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  void _openFocus() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FocusSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.divider)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavSlot(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavSlot(
                  icon: Icons.alarm_outlined,
                  activeIcon: Icons.alarm,
                  label: 'Alarms',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _FocusSlot(onTap: _openFocus),
                _NavSlot(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Progress',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _NavSlot(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavSlot({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final colour = selected ? c.accentInk : c.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 22, color: colour),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: colour,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The centre slot: an orange ring lifted above the bar, per the spec's
/// "centre raised 18px above the bar".
class _FocusSlot extends StatelessWidget {
  final VoidCallback onTap;

  const _FocusSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.16),
                  border: Border.all(color: c.accent, width: 2),
                ),
                child: Icon(Icons.circle_outlined, size: 20, color: c.accent),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: Text(
                'Focus',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.accentInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
