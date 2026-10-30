import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// Pastille d'état : la couleur ne porte jamais seule l'information.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.color,
    required this.label,
    this.textStyle,
  });

  final Color color;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: (textStyle ?? Tokens.caption).copyWith(color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
