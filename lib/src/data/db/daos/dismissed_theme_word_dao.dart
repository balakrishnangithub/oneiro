import 'package:drift/drift.dart';

import '../oneiro_database.dart';
import '../tables.dart';

part 'dismissed_theme_word_dao.g.dart';

/// Data-access object for [DismissedThemeWords].
///
/// Dismissal is permanent from the UI's point of view: rows are only ever
/// added or removed wholesale (a future "restore all" setting).
@DriftAccessor(tables: [DismissedThemeWords])
class DismissedThemeWordDao extends DatabaseAccessor<OneiroDatabase>
    with _$DismissedThemeWordDaoMixin {
  DismissedThemeWordDao(super.db);

  /// Live set of dismissed (lowercased) words.
  Stream<Set<String>> watchDismissed() => select(dismissedThemeWords).watch()
      .map((rows) => rows.map((row) => row.word).toSet());

  /// One-shot variant of [watchDismissed].
  Future<Set<String>> getDismissed() async =>
      (await select(dismissedThemeWords).get())
          .map((row) => row.word)
          .toSet();

  /// Remembers [word] as dismissed at [dismissedAtMs]. Idempotent.
  Future<void> dismiss(String word, int dismissedAtMs) =>
      into(dismissedThemeWords).insertOnConflictUpdate(
        DismissedThemeWordsCompanion(
          word: Value(word),
          dismissedAt: Value(dismissedAtMs),
        ),
      );

  /// Removes every dismissal (undo-all escape hatch).
  Future<int> clearAll() => delete(dismissedThemeWords).go();
}
