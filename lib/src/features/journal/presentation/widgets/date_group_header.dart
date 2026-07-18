import 'package:flutter/material.dart';

import '../../../../core/utils/date_x.dart';

/// Pinned section header for one calendar day in the journal list.
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final String? relative = date.isSameDay(now)
        ? 'Today'
        : date.isSameDay(now.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : null;

    return Container(
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            formatDreamDate(date),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (relative != null) ...[
            const SizedBox(width: 8),
            Text(
              '· $relative',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
