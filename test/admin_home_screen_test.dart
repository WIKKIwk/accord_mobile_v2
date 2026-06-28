import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/motion_widgets.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_home_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_navigation_drawer.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_store.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/profile_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('admin home defers summary load until after first frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['party.supplier.read'],
    );
    AdminStore.instance.clear();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminHomeScreen(),
        ),
      );

      expect(seenRequests, isEmpty);
      expect(AdminStore.instance.loadingSummary, isFalse);
      for (var i = 0; i < 20 && seenRequests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(seenRequests, contains('GET /v1/mobile/admin/suppliers/summary'));
    }, createHttpClient: (_) => _SummaryHttpClient(seenRequests));
  });

  testWidgets('custom catalog role opens admin home without summary request', (
    tester,
  ) async {
    final seenRequests = <String>[];
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.customer,
      displayName: 'Custom operator',
      legalName: '',
      ref: 'custom',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'catalog.item.read',
        'catalog.item.create',
        'gscale.print',
        'rps.batch.manage',
      ],
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mahsulot qo‘shish'), findsOneWidget);
      expect(find.text('GScale'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SmoothAppear,
        ),
        findsNothing,
      );
      expect(find.text('Uy'), findsOneWidget);
      expect(find.text('Foydalanuvchilar'), findsNothing);
      expect(find.text('Faoliyat'), findsNothing);
      expect(find.text('Jami users'), findsNothing);
      expect(seenRequests, isEmpty);
    }, createHttpClient: (_) => _RecordingHttpClient(seenRequests));
  });

  testWidgets('custom catalog role drawer hides blocked admin routes', (
    tester,
  ) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.customer,
      displayName: 'Custom operator',
      legalName: '',
      ref: 'custom',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'catalog.item.read',
        'catalog.item.create',
        'gscale.print',
        'rps.batch.manage',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.earthy),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AdminNavigationDrawer(selectedIndex: 0, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uy'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Tarozilar rejimi'), findsOneWidget);
    expect(find.text('Foydalanuvchilar'), findsNothing);
    expect(find.text('Harakatlar'), findsNothing);
    expect(find.text('Rollar'), findsNothing);
  });

  testWidgets('admin drawer shows apparatus groups route', (tester) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'production.map.manage'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.earthy),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AdminNavigationDrawer(selectedIndex: 0, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ish xaritasi'), findsOneWidget);
    expect(find.text('Yarim tayyor mahsulotlar'), findsOneWidget);
    expect(find.text('Aparatlar'), findsOneWidget);
  });

  testWidgets('admin drawer labels follow selected language', (tester) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'production.map.manage'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.earthy),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AdminNavigationDrawer(selectedIndex: 0, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work map'), findsOneWidget);
    expect(find.text('Semi-finished products'), findsOneWidget);
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Ish xaritasi'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.earthy),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AdminNavigationDrawer(selectedIndex: 0, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Карта работ'), findsOneWidget);
    expect(find.text('Полуфабрикаты'), findsOneWidget);
    expect(find.text('Оборудование'), findsOneWidget);
    expect(find.text('Work map'), findsNothing);
  });

  testWidgets('profile labels follow selected language', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.customer,
      displayName: 'Custom operator',
      legalName: '',
      ref: 'custom',
      phone: '',
      avatarUrl: '',
      capabilities: ['catalog.item.read'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.earthy),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Role-based account'), findsOneWidget);
    expect(find.text('Profile settings'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.text('Security'), findsNothing);

    await tester.tap(find.text('Profile settings'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Choose the app language'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Role asosidagi account'), findsNothing);
    expect(find.text('Til'), findsNothing);
    expect(find.text('Xavfsizlik'), findsNothing);
  });

  testWidgets('admin home summary labels follow selected language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'admin.access',
        'catalog.item.read',
        'catalog.item.create',
        'catalog.item_group.create',
        'party.supplier.read',
        'party.supplier.create',
        'warehouse.read',
        'production.map.manage',
        'production.wip.read',
        'gscale.print',
        'server.monitor.read',
      ],
    );
    AdminStore.instance.clear();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminHomeScreen(),
        ),
      );
      for (var i = 0;
          i < 20 && find.text('Total users').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Total users'), findsOneWidget);
      expect(find.text('Active users'), findsOneWidget);
      expect(find.text('Blocked users'), findsOneWidget);
      expect(find.text('Jami users'), findsNothing);
    }, createHttpClient: (_) => _SummaryHttpClient(<String>[]));
  });

  testWidgets('admin home action labels follow selected language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.customer,
      displayName: 'Custom operator',
      legalName: '',
      ref: 'custom',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'admin.access',
        'catalog.item.read',
        'catalog.item.create',
        'catalog.item.bulk_move',
        'catalog.item_group.read',
        'catalog.item_group.manage',
        'production.map.manage',
        'raw_material.rule.manage',
        'raw_material.assign',
        'gscale.print',
      ],
    );
    AdminStore.instance.clear();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Warehouses'), findsOneWidget);
      expect(find.text('Ombor'), findsNothing);

      await tester.dragUntilVisible(
        find.text('Quick orders'),
        find.byType(ListView),
        const Offset(0, -320),
      );
      expect(find.text('Quick orders'), findsOneWidget);
      expect(find.text('Tezkor buyurtmalar'), findsNothing);

      await tester.dragUntilVisible(
        find.text('Work map'),
        find.byType(ListView),
        const Offset(0, -320),
      );
      expect(find.text('Work map'), findsOneWidget);
      expect(find.text('reja menu'), findsNothing);

      await tester.dragUntilVisible(
        find.text('Semi-finished products'),
        find.byType(ListView),
        const Offset(0, -320),
      );
      expect(find.text('Semi-finished products'), findsOneWidget);
      expect(find.text('Oraliq mahsulotlar'), findsNothing);
    }, createHttpClient: (_) => _RecordingHttpClient(<String>[]));
  });

  testWidgets('custom catalog profile home returns to capability home route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.customer,
      displayName: 'Custom operator',
      legalName: '',
      ref: 'custom',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'catalog.item.read',
        'catalog.item.create',
        'gscale.print',
        'rps.batch.manage',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.earthy),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bildirish'), findsNothing);

    await tester.tap(find.text('Uy').last);
    await tester.pumpAndSettle();

    expect(find.text('Ruxsat yo‘q'), findsNothing);
    expect(find.text('Mahsulot qo‘shish'), findsOneWidget);
  });
}

class _RecordingHttpClient extends Fake implements HttpClient {
  _RecordingHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    seenRequests.add('GET ${url.path}');
    throw UnsupportedError('unexpected HTTP request: $url');
  }
}

class _SummaryHttpClient extends Fake implements HttpClient {
  _SummaryHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    seenRequests.add('$method ${url.path}');
    return _SummaryHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
}

class _SummaryHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  bool bufferOutput = true;

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  HttpHeaders get headers => _SummaryHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _SummaryHttpClientResponse();
}

class _SummaryHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final List<int> _bytes = utf8.encode(
    '{"total_suppliers":1,"active_suppliers":1,"blocked_suppliers":0}',
  );

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _SummaryHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  String get reasonPhrase => '';

  @override
  bool get persistentConnection => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      throw UnsupportedError('redirect');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SummaryHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}
