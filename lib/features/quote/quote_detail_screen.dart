import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../common/quote_card.dart';

class QuoteDetailScreen extends ConsumerWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});

  final String quoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(contentProvider).value?.quote(quoteId);
    return Scaffold(
      appBar: AppBar(title: Text(quote?.author ?? 'Quote')),
      body: quote == null
          ? const Center(child: Text('This quote is no longer available.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [QuoteCard(quote: quote, initiallyExpanded: true)],
            ),
    );
  }
}
