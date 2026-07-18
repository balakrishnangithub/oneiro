import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/features/training/data/notification_onboarding.dart';

import '../../support/fake_training_services.dart';
import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  Future<String?> flagValue() async {
    final row =
        await (db.select(db.appSettings)
              ..where((r) => r.key.equals(notificationPermissionRequestedKey)))
            .getSingleOrNull();
    return row?.value;
  }

  test('already granted: no prompt, no flag written', () async {
    final service = FakeNotificationPermissionService(granted: true);

    await ensureNotificationPermissionRequestedOnce(db: db, service: service);

    expect(service.requestCount, 0);
    expect(await flagValue(), isNull);
  });

  test('first launch prompts once and records the flag', () async {
    final service = FakeNotificationPermissionService(granted: false);

    await ensureNotificationPermissionRequestedOnce(db: db, service: service);

    expect(service.requestCount, 1);
    expect(await flagValue(), 'true');
  });

  test('later launches never prompt again, even while still denied', () async {
    final service = FakeNotificationPermissionService(granted: false);

    await ensureNotificationPermissionRequestedOnce(db: db, service: service);
    await ensureNotificationPermissionRequestedOnce(db: db, service: service);
    await ensureNotificationPermissionRequestedOnce(db: db, service: service);

    expect(service.requestCount, 1);
  });

  test('grant later via system settings needs no further prompt', () async {
    final service = FakeNotificationPermissionService(granted: false);

    await ensureNotificationPermissionRequestedOnce(db: db, service: service);
    service.granted = true;
    await ensureNotificationPermissionRequestedOnce(db: db, service: service);

    expect(service.requestCount, 1);
  });
}
