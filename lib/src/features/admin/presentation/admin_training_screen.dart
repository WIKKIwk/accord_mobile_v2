import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminTrainingScreen extends StatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  State<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends State<AdminTrainingScreen> {
  List<AdminApparatus> _apparatus = const [];
  bool _loading = true;
  String? _error;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final apparatus = await MobileApi.instance.adminApparatus(limit: 10000);
      if (!mounted) {
        return;
      }
      setState(() {
        _apparatus = [
          ...apparatus,
        ]..sort(
            (left, right) => left.name.toLowerCase().compareTo(
                  right.name.toLowerCase(),
                ),
          );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Aparatlar yuklanmadi';
      });
    }
  }

  Future<void> _setTrainingEnabled(
    AdminApparatus apparatus,
    bool enabled,
  ) async {
    if (_savingId != null) {
      return;
    }
    setState(() => _savingId = apparatus.id);
    try {
      final saved = await MobileApi.instance.adminCreateApparatus(
        apparatus.name,
        id: apparatus.id,
        family: apparatus.family,
        kind: apparatus.kind,
        capabilities: apparatus.capabilities,
        capabilityProfiles: apparatus.capabilityProfiles,
        colorStations: apparatus.colorStations,
        trainingEnabled: enabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _apparatus = [
          for (final item in _apparatus)
            if (item.id == saved.id) saved else item,
        ];
      });
      showAdminTopNotice(
        context,
        enabled ? 'Training rejimi yoqildi' : 'Training rejimi o‘chirildi',
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Training rejimi saqlanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _savingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AdminShell(
      title: 'Training',
      selectedRouteName: AppRoutes.adminTraining,
      activeTab: AdminDockTab.home,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _error != null
                ? AppRetryState(onRetry: _load)
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      bottomPadding,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.school_outlined),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Training rejimi apparat bo‘yicha boshqariladi. '
                                'Hozircha bu sahifa faqat rejim flag’ini saqlaydi; '
                                'demo order va QR keyingi bosqichda ulanadi.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_apparatus.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Aparatlar topilmadi')),
                        )
                      else
                        for (final apparatus in _apparatus)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: SwitchListTile.adaptive(
                              value: apparatus.trainingEnabled,
                              onChanged: _savingId == null
                                  ? (enabled) =>
                                      _setTrainingEnabled(apparatus, enabled)
                                  : null,
                              title: Text(apparatus.name),
                              subtitle: Text(
                                apparatus.trainingEnabled
                                    ? 'Training faol'
                                    : 'Production rejimi',
                              ),
                              secondary: _savingId == apparatus.id
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.precision_manufacturing),
                            ),
                          ),
                    ],
                  ),
      ),
    );
  }
}
