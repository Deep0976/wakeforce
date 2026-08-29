import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/focus_dnd_service.dart';
import '../services/shield_provider.dart';
import '../theme/app_theme.dart';

/// Choose which apps Focus covers. Sorted so the ones already shielded sit at
/// the top -- the list is long, and the student's own choices should not be
/// buried alphabetically among two hundred system apps.
class ShieldPickerScreen extends StatefulWidget {
  const ShieldPickerScreen({super.key});

  @override
  State<ShieldPickerScreen> createState() => _ShieldPickerScreenState();
}

class _ShieldPickerScreenState extends State<ShieldPickerScreen> {
  List<InstalledApp>? _apps;
  String _query = '';

  @override
  void initState() {
    super.initState();
    FocusDndService.instance.installedApps().then((list) {
      if (mounted) setState(() => _apps = list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final shield = context.watch<ShieldProvider>();
    final apps = _apps;

    return Scaffold(
      appBar: AppBar(title: const Text('Shield apps')),
      body: apps == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.gapTight,
                    AppSpacing.screen,
                    AppSpacing.gapTight,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search apps',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: Builder(builder: (context) {
                    final visible = apps
                        .where((a) => a.label.toLowerCase().contains(_query))
                        .toList()
                      ..sort((a, b) {
                        final sa = shield.shielded.contains(a.packageName);
                        final sb = shield.shielded.contains(b.packageName);
                        if (sa != sb) return sa ? -1 : 1;
                        return a.label.toLowerCase().compareTo(
                              b.label.toLowerCase(),
                            );
                      });
                    if (visible.isEmpty) {
                      return Center(
                        child: Text('No apps match "$_query"',
                            style: theme.textTheme.bodyMedium),
                      );
                    }
                    return ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final app = visible[i];
                        final on = shield.shielded.contains(app.packageName);
                        return CheckboxListTile(
                          value: on,
                          onChanged: (_) => shield.toggle(app.packageName),
                          title: Text(app.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(app.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall),
                          activeColor: c.accent,
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    );
                  }),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    child: Text(
                      '${shield.count} app${shield.count == 1 ? '' : 's'} shielded',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
