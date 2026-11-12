import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/safety/crisis_detector.dart';
import '../../core/safety/help_resources.dart';

/// Shown instead of any quotes when the text suggests a crisis. Calm, short,
/// with direct help. Pops `true` only if the user chose to continue.
class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key, required this.level});

  final CrisisLevel level;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open ${uri.path.isEmpty ? uri.host : uri.path}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('You are not alone'),
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'It sounds like you might be going through something really painful.',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'You deserve support from a real person right now. Talking to someone '
              'can help, and it is free and confidential.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            for (final r in helpResources) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(r.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        r.detail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _open(context, r.uri),
                        icon: Icon(
                          r.uri.scheme == 'tel'
                              ? Icons.call
                              : Icons.open_in_new,
                        ),
                        label: Text(r.label),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Go back'),
            ),
            if (level == CrisisLevel.possible) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("I'm safe, show my reflections"),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              reflectionNotTherapy,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
