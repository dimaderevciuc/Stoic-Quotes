import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/content/content_repository.dart';
import '../../core/user/user_repository.dart';
import '../common/quote_card.dart';
import 'shuffle_bag.dart';

/// Random quotes, like the first version of the app: swipe or use
/// Previous and Next. The favorite heart is on each card.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final repo = ref.watch(userRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'About and safety',
            onPressed: () => context.push('/about'),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: switch ((content, repo)) {
        (AsyncData(value: final c), AsyncData(value: final r)) => _Explorer(
          content: c,
          repo: r,
        ),
        (AsyncError(), _) || (_, AsyncError()) => const Center(
          child: Text('Could not load the quotes.'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Explorer extends StatefulWidget {
  const _Explorer({required this.content, required this.repo});

  final Content content;
  final UserRepository repo;

  @override
  State<_Explorer> createState() => _ExplorerState();
}

class _ExplorerState extends State<_Explorer> {
  ShuffleBag? _bag;
  final _history = <String>[];
  int _index = -1;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final seen = await widget.repo.seenQuoteIds();
    _bag = ShuffleBag([for (final q in widget.content.quotes) q.id], seen);
    await _next();
  }

  Future<void> _next() async {
    final bag = _bag;
    if (bag == null) return;
    if (_index < _history.length - 1) {
      setState(() {
        _forward = true;
        _index++;
      });
      return;
    }
    final id = bag.draw(avoid: _index >= 0 ? _history[_index] : null);
    if (bag.startedNewRound) await widget.repo.clearSeen();
    await widget.repo.markSeen(id);
    if (!mounted) return;
    setState(() {
      _forward = true;
      _history.add(id);
      _index = _history.length - 1;
    });
  }

  void _previous() {
    if (_index <= 0) return;
    setState(() {
      _forward = false;
      _index--;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index < 0) return const Center(child: CircularProgressIndicator());
    final quote = widget.content.quote(_history[_index])!;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              // Swipe left for the next quote, right for the previous one.
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -200) {
                  HapticFeedback.selectionClick();
                  _next();
                } else if (v > 200) {
                  HapticFeedback.selectionClick();
                  _previous();
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(_forward ? 0.08 : -0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: QuoteCard(key: ValueKey(quote.id), quote: quote),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _index > 0 ? _previous : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    iconAlignment: IconAlignment.end,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Swipe to browse',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
