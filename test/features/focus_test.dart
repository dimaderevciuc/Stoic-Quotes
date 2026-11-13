// The first-launch intro, focus picks, Explore "For you" and the Reflect
// suggestions that follow the picks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/app/app.dart';
import 'package:stoic_quotes/app/providers.dart';
import 'package:stoic_quotes/core/focus/focus_areas.dart';
import 'package:stoic_quotes/core/reflection_service.dart';
import 'package:stoic_quotes/core/user/user_database.dart';
import 'package:stoic_quotes/core/user/user_repository.dart';

import '../helpers.dart';

void main() {
  final content = loadContentFromDisk();
  late UserRepository repo;

  setUp(() => repo = UserRepository(openTestUserDatabase()));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
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
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  String title(String areaId) => focusAreaById(areaId)!.title;

  Future<void> pick(WidgetTester tester, String areaId) async {
    final tile = find.text(title(areaId));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  testWidgets('first launch: intro pages, pick focus areas, then Reflect', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text("Wisdom for what you're going through"), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('How to use it'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Yours alone'), findsOneWidget);
    expect(find.textContaining('What you type is never saved'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('What would you like to focus on?'), findsOneWidget);
    expect(find.text('0 of 5 chosen'), findsOneWidget);
    // Start needs at least one pick.
    final start = find.widgetWithText(FilledButton, 'Start');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await pick(tester, 'discipline');
    await pick(tester, 'calm');

    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(await repo.focusAreaIds(), ['discipline', 'calm']);
    expect(await repo.introSeen(), isTrue);
    // Suggestions follow the picks.
    expect(
      find.text(content.situations['overthinking']!.title),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('no more than 5 picks', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    for (final a in focusAreas.take(6)) {
      await pick(tester, a.id);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();
    expect(await repo.focusAreaIds(), [
      for (final a in focusAreas.take(5)) a.id,
    ]);
    await finish(tester);
  });

  testWidgets('skipping saves no picks and does not show the intro again', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(await repo.focusAreaIds(), isEmpty);
    expect(await repo.introSeen(), isTrue);
    await finish(tester);

    await pumpApp(tester);
    expect(find.text("What's on your mind?"), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Explore: Random first, For you shows quotes for the picks', (
    tester,
  ) async {
    await repo.markIntroSeen();
    await repo.setFocusAreaIds(['loss', 'pushing-further']);
    await pumpApp(tester);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Random'), findsOneWidget);
    expect(find.text(title('loss')), findsNothing);

    await tester.tap(find.text('For you'));
    await tester.pumpAndSettle();
    expect(find.text('Edit picks'), findsOneWidget);
    // The first card is labelled with the first pick, the next with the second.
    expect(find.text(title('loss')), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text(title('pushing-further')), findsOneWidget);

    // Editing the picks updates the tab.
    await tester.tap(find.text('Edit picks'));
    await tester.pumpAndSettle();
    expect(find.text('Your focus'), findsOneWidget);
    await pick(tester, 'loss');
    await pick(tester, 'pushing-further');
    await pick(tester, 'temper');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await repo.focusAreaIds(), ['temper']);
    // The header line and the card label.
    expect(find.text(title('temper')), findsNWidgets(2));
    await finish(tester);
  });

  testWidgets('Explore: For you without picks asks for them', (tester) async {
    await repo.markIntroSeen();
    await pumpApp(tester);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('For you'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your focus'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to focus on?'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('About: view the intro again and return', (tester) async {
    await repo.markIntroSeen();
    await pumpApp(tester);
    await tester.tap(find.byTooltip('About and safety'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View intro again'));
    await tester.pumpAndSettle();
    expect(find.text("Wisdom for what you're going through"), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('About and safety'), findsOneWidget);
    await finish(tester);
  });
}
