import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/content/content_repository.dart';
import '../../core/focus/focus_areas.dart';
import '../../core/focus/for_you_feed.dart';
import '../../core/user/user_repository.dart';
import '../common/quote_card.dart';
import 'shuffle_bag.dart';

/// Two tabs: Random (like the first version of the app) and For you (quotes
/// for the person's focus picks). Swipe or use Previous and Next in both.
/// Always opens on Random.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final repo = ref.watch(userRepositoryProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explore'),
          actions: [
            IconButton(
              tooltip: 'About and safety',
              onPressed: () => context.push('/about'),
              icon: const Icon(Icons.info_outline),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            dividerColor: Colors.transparent,
            indicatorColor: AppColors.amber,
            labelColor: AppColors.amber,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'Random'),
              Tab(text: 'For you'),
            ],
          ),
        ),
        body: switch ((content, repo)) {
          (AsyncData(value: final c), AsyncData(value: final r)) => _Tabs(
            content: c,
            repo: r,
          ),
          (AsyncError(), _) || (_, AsyncError()) => const Center(
            child: Text('Could not load the quotes.'),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// No TabBarView: its sideways swipe would fight the swipe between quotes.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.content, required this.repo});

  final Content content;
  final UserRepository repo;

  @override
  Widget build(BuildContext context) {
    final tabs = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) => IndexedStack(
        index: tabs.index,
        children: [
          _QuoteBrowser(
            key: const ValueKey('random'),
            content: content,
            createSource: () => _RandomSource(content, repo),
          ),
          _ForYou(content: content),
        ],
      ),
    );
  }
}

/// Where the next quote comes from; [FocusArea] is shown above the card.
abstract class _Source {
  Future<({String id, FocusArea? area})> next({String? avoid});
}

/// Every quote once before any repeats; the round is kept in user.db.
class _RandomSource implements _Source {
  _RandomSource(this.content, this.repo);

  final Content content;
  final UserRepository repo;
  ShuffleBag? _bag;

  @override
  Future<({String id, FocusArea? area})> next({String? avoid}) async {
    final bag = _bag ??= ShuffleBag([
      for (final q in content.quotes) q.id,
    ], await repo.seenQuoteIds());
    final id = bag.draw(avoid: avoid);
    if (bag.startedNewRound) await repo.clearSeen();
    await repo.markSeen(id);
    return (id: id, area: null);
  }
}

class _FeedSource implements _Source {
  _FeedSource(this.feed);

  final ForYouFeed feed;

  @override
  Future<({String id, FocusArea? area})> next({String? avoid}) async {
    final pick = feed.next(avoid: avoid);
    return (id: pick.quoteId, area: pick.area);
  }
}

class _ForYou extends ConsumerWidget {
  const _ForYou({required this.content});

  final Content content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ids = ref.watch(focusAreaIdsProvider).value;
    if (ids == null) return const Center(child: CircularProgressIndicator());
    final picks = resolveFocusAreas(ids);
    if (picks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 40, color: AppColors.amber),
              const SizedBox(height: 16),
              Text(
                'Quotes for what matters to you',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose up to ${FocusArea.maxPicks} things you would like to '
                'focus on, and this tab will show quotes for them.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push('/focus'),
                child: const Text('Choose your focus'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  [for (final a in picks) a.title].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/focus'),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Edit picks'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _QuoteBrowser(
            // A new feed whenever the picks change.
            key: ValueKey(ids.join(',')),
            content: content,
            createSource: () => _FeedSource(ForYouFeed(picks, content)),
          ),
        ),
      ],
    );
  }
}

class _QuoteBrowser extends StatefulWidget {
  const _QuoteBrowser({
    super.key,
    required this.content,
    required this.createSource,
  });

  final Content content;

  /// Called once, so the source keeps its place across rebuilds.
  final _Source Function() createSource;

  @override
  State<_QuoteBrowser> createState() => _QuoteBrowserState();
}

class _QuoteBrowserState extends State<_QuoteBrowser> {
  late final _Source _source = widget.createSource();
  final _history = <({String id, FocusArea? area})>[];
  int _index = -1;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _next();
  }

  Future<void> _next() async {
    if (_index < _history.length - 1) {
      setState(() {
        _forward = true;
        _index++;
      });
      return;
    }
    final item = await _source.next(
      avoid: _index >= 0 ? _history[_index].id : null,
    );
    if (!mounted) return;
    setState(() {
      _forward = true;
      _history.add(item);
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
    final theme = Theme.of(context);
    final item = _history[_index];
    final quote = widget.content.quote(item.id)!;
    final area = item.area;
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
                  child: Column(
                    key: ValueKey(quote.id),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (area != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Row(
                            children: [
                              Icon(area.icon, size: 16, color: AppColors.amber),
                              const SizedBox(width: 6),
                              Text(
                                area.title,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      QuoteCard(quote: quote),
                    ],
                  ),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
