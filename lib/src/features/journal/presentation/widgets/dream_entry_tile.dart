import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/db/oneiro_database.dart';

/// One journal row: dream-body preview plus a moon marker for lucid dreams.
class DreamEntryTile extends StatelessWidget {
  const DreamEntryTile({required this.entry, this.onTap, super.key});

  final DreamEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          entry.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        trailing: entry.isLucid
            ? Tooltip(
                message: 'Lucid dream',
                child: Icon(
                  Icons.nightlight_round,
                  color: AppTheme.lucidAccent,
                  size: 22,
                ),
              )
            : null,
      ),
    );
  }
}
