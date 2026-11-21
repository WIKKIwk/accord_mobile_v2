import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/lists/app_segment_surface_card.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'metalayzer_navigation.dart';

class MetalayzerMaterialsScreen extends StatefulWidget {
  const MetalayzerMaterialsScreen({super.key});

  @override
  State<MetalayzerMaterialsScreen> createState() =>
      _MetalayzerMaterialsScreenState();
}

class _MetalayzerMaterialsScreenState extends State<MetalayzerMaterialsScreen> {
  List<MetalayzerMaterial> _items = [];
  String? _scope, _cursor, _error, _moreError;
  bool _loading = false, _loadingMore = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scope = _currentScope();
    AppSession.instance.revision.addListener(_sessionChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  String? _currentScope() {
    try {
      return MobileApi.instance.metalayzerScope();
    } on StateError {
      return null;
    }
  }

  void _sessionChanged() {
    final scope = _currentScope();
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _requestId++;
      _items = [];
      _cursor = _error = _moreError = null;
      _loading = _loadingMore = false;
    });
    unawaited(_load());
  }

  bool _isCurrent(int requestId, String scope) =>
      mounted && requestId == _requestId && scope == _currentScope();

  Future<void> _load({bool append = false}) async {
    final scope = _scope;
    final cursor = append ? _cursor : null;
    if (scope == null || scope != _currentScope()) return;
    if (append && (cursor == null || _loading || _loadingMore)) return;

    final requestId = ++_requestId;
    setState(() {
      _loading = !append;
      _loadingMore = append;
      _error = _moreError = null;
    });
    try {
      final page = await MobileApi.instance.metalayzerMaterials(cursor: cursor);
      if (!_isCurrent(requestId, scope)) return;
      setState(() {
        final seen = <String>{
          if (append)
            for (final item in _items) item.barcode.trim().toLowerCase(),
        };
        _items = [
          if (append) ..._items,
          for (final item in page.items)
            if (seen.add(item.barcode.trim().toLowerCase())) item,
        ];
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (!_isCurrent(requestId, scope)) return;
      final message = switch (error) {
        MobileApiException() => error.message,
        FormatException() => 'Xomashyo ro‘yxati tasdiqlanmadi',
        _ => 'Ro‘yxatni yuklab bo‘lmadi',
      };
      setState(() {
        if (append) {
          _moreError = message;
        } else {
          _error = message;
        }
      });
    } finally {
      if (_isCurrent(requestId, scope)) {
        setState(() => _loading = _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      title: metalayzerMaterialsTitle,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      appBarBottomLoading: _loading && _items.isNotEmpty,
      drawer: const MetalayzerDrawer(
        selectedRouteName: AppRoutes.metalayzerMaterials,
      ),
      bottom: const MetalayzerDock(),
      child: AppRefreshIndicator(
        onRefresh: _load,
        allowRefreshOnShortContent: true,
        child: CustomScrollView(
          primary: true,
          physics: const TopRefreshScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverMainAxisGroup(slivers: [
                if (_scope == null)
                  const SliverToBoxAdapter(
                    child: Text('Metalayzer akkaunti bilan kiring.'),
                  )
                else if (_loading && _items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Center(child: AppLoadingIndicator()),
                  )
                else if (_error != null)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              style: TextStyle(color: scheme.error)),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  )
                else if (_items.isEmpty)
                  const SliverToBoxAdapter(
                    child:
                        Center(child: Text('Metallangan xomashyo hali yo‘q')),
                  ),
                SliverList.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppSegmentSurfaceCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading:
                              Icon(Icons.check_circle, color: scheme.primary),
                          title: Text(item.itemName.isEmpty
                              ? item.itemCode
                              : item.itemName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.warehouse),
                              SelectableText('QR: ${item.barcode}'),
                              Text(formatQuantityWithUnit(item.qty, item.uom,
                                  decimalPlaces: 6, trimTrailingZeros: true)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_cursor != null && _error == null)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_moreError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(_moreError!,
                                style: TextStyle(color: scheme.error)),
                          ),
                        OutlinedButton(
                          onPressed: _loading || _loadingMore
                              ? null
                              : () => _load(append: true),
                          style: appOutlinedActionButtonStyle(),
                          child: Text(_loadingMore
                              ? 'Yuklanmoqda...'
                              : _moreError != null
                                  ? 'Qayta urinish'
                                  : 'Yana yuklash'),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
