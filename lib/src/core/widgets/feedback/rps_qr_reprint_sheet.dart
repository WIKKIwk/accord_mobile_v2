import 'package:flutter/material.dart';

import '../../godex_rps_renderer.dart';

class RpsQrReprintCancelled implements Exception {
  const RpsQrReprintCancelled();
}

class RpsQrDetail {
  const RpsQrDetail(this.label, this.value);

  final String label;
  final String value;
}

class RpsQrReprintSheet extends StatefulWidget {
  const RpsQrReprintSheet({
    super.key,
    required this.payload,
    required this.itemName,
    required this.details,
    required this.onReprint,
    required this.errorMessage,
    this.title = 'Chop etilgan QR',
    this.successMessage = 'Mavjud QR qayta chop etildi',
    this.previewKey,
    this.reprintButtonKey = const ValueKey('rps-qr-reprint'),
    this.onEdit,
    this.editButtonKey,
    this.onDelete,
    this.deleteButtonKey,
    this.deleteButtonLabel = 'QRni o‘chirish',
  });

  final String title;
  final String payload;
  final String itemName;
  final List<RpsQrDetail> details;
  final Future<String?> Function() onReprint;
  final String Function(Object error) errorMessage;
  final String successMessage;
  final Key? previewKey;
  final Key reprintButtonKey;
  final Future<void> Function()? onEdit;
  final Key? editButtonKey;
  final Future<void> Function()? onDelete;
  final Key? deleteButtonKey;
  final String deleteButtonLabel;

  @override
  State<RpsQrReprintSheet> createState() => _RpsQrReprintSheetState();
}

class _RpsQrReprintSheetState extends State<RpsQrReprintSheet> {
  bool _printing = false;
  bool _deleting = false;
  String? _errorText;

  Future<void> _reprint() async {
    if (_printing) {
      return;
    }
    setState(() {
      _printing = true;
      _errorText = null;
    });
    try {
      final warning = await widget.onReprint();
      if (!mounted) {
        return;
      }
      setState(() {
        _printing = false;
        _errorText = (warning?.trim().isEmpty ?? true) ? null : warning;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(widget.successMessage)),
      );
    } on RpsQrReprintCancelled {
      if (mounted) {
        setState(() {
          _printing = false;
          _errorText = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _printing = false;
          _errorText = widget.errorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_printing || _deleting || widget.onDelete == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batch QRni o‘chirish'),
        content: const Text(
          'Bu QR Laminatsiya ishini boshlash uchun ishlatilmaydi. Keyin yana generatsiya qilish mumkin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _deleting = true;
      _errorText = null;
    });
    try {
      await widget.onDelete!();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _errorText = widget.errorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.onEdit != null)
                    IconButton(
                      key: widget.editButtonKey,
                      onPressed: _printing || _deleting ? null : widget.onEdit,
                      tooltip: 'WIPni o‘zgartirish',
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  IconButton(
                    onPressed: _printing || _deleting
                        ? null
                        : () => Navigator.pop(context),
                    tooltip: 'Yopish',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: RpsQrPreview(
                  key: widget.previewKey ??
                      ValueKey('rps-qr-preview-${widget.payload}'),
                  payload: widget.payload,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.itemName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                widget.payload,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 16),
              for (final detail in widget.details)
                _RpsQrDetailLine(label: detail.label, value: detail.value),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: widget.reprintButtonKey,
                onPressed: _printing || _deleting ? null : _reprint,
                icon: _printing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_rounded),
                label: Text(_printing ? 'Chop etilmoqda…' : 'Qayta chop etish'),
              ),
              if (widget.onDelete != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: widget.deleteButtonKey,
                  onPressed: _printing || _deleting ? null : _delete,
                  icon: _deleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _deleting ? 'O‘chirilmoqda…' : widget.deleteButtonLabel,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RpsQrPreview extends StatelessWidget {
  const RpsQrPreview({super.key, required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final matrix = GodexRpsRenderer.qrMatrix(payload);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox.square(
          dimension: 208,
          child: CustomPaint(painter: _RpsQrPainter(matrix)),
        ),
      ),
    );
  }
}

class _RpsQrDetailLine extends StatelessWidget {
  const _RpsQrDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RpsQrPainter extends CustomPainter {
  const _RpsQrPainter(this.matrix);

  final QrCodeMatrix matrix;

  @override
  void paint(Canvas canvas, Size size) {
    const quietZone = 4;
    final totalModules = matrix.size + quietZone * 2;
    final moduleSize = (size.shortestSide ~/ totalModules).toDouble();
    final drawnSize = moduleSize * totalModules;
    final offsetX = (size.width - drawnSize) / 2;
    final offsetY = (size.height - drawnSize) / 2;
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (!matrix.isDark(x, y)) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            offsetX + (x + quietZone) * moduleSize,
            offsetY + (y + quietZone) * moduleSize,
            moduleSize,
            moduleSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RpsQrPainter oldDelegate) =>
      oldDelegate.matrix != matrix;
}
