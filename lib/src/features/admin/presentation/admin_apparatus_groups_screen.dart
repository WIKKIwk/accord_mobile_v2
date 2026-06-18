import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';

const double _apparatusGroupsPanelGap = 4;
const double _apparatusGroupsPanelTopGap = 8;

InputDecoration _apparatusGroupFieldDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder outline({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color ?? scheme.outlineVariant, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: scheme.surface,
    border: outline(),
    enabledBorder: outline(),
    focusedBorder: outline(color: scheme.primary, width: 1.2),
    errorBorder: outline(color: scheme.error),
    focusedErrorBorder: outline(color: scheme.error, width: 1.2),
  );
}

class AdminApparatusGroupsScreen extends StatefulWidget {
  const AdminApparatusGroupsScreen({
    super.key,
    this.focusApparatusName = false,
    this.createOnly = false,
  });

  final bool focusApparatusName;
  final bool createOnly;

  @override
  State<AdminApparatusGroupsScreen> createState() =>
      _AdminApparatusGroupsScreenState();
}

class _AdminApparatusGroupsScreenState
    extends State<AdminApparatusGroupsScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _apparatusName = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _apparatusNameFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<AdminWarehouse> _apparatus = const [];
  List<AdminApparatusGroup> _groups = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  bool _creatingApparatus = false;
  String? _loadError;
  String? _editingGroupName;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.focusApparatusName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apparatusNameFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _apparatusName.dispose();
    _nameFocus.dispose();
    _apparatusNameFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminApparatusGroups(),
        MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = results[0] as List<AdminApparatusGroup>;
        _apparatus = results[1] as List<AdminWarehouse>;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = 'Aparat guruhlari yuklanmadi';
      });
    }
  }

  void _editGroup(AdminApparatusGroup group) {
    setState(() {
      _editingGroupName = group.name;
      _name.text = group.name;
      _selected
        ..clear()
        ..addAll(_matchedApparatusNames(group.apparatus));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      _nameFocus.requestFocus();
    });
  }

  Iterable<String> _matchedApparatusNames(List<String> groupApparatus) sync* {
    for (final apparatusName in groupApparatus) {
      final normalized = apparatusName.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      for (final item in _apparatus) {
        if (item.warehouse.trim().toLowerCase() == normalized) {
          yield item.warehouse;
          break;
        }
      }
    }
  }

  void _clearEditor() {
    setState(() {
      _editingGroupName = null;
      _name.clear();
      _selected.clear();
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _selected.isEmpty || _saving) {
      showAdminTopNotice(context, 'Guruh nomi va aparatlar kerak');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await MobileApi.instance.adminSaveApparatusGroup(
        AdminApparatusGroup(
          name: name,
          apparatus: _selected.toList(growable: false),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final key = saved.name.toLowerCase();
        final next = [
          for (final group in _groups)
            if (group.name.toLowerCase() != key) group,
          saved,
        ]..sort((left, right) => left.name.compareTo(right.name));
        _groups = next;
        _clearEditor();
      });
      showAdminTopNotice(context, 'Aparat guruhi saqlandi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Aparat guruhi saqlanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createApparatus() async {
    final name = _apparatusName.text.trim();
    if (name.isEmpty || _creatingApparatus) {
      showAdminTopNotice(context, 'Aparat nomi kerak');
      return;
    }
    setState(() => _creatingApparatus = true);
    try {
      final created = await MobileApi.instance.adminCreateApparatus(name);
      if (!mounted) {
        return;
      }
      setState(() {
        final key = created.warehouse.toLowerCase();
        final next = [
          for (final item in _apparatus)
            if (item.warehouse.toLowerCase() != key) item,
          created,
        ]..sort(
            (left, right) => left.warehouse.toLowerCase().compareTo(
                  right.warehouse.toLowerCase(),
                ),
          );
        _apparatus = next;
        _selected.add(created.warehouse);
        _apparatusName.clear();
      });
      showAdminTopNotice(context, 'Aparat qo\'shildi');
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Aparat qo\'shilmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _creatingApparatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AppShell(
      title: widget.createOnly ? 'Aparat qo\'shish' : 'Aparat guruhlari',
      subtitle: '',
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: widget.createOnly
            ? AppRoutes.adminApparatusCreate
            : AppRoutes.adminApparatusGroups,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _loadError != null
                ? AppRetryState(
                    onRetry: () async {
                      setState(() {
                        _loading = true;
                        _loadError = null;
                      });
                      await _load();
                    },
                  )
                : ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      _apparatusGroupsPanelGap,
                      _apparatusGroupsPanelTopGap,
                      _apparatusGroupsPanelGap,
                      bottomPadding,
                    ),
                    children: [
                      if (!widget.createOnly) ...[
                        if (_editingGroupName != null) ...[
                          Material(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tahrirlanmoqda: $_editingGroupName',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: scheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _clearEditor,
                                    child: const Text('Bekor qilish'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          decoration: _apparatusGroupFieldDecoration(
                            context,
                            labelText: 'Guruh nomi',
                            hintText: 'pechat',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _apparatusName,
                        focusNode: _apparatusNameFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createApparatus(),
                        decoration: _apparatusGroupFieldDecoration(
                          context,
                          labelText: 'Aparat nomi',
                          hintText: 'Bobst 1',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _creatingApparatus ? null : _createApparatus,
                        icon: const Icon(Icons.precision_manufacturing_outlined),
                        label: Text(
                          _creatingApparatus
                              ? 'Qo\'shilmoqda...'
                              : 'Aparat qo\'shish',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.createOnly)
                        for (final item in _apparatus)
                          ListTile(
                            title: Text(item.warehouse),
                            dense: true,
                            leading: const Icon(
                              Icons.precision_manufacturing_outlined,
                            ),
                          )
                      else ...[
                        for (final item in _apparatus)
                          CheckboxListTile(
                            value: _selected.contains(item.warehouse),
                            title: Text(item.warehouse),
                            dense: true,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(item.warehouse);
                                } else {
                                  _selected.remove(item.warehouse);
                                }
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
                        ),
                        const SizedBox(height: 20),
                        for (final group in _groups) ...[
                          _ApparatusGroupEditTile(
                            group: group,
                            editing: _editingGroupName?.trim().toLowerCase() ==
                                group.name.trim().toLowerCase(),
                            onEdit: () => _editGroup(group),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _ApparatusGroupEditTile extends StatelessWidget {
  const _ApparatusGroupEditTile({
    required this.group,
    required this.editing,
    required this.onEdit,
  });

  final AdminApparatusGroup group;
  final bool editing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: editing ? scheme.secondaryContainer.withValues(alpha: 0.45) : scheme.surface,
      elevation: editing ? 0 : 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.apparatus.length} ta aparat',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tahrirlash',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
