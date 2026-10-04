import 'dart:convert';

import '../network/server_endpoint_store.dart';
import 'state/app_session.dart';

/// Identity and authorization for a short-lived read, excluding token refreshes.
/// A same-account reauthentication can increment the session revision without
/// changing which data a pending read or user action is allowed to use.
String currentSessionReadScope() {
  final profile = AppSession.instance.profile;
  return jsonEncode([
    ServerEndpointStore.instance.baseUrl,
    profile?.role.name,
    profile?.ref,
    _sortedScopeValues(profile?.effectiveCapabilities ?? const []),
    _sortedScopeValues(profile?.assignedApparatus ?? const []),
    _sortedScopeValues(profile?.assignedItemGroups ?? const []),
    _sortedScopeValues(profile?.assignedWarehouses ?? const []),
  ]);
}

List<String> _sortedScopeValues(List<String> values) =>
    values.toSet().toList()..sort();
