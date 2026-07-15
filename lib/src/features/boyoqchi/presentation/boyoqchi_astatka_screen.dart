import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/returned_paint_models.dart';
import '../state/returned_paint_draft_store.dart';
import 'widgets/boyoqchi_dock.dart';
import 'widgets/boyoqchi_navigation_drawer.dart';
import 'widgets/returned_paint_sheet.dart';
import 'package:flutter/material.dart';

typedef BoyoqchiAstatkaLoader = Future<ReturnedPaintRequestPage> Function();
typedef BoyoqchiReturnedPaintCompleter = Future<ReturnedPaintRequest> Function(
  ReturnedPaintCompleteSubmission input,
);

class BoyoqchiAstatkaScreen extends StatefulWidget {
  const BoyoqchiAstatkaScreen({
    super.key,
    this.loader,
    this.completer,
  });

  final BoyoqchiAstatkaLoader? loader;
  final BoyoqchiReturnedPaintCompleter? completer;

  @override
  State<BoyoqchiAstatkaScreen> createState() => _BoyoqchiAstatkaScreenState();
}

class _BoyoqchiAstatkaScreenState extends State<BoyoqchiAstatkaScreen> {
  late Future<ReturnedPaintRequestPage> _requests;
  String? _expandedRequestKey;

  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<ReturnedPaintRequestPage> _load() {
    return widget.loader?.call() ??
        MobileApi.instance.boyoqchiReturnedPaintRequests(limit: 100);
  }

  Future<void> _refresh() async {
    final requests = _load();
    setState(() {
      _requests = requests;
      _expandedRequestKey = null;
    });
    await requests;
  }

  String _requestKey(ReturnedPaintRequest request) {
    final id = request.id.trim();
    if (id.isNotEmpty) return id;
    return '${request.orderId.trim()}|${request.orderCode.trim()}|${request.createdAt.toIso8601String()}';
  }

  void _onRequestExpanded(ReturnedPaintRequest request, bool expanded) {
    setState(() {
      _expandedRequestKey = expanded ? _requestKey(request) : null;
    });
  }

  Future<void> _openReturnedPaintInput(ReturnedPaintRequest request) async {
    final scope = returnedPaintBoyoqchiDraftScope(
      actorRef: AppSession.instance.profile?.ref ?? '',
      requestId: request.id,
    );
    final draft = await ReturnedPaintDraftStore.instance.load(
      scope: scope,
      initialImage: request.image,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ReturnedPaintSheet(
        draft: draft,
        orderId: request.orderId,
        apparatus: request.apparatus,
        saveLabel: 'Saqlash',
        onSave: (items) async {
          final input = ReturnedPaintCompleteSubmission(
            requestId: request.id,
            items: items,
          );
          await (widget.completer?.call(input) ??
              MobileApi.instance.completeReturnedPaint(input));
          await ReturnedPaintDraftStore.instance.clear(scope);
          if (mounted) await _refresh();
        },
      ),
    );
  }

