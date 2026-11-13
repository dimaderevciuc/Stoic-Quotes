import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/focus/focus_areas.dart';
import '../../core/reflection_service.dart';
import '../../core/safety/crisis_detector.dart';
import '../common/quote_card.dart';
import '../common/reflection_note.dart';
import 'exercise_card.dart';

/// Home: describe what is going on, get a matched situation and quotes.
///
/// Privacy: the text lives only in this widget's memory. It is never saved,
/// logged or sent anywhere.
class SituationScreen extends ConsumerStatefulWidget {
  const SituationScreen({super.key});

  /// Suggestions when the person has no focus picks.
  static const examples = ['I keep procrastinating', "I'm not good enough"];

  @override
  ConsumerState<SituationScreen> createState() => _SituationScreenState();
}

class _SituationScreenState extends ConsumerState<SituationScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  FoundReflection? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reflect({bool acceptedPossibleCrisis = false}) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _focus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final finder = await ref.read(reflectionFinderProvider.future);
      final reflection = await finder.reflect(
        text,
        acceptedPossibleCrisis: acceptedPossibleCrisis,
      );
      if (!mounted) return;
      switch (reflection) {
        case CrisisReflection(:final level):
          setState(() => _busy = false);
          final proceed = await context.push<bool>('/crisis', extra: level);
          if (proceed == true && level == CrisisLevel.possible && mounted) {
            await _reflect(acceptedPossibleCrisis: true);
          }
        case FoundReflection():
          setState(() {
            _busy = false;
            _result = reflection;
          });
          unawaited(HapticFeedback.selectionClick());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (_scroll.hasClients) {
            await _scroll.animateTo(
              260,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          }
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong while reflecting. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelReady = ref.watch(reflectionFinderProvider).hasValue;
    final result = _result;
    // Suggestions follow the focus picks; the defaults otherwise.
    final content = ref.watch(contentProvider).value;
    final picks = resolveFocusAreas(
      ref.watch(focusAreaIdsProvider).value ?? const [],
    );
    final suggestions = content == null
        ? SituationScreen.examples
        : suggestionTitles(picks, content, fallback: SituationScreen.examples);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stoic Quotes'),
        actions: [
          IconButton(
            tooltip: 'About and safety',
            onPressed: () => context.push('/about'),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text("What's on your mind?", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Describe what you are going through in your own words. ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focus,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: 'Type here...'),
              onChanged: (_) => setState(() {}),
            ),
            // One row that scrolls sideways keeps the Reflect button in view.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final example in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(example),
                        onPressed: () {
                          _controller.text = example;
                          setState(() {});
                          _reflect();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _controller.text.trim().isEmpty || _busy
                  ? null
                  : _reflect,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.self_improvement),
              label: Text(_busy && !modelReady ? 'Preparing...' : 'Reflect'),
            ),
            const SizedBox(height: 12),
            const Center(child: ReflectionNote()),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: result == null
                  ? const SizedBox.shrink()
                  : _Results(key: ValueKey(result), result: result),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.result});

  final FoundReflection result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final situation = result.situation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Semantics(
          header: true,
          child: Text(
            situation?.title ?? 'Reflections that may help',
            style: theme.textTheme.titleLarge?.copyWith(color: AppColors.amber),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          situation == null
              ? 'Thoughts from Stoic writers on what you described.'
              : 'Thoughts from Stoic writers for this situation.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        for (final quote in result.quotes) ...[
          QuoteCard(
            quote: quote,
            application: situation?.applications[quote.id],
          ),
          const SizedBox(height: 14),
        ],
        if (situation != null) ExerciseCard(steps: situation.exercise),
      ],
    );
  }
}
