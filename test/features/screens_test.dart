// Widget tests for every screen, with real content, an in-memory user
// database and a fake reflection finder (the model needs native code).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/app/app.dart';
import 'package:stoic_quotes/app/providers.dart';
import 'package:stoic_quotes/core/reflection_service.dart';
import 'package:stoic_quotes/core/user/user_database.dart';
import 'package:stoic_quotes/core/user/user_repository.dart';

import '../helpers.dart';

void main() {
  final content = loadContentFromDisk();
  late UserRepository repo;
  late FakeReflectionFinder finder;

  setUp(() {
    repo = UserRepository(openTestUserDatabase());
    finder = FakeReflectionFinder(content);
  });

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
            (ref) async => finder as ReflectionFinder,
          ),
        ],
        child: const StoicQuotesApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    // Dispose the widgets (and their drift stream listeners) first; the
    // in-memory database is simply dropped with the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Reflect: text in, situation and explanation first cards out', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(
      find.text('This app offers reflection, not therapy.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField),
      'I keep procrastinating on my thesis',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reflect'));
    await tester.pumpAndSettle();

    final situation = content.situations['procrastination']!;
    // The title also appears as an example chip above.
    expect(find.text(situation.title), findsWidgets);
    final first = content.quote(situation.quoteIds.first)!;
    expect(find.text(first.explanation), findsOneWidget);
    expect(find.text(first.text), findsOneWidget);
    expect(find.text('How it applies'), findsWidgets);
    // The exercise is at the end of the results.
    await tester.scrollUntilVisible(
      find.text('Try this'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Try this'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Reflect: a crisis shows help, never quotes', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'crisis');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reflect'));
    await tester.pumpAndSettle();
    expect(find.text('You are not alone'), findsOneWidget);
    expect(find.text('Call 142'), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);
    expect(find.text("I'm safe, show my reflections"), findsNothing);
    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('How it applies'), findsNothing);
    await finish(tester);
  });

  testWidgets('Reflect: a possible crisis lets the user continue', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'maybe crisis');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reflect'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text("I'm safe, show my reflections"),
      200,
    );
    await tester.tap(find.text("I'm safe, show my reflections"));
    await tester.pumpAndSettle();
    expect(finder.calls.last, ('maybe crisis', true));
    expect(find.text('Reflections that may help'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Explore: a quote, next and previous, favorite', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
    String shownExplanation() => content.quotes
        .firstWhere((q) => find.text(q.explanation).evaluate().isNotEmpty)
        .explanation;
    final first = shownExplanation();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(shownExplanation(), isNot(first));
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(shownExplanation(), first);
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    expect(await repo.seenQuoteIds(), hasLength(2));
    await finish(tester);
  });

  testWidgets('Favorites: empty state, then a saved quote, then removed', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Favorites').last);
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);

    await repo.addFavorite('ma-4-3-a');
    await tester.pumpAndSettle();
    final q = content.quote('ma-4-3-a')!;
    expect(find.text(q.explanation), findsOneWidget);

    await tester.tap(find.text(q.explanation));
    await tester.pumpAndSettle();
    expect(find.text(q.context), findsOneWidget); // detail page, passage open
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('About: privacy, safety, sources and licenses', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('About and safety'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.textContaining('No data leaves your device'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sources'), 300);
    expect(find.textContaining('George Long'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Open source licenses'), 300);
    expect(find.text('Open source licenses'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Semantics: buttons have labels for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    // Icon buttons expose their tooltip to TalkBack as the spoken description.
    for (final tip in [
      'Add to favorites',
      'Share as image',
      'About and safety',
    ]) {
      expect(
        tester.getSemantics(find.byTooltip(tip)),
        isSemantics(tooltip: tip, isButton: true, hasTapAction: true),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    await finish(tester);
  });
}
