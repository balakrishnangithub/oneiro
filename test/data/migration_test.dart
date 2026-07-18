import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Builds a v1 database file by hand: the two Stage A/B tables plus rows,
/// stamped with `user_version = 1`.
File _createV1DatabaseFile(Directory dir) {
  final file = File('${dir.path}${Platform.pathSeparator}oneiro_v1.sqlite');
  final db = raw.sqlite3.open(file.path);
  db.execute('''
    CREATE TABLE dream_entries (
      id TEXT NOT NULL PRIMARY KEY,
      dream_date INTEGER NOT NULL,
      text TEXT NOT NULL,
      is_lucid INTEGER NOT NULL DEFAULT 0 CHECK (is_lucid IN (0, 1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )
  ''');
  db.execute('''
    CREATE TABLE app_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)
  ''');
  db.execute(
    'INSERT INTO dream_entries (id, dream_date, text, is_lucid, created_at, '
    'updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    ['keep-me', 1778457600000, 'A v1 dream', 1, 1000, 1000, null],
  );
  db.execute('INSERT INTO app_settings (key, value) VALUES (?, ?)', [
    'training.checksPerDay',
    '6',
  ]);
  db.execute('PRAGMA user_version = 1');
  db.dispose();
  return file;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('oneiro_migration_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('v1 → v2 upgrade keeps existing rows and adds dismissed_theme_words',
      () async {
    final file = _createV1DatabaseFile(tempDir);

    final db = OneiroDatabase.withExecutor(NativeDatabase(file));
    addTearDown(db.close);

    // Pre-migration rows survive.
    final entries = await db.select(db.dreamEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.id, 'keep-me');
    expect(entries.single.isLucid, isTrue);

    final settings = await db.select(db.appSettings).get();
    expect(settings.single.key, 'training.checksPerDay');
    expect(settings.single.value, '6');

    // The new table exists and is usable.
    expect(await db.dismissedThemeWordDao.getDismissed(), isEmpty);
    await db.dismissedThemeWordDao.dismiss('flying', 2000);
    expect(await db.dismissedThemeWordDao.getDismissed(), {'flying'});

    // Drift stamped the upgraded version.
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(version, 2);
  });

  test('fresh installs are created directly at v2', () async {
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}oneiro_fresh.sqlite',
    );
    final db = OneiroDatabase.withExecutor(NativeDatabase(file));
    addTearDown(db.close);

    // Touch the database so it opens.
    expect(await db.select(db.dreamEntries).get(), isEmpty);
    expect(await db.dismissedThemeWordDao.getDismissed(), isEmpty);

    final version = await db
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(version, 2);
  });
}
