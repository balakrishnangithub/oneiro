import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/oneiro_database.dart';
import '../../data/providers.dart';

/// Current text typed into the journal search field.
final journalSearchQueryProvider = NotifierProvider<JournalSearchQuery, String>(
  JournalSearchQuery.new,
);

class JournalSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

/// Live list of journal entries, filtered by [journalSearchQueryProvider].
final journalEntriesProvider = StreamProvider<List<DreamEntry>>((ref) {
  final query = ref.watch(journalSearchQueryProvider);
  return ref.watch(dreamRepositoryProvider).watchEntries(query: query);
});
