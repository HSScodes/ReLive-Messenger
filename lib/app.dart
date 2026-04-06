import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wlm_project/l10n/app_localizations.dart';

import 'screens/login/login_screen.dart';

class WlmApp extends ConsumerWidget {
  const WlmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textTheme = TextTheme(
      bodyMedium: TextStyle(fontFamily: 'SegoeUI'),
      bodyLarge: TextStyle(fontFamily: 'SegoeUI'),
      titleLarge: TextStyle(fontFamily: 'SegoeUI', fontWeight: FontWeight.w600),
    );

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF33A7E8)),
        fontFamily: 'SegoeUI',
        textTheme: textTheme,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
