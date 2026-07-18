import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../journal/journal_providers.dart';
import '../domain/word_frequency_analyzer.dart';
import '../patterns_providers.dart';

/// Recurring words and hashtags across the dream journal.
///
/// Tapping a word jumps to the journal pre-filtered by it; the eye-off
/// action banishes a word forever (dismissals are persisted).
class PatternsPage extends ConsumerWidget {
  const PatternsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(themeWordsProvider);
    final filter = ref.watch(patternFilterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dream patterns')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<PatternFilter>(
              segments: [
                for (final option in PatternFilter.values)
                  ButtonSegment(value: option, label: Text(option.label)),
              ],
              selected: {filter},
              onSelectionChanged: (selection) => ref
                  .read(patternFilterProvider.notifier)
                  .update(selection.single),
            ),
          ),
          Expanded(
            child: wordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  const Center(child: Text('Could not load patterns')),
              data: (words) => words.isEmpty
                  ? const _EmptyPatterns()
                  : _ThemeWordList(words: words),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPatterns extends StatelessWidget {
  const _EmptyPatterns();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Write more dreams to reveal your patterns',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeWordList extends ConsumerWidget {
  const _ThemeWordList({required this.words});

  final List<WordFrequency> words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: words.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          _ThemeWordTile(frequency: words[index], rank: index + 1),
    );
  }
}

class _ThemeWordTile extends ConsumerWidget {
  const _ThemeWordTile({required this.frequency, required this.rank});

  final WordFrequency frequency;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isHashtag = frequency.word.startsWith('#');
    return ListTile(
      onTap: () {
        ref.read(journalSearchQueryProvider.notifier).update(frequency.word);
        context.go(AppRoutes.journal);
      },
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text('$rank', style: theme.textTheme.labelLarge),
      ),
      title: Text(
        frequency.word,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isHashtag ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        frequency.count == 1
            ? 'appears once'
            : 'appears ${frequency.count} times',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.visibility_off_outlined),
        tooltip: 'Hide this theme',
        onPressed: () => dismissThemeWord(ref, frequency.word),
      ),
    );
  }
}
