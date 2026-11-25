import 'dart:convert';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/qolip_rework_http.dart';

const _filename = 'ko‘k andoza.pdf';
const _body = '%PDF attachment';
const _details = 'Ko‘k qolipdagi belgini tekshiring';
const _product = 'Tanlangan mahsulot';
const _productCode = 'ITEM-TARGET';
const _base = '/v1/mobile/qolip/products';

class _FilePicker extends FilePicker {
  ({String? name, Uint8List? bytes})? saved;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(withReadStream, isTrue);
    final bytes = utf8.encode(_body);
    return FilePickerResult([
      PlatformFile(
        name: _filename,
        size: bytes.length,
        readStream: Stream.value(bytes),
      ),
    ]);
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saved = (name: fileName, bytes: bytes);
    return fileName;
  }
}

http.Response _json(Map<String, Object?> data, {int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  testWidgets(
      'qolipchi attaches a file to an unavailable product and reopens it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    QolipCatalogStore.instance.reset();
    AppSession.instance.token = 'qolip-information-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolip-product-information',
      phone: '',
      avatarUrl: '',
    );
    final picker = _FilePicker();
    FilePicker.platform = picker;
    addTearDown(() {
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
      QolipCatalogStore.instance.reset();
    });

    final productId = qolipCatalogId(_productCode);
    final uploads = <http.Request>[];
    var saved = false;
    Map<String, Object?> information() => {
          'information': {
            'revision': saved ? 1 : 0,
            'details': saved ? _details : '',
            'attachment_name': saved ? _filename : null,
            'attachment_size': saved ? _body.length : null,
          },
        };

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: QolipProductsScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.text(_product));
      await tester.pumpAndSettle();
      expect(find.text('1 ta tanlandi'), findsOneWidget);
      expect(find.byTooltip('Tanlanganlarni o‘chirish'), findsNothing);
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      expect(find.text('Qolip qo‘shish'), findsNothing);
      await tester.tap(find.text('Ma’lumot qo‘shish'));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, 'Yozma tafsilot');
      await tester.enterText(field, _details);
      await tester.tap(find.text('Fayl biriktirish'));
      await tester.pumpAndSettle();
      expect(find.text(_filename), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
      await tester.pumpAndSettle();
      expect(find.text('Ma’lumotni saqlab bo‘lmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, _details);
      expect(find.text(_filename), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
      await tester.pumpAndSettle();
      expect(uploads, hasLength(2));
      for (final upload in uploads) {
        expect(upload.url.queryParameters, {'id': productId});
        expect(
            upload.headers['Authorization'], 'Bearer qolip-information-token');
        final multipart = utf8.decode(upload.bodyBytes);
        expect(multipart, contains('"revision":0'));
        expect(multipart, contains(_details));
        expect(multipart, contains(_filename));
        expect(multipart, contains(_body));
      }

      await tester.tap(find.text('Ma’lumotni ko‘rish'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SelectableText, _details), findsOneWidget);
      await tester.tap(find.byTooltip('Faylni yuklab olish'));
      await tester.pumpAndSettle();
      expect(picker.saved?.name, _filename);
      expect(picker.saved?.bytes, utf8.encode(_body));
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => qolipCatalogClient((request) async {
              switch (request.url.path) {
                case '$_base/page':
                  return _json({
                    'items': [
                      {'id': productId, 'name': _product},
                      {
                        'id': qolipCatalogId('ITEM-OTHER'),
                        'name': 'Ikkinchi mahsulot'
                      },
                    ],
                    'has_more': false,
                  });
                case '$_base/detail':
                  expect(request.url.queryParameters, {'id': productId});
                  return _json({
                    'information_status': {
                      'revision': saved ? 1 : 0,
                      'has_content': saved,
                    },
                    'products': [
                      {
                        'code': _productCode,
                        'name': _product,
                        'qolip_code': 'M-1',
                        'qolip_set_id': 'K-1',
                        'is_in_use': true,
                      },
                      {
                        'code': _productCode,
                        'name': _product,
                        'qolip_code': 'M-2',
                        'qolip_set_id': 'K-2',
                      },
                    ],
                  });
                case '$_base/information':
                  expect(request.url.queryParameters, {'id': productId});
                  if (request.method == 'PUT') {
                    uploads.add(request);
                    if (uploads.length == 1) return _json({}, status: 502);
                    saved = true;
                  }
                  return _json(information());
                case '$_base/information/attachment':
                  expect(request.url.queryParameters,
                      {'id': productId, 'revision': '1'});
                  return http.Response(
                    _body,
                    200,
                    headers: {'content-type': 'application/octet-stream'},
                  );
                default:
                  return _json({}, status: 404);
              }
            }));
  });
}
