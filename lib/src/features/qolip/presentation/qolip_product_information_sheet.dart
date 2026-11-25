import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';

Future<QolipProductInformation?> showQolipProductInformationSheet(
  BuildContext context, {
  required String catalogId,
  required String productName,
  required String productCode,
  required bool edit,
}) {
  return showModalBottomSheet<QolipProductInformation>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => _ProductInformationSheet(
      catalogId: catalogId,
      productName: productName,
      productCode: productCode,
      edit: edit,
    ),
  );
}

class _ProductInformationSheet extends StatefulWidget {
  const _ProductInformationSheet({
    required this.catalogId,
    required this.productName,
    required this.productCode,
    required this.edit,
  });

  final String catalogId;
  final String productName;
  final String productCode;
  final bool edit;

  @override
  State<_ProductInformationSheet> createState() =>
      _ProductInformationSheetState();
}

class _ProductInformationSheetState extends State<_ProductInformationSheet> {
  final _details = TextEditingController();
  final _scope = currentSessionReadScope();
  QolipProductInformation? _information;
  ({String name, Uint8List bytes})? _pickedFile;
  late bool _editing = widget.edit;
  bool _removeAttachment = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _active => mounted && _scope == currentSessionReadScope();
  String? get _storedFilename =>
      _removeAttachment ? null : _information?.attachmentName;
  bool get _hasChanges =>
      _details.text.trim() != _information?.details ||
      _pickedFile != null ||
      _removeAttachment;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_active) return;
    setState(() => _loading = true);
    try {
      final information =
          await MobileApi.instance.qolipProductInformation(widget.catalogId);
      if (!_active) return;
      _details.text = information.details;
      setState(() => _information = information);
    } catch (_) {
      // The retry state owns failures before any draft is entered.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    if (!_active || _busy) return;
    _startAction();
    try {
      final result = await FilePicker.platform.pickFiles(
        withReadStream: true,
        withData: false,
      );
      if (!_active || result == null) return;
      final file = result.files.single;
      if (file.size > qolipInformationMaxFileBytes) {
        setState(() => _error = 'file_too_large');
        return;
      }
      final stream = file.readStream;
      if (stream == null) throw const FormatException('Missing file stream');
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        if (!_active) return;
        if (bytes.length + chunk.length > qolipInformationMaxFileBytes) {
          setState(() => _error = 'file_too_large');
          return;
        }
        bytes.add(chunk);
      }
      if (!_active) return;
      if (bytes.isEmpty || bytes.length != file.size) {
        throw const FormatException('Invalid file length');
      }
      setState(() {
        _pickedFile = (name: file.name, bytes: bytes.takeBytes());
        _removeAttachment = false;
      });
    } catch (_) {
      if (_active) setState(() => _error = 'file_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final information = _information;
    if (!_active || _busy || information == null || !_hasChanges) return;
    _startAction();
    try {
      final saved = await MobileApi.instance.qolipSaveProductInformation(
        widget.catalogId,
        revision: information.revision,
        details: _details.text.trim(),
        removeAttachment: _removeAttachment,
        attachment: _pickedFile,
      );
      if (!mounted || _scope != currentSessionReadScope()) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      _report(error, 'save_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final information = _information;
    final filename = _storedFilename;
    if (!_active || _busy || information == null || filename == null) return;
    _startAction();
    try {
      final bytes = await MobileApi.instance.qolipDownloadProductAttachment(
        widget.catalogId,
        information,
      );
      if (_active) {
        await FilePicker.platform.saveFile(fileName: filename, bytes: bytes);
      }
    } catch (error) {
      _report(error, 'download_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startAction() => setState(() {
        _busy = true;
        _error = null;
      });

  void _report(Object error, String fallback) {
    if (!_active) return;
    final code = error is MobileApiException ? error.code : null;
    setState(() {
      _error = switch (code) {
        'qolip_information_changed' => 'changed',
        'qolip_attachment_too_large' => 'file_too_large',
        'invalid_qolip_attachment' => 'file_failed',
        _ => fallback,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final information = _active ? _information : null;
    final filename = _pickedFile?.name ?? _storedFilename;
    final title = _editing
        ? information?.hasContent == true
            ? 'edit'
            : 'add'
        : 'view';
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.qolipInformationText(title),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(widget.productName, style: theme.textTheme.titleMedium),
              if (widget.productCode.isNotEmpty &&
                  widget.productCode != widget.productName)
                Text(widget.productCode, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: AppLoadingIndicator())
              else if (information == null)
                AppRetryState(
                  message: l10n.qolipInformationText('load_failed'),
                  onRetry: _load,
                )
              else ...[
                if (_editing)
                  TextField(
                    controller: _details,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    minLines: 3,
                    maxLines: 6,
                    maxLength: qolipInformationMaxDetails,
                    decoration: InputDecoration(
                      labelText: l10n.qolipInformationText('details'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  )
                else if (information.details.isNotEmpty)
                  SelectableText(information.details)
                else if (!information.hasContent)
                  Text(l10n.qolipInformationText('empty')),
                if (filename != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(filename, overflow: TextOverflow.ellipsis),
                    onTap: _busy || _pickedFile != null ? null : _download,
                    trailing: _editing
                        ? IconButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      if (_pickedFile != null) {
                                        _pickedFile = null;
                                      } else {
                                        _removeAttachment = true;
                                      }
                                    }),
                            tooltip: l10n.qolipInformationText('remove'),
                            icon: const Icon(Icons.close),
                          )
                        : IconButton(
                            onPressed: _busy ? null : _download,
                            tooltip: l10n.qolipInformationText('download'),
                            icon: const Icon(Icons.download_outlined),
                          ),
                  ),
                if (_editing)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(l10n.qolipInformationText(
                        filename == null ? 'attach' : 'replace',
                      )),
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_error case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.qolipInformationText(error),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 8),
                if (_editing)
                  FilledButton(
                    onPressed: _busy ||
                            !_hasChanges ||
                            _details.text.runes.length >
                                qolipInformationMaxDetails
                        ? null
                        : _save,
                    child: Text(l10n.qolipText('action.save')),
                  )
                else
                  OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.qolipInformationText('edit')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
