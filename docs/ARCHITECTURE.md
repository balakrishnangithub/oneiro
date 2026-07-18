# Oneiro — Architecture (Stage A)

Oneiro is a dream-journal app for lucid dreamers. This document describes the
Stage A layering and where the later stages (reminders, patterns, progress,
sync, import) plug in without refactoring.

## Layers

```
lib/
  main.dart                  entry point: ProviderScope + OneiroApp
  src/
    app.dart                 MaterialApp.router, theme wiring
    core/                    shared, feature-agnostic
      theme/app_theme.dart   Material 3 light/dark, deep-indigo night palette
      utils/date_x.dart      day-granularity date helpers + intl formats
    routing/
      app_router.dart        go_router: StatefulShellRoute + editor routes
      app_shell.dart         bottom NavigationBar (Journal/Patterns/Progress/Settings)
    data/                    persistence, no Flutter widgets
      db/tables.dart         drift tables
      db/oneiro_database.dart  OneiroDatabase (+ .g.dart, committed)
      db/daos/               DreamEntryDao (+ .g.dart, committed)
      repositories/          DreamRepository contract + DriftDreamRepository
      providers.dart         oneiroDatabaseProvider / dreamRepositoryProvider
    features/
      journal/               Stage A feature
        journal_providers.dart   search query + entries stream providers
        presentation/          pages + widgets (Consumer widgets only)
      patterns|progress|settings/  placeholder pages
```

Rules:

- **core** never imports data or features. **data** never imports features.
- Presentation talks to persistence only through `DreamRepository`
  (`dreamRepositoryProvider`), never to the DAO/database directly.
- Everything stateful is provided through Riverpod; tests override
  `oneiroDatabaseProvider` with an in-memory `NativeDatabase` and get a fully
  wired repository for free.

## Data model

- `dream_entries`: `id` (client-generated UUID, PK), `dreamDate` (INTEGER,
  millis of local midnight — day granularity), `text` (via Dart getter `body`),
  `isLucid`, `createdAt`, `updatedAt`, `deletedAt` (nullable tombstone).
- `app_settings`: generic `key`/`value` store for all later settings.
- Deletion is always soft (`deletedAt`) so a sync stage can propagate
  tombstones before rows are purged. The DAO filters tombstones everywhere.
- `schemaVersion` is 1; migrations land in `OneiroDatabase.migration`.

## Where later stages plug in

- **Reminders (reality checks, morning prompt, night clues):** settings go into
  `app_settings`; a new `data/notifications/` ledger table + service reads them
  via a new provider. No journal changes needed. New top-level routes attach in
  `app_router.dart` (settings dialogs) — the shell stays untouched.
- **Patterns (word/hashtag stats):** read-only queries over
  `DreamEntryDao` (add a `patterns` DAO or repository). Replace
  `features/patterns/` placeholder; the tab slot already exists.
- **Progress (achievements/counters):** `DreamRepository.countEntries()` /
  `countLucid()` already exist; add counter settings in `app_settings` and a
  presentation-only feature in `features/progress/`.
- **Sync (cloud backup):** implement a syncing `DreamRepository` (or wrap
  `DriftDreamRepository`) that pushes dirty rows and pulls remote changes;
  swap the implementation inside `dreamRepositoryProvider`. The UI does not
  change. UUID primary keys and `updatedAt`/`deletedAt` tombstones were chosen
  for exactly this.
- **Import (Awoken-style text export):** a `data/import/` parser produces
  `DreamEntriesCompanion`s and inserts through the DAO; day-granularity dates
  match the export format. UI entry point lives in Settings.
- **Settings screen:** replace the placeholder; persist everything in
  `app_settings` (add a typed settings repository when keys grow).

## Testing notes

- Unit/widget tests run on the host with `NativeDatabase.memory()` (sqlite3
  falls back to Windows' `winsqlite3.dll`; no override needed).
- Drift schedules a zero-duration timer when a watched stream is cancelled;
  widget tests call `test/support/unmount_app.dart`'s `unmountApp(tester)` so
  no fake timer is left pending at test end.
- Generated drift files (`*.g.dart`) are committed; regenerate with
  `flutter pub run build_runner build --delete-conflicting-outputs`.
- No Android SDK on the dev machine: validate only with `flutter analyze` and
  `flutter test`.
