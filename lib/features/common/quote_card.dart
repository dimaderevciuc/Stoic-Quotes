import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/content/quote.dart';
import '../../core/share/share_quote.dart';
import 'favorite_button.dart';

/// A quote card in the order Dima chose: the plain explanation first, then the
/// original quote with its source, then how it applies; the full passage opens
/// on tap. Favorite and share sit at the bottom.
class QuoteCard extends StatefulWidget {
  const QuoteCard({
    super.key,
    required this.quote,
    this.application,
    this.initiallyExpanded = false,
    this.onOpen,
  });

  final Quote quote;

  /// How the quote applies to the matched situation, if any.
  final String? application;
  final bool initiallyExpanded;

  /// Opens the quote on its own page (used by Favorites).
  final VoidCallback? onOpen;

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  final _shareKey = GlobalKey();
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.quote;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpen ?? () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Everything inside the boundary becomes the shared image.
            RepaintBoundary(
              key: _shareKey,
              child: ColoredBox(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.explanation,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.only(left: 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: AppColors.amber, width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.text, style: quoteStyle(context, size: 18)),
                            const SizedBox(height: 8),
                            Text(
                              q.author,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.amberSoft,
                              ),
                            ),
                            Text(
                              q.sourceLine,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.application case final application?)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it applies',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(application, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full passage',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.amber,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            q.context,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Lora',
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  // Flexible: with large system text the label shortens
                  // instead of pushing the icons off screen.
                  // Expanded + Align: icons stay at the right edge, and with
                  // large system text the label shortens instead of overflowing.
                  Expanded(
                    child: widget.onOpen != null
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              icon: Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _expanded ? 'Hide passage' : 'Read the passage',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Share as image',
                    onPressed: () => shareQuoteImage(_shareKey, q),
                    icon: const Icon(
                      Icons.ios_share,
                      color: AppColors.amberSoft,
                    ),
                  ),
                  FavoriteButton(quoteId: q.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
