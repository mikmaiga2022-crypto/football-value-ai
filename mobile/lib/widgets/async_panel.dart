import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/tokens.dart';
import '../core/api/api_exception.dart';

/// Rendu uniforme d'un `AsyncValue` : squelette, erreur actionnable, données.
class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.skeletonCount = 3,
    this.skeletonHeight = 84,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Future<void> Function()? onRetry;
  final int skeletonCount;
  final double skeletonHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: builder,
      loading: () => Column(
        children: [
          for (var i = 0; i < skeletonCount; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space3),
              child: _Skeleton(height: skeletonHeight),
            ),
        ],
      ),
      error: (error, _) => _ErrorCard(error: error, onRetry: onRetry),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.surfaces.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: context.surfaces.border),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, this.onRetry});

  final Object error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Chargement impossible. Vérifiez votre connexion.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    'Données indisponibles',
                    style: Tokens.bodyStrong.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              message,
              style: Tokens.caption.copyWith(color: context.surfaces.muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Tokens.space2),
              TextButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
