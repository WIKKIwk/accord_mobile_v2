part of 'preparation_screen.dart';

class PreparationFormulaCatalogScreen extends PreparationFormulaOrdersScreen {
  const PreparationFormulaCatalogScreen({super.key})
      : super(initialSaved: true);
}

Future<bool> _renameCatalogRecipe(
  BuildContext context,
  PreparationFormulaCatalogEntry entry,
) async {
  final scope = currentSessionReadScope();
  final rename = await showSpringBottomSheet<bool>(
    context: context,
    builder: (_) => AppActionSheet<bool>(
      title: entry.name,
      subtitle: entry.code,
      actions: const [
        AppActionSheetAction(
          title: 'Nomini o‘zgartirish',
          icon: Icons.drive_file_rename_outline,
          value: true,
        ),
      ],
    ),
  );
  if (rename != true ||
      !context.mounted ||
      scope != currentSessionReadScope()) {
    return false;
  }
  final saved = await showPreparationFormulaRenameDialog(
    context,
    variantId: entry.id,
    name: entry.name,
    productCode: entry.productCode,
    materialId: entry.materialId,
  );
  return saved != null && scope == currentSessionReadScope();
}
