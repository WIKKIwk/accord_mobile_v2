import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({super.key, required this.home, this.theme});

  final Widget home;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: home,
      );
}
