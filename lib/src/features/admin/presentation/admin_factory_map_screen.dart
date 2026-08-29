import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../shared/models/app_models.dart';
import '../logic/apparatus_queue_state.dart';
import '../logic/factory_map_mapping.dart';
import '../logic/factory_map_order_filter.dart';
import '../models/production_map_models.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_production_map_orders_screen.dart'
    show showAdminProductionMapOrderReadOnlyDetail;
import 'widgets/admin_dock.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_top_notice.dart';

part 'admin_factory_map_screen_helpers_part_01.dart';
part 'admin_factory_map_screen_models_part_02.dart';
part 'admin_factory_map_screen_models_part_03.dart';
