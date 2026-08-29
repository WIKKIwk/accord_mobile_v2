import 'dart:math' as math;

import '../../../app/app_router.dart';
import '../../../core/cache/json_cache_store.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/store/notification_hidden_store.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/notifications/store/notification_unread_store.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../shared/models/app_models.dart';
import '../state/werka_notification_store.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'werka_notifications_screen_widgets_part_01.dart';
part 'werka_notifications_screen_models_part_02.dart';
part 'werka_notifications_screen_declarations_part_03.dart';
