import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../admin/logic/canonical_apparatus_groups.dart';
import '../../shared/models/app_models.dart';

List<AdminApparatus> assignedPaddonApparatus(
  Iterable<AdminApparatus> catalog,
  Iterable<String> assigned,
) {
  final assignedIds = assigned.map((id) => id.trim()).toSet();
  return canonicalApparatusGroups(catalog)
      .where((group) => group.operation == 'cut')
      .expand((group) => group.apparatus)
      .where((apparatus) => assignedIds.contains(apparatus.id))
      .toList(growable: false);
}

String apparatusPaddonsRoute(String apparatusId, {String apparatusName = ''}) =>
    Uri(
      path: AppRoutes.apparatusPaddons,
      queryParameters: {
        'apparatus': apparatusId.trim(),
        if (apparatusName.trim().isNotEmpty) 'name': apparatusName.trim(),
      },
    ).toString();

String apparatusPaddonsTitle(AppLocalizations l10n, String apparatusName) =>
    l10n.productionText('worker.paddon.apparatus',
        values: {'apparatus': apparatusName});
