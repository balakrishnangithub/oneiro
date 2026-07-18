# Oneiro — Architecture (Stages A + B + C + D)

Oneiro is a dream-journal app for lucid dreamers. This document describes the
Stage A layering, the Stage B training engine, the Stage C patterns/progress
features, and where the later stages (sync, import) plug in without
refactoring.

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
      db/daos/               DreamEntryDao, DismissedThemeWordDao (+ .g.dart)
      repositories/          DreamRepository contract + DriftDreamRepository
      providers.dart         oneiroDatabaseProvider / dreamRepositoryProvider
    features/
      backup/                 Stage D: Awoken import + text/JSON export
        domain/                 parser, exporter, dedupe service (pure Dart)
        data/                   file-picker and share-gateway plugin seams
        presentation/           Settings "Backup & Import" section
      journal/               Stage A feature
        journal_providers.dart   search query + entries stream providers
        presentation/          pages + widgets (Consumer widgets only)
      patterns/               Stage C: theme words
        domain/                 WordFrequencyAnalyzer + stopwords (pure Dart)
        patterns_providers.dart filter, dismissed words, theme stream
        presentation/          patterns page (ranked words, banish action)
      progress/               Stage C: stats & milestones
        domain/                 JournalStats, weekly histogram, achievements
        progress_providers.dart today (injectable), stats/chart/milestones
        presentation/          progress page (cards, bar chart, milestones)
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
- `dismissed_theme_words` (v2): `word` (lowercased token, PK), `dismissedAt` —
  theme words the user banished from the patterns page.
- Deletion is always soft (`deletedAt`) so a sync stage can propagate
  tombstones before rows are purged. The DAO filters tombstones everywhere.
- `schemaVersion` is 2; migrations land in `OneiroDatabase.migration`
  (v1 → v2 creates `dismissed_theme_words`; covered by
  `test/data/migration_test.dart`, which hand-builds a v1 file with raw
  sqlite3 and upgrades it).

## Patterns and progress (Stage C)

- `features/patterns/domain/word_frequency_analyzer.dart` is pure Dart:
  Unicode-aware tokenization (`\p{L}\p{M}`, so combining-mark scripts like
  Tamil survive), `#hashtags` kept as first-class tokens that bypass the
  stopword list, a hand-written English stopword list
  (`domain/stopwords.dart`), minimum word length 3, optional lucid-only
  filtering. `themeWordsProvider` recomputes from the entries stream minus
  the dismissed-word stream; dismissing writes through
  `DismissedThemeWordDao`. Tapping a word sets
  `journalSearchQueryProvider` and navigates to the journal.
- `features/progress/domain/journal_stats.dart` computes `JournalStats`
  (totals, lucid %, current/longest day streaks, 7/30-day windows, average
  words) from lightweight `EntrySummary` values with `today` injected, so
  streaks are deterministic in tests. `weeklyActivity` produces a
  Monday-anchored 8-week histogram.
- `features/progress/domain/achievements.dart` holds the original
  "Dreamwalker milestones": four tracks (journal entries, lucid dreams,
  reality checks, dream clues heard) with named thresholds and
  progress-to-next scaling. Entry/lucid counters come from
  `DreamRepository`, the other two from `SettingsRepository`.
- The progress page renders a stat-card grid, an fl_chart bar chart of the
  weekly histogram, and the milestone list. fl_chart is pinned to 1.0.0
  because 1.1.0 requires a newer `vector_math` than the Flutter 3.32 SDK
  ships.

## Where later stages plug in

- **Sync (cloud backup):** implement a syncing `DreamRepository` (or wrap
  `DriftDreamRepository`) that pushes dirty rows and pulls remote changes;
  swap the implementation inside `dreamRepositoryProvider`. The UI does not
  change. UUID primary keys and `updatedAt`/`deletedAt` tombstones were chosen
  for exactly this.

## Backup and import (Stage D)

- `features/backup/domain/awoken_import_parser.dart` parses the Awoken
  plain-text export grammar: a `----` line (exactly four dashes) precedes
  every entry; labels are `Date: `, `Lucidity: ` and `Dream:`; the body runs
  to the next separator. The parser is pure Dart, never throws, and is
  liberal: CRLF tolerated, the weekday token ignored (mismatches accepted),
  and September read as `Sep`/`Sept`/`September`. Malformed blocks are
  counted in `skippedCount` with human-readable `warnings`.
- `features/backup/domain/awoken_exporter.dart` renders entries back into
  the same grammar (title line names ONEIRO), with the weekday recomputed
  from the date. Round-trip property: `parse(export(entries)) == entries`.
- `features/backup/domain/awoken_import_service.dart` dedupes on a
  deterministic FNV-1a signature of `(dreamDate, normalized body)` where
  normalization trims and collapses whitespace. One bulk pre-check loads all
  live signatures via `DreamRepository.getAllActive()`, so re-importing the
  same file imports 0; tombstoned entries do not block re-import.
- `features/backup/domain/journal_json_export.dart` is the full-fidelity
  backup (ids, `createdAt`/`updatedAt`, pretty-printed); the schema is
  documented in `docs/backup-format.md`.
- Plugin seams: `ImportFilePicker` (file_picker) and `BackupShareGateway`
  (path_provider + share_plus, writes to app documents then opens the share
  sheet) live in `features/backup/data/` behind providers in
  `backup_providers.dart`; widget tests substitute the fakes in
  `test/support/fake_backup_services.dart`.
- UI: the "Backup & Import" section on the Settings page
  (`features/backup/presentation/backup_section.dart`) runs import as
  pick → parse → preview dialog (count, date range, lucid count, warnings)
  → progress dialog → result ("imported X, skipped Y duplicates, Z
  unreadable").
- `test/features/backup/awoken_real_file_test.dart` verifies the parser
  against a real export file only when `AWOKEN_EXPORT_PATH` points at one
  (377 entries / 7 lucid / 2026-05-18 → 2015-11-14 / 0 skipped); it skips
  itself otherwise. The real file is private and must never be committed.

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
