part of '../mobile_api.dart';

extension MobileApiAdminUsersList on MobileApi {
Future<AdminUserListPage> adminUserList({
    String query = '',
    int limit = 20,
    int offset = 0,
    String role = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final pageLimit = limit <= 0 ? 20 : limit.clamp(1, 50);
      final normalizedRole = role.trim().toLowerCase();
      final systemRole = switch (normalizedRole) {
        'qolipchi' => UserRole.qolipchi,
        'boyoqchi' => UserRole.boyoqchi,
        'material_taminotchi' ||
        'material-taminotchi' =>
          UserRole.materialTaminotchi,
        _ => null,
      };
      if (systemRole != null) {
        final needle = query.trim().toLowerCase();
        final items = _testModeSystemUsers
            .where(
              (user) =>
                  user.role == systemRole &&
                  (needle.isEmpty ||
                      user.name.toLowerCase().contains(needle) ||
                      user.phone.toLowerCase().contains(needle)),
            )
            .map(
              (user) => AdminUserListEntry(
                id: user.id,
                name: user.name,
                phone: user.phone,
                kind: switch (systemRole) {
                  UserRole.qolipchi => AdminUserKind.qolipchi,
                  UserRole.materialTaminotchi =>
                    AdminUserKind.materialTaminotchi,
                  _ => AdminUserKind.boyoqchi,
                },
                principalRole: systemRole,
                roleLabelOverride: userRoleLabel(systemRole),
              ),
            )
            .toList(growable: false);
        return AdminUserListPage(
          items: items.skip(offset).take(pageLimit).toList(growable: false),
          hasMore: items.length > offset + pageLimit,
        );
      }
      if (normalizedRole == 'worker' ||
          normalizedRole == 'ishchi' ||
          normalizedRole == 'aparatchi') {
        final needle = query.trim().toLowerCase();
        final items = _testModeWorkers
            .where(
              (worker) =>
                  needle.isEmpty ||
                  worker.name.toLowerCase().contains(needle) ||
                  worker.phone.toLowerCase().contains(needle) ||
                  worker.level.toLowerCase().contains(needle),
            )
            .map(
              (worker) => AdminUserListEntry(
                id: worker.id,
                name: worker.name,
                phone: worker.phone,
                kind: AdminUserKind.worker,
                principalRole: UserRole.aparatchi,
                roleLabelOverride: worker.level,
              ),
            )
            .toList(growable: false);
        return AdminUserListPage(
          items: items.skip(offset).take(pageLimit).toList(growable: false),
          hasMore: items.length > offset + pageLimit,
        );
      }
      if (normalizedRole == 'werka') {
        final page = TestModeDemoData.userListPage(
          query: query,
          limit: pageLimit,
          offset: offset,
        );
        final items = page.items
            .where(
              (item) =>
                  item.kind == AdminUserKind.werka ||
                  item.principalRole == UserRole.werka,
            )
            .toList(growable: false);
        return AdminUserListPage(items: items, hasMore: false);
      }
      return TestModeDemoData.userListPage(
        query: query,
        limit: pageLimit,
        offset: offset,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/users/list').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
            if (role.trim().isNotEmpty) 'role': role.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin user list failed');
    }
    return AdminUserListPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
