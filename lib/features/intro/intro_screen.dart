import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/focus/focus_areas.dart';
import '../../core/safety/help_resources.dart';
import '../focus/focus_picker.dart';

/// Shown once on first launch (and again from About): what the app is, how
/// to use it, privacy and care, then the optional focus picks.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key, this.again = false});

  /// Opened from About: close back to it instead of going home.
  final bool again;

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  static const _pageCount = 4;
  final _pages = PageController();
  int _page = 0;
  List<String>? _selected;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _onPicks => _page == _pageCount - 1;

  Future<void> _finish({required bool savePicks}) async {
    final repo = await ref.read(userRepositoryProvider.future);
    if (savePicks) await repo.setFocusAreaIds(_selected ?? const []);
    await repo.markIntroSeen();
    if (!mounted) return;
    if (widget.again && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _next() => _pages.nextPage(
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(focusAreaIdsProvider).value ?? const [];
    final selected = _selected ?? stored;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: TextButton(
                  onPressed: () => _onPicks
                      ? _finish(savePicks: false)
                      : _pages.animateToPage(
                          _pageCount - 1,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Text(_onPicks ? 'Skip for now' : 'Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _InfoPage(
                    icon: Icons.self_improvement,
                    title: "Wisdom for what you're going through",
                    rows: [
                      (
                        null,
                        'Stoic Quotes brings you Seneca, Epictetus, Marcus '
                            'Aurelius and other Stoic writers on everyday '
                            'life: work, worry, anger, loss and finding your '
                            'way.',
                      ),
                      (
                        null,
                        'Every quote is copied word for word from a real '
                            'translation, with its source, and explained in '
                            'plain words.',
                      ),
                    ],
                  ),
                  const _InfoPage(
                    icon: Icons.touch_app_outlined,
                    title: 'How to use it',
                    rows: [
                      (
                        Icons.self_improvement,
                        'Reflect: write what is on your mind in your own '
                            'words. You get matching quotes, how they apply '
                            'to you, and a small exercise.',
                      ),
                      (
                        Icons.auto_awesome,
                        'Explore: browse quotes at random, or under For you '
                            'see quotes for what you choose to focus on.',
                      ),
                      (
                        Icons.favorite,
                        'Favorites: keep the ones that speak to you.',
                      ),
                    ],
                  ),
                  const _InfoPage(
                    icon: Icons.lock_outline,
                    title: 'Yours alone',
                    rows: [
                      (
                        Icons.phone_android,
                        'Everything stays on your phone. There is no '
                            'account, no internet connection and no '
                            'tracking. What you type is never saved.',
                      ),
                      (
                        Icons.favorite_outline,
                        '$reflectionNotTherapy If you are going through '
                            'something heavy, it will point you to people '
                            'who can help.',
                      ),
                    ],
                  ),
                  _PicksPage(
                    selected: selected,
                    onChanged: (ids) => setState(() => _selected = ids),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.amber : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  if (_onPicks)
                    FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => _finish(savePicks: true),
                      child: const Text('Start'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Next'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;

  /// Paragraphs, each with an optional leading icon.
  final List<(IconData?, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.amber),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: 20),
              for (final (rowIcon, text) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rowIcon != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            rowIcon,
                            size: 20,
                            color: AppColors.amberSoft,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(
                          text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PicksPage extends StatelessWidget {
  const _PicksPage({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        Semantics(
          header: true,
          child: Text(
            'What would you like to focus on?',
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick up to ${FocusArea.maxPicks}. Explore will have quotes for '
          'them under For you. You can change this any time.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        FocusCounter(count: selected.length),
        const SizedBox(height: 12),
        FocusPicker(selected: selected, onChanged: onChanged),
      ],
    );
  }
}
