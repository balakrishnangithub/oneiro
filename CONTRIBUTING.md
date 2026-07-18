# Contributing to Oneiro

Thanks for helping build a free dream journal for everyone.

## Ground rules

1. **Clean room only.** Never copy code, text, images, audio, or other
   assets from proprietary apps (including Awoken). Reimplement
   *functionality* in your own words and code. Ideas are free; expression is
   copyrighted.
2. **Privacy is a feature.** No analytics, ads, or third-party trackers.
   Anything leaving the device must be end-to-end encrypted and
   user-initiated.
3. **Tests are the contract.** `flutter analyze` must be clean and
   `flutter test` must pass. New logic lands with tests; plugin-facing code
   goes behind an interface with a fake.

## Development setup

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
```

- Architecture and layering: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Sync/encryption format: [docs/sync-format.md](docs/sync-format.md)
- Backup/import formats: [docs/backup-format.md](docs/backup-format.md)

## Commits & PRs

- Conventional Commits (`feat(journal): …`, `fix(sync): …`, `test(…)`, `docs: …`).
- Keep PRs focused; describe user-visible changes and test coverage.
- Generated drift code (`*.g.dart`) and `pubspec.lock` are committed.

## Code style

- `flutter_lints` defaults; format with `dart format .` before committing.
- Pure-Dart domain logic (no Flutter imports in `domain/`) so it stays
  unit-testable without a device.
