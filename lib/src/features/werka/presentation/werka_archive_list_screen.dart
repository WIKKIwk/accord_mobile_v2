import '../../../core/api/mobile_api.dart';
import '../../../core/files/archive_pdf_photo_saver.dart';
import '../../../core/files/archive_pdf_saver.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../shared/models/app_models.dart';
import 'widgets/werka_dock.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

part 'werka_archive_list_screen__WerkaArchiveListScreenState_methods_01.dart';
part 'werka_archive_list_screen__WerkaArchiveListScreenState_methods_02.dart';
part 'werka_archive_list_screen_models_part_01.dart';

class _WerkaArchiveListScreenState extends State<WerkaArchiveListScreen> {
  bool _loading = true;
  bool _downloading = false;
  Object? _error;
  WerkaArchiveResponse? _data;
  late DateTime? _from;
  late DateTime? _to;
  bool _showDateCalendar = false;

  @override
  void initState() {
    super.initState();
    _from = widget.args.from;
    _to = widget.args.to;
    final now = DateTime.now();
    if (widget.args.period == WerkaArchivePeriod.daily &&
        (_from == null || _to == null)) {
      final selected = DateUtils.dateOnly(now);
      _from = selected;
      _to = selected;
    } else if (widget.args.period == WerkaArchivePeriod.monthly &&
        (_from == null || _to == null)) {
      _from = DateTime(now.year, now.month, 1);
      _to = _lastDayOfMonth(now.year, now.month);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_kindTitle(context.l10n)} • ${_periodTitle(context.l10n)}';
    useNativeNavigationTitle(context, title);
    return AppShell(
      title: title,
      subtitle: _subtitle(context),
      nativeTopBar: true,
      actions: [
        IconButton.filledTonal(
          onPressed: (_data?.items.isNotEmpty ?? false) && !_downloading
              ? _downloadPdf
              : null,
          icon: Icon(
            _downloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
          ),
          tooltip: context.l10n.archiveDownloadPdfAction,
        ),
      ],
      leading: NativeBackButtonSlot(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      bottom: const WerkaDock(activeTab: null),
      child: _buildBody(context),
    );
  }
}
