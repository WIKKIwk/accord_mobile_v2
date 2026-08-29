import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_location_transfer_screen__QolipLocationTransferScreenState_methods_01.dart';
part 'qolip_location_transfer_screen_widgets_part_01.dart';

class _QolipLocationTransferScreenState
    extends State<QolipLocationTransferScreen> {
  late Future<QolipBlocksResult> _blocksFuture;
  Future<List<QolipLocationEntry>>? _locationsFuture;
  final TextEditingController _quantityController = TextEditingController();
  String? _sourceBlockName;
  String? _targetBlockName;
  QolipLocationEntry? _selectedSource;
  String? _targetCell;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _blocksFuture = _loadBlocks();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.qolipText('transfer.title'),
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: QolipNavigationDrawer(
        selectedIndex: 4,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: null),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: FutureBuilder<QolipBlocksResult>(
        future: _blocksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: _reload);
          }
          final data = snapshot.data ??
              const QolipBlocksResult(warehouses: [], blocks: []);
          if (data.blocks.isEmpty) {
            return Center(child: Text(l10n.qolipText('transfer.empty')));
          }
          return _buildTransferForm(data);
        },
      ),
    );
  }
}
