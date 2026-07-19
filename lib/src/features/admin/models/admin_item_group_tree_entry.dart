class AdminItemGroupTreeEntry {
  const AdminItemGroupTreeEntry({
    required this.name,
    required this.itemGroupName,
    required this.parentItemGroup,
    required this.isGroup,
  });

  final String name;
  final String itemGroupName;
  final String parentItemGroup;
  final bool isGroup;

  factory AdminItemGroupTreeEntry.fromJson(Map<String, dynamic> json) {
    return AdminItemGroupTreeEntry(
      name: json['name'] as String? ?? '',
      itemGroupName: json['item_group_name'] as String? ?? '',
      parentItemGroup: json['parent_item_group'] as String? ?? '',
      isGroup: json['is_group'] as bool? ?? false,
    );
  }
}

bool adminItemGroupRequiresCustomer(
  String itemGroup,
  List<AdminItemGroupTreeEntry> groups,
) {
  const finishedGoodsGroup = 'tayyor mahsulot';
  var current = itemGroup.trim();
  final seen = <String>{};
  while (current.isNotEmpty && seen.add(current.toLowerCase())) {
    if (current.toLowerCase() == finishedGoodsGroup) {
      return true;
    }
    AdminItemGroupTreeEntry? matched;
    for (final group in groups) {
      final name = group.itemGroupName.trim().isNotEmpty
          ? group.itemGroupName.trim()
          : group.name.trim();
      if (name.toLowerCase() == current.toLowerCase() ||
          group.name.trim().toLowerCase() == current.toLowerCase()) {
        matched = group;
        break;
      }
    }
    if (matched == null) {
      break;
    }
    current = matched.parentItemGroup.trim();
  }
  return false;
}
