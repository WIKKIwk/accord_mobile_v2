import 'apparatus_queue_state.dart';

enum FactoryMapOrderFilter { inProgress, completed, all }

extension FactoryMapOrderFilterX on FactoryMapOrderFilter {
  String get label => switch (this) {
        FactoryMapOrderFilter.inProgress => 'Jarayonda',
        FactoryMapOrderFilter.completed => 'Tugagan',
        FactoryMapOrderFilter.all => 'Barchasi',
      };

  String get emptyMessage => switch (this) {
        FactoryMapOrderFilter.inProgress =>
          'Bu apparatda jarayondagi order topilmadi.',
        FactoryMapOrderFilter.completed =>
          'Bu apparatda tugagan order topilmadi.',
        FactoryMapOrderFilter.all =>
          'Bu apparatda order, homashyo yoki WIP topilmadi.',
      };
}

bool factoryMapOrderMatchesFilter({
  required String orderId,
  required Map<String, String> states,
  required FactoryMapOrderFilter filter,
}) {
  if (filter == FactoryMapOrderFilter.all) {
    return true;
  }
  final state = apparatusQueueOrderStateFromRaw(states[orderId.trim()]);
  return switch (filter) {
    FactoryMapOrderFilter.inProgress =>
      state == ApparatusQueueOrderState.inProgress ||
          state == ApparatusQueueOrderState.paused,
    FactoryMapOrderFilter.completed =>
      state == ApparatusQueueOrderState.completed,
    FactoryMapOrderFilter.all => true,
  };
}

List<String> filterFactoryMapOrderIds({
  required Iterable<String> orderIds,
  required Map<String, String> states,
  required FactoryMapOrderFilter filter,
}) {
  return orderIds
      .where(
        (orderId) => factoryMapOrderMatchesFilter(
          orderId: orderId,
          states: states,
          filter: filter,
        ),
      )
      .toList(growable: false);
}
