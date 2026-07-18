import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/oneiro_database.dart';
import 'repositories/dream_repository.dart';

/// The single shared database instance.
///
/// Overridden in tests with an in-memory database.
final oneiroDatabaseProvider = Provider<OneiroDatabase>((ref) {
  final db = OneiroDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The repository presentation code talks to.
final dreamRepositoryProvider = Provider<DreamRepository>((ref) {
  final db = ref.watch(oneiroDatabaseProvider);
  return DriftDreamRepository(db.dreamEntryDao);
});
