import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'werka_archive_list_screen.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

part 'werka_archive_sent_hub_screen__WerkaArchiveSentHubScreenState_methods_01.dart';
part 'werka_archive_sent_hub_screen_widgets_part_01.dart';

class _WerkaArchiveSentHubScreenState extends State<WerkaArchiveSentHubScreen> {
  late DateTime _displayMonth;
  late DateTime _selectedDate;
  late int _displayYear;
  late int _startYear;

  bool _loading = true;
  Object? _error;
  bool _dailyOpen = true;
  bool _monthlyOpen = false;
  bool _yearlyOpen = false;
  Set<int> _activeDays = <int>{};
  Set<int> _activeMonths = <int>{};
  Set<int> _activeYears = <int>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateUtils.dateOnly(now);
    _displayYear = now.year;
    _startYear = now.year - 5;
    _loadCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    useNativeNavigationTitle(context, l10n.archiveSentTitle);
    return AppShell(
      title: l10n.archiveSentTitle,
      subtitle: l10n.archiveChoosePeriod,
      nativeTopBar: true,
      leading: NativeBackButtonSlot(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      bottom: const WerkaDock(activeTab: null),
      child: _buildBody(context),
    );
  }
}
