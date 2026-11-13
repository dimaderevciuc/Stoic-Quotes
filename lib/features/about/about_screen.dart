import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/safety/help_resources.dart';

/// Contact address shown on the About screen. Empty hides the row
/// (Dima to provide one).
const contactEmail = '';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sources = ref.watch(contentProvider).value?.sources ?? const [];
    final version = ref.watch(_versionProvider).value ?? '';
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textMuted,
    );
    Widget section(String title, List<Widget> children, {IconData? icon}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppColors.amber, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('About and safety')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          section('Stoic Quotes', icon: Icons.self_improvement, [
            Text(
              'Describe what you are going through and find words from Stoic writers that '
              'may help, each with a plain explanation and a small practice.',
              style: muted,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/focus'),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Your focus'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/intro?again=1'),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('View intro again'),
                ),
              ],
            ),
          ]),
          section('Privacy', icon: Icons.lock_outline, [
            Text(
              'No data leaves your device. There is no account, no internet connection and no '
              'tracking. What you type is used once to find quotes and is never saved. '
              'Your favorites and focus picks are stored encrypted on your phone.',
              style: muted,
            ),
          ]),
          section('Safety', icon: Icons.health_and_safety_outlined, [
            Text(
              '$reflectionNotTherapy Stoicism is not a replacement for medical or '
              'psychological care. If you are struggling, please reach out:',
              style: muted,
            ),
            const SizedBox(height: 8),
            for (final r in helpResources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.uri.scheme == 'tel' ? Icons.call : Icons.public,
                  color: AppColors.amberSoft,
                ),
                title: Text(r.name),
                subtitle: Text(r.label),
                onTap: () =>
                    launchUrl(r.uri, mode: LaunchMode.externalApplication),
              ),
          ]),
          section('Sources', icon: Icons.menu_book_outlined, [
            Text(
              'Every quote is copied word for word from a public domain translation. The '
              'explanations, "how it applies" notes and exercises were written for this app.',
              style: muted,
            ),
            const SizedBox(height: 8),
            for (final s in sources)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${s.author}, ',
                        style: const TextStyle(color: AppColors.amberSoft),
                      ),
                      TextSpan(
                        text: s.title,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      TextSpan(
                        text: s.translator.isEmpty
                            ? ' (${s.year}). ${s.origin}.'
                            : ', translated by ${s.translator} (${s.year}). ${s.origin}.',
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'James Allen was not a Stoic; As a Man Thinketh is included for its closely '
              'related ideas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ]),
          section('How matching works', icon: Icons.memory, [
            Text(
              'A small language model (gte-small, MIT license) runs on your phone to compare '
              'your words with the quotes. It never connects to the internet.',
              style: muted,
            ),
          ]),
          if (contactEmail.isNotEmpty)
            section('Contact', icon: Icons.mail_outline, [
              TextButton(
                onPressed: () =>
                    launchUrl(Uri(scheme: 'mailto', path: contactEmail)),
                child: const Text(contactEmail),
              ),
            ]),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Stoic Quotes',
              applicationVersion: version,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open source licenses'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Version $version',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
