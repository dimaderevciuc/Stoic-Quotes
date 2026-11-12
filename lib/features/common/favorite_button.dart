import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// The red heart from the first app version, now with a small pop animation.
class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({super.key, required this.quoteId});

  final String quoteId;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isFavorite) async {
    unawaited(HapticFeedback.lightImpact());
    if (!isFavorite) unawaited(_pop.forward(from: 0));
    final repo = await ref.read(userRepositoryProvider.future);
    await repo.toggleFavorite(widget.quoteId);
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(favoriteIdsProvider).value ?? const <String>[];
    final isFavorite = ids.contains(widget.quoteId);
    final scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));
    return IconButton(
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onPressed: () => _toggle(isFavorite),
      icon: ScaleTransition(
        scale: scale,
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: AppColors.heart,
        ),
      ),
    );
  }
}
