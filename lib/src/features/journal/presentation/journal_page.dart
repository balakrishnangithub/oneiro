import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_x.dart';
import '../../../data/db/oneiro_database.dart';
import '../../../data/providers.dart';
import '../../../routing/app_router.dart';
import '../journal_providers.dart';
import 'widgets/date_group_header.dart';
import 'widgets/dream_entry_tile.dart';

/// Home of the dream journal: searchable, date-grouped list of entries.
class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteEntry(DreamEntry entry) async {
    final repository = ref.read(dreamRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repository.softDelete(entry.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Dream removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repository.restore(entry.id),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dream journal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newDream),
        icon: const Icon(Icons.add),
        label: const Text('New dream'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(journalSearchQueryProvider.notifier).update(value),
              decoration: InputDecoration(
                hintText: 'Search your dreams',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(journalSearchQueryProvider.notifier)
                                .update('');
                          },
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Text('Something went wrong while reading your dreams.'),
              ),
              data: (list) => list.isEmpty
                  ? const _JournalEmptyState()
                  : _JournalList(entries: list, onDelete: _deleteEntry),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.entries, required this.onDelete});

  final List<DreamEntry> entries;
  final ValueChanged<DreamEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final groups = groupBy<DreamEntry, DateTime>(
      entries,
      (entry) =>
          DateTime.fromMillisecondsSinceEpoch(entry.dreamDate).startOfDay,
    );

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        // Each day group must be wrapped in a SliverMainAxisGroup: bare
        // PinnedHeaderSlivers stack on top of each other instead of the
        // incoming header pushing the previous one away.
        for (final MapEntry(key: day, value: dayEntries) in groups.entries)
          SliverMainAxisGroup(
            slivers: [
              PinnedHeaderSliver(child: DateGroupHeader(date: day)),
              SliverList.builder(
                itemCount: dayEntries.length,
                itemBuilder: (context, index) {
                  final entry = dayEntries[index];
                  return Dismissible(
                    key: ValueKey(entry.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => onDelete(entry),
                    background: Container(
                      alignment: Alignment.centerRight,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    child: DreamEntryTile(
                      entry: entry,
                      onTap: () => context.push(AppRoutes.editDream(entry.id)),
                    ),
                  );
                },
              ),
            ],
          ),
        // Keep the last entry clear of the FAB.
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }
}

class _JournalEmptyState extends StatelessWidget {
  const _JournalEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your journal is still blank',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Write down your dream right after waking — even a single '
              'sentence trains your dream memory.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
