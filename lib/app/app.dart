import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/router/app_router.dart';
import 'theme/monaco_theme.dart';

class MonacoApp extends ConsumerWidget {
  const MonacoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'barberOS',
      debugShowCheckedModeBanner: false,
      theme: MonacoTheme.dark,
      routerConfig: router,
    );
  }
}
