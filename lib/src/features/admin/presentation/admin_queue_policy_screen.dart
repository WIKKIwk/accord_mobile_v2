import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../logic/production_map_pechat_rules.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminQueuePolicyScreen extends StatefulWidget {
  const AdminQueuePolicyScreen({super.key});

  @override
  State<AdminQueuePolicyScreen> createState() => _AdminQueuePolicyScreenState();
}

class _AdminQueuePolicyScreenState extends State<AdminQueuePolicyScreen> {
  late Future<_QueuePolicyData> _future;
  final Set<String> _saving = {};
  Map<String, AdminApparatusQueuePolicy> _policies = const {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QueuePolicyData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 300),
      MobileApi.instance.adminApparatusQueuePolicies(),
    ]);
    final apparatus = results[0] as List<AdminWarehouse>;
    final policies = results[1] as Map<String, AdminApparatusQueuePolicy>;
    _policies = policies;
    return _QueuePolicyData(apparatus: apparatus, policies: policies);
  }

  Future<void> _updatePolicy(
    AdminWarehouse apparatus,
    ApparatusQueuePolicy policy,
  ) async {
    final title = apparatus.warehouse.trim();
    if (title.isEmpty || _saving.contains(title)) {
      return;
    }
    setState(() => _saving.add(title));
    try {
      final saved = await MobileApi.instance.adminUpdateApparatusQueuePolicy(
        apparatus: title,
        policy: policy,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _policies = {..._policies, saved.apparatus: saved};
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : 'Navbat sozlamasi saqlanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _saving.remove(title));
      }
    }
  }

  AdminApparatusQueuePolicy _effectivePolicy(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final pechatLocked = productionMapPechatColorCount(title) != null;
    if (pechatLocked) {
      return AdminApparatusQueuePolicy(
        apparatus: title,
        policy: ApparatusQueuePolicy.strictSequence,
        locked: true,
        reason: 'pechat_always_strict',
      );
    }
    final direct = _policies[title];
    if (direct != null) {
      return direct;
    }
    for (final entry in _policies.entries) {
      if (productionMapWarehouseTitlesMatch(entry.key, title)) {
        return entry.value;
      }
    }
    return AdminApparatusQueuePolicy(
      apparatus: title,
      policy: ApparatusQueuePolicy.strictSequence,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Aparat navbati',
      subtitle: '',
      nativeTopBar: true,
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
      child: FutureBuilder<_QueuePolicyData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(
              onRetry: () async {
                setState(() {
                  _future = _load();
                });
              },
            );
          }
          final apparatus = snapshot.data!.apparatus;
          final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
          return ListView.separated(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 6, 0, bottomPadding),
            itemCount: apparatus.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = apparatus[index];
              final policy = _effectivePolicy(item);
              final title = item.warehouse.trim();
              return _QueuePolicyTile(
                title: title,
                policy: policy,
                saving: _saving.contains(title),
                onChanged: policy.locked
                    ? null
                    : (value) => _updatePolicy(item, value),
              );
            },
          );
        },
      ),
    );
  }
}

class _QueuePolicyData {
  const _QueuePolicyData({required this.apparatus, required this.policies});

  final List<AdminWarehouse> apparatus;
  final Map<String, AdminApparatusQueuePolicy> policies;
}

class _QueuePolicyTile extends StatelessWidget {
  const _QueuePolicyTile({
    required this.title,
    required this.policy,
    required this.saving,
    required this.onChanged,
  });

  final String title;
  final AdminApparatusQueuePolicy policy;
  final bool saving;
  final ValueChanged<ApparatusQueuePolicy>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (saving)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<ApparatusQueuePolicy>(
              segments: const [
                ButtonSegment(
                  value: ApparatusQueuePolicy.strictSequence,
                  icon: Icon(Icons.format_list_numbered_rounded),
                  label: Text('Ketma-ket'),
                ),
                ButtonSegment(
                  value: ApparatusQueuePolicy.freePick,
                  icon: Icon(Icons.ads_click_rounded),
                  label: Text('Erkin'),
                ),
              ],
              selected: {policy.policy},
              onSelectionChanged: onChanged == null || saving
                  ? null
                  : (values) => onChanged!(values.first),
            ),
          ],
        ),
      ),
    );
  }
}
