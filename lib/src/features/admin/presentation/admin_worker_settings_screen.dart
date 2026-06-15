import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/common_widgets.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';

const List<String> adminWorkerLevels = [
  'Brigader',
  'Master',
  '1 - darajali',
  '2 - darajali',
  '3 - darajali',
];

class AdminWorkerSettingsScreen extends StatefulWidget {
  const AdminWorkerSettingsScreen({super.key});

  @override
  State<AdminWorkerSettingsScreen> createState() =>
      _AdminWorkerSettingsScreenState();
}

class _AdminWorkerSettingsScreenState extends State<AdminWorkerSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedLevel = adminWorkerLevels.first;
  late Future<List<AdminWorker>> _future;
  bool _saving = false;
  bool _openingRoute = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<List<AdminWorker>> _load() {
    return MobileApi.instance.adminWorkers();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _createWorker() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminCreateWorker(
        name: name,
        level: _selectedLevel,
      );
      _nameController.clear();
      _selectedLevel = adminWorkerLevels.first;
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ishchi saqlandi')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _updateLevel(AdminWorker worker, String level) async {
    await MobileApi.instance.adminUpdateWorkerLevel(
      id: worker.id,
      level: level,
    );
    _reload();
  }

  void _openDrawerRoute(String routeName) {
    if (_openingRoute) {
      return;
    }
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    _openingRoute = true;
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.adminWorkerSettings,
        onNavigate: _openDrawerRoute,
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => AppShellDrawerScope.maybeOf(context)?.openDrawer(),
      ),
      title: 'Ishchi sozlamalari',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
      child: AppRefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 116),
          children: [
            SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Ishchi nomi',
                      filled: true,
                    ),
                    onSubmitted: (_) => unawaited(_createWorker()),
                  ),
                  const SizedBox(height: 12),
                  _WorkerLevelPicker(
                    value: _selectedLevel,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _selectedLevel = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _createWorker,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Ishchi qo‘shish'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<AdminWorker>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: AppLoadingIndicator()),
                  );
                }
                final workers = snapshot.data ?? const <AdminWorker>[];
                if (workers.isEmpty) {
                  return const SoftCard(
                    child: Center(child: Text('Ishchi topilmadi')),
                  );
                }
                return Column(
                  children: [
                    for (final worker in workers) ...[
                      _WorkerLevelTile(
                        worker: worker,
                        onLevelChanged: (level) =>
                            unawaited(_updateLevel(worker, level)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerLevelTile extends StatelessWidget {
  const _WorkerLevelTile({
    required this.worker,
    required this.onLevelChanged,
  });

  final AdminWorker worker;
  final ValueChanged<String> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              worker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: _WorkerLevelPicker(
              value: adminWorkerLevels.contains(worker.level)
                  ? worker.level
                  : adminWorkerLevels.last,
              onChanged: (value) {
                if (value == null || value == worker.level) {
                  return;
                }
                onLevelChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerLevelPicker extends StatelessWidget {
  const _WorkerLevelPicker({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Daraja',
        filled: true,
      ),
      items: [
        for (final level in adminWorkerLevels)
          DropdownMenuItem(value: level, child: Text(level)),
      ],
      onChanged: onChanged,
    );
  }
}
