import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The situation's practice, as steps the user can tick off (kept in memory only).
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({super.key, required this.steps});

  final List<String> steps;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  late final _done = List<bool>.filled(widget.steps.length, false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Text('Try this', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (final (i, step) in widget.steps.indexed)
              CheckboxListTile(
                value: _done[i],
                onChanged: (v) => setState(() => _done[i] = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  step,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: _done[i] ? TextDecoration.lineThrough : null,
                    color: _done[i] ? AppColors.textMuted : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
