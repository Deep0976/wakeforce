import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  Future<void> _pickThemeMode(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: context.wake.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: settings.themeMode,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen, AppSpacing.card, AppSpacing.screen, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SectionLabel('Appearance'),
                ),
              ),
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  title: Text(
                    switch (mode) {
                      ThemeMode.system => 'System default',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    },
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  value: mode,
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await settings.setThemeMode(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthService>().currentUser;
    final settings = context.watch<SettingsProvider>();
    final themeModeLabel = switch (settings.themeMode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.gap,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: [
            Text('Settings', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.gapWide),

            // Profile
            WakeCard(
              padding: const EdgeInsets.all(AppSpacing.cardTight),
              child: Row(
                children: [
                  _Avatar(
                    photoUrl: user?.photoUrl,
                    displayName: user?.displayName,
                  ),
                  const SizedBox(width: AppSpacing.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.displayName ?? 'WakeForce user',
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapWide),

            SectionLabel('General'),
            _RowGroup(
              rows: [
                _SettingRow(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  onTap: () => _showComingSoon(context, 'Notification settings'),
                ),
                _SettingRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Alarm sound',
                  value: 'Default',
                  onTap: () => _showComingSoon(context, 'Alarm sound'),
                ),
                _SettingRow(
                  icon: Icons.contrast,
                  label: 'Appearance',
                  value: themeModeLabel,
                  onTap: () => _pickThemeMode(context),
                ),
                _SettingRow(
                  icon: Icons.language,
                  label: 'Language',
                  value: 'English',
                  onTap: () => _showComingSoon(context, 'Language'),
                ),
                _SettingRow(
                  icon: Icons.cloud_outlined,
                  label: 'Backup & sync',
                  onTap: () => _showComingSoon(context, 'Backup & sync'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gapWide),

            SectionLabel('Support'),
            _RowGroup(
              rows: [
                _SettingRow(
                  icon: Icons.help_outline,
                  label: 'Help & FAQ',
                  onTap: () => _showComingSoon(context, 'Help & FAQ'),
                ),
                _SettingRow(
                  icon: Icons.ios_share,
                  label: 'Share app',
                  onTap: () => _showComingSoon(context, 'Sharing'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gapWide),

            // Log out reads as a destructive action: tinted fill, red ink.
            _LogOutButton(
              onPressed: () => context.read<AuthService>().signOut(),
            ),
            const SizedBox(height: AppSpacing.gap),
            Center(
              child: Text('WakeForce · v1.0.0', style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;

  const _Avatar({this.photoUrl, this.displayName});

  String get _initials {
    final name = (displayName ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    if (photoUrl != null) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(photoUrl!));
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.personal],
        ),
      ),
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
      ),
    );
  }
}

/// Rows grouped into one card with hairline dividers between them.
class _RowGroup extends StatelessWidget {
  final List<Widget> rows;
  const _RowGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return WakeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Divider(height: 1, thickness: 1, color: c.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinHitTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardTight,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: c.textMuted),
            const SizedBox(width: AppSpacing.gap),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyLarge),
            ),
            if (value != null) ...[
              Text(value!, style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, size: 18, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LogOutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return Material(
      color: danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onPressed,
        child: Container(
          height: kMinHitTarget + 4,
          alignment: Alignment.center,
          child: Text(
            'Log out',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: danger,
                  fontSize: 14,
                ),
          ),
        ),
      ),
    );
  }
}
