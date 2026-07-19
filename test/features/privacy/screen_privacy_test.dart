import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/features/privacy/data/screen_privacy_repository.dart';

import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late ScreenPrivacyRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = ScreenPrivacyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('defaults to ON before anything is stored', () async {
    expect(await repo.load(), isTrue);
    expect(await repo.watch().first, isTrue);
  });

  test('persists off and back on', () async {
    await repo.save(false);
    expect(await repo.load(), isFalse);
    expect(await repo.watch().first, isFalse);

    await repo.save(true);
    expect(await repo.load(), isTrue);
  });

  test('watch emits live changes', () async {
    final values = <bool>[];
    final sub = repo.watch().listen(values.add);
    // Let the initial emission arrive before mutating.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await repo.save(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.save(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(values, [true, false, true]);
    await sub.cancel();
  });
}
