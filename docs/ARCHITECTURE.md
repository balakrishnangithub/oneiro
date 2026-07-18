# Oneiro — Architecture (Stages A + B)

Oneiro is a dream-journal app for lucid dreamers. This document describes the
Stage A layering, the Stage B training engine, and where the later stages
(patterns, progress, sync, import) plug in without refactoring.

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
      patterns|progress/      placeholder pages
      settings/               Stage B: full training settings UI
      training/               Stage B feature
        domain/                 pure Dart, no Flutter/plugins
          training_settings.dart  TrainingSettings value type + TotemSound
          training_settings_store.dart  persistence contract for the domain
          daily_plan_generator.dart  seeded pseudo-random day/night plans
          pause_service.dart      pause/resume + isPaused
          clue_player.dart        CluePlayer audio interface
        data/
          settings_repository.dart  typed app_settings façade + counters
          notification_gateway.dart  plugin abstraction + thin impl
          notification_scheduler.dart  settings → concrete OS schedule
          notification_permission_service.dart  Android 13+ runtime flow
          dream_clue_player.dart  audioplayers CluePlayer
        presentation/
          reality_check_page.dart  full-screen reality-check ritual
        training_providers.dart  DI, replan trigger, notification-tap routing
```

Rules:

- **core** never imports data or features. **data** never imports features.
- Presentation talks to persistence only through `DreamRepository`
  (`dreamRepositoryProvider`), never to the DAO/database directly.
- Training settings and counters live in `app_settings` behind
  `SettingsRepository` (a feature-level repository, since the keys belong to
  the training domain); the drift table stays generic.
- **All plugin-facing code is thin and behind interfaces**
  (`NotificationGateway`, `CluePlayer`, `NotificationPermissionService`);
  planning logic (`DailyPlanGenerator`, `NotificationScheduler`,
  `PauseService`) is pure Dart and unit-tested with fakes.
- Everything stateful is provided through Riverpod; tests override
  `oneiroDatabaseProvider` with an in-memory `NativeDatabase` and get a fully
  wired repository for free.

## Training engine (Stage B)

- `DailyPlanGenerator` produces deterministic plans: the seed derives from
  the calendar date plus a per-kind salt, so re-planning is idempotent.
  Trigger times keep a 45-minute minimum spacing; the night window may cross
  midnight (end rolls into the next day).
- `NotificationScheduler.replan(settings)` cancels everything, then
  schedules reality checks for today+tomorrow, tonight's dream clues
  (anchoring the night window to yesterday/today/tomorrow and dropping past
  instants), and the daily morning reminder. Notification ids derive from
  the trigger instant, so rescheduling never duplicates.
- A training pause suppresses reality checks and dream clues but **never**
  the morning journal reminder.
- `trainingReplanProvider` watches the settings stream and re-plans on app
  start and after every settings change; `OneiroApp` watches it once.
- Tapping a notification routes by payload: reality check → `/reality-check`
  dialog (both answers increment `realityCheckCount`); dream clue → plays
  the totem sound via `CluePlayer` and increments `dreamClueCount`.
- Totem audio assets live in `assets/audio/totem_{chime,bell,drop}.wav`
  (original recordings, declared in `pubspec.yaml`).

## Data model

- `dream_entries`: `id` (client-generated UUID, PK), `dreamDate` (INTEGER,
  millis of local midnight — day granularity), `text` (via Dart getter `body`),
  `isLucid`, `createdAt`, `updatedAt`, `deletedAt` (nullable tombstone).
- `app_settings`: generic `key`/`value` store for all later settings.
- Deletion is always soft (`deletedAt`) so a sync stage can propagate
  tombstones before rows are purged. The DAO filters tombstones everywhere.
- `schemaVersion` is 1; migrations land in `OneiroDatabase.migration`.

## Where later stages plug in

- **Patterns (word/hashtag stats):** read-only queries over
  `DreamEntryDao` (add a `patterns` DAO or repository). Replace
  `features/patterns/` placeholder; the tab slot already exists.
- **Progress (achievements/counters):** `DreamRepository.countEntries()` /
  `countLucid()` already exist; the training counters
  (`SettingsRepository.realityCheckCount()` / `dreamClueCount()`) are ready
  for achievements; add a presentation-only feature in `features/progress/`.
- **Sync (cloud backup):** implement a syncing `DreamRepository` (or wrap
  `DriftDreamRepository`) that pushes dirty rows and pulls remote changes;
  swap the implementation inside `dreamRepositoryProvider`. The UI does not
  change. UUID primary keys and `updatedAt`/`deletedAt` tombstones were chosen
  for exactly this.
- **Import (Awoken-style text export):** a `data/import/` parser produces
  `DreamEntriesCompanion`s and inserts through the DAO; day-granularity dates
  match the export format. UI entry point lives in Settings.

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
- Widget tests override `notificationGatewayProvider`, `cluePlayerProvider`
  and `notificationPermissionServiceProvider` with the fakes in
  `test/support/fake_training_services.dart`; the notification plugins are
  never exercised on the host. The settings page test also enlarges
  `tester.view` because the settings `ListView` builds children lazily.
