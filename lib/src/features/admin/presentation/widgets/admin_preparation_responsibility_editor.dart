import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../preparation/models/preparation_models.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';

/// Tayyorlov masteri uchun javobgar homashyolar (calculate-material oilalari).
/// Ombor editor pattern'i: chip ro'yxati + picker orqali qo'shish + confirm bilan o'chirish.
/// Faqat `tayyorlovMasteri` user-detail'da ko'rsatiladi; boshqa rollarga tegmaydi.
class AdminPreparationResponsibilityEditor extends StatefulWidget {
  const AdminPreparationResponsibilityEditor({
    super.key,
    required this.assigned,
    required this.principalRef,
    required this.displayName,
    required this.reloadAssigned,
    required this.onChanged,
    this.buttonRadius = 14,
  });

  final List<PreparationResponsibility> assigned;
  final String principalRef;
  final String displayName;
  final Future<List<PreparationResponsibility>> Function() reloadAssigned;
  final ValueChanged<List<PreparationResponsibility>> onChanged;
  final double buttonRadius;

  @override
  State<AdminPreparationResponsibilityEditor> createState() =>
      _AdminPreparationResponsibilityEditorState();
}

class _AdminPreparationResponsibilityEditorState
    extends State<AdminPreparationResponsibilityEditor> {
  bool _adding = false;
  String? _removingId;

  String _normalize(String value) => value.trim().toLowerCase();

  Future<void> _addResponsibility() async {
    if (_adding) {
      return;
    }
    setState(() => _adding = true);
    try {
      final catalog = await MobileApi.instance.calculateMaterials();
      final assignedKeys = widget.assigned
          .map((item) => _normalize(item.materialId))
          .toSet();
      final available = catalog
          .where((material) =>
              material.active && !assignedKeys.contains(_normalize(material.id)))
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barcha homashyolar allaqachon biriktirilgan'),
          ),
        );
        return;
      }
      final picked = await showModalBottomSheet<CalculateMaterial>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (sheetContext) => M3AsyncPickerSheet<CalculateMaterial>(
          title: 'Homashyo tanlang',
          hintText: 'Qidirish',
          pageSize: 50,
          loadPage: (query, offset, limit) async => available
              .where((material) => material.name
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()))
              .skip(offset)
              .take(limit)
              .toList(),
          itemTitle: (item) => item.name,
          itemSubtitle: (item) => '${item.variants.length} mikron varianti',
          onSelected: (item) => Navigator.of(sheetContext).pop(item),
        ),
      );
      if (!mounted || picked == null) {
        return;
      }
      final saved =
          await MobileApi.instance.preparationAssignResponsibility(
        principalRef: widget.principalRef,
        materialId: picked.id,
      );
      final updated = await widget.reloadAssigned();
      final confirmed = updated.any(
        (item) => _normalize(item.materialId) == _normalize(saved.materialId),
      );
      if (!confirmed) {
        throw const MobileApiException(
          code: 'responsibility_not_confirmed',
          message: 'Biriktirish tasdiqlanmadi',
        );
      }
      if (mounted) {
        widget.onChanged(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biriktirildi: ${saved.materialName}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biriktirilmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _removeResponsibility(PreparationResponsibility item) async {
    if (_removingId != null) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Biriktirishni olib tashlash',
      message:
          '${item.materialName} — ${widget.displayName} endi bu homashyoli buyurtmalarni ko‘rmaydi.',
      cancelLabel: 'Yo‘q',
      confirmLabel: 'Ha',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _removingId = item.materialId);
    try {
      await MobileApi.instance.preparationUnassignResponsibility(
        principalRef: widget.principalRef,
        materialId: item.materialId,
      );
      final updated = await widget.reloadAssigned();
      final stillExists = updated.any(
        (entry) =>
            _normalize(entry.materialId) == _normalize(item.materialId),
      );
      if (stillExists) {
        throw const MobileApiException(
          code: 'unassignment_not_confirmed',
          message: 'Olib tashlash tasdiqlanmadi',
        );
      }
      if (mounted) {
        widget.onChanged(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Olib tashlandi: ${item.materialName}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Olib tashlanmadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Javobgar homashyolar',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.assigned.isEmpty
              ? 'Hech qanday homashyo biriktirilmagan — bu master buyurtmalarni ko‘rmaydi.'
              : 'Shu homashyolari bor buyurtmalar masterga ko‘rinadi.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.assigned.isEmpty
                ? scheme.error
                : scheme.onSurfaceVariant,
          ),
        ),
        if (widget.assigned.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in widget.assigned)
                InputChip(
                  key: ValueKey(
                      'admin-prep-resp-${item.materialId}'),
                  avatar:
                      const Icon(Icons.inventory_2_outlined, size: 17),
                  label: Text(item.materialName.isEmpty
                      ? item.materialId
                      : item.materialName),
                  deleteIcon: _removingId == item.materialId
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded, size: 18),
                  onDeleted: _removingId == null
                      ? () => _removeResponsibility(item)
                      : null,
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('admin-prep-resp-add'),
            style: appOutlinedActionButtonStyle(
              borderRadius: widget.buttonRadius,
            ),
            onPressed: _adding ? null : _addResponsibility,
            icon: _adding
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: const Text('Homashyo biriktirish'),
          ),
        ),
      ],
    );
  }
}
