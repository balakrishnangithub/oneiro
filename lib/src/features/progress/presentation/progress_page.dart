import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/achievements.dart';
import '../domain/journal_stats.dart';
import '../progress_providers.dart';

/// Lucid-dreaming progress: journal statistics, weekly activity chart and
/// Dreamwalker milestones.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(journalStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            const Center(child: Text('Could not load progress')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsGrid(stats: stats),
            const SizedBox(height: 16),
            const _WeeklyChartCard(),
            const SizedBox(height: 16),
            const _AchievementsCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Grid of headline numbers.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final JournalStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (label: 'Journal entries', value: '${stats.totalEntries}'),
      (label: 'Lucid dreams', value: '${stats.lucidCount}'),
      (label: 'Lucid rate', value: '${stats.lucidPercent.round()}%'),
      (label: 'Current streak', value: _days(stats.currentStreak)),
      (label: 'Longest streak', value: _days(stats.longestStreak)),
      (label: 'Last 7 days', value: '${stats.entriesLast7Days}'),
      (label: 'Last 30 days', value: '${stats.entriesLast30Days}'),
      (
        label: 'Avg words',
        value: stats.averageWordsPerEntry.round().toString(),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [for (final tile in tiles) _StatCard(tile.label, tile.value)],
    );
  }

  static String _days(int count) => count == 1 ? '1 day' : '$count days';
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Bar chart of entries per week for the last 8 weeks.
class _WeeklyChartCard extends ConsumerWidget {
  const _WeeklyChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weeksAsync = ref.watch(weeklyActivityProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entries per week',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: weeksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => const Center(child: Text('No chart data')),
                data: (weeks) => _WeeklyBarChart(weeks: weeks),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.weeks});

  final List<WeekBucket> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = weeks.fold<int>(
      0,
      (max, w) => w.count > max ? w.count : max,
    );
    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weeks.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d/M').format(weeks[index].weekStart),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weeks.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weeks[i].count.toDouble(),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: i == weeks.length - 1
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondaryContainer,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Dreamwalker milestones with progress bars.
class _AchievementsCard extends ConsumerWidget {
  const _AchievementsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final achievementsAsync = ref.watch(achievementsProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dreamwalker milestones',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            achievementsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => const Text('Could not load milestones'),
              data: (achievements) => Column(
                children: [
                  for (final achievement in achievements)
                    _AchievementRow(progress: achievement),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = progress.nextMilestone;
    final current = progress.currentMilestoneName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progress.track.title, style: theme.textTheme.titleSmall),
              Text(
                next == null
                    ? '${progress.value} — complete'
                    : '${progress.value} / ${next.threshold}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.progressToNext,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'Highest milestone: $current'
                : current == null
                ? 'Next: ${next.name}'
                : '$current · Next: ${next.name}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
