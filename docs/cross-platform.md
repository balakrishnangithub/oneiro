# Cross-platform readiness

Oneiro is developed Android-first, but the codebase is deliberately kept
portable so iOS (and later desktop) support is an incremental effort, not a
rewrite. This note records the rules we follow and the current state of each
platform-sensitive area.

## Rules that keep the code portable

1. **No `dart:io` in widget or domain code.** Direct `dart:io` usage is
   confined to small `data/` adapters (vault stores, backup share gateway)
   that sit behind interfaces. Everything above them is pure Dart.
2. **Every platform capability hides behind an abstract interface** with a
   fake for tests: `NotificationGateway`, `NotificationPermissionService`,
   `SpeechRecognizer`, `SecureCredentialsStore`, `ScreenPrivacyService`,
   `SyncWakeLock`, `BackgroundSyncScheduler`, backup share/pick gateways.
3. **Platform branches are capability checks, not scattered `Platform.isX`
   sprinkled through the UI.** Where a check is unavoidable it lives in one
   adapter (`background_sync.dart`, `screen_privacy_service.dart`).
4. **Paths are always built with `package:path`** (`p.join`), never string
   concatenation with `/`.
5. **Plugins are chosen for platform coverage** (see the table below); a
   plugin that only works on Android must be replaceable without touching
   feature code.

## Current state per area

| Area | Plugin / mechanism | Android | iOS | macOS | Windows / Linux |
|---|---|---|---|---|---|
| Database | drift + sqlite3 (bundled) | ✅ | ✅ | ✅ | ✅ |
| Local notifications | flutter_local_notifications | ✅ | ✅ (Darwin settings wired) | ✅ | ⚠️ plugin has no desktop impl — gateway no-ops |
| Notification permission | flutter_local_notifications | ✅ runtime prompt | ✅ `requestPermissions` | ✅ | n/a (treated as granted) |
| Timezone | flutter_timezone | ✅ | ✅ | ✅ | ✅ |
| Background sync | workmanager (guarded Android-only) | ✅ ~6 h periodic | 🔲 BGTaskScheduler later | n/a | n/a |
| Wake lock during sync | wakelock_plus | ✅ | ✅ | ✅ | ✅ |
| Credential vault | flutter_secure_storage | ✅ | ✅ | ✅ | ✅ |
| WebDAV sync | webdav_client + dio (pure Dart) | ✅ | ✅ | ✅ | ✅ |
| Vault crypto | cryptography + pointycastle (pure Dart) | ✅ | ✅ | ✅ | ✅ |
| Local-folder vault | dart:io + package:path | ✅ | ✅ | ✅ | ✅ |
| Backup export/share | file_picker + share_plus | ✅ | ✅ | ✅ | ✅ |
| Speech dictation | speech_to_text, degrades gracefully | ✅ | ✅ | ✅ | ❌ hidden (initialize → false) |
| Audio (dream clues) | audioplayers | ✅ | ✅ | ✅ | ✅ |
| Recents/screenshot privacy | FLAG_SECURE via MethodChannel | ✅ | n/a (iOS has no equivalent; `UIScreenCapturedDidChange` is detection-only) | n/a | n/a |
| Charts | fl_chart (pure Dart) | ✅ | ✅ | ✅ | ✅ |

## What an iOS port still needs

- **Xcode project + signing** (`flutter create --platforms ios .` then team
  signing), plus `Info.plist` entries: `NSMicrophoneUsageDescription`
  (dictation), `NSPhotoLibraryUsageDescription` is *not* needed,
  background-mode `fetch`/`processing` for BGTaskScheduler.
- **Background sync via BGTaskScheduler.** The seam already exists:
  `BackgroundSyncScheduler` is an interface and `runBackgroundSync(...)` is
  platform-neutral Dart — only the scheduler adapter changes. Note iOS
  background execution is best-effort and far more restricted than
  WorkManager.
- **Launcher icons** for iOS (`flutter_launcher_icons` recipe already in
  `pubspec.yaml` — extend it with `ios: true`).
- **App Store metadata** (fastlane `ios` lane; the Android lane under
  `fastlane/` is the template).
- **Recents privacy** has no direct iOS analog; a common approximation is a
  privacy blur overlay shown from `applicationWillResignActive`.

## What a desktop port still needs

- A window-size floor (the layouts are phone-first) and mouse/keyboard
  affordances.
- `flutter_local_notifications` has no Windows/Linux implementation, so
  reminders would silently no-op — an alternative scheduler (or in-app
  only reminders) would be needed there.
- `speech_to_text` is unavailable on Windows/Linux; the dictation button
  already hides itself when `initialize()` reports unavailability.
