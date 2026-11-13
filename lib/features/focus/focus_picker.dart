import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/focus/focus_areas.dart';

/// Pick up to [FocusArea.maxPicks] areas. Used by the intro and the
/// "Your focus" screen.
class FocusPicker extends StatelessWidget {
  const FocusPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Ids, in the order they were picked.
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final full = selected.length >= FocusArea.maxPicks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final area in focusAreas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AreaTile(
              area: area,
              selected: selected.contains(area.id),
              enabled: selected.contains(area.id) || !full,
              onTap: () {
                HapticFeedback.selectionClick();
                final next = [...selected];
                if (!next.remove(area.id)) next.add(area.id);
                onChanged(next);
              },
            ),
          ),
      ],
    );
  }
}

/// "3 of 5 chosen".
class FocusCounter extends StatelessWidget {
  const FocusCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    '$count of ${FocusArea.maxPicks} chosen',
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: count > 0 ? AppColors.amberSoft : AppColors.textMuted,
    ),
  );
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.area,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final FocusArea area;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: selected ? AppColors.surfaceHigh : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? AppColors.amber : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    area.icon,
                    color: selected ? AppColors.amber : AppColors.textMuted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(area.title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          area.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? AppColors.amber : Colors.white24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Change the picks later (from Explore "For you" or About).
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  List<String>? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stored = ref.watch(focusAreaIdsProvider).value;
    final selected = _selected ?? stored;
    return Scaffold(
      appBar: AppBar(title: const Text('Your focus')),
      body: selected == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        Text(
                          'What would you like to focus on?',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick up to ${FocusArea.maxPicks}. Explore shows '
                          'quotes for them under For you.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FocusCounter(count: selected.length),
                        const SizedBox(height: 12),
                        FocusPicker(
                          selected: selected,
                          onChanged: (ids) => setState(() => _selected = ids),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final repo = await ref.read(
                            userRepositoryProvider.future,
                          );
                          await repo.setFocusAreaIds(selected);
                          if (context.mounted) context.pop();
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
