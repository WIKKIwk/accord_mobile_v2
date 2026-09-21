part of 'preparation_screen.dart';

String _warehouseErrorMessage(Object error) => error is MobileApiException
    ? error.message
    : 'Ombor bilan amal bajarilmadi. Internet aloqasini tekshirib, qayta urinib ko‘ring';

extension _PreparationWarehouseManagement on _PreparationWarehouseScreenState {
  Future<void> _warehouseActions(String warehouse) async {
    if (_managingWarehouse ||
        widget.locked ||
        !_managedWarehouses.contains(warehouse)) {
      return;
    }
    final action = await showSpringBottomSheet<String>(
      context: context,
      builder: (_) => AppActionSheet<String>(
        title: warehouse,
        actions: const [
          AppActionSheetAction(
            title: 'Nomini o‘zgartirish',
            icon: Icons.edit_outlined,
            value: 'rename',
          ),
          AppActionSheetAction(
            title: 'O‘chirish',
            icon: Icons.delete_outline_rounded,
            value: 'delete',
            destructive: true,
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    String? newName;
    if (action == 'rename') {
      newName = await showDialog<String>(
        context: context,
        builder: (_) => _PreparationInputDialog(
          title: 'Ombor nomini o‘zgartirish',
          label: 'Ombor nomi',
          initialValue: warehouse,
        ),
      );
      if (newName == null || !mounted) return;
    } else {
      final confirmed = await showM3ConfirmDialog(
        context: context,
        title: 'Omborni o‘chirish',
        message:
            '«$warehouse» ombori o‘chirilsinmi? Ichida homashyo yoki bog‘langan yozuvlar bo‘lsa, o‘chirilmaydi.',
        cancelLabel: 'Bekor qilish',
        confirmLabel: 'O‘chirish',
        destructive: true,
      );
      if (confirmed != true || !mounted) return;
    }
    if (_managingWarehouse) return;
    _updateWarehouse(() => _managingWarehouse = true);
    try {
      final String? renamed;
      if (action == 'rename') {
        renamed = await MobileApi.instance
            .preparationRenameWarehouse(warehouse: warehouse, name: newName!);
      } else {
        await MobileApi.instance.preparationDeleteWarehouse(warehouse);
        renamed = null;
      }
      if (!mounted) return;
      await widget.onReload();
      if (!mounted) return;
      _updateWarehouse(() {
        if (_warehouse == warehouse) {
          _warehouse = renamed ?? _warehouses.firstOrNull;
        }
        _materials = widget.freshMaterials();
      });
      if (_warehouse != null) widget.onWarehouseSelected(_warehouse!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'rename'
              ? 'Ombor nomi o‘zgartirildi'
              : 'Ombor o‘chirildi')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_warehouseErrorMessage(error))));
      }
    } finally {
      if (mounted) _updateWarehouse(() => _managingWarehouse = false);
    }
  }
}
