import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart' show AppRefreshIndicator;
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_shell.dart';
import 'package:flutter/material.dart';

part 'admin_wip_batches_screen__WipBatchStatusX_methods_01.dart';
part 'admin_wip_batches_screen_declarations_part_01.dart';
part 'admin_wip_batches_screen_widgets_part_02.dart';
part 'admin_wip_batches_screen_models_part_03.dart';

const double _wipPanelGap = 4;
const double _wipPanelTopGap = 8;
const int _wipFetchLimit = 250;

extension _WipBatchStatusX on _WipBatchStatus {
  String get apiValue {
    return switch (this) {
      _WipBatchStatus.waiting => 'waiting',
      _WipBatchStatus.inUse => 'in_use',
      _WipBatchStatus.processed => 'processed',
    };
  }
}
