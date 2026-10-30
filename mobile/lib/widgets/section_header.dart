import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/tokens.dart';

/// Titre de section : petites capitales + action optionnelle.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.caption,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: Tokens.section.copyWith(color: surfaces.muted),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    caption!,
                    style: Tokens.caption.copyWith(color: surfaces.muted),
                  ),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, Tokens.minTouchTarget),
              foregroundColor: Theme.of(context).colorScheme.secondary,
              textStyle: Tokens.caption.copyWith(fontWeight: FontWeight.w700),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
