import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/utils/constants.dart';
import 'theme/monaco_theme.dart';

class MonacoApp extends ConsumerWidget {
  const MonacoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: MonacoTheme.dark,
      darkTheme: MonacoTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Evita que el texto gigante del sistema rompa las láminas: se respeta
      // la accesibilidad hasta 1.3x, que es lo que el layout aguanta.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
