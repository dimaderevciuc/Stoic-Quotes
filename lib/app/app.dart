import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class StoicQuotesApp extends ConsumerStatefulWidget {
  const StoicQuotesApp({super.key, this.router});

  /// Tests pass their own router; the app builds the default one.
  final GoRouter? router;

  @override
  ConsumerState<StoicQuotesApp> createState() => _StoicQuotesAppState();
}

class _StoicQuotesAppState extends ConsumerState<StoicQuotesApp> {
  late final GoRouter _router =
      widget.router ?? buildRouter(needsIntro: _needsIntro);

  Future<bool> _needsIntro() async {
    try {
      final repo = await ref.read(userRepositoryProvider.future);
      return !await repo.introSeen();
    } on Object {
      // Never block the app on the intro.
      return false;
    }
  }

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
