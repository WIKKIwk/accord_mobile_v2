import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/timers/retry_after_countdown.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'admin_suppliers_screen.dart';
import 'widgets/admin_dock.dart';
import '../logic/admin_aparatchi_assignment.dart';
import 'widgets/admin_apparatus_scope_picker.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_user_create_screen_widgets_part_01.dart';
part 'admin_user_create_screen_models_part_02.dart';
part 'admin_user_create_screen_declarations_part_03.dart';
part 'admin_user_create_screen_helpers_part_04.dart';

const AdminRoleDefinition _materialTaminotchiRoleDefinition =
    AdminRoleDefinition(
  id: 'material_taminotchi',
  label: 'Material taminotchisi',
  baseRole: UserRole.materialTaminotchi,
  capabilityCodes: [
    'gscale.catalog.read',
    'gscale.print',
    'rps.batch.manage',
    'catalog.item.create',
    'raw_material.assign',
  ],
  system: true,
);

const AdminRoleDefinition _boyoqchiRoleDefinition = AdminRoleDefinition(
  id: 'boyoqchi',
  label: 'Bo‘yoqchi',
  baseRole: UserRole.boyoqchi,
  capabilityCodes: [
    'boyoqchi.access',
    'returned_paint.request.read',
  ],
  system: true,
);

const EdgeInsets _adminUserCreatePagePadding = EdgeInsets.fromLTRB(
  12,
  8,
  12,
  24,
);
const double _adminUserCreatePanelGap = 4;
const double _adminUserCreateSectionRadius = 18;
const double _adminUserCreateFieldGap = 12;