  void _openDrawerRoute(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128.0;
    return AppShell(
      title: 'Astatka',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      drawer: BoyoqchiNavigationDrawer(
        selectedRouteName: AppRoutes.boyoqchiAstatka,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const BoyoqchiDock(activeTab: BoyoqchiDockTab.astatka),
      child: FutureBuilder<ReturnedPaintRequestPage>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return _AstatkaMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Astatka ma’lumotlari yuklanmadi',
              actionLabel: 'Qayta yuklash',
              onAction: _refresh,
            );
          }
          final requests = snapshot.data?.items ?? const [];
          if (requests.isEmpty) {
            return _AstatkaMessage(
              icon: Icons.inventory_2_outlined,
              title: 'Hisoblangan Astatka ma’lumotlari hali yo‘q',
              actionLabel: 'Yangilash',
              onAction: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const TopRefreshScrollPhysics(),
              padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding),
              itemCount: requests.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: M3SegmentedListGeometry.gap),
              itemBuilder: (context, index) {
                final request = requests[index];
                return _AstatkaRequestCard(
                  request: request,
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    requests.length,
                  ),
                  expanded: _expandedRequestKey == _requestKey(request),
                  onExpandedChanged: (expanded) =>
                      _onRequestExpanded(request, expanded),
                  onReturnedPaintRequested: request.waitingForBoyoqchiInput
                      ? () => _openReturnedPaintInput(request)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AstatkaRequestCard extends StatelessWidget {
  const _AstatkaRequestCard({
    required this.request,
    required this.slot,
    required this.expanded,
    required this.onExpandedChanged,
    this.onReturnedPaintRequested,
  });

  final ReturnedPaintRequest request;
  final M3SegmentVerticalSlot slot;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Future<void> Function()? onReturnedPaintRequested;

  @override
  Widget build(BuildContext context) {
    final calculation = request.calculation;
    final waiting = request.waitingForBoyoqchiInput;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return M3ExpandableFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      headerPadding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      header: Row(
        children: [
          Expanded(
            child: Text(
              _orderLabel(request),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      expandedChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AstatkaInfoRow(
              label: 'Order kodi',
              value: _orderCode(request),
              prominent: true,
            ),
            _AstatkaInfoRow(
              label: 'Operator',
              value: _operator(request),
            ),
            _AstatkaInfoRow(
              label: 'Sana va vaqt',
              value: formatLocalDateTime(request.createdAt),
            ),
            if (request.image case final image?) ...[
              const SizedBox(height: 4),
              ReturnedPaintImageView(
                image: image,
                onTap: () => showReturnedPaintImagePreview(
                  context,
                  image,
                  allowDownload: true,
                ),
              ),
            ],
            const Divider(height: 24),
            if (waiting) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Qaytarilgan bo‘yoq qiymatlari kiritilmagan. '
                    'Rasmdagi qiymatlarni Bo‘yoqchi to‘ldirishi kerak.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onReturnedPaintRequested,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Qaytarilgan bo‘yoq'),
              ),
            ] else if (calculation != null) ...[
              _AstatkaInfoRow(
                label: 'Rasxot jami Mix',
                value: _amount(calculation.rasxotMixTotal),
              ),
              _AstatkaInfoRow(
                label: 'Astatka jami Mix',
                value: _amount(calculation.astatkaMixTotal),
              ),
              _AstatkaInfoRow(
                label: 'Rasxot spirt miqdori',
                value: _amount(calculation.rasxotAlcohol),
              ),
              _AstatkaInfoRow(
                label: 'Astatka spirt miqdori',
                value: _amount(calculation.astatkaAlcohol),
              ),
              _AstatkaInfoRow(
                label: 'Yakuniy ishlatilgan spirt',
                value: _amount(calculation.finalUsedAlcohol),
                prominent: true,
              ),
              const Divider(height: 24),
              _AstatkaInfoRow(
                label: 'Rasxot sof bo‘yoq miqdori',
                value: _amount(calculation.rasxotPurePaint),
              ),
              _AstatkaInfoRow(
                label: 'Astatka sof bo‘yoq miqdori',
                value: _amount(calculation.astatkaPurePaint),
              ),
              _AstatkaInfoRow(
                label: 'Yakuniy ishlatilgan bo‘yoq',
                value: _amount(calculation.finalUsedPaint),
                prominent: true,
                bottomPadding: 0,
              ),
            ] else ...[
              Text(
                'Ushbu eski hisobot uchun hisoblash ma’lumoti mavjud emas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AstatkaInfoRow extends StatelessWidget {
  const _AstatkaInfoRow({
    required this.label,
    required this.value,
    this.prominent = false,
    this.bottomPadding = 8,
  });

  final String label;
  final String value;
  final bool prominent;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: prominent ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AstatkaMessage extends StatelessWidget {
  const _AstatkaMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _orderCode(ReturnedPaintRequest request) {
  final code = request.orderCode.trim();
  if (code.isNotEmpty) return code;
  final orderId = request.orderId.trim();
  return orderId.isEmpty ? '—' : orderId;
}

String _orderLabel(ReturnedPaintRequest request) {
  final name = request.orderName.trim();
  final code = request.orderCode.trim();
  if (name.isNotEmpty && code.isNotEmpty) return '$name — #$code';
  if (name.isNotEmpty) return name;
  if (code.isNotEmpty) return '#$code';
  return request.orderId.trim().isEmpty ? '—' : request.orderId.trim();
}

String _operator(ReturnedPaintRequest request) {
  final displayName = request.senderDisplayName.trim();
  if (displayName.isNotEmpty) return displayName;
  final senderRef = request.senderRef.trim();
  return senderRef.isEmpty ? '—' : senderRef;
}

String _amount(String rawValue) {
  var value = rawValue.trim();
  if (value.contains('.')) {
    value =
        value.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return value.isEmpty ? '—' : '$value kg';
}
