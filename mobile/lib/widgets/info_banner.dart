import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/tokens.dart';

enum BannerTone { info, warning, danger }

/// Bandeau non bloquant : erreur, dégradation, information légale.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = BannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final BannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      BannerTone.info => scheme.secondary,
      BannerTone.warning => surfaces.priorityC,
      BannerTone.danger => scheme.error,
    };
    final resolvedIcon = icon ??
        switch (tone) {
          BannerTone.info => Icons.info_outline,
          BannerTone.warning => Icons.warning_amber_rounded,
          BannerTone.danger => Icons.error_outline,
        };

    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(resolvedIcon, size: 20, color: color),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: Tokens.caption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        actionLabel!,
                        style: Tokens.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
