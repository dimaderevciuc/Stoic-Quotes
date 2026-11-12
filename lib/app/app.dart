import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

class StoicQuotesApp extends StatefulWidget {
  const StoicQuotesApp({super.key, this.router});

  /// Tests pass their own router; the app builds the default one.
  final GoRouter? router;

  @override
  State<StoicQuotesApp> createState() => _StoicQuotesAppState();
}

class _StoicQuotesAppState extends State<StoicQuotesApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stoic Quotes',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}
