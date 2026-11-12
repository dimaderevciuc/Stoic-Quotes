import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/safety/help_resources.dart';

/// The always visible safety note (PLAN section 8.3).
class ReflectionNote extends StatelessWidget {
  const ReflectionNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.favorite_outline,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            reflectionNotTherapy,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
