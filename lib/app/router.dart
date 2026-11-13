import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/safety/crisis_detector.dart';
import '../features/about/about_screen.dart';
import '../features/crisis/crisis_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/focus/focus_picker.dart';
import '../features/intro/intro_screen.dart';
import '../features/quote/quote_detail_screen.dart';
import '../features/situation/situation_screen.dart';

/// [needsIntro] is asked once, on the first navigation to Reflect, so the
/// introduction shows on first launch only.
GoRouter buildRouter({Future<bool> Function()? needsIntro}) {
  var introChecked = false;
  return GoRouter(
    redirect: (context, state) async {
      if (introChecked || needsIntro == null) return null;
      introChecked = true;
      if (state.matchedLocation != '/') return null;
      return await needsIntro() ? '/intro' : null;
    },
    routes: _routes,
  );
}

final _routes = <RouteBase>[
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => AppShell(shell: shell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SituationScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (_, _) => const FavoritesScreen(),
          ),
        ],
      ),
    ],
  ),
  GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
  GoRoute(
    path: '/intro',
    builder: (_, state) =>
        IntroScreen(again: state.uri.queryParameters['again'] == '1'),
  ),
  GoRoute(path: '/focus', builder: (_, _) => const FocusScreen()),
  GoRoute(
    path: '/quote/:id',
    builder: (_, state) =>
        QuoteDetailScreen(quoteId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/crisis',
    pageBuilder: (_, state) => MaterialPage(
      fullscreenDialog: true,
      child: CrisisScreen(
        level: state.extra as CrisisLevel? ?? CrisisLevel.certain,
      ),
    ),
  ),
];

/// Bottom navigation: Reflect, Explore, Favorites.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement),
            label: 'Reflect',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
