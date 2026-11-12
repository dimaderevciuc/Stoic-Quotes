// Renders every screen at phone size with the real fonts, for the Checkpoint 4
// screenshots. Opt in, because golden images differ between machines:
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/app/app.dart';
import 'package:stoic_quotes/app/providers.dart';
import 'package:stoic_quotes/core/reflection_service.dart';
import 'package:stoic_quotes/core/user/user_database.dart';
import 'package:stoic_quotes/core/user/user_repository.dart';

import '../helpers.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  final content = loadContentFromDisk();

  setUpAll(() async {
    if (!_enabled) return;
    await _loadFont('Inter', ['assets/fonts/Inter.ttf']);
    await _loadFont('Lora', [
      'assets/fonts/Lora.ttf',
      'assets/fonts/Lora-Italic.ttf',
    ]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _loadFont('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  Future<UserRepository> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final repo = UserRepository(openTestUserDatabase());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentProvider.overrideWith((ref) async => content),
          userRepositoryProvider.overrideWith((ref) async => repo),
          reflectionFinderProvider.overrideWith(
            (ref) async => FakeReflectionFinder(content) as ReflectionFinder,
          ),
        ],
        child: const StoicQuotesApp(),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(StoicQuotesApp),
      matchesGoldenFile('../../screenshots/$name.png'),
    );
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('screenshots', (tester) async {
    final repo = await pumpApp(tester);
    await shot(tester, '1-reflect');

    await tester.enterText(
      find.byType(TextField),
      'I keep procrastinating on my thesis and feel guilty about it',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reflect'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await shot(tester, '2-reflect-results');
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await shot(tester, '3-reflect-exercise');

    await repo.addFavorite('sen-shortness-9-a');
    await repo.addFavorite('ma-4-3-a');
    await repo.addFavorite('epi-ench-5-a');
    await tester.tap(find.text('Explore'));
    await shot(tester, '4-explore');

    await tester.tap(find.text('Favorites').last);
    await shot(tester, '5-favorites');

    await tester.tap(find.byTooltip('About and safety'));
    await shot(tester, '6-about');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reflect').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'maybe crisis');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reflect'));
    await shot(tester, '7-crisis');
    await done(tester);
  }, skip: !_enabled);
}
