import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'domain/word_frequency_analyzer.dart';

/// Which dreams feed the pattern analysis.
enum PatternFilter {
  all,
  lucidOnly;

  String get label => switch (this) {
    PatternFilter.all => 'All dreams',
    PatternFilter.lucidOnly => 'Lucid only',
  };
}

/// Current pattern filter on the patterns page.
final patternFilterProvider =
    NotifierProvider<PatternFilterNotifier, PatternFilter>(
      PatternFilterNotifier.new,
    );

class PatternFilterNotifier extends Notifier<PatternFilter> {
  @override
  PatternFilter build() => PatternFilter.all;

  void update(PatternFilter filter) => state = filter;
}

/// Live set of words the user banished from the theme list.
final dismissedThemeWordsProvider = StreamProvider<Set<String>>((ref) {
  return ref
      .watch(oneiroDatabaseProvider)
      .dismissedThemeWordDao
      .watchDismissed();
});

/// Banishes [word] from the theme list permanently.
Future<void> dismissThemeWord(WidgetRef ref, String word) {
  return ref
      .read(oneiroDatabaseProvider)
      .dismissedThemeWordDao
      .dismiss(word, DateTime.now().millisecondsSinceEpoch);
}

/// Recurring theme words across the journal, filtered and minus dismissals.
final themeWordsProvider = StreamProvider<List<WordFrequency>>((ref) async* {
  final filter = ref.watch(patternFilterProvider);
  final dismissed = ref.watch(dismissedThemeWordsProvider).valueOrNull ?? {};
  final analyzer = const WordFrequencyAnalyzer();
  await for (final entries
      in ref.watch(dreamRepositoryProvider).watchEntries()) {
    final frequencies = analyzer.analyzeEntries(
      entries.map((e) => (text: e.body, isLucid: e.isLucid)),
      lucidOnly: filter == PatternFilter.lucidOnly,
    );
    yield [
      for (final frequency in frequencies)
        if (!dismissed.contains(frequency.word)) frequency,
    ];
  }
});
