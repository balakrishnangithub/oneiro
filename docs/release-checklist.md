# Release checklist

Everything below is one-time setup (sections 1–2) plus the repeatable
per-release flow (section 3). F-Droid submission (section 4) is optional.

## 1. One-time: create your upload keystore

> Already have a Play-App-Signing upload key? Reuse it instead and skip to
> editing `android/key.properties`.

```bash
keytool -genkey -v -keystore oneiro-upload-key.jks -keyalg RSA -keysize 2048 -validity 10950 -alias upload
```

1. Move `oneiro-upload-key.jks` into `android/`.
2. Copy `android/key.properties.template` → `android/key.properties` and fill
   in the passwords you chose.
3. Both files are git-ignored — never commit them. **Back the keystore up
   somewhere safe; losing it means you can never update the app again.**
4. Verify locally: `flutter build apk --release` → check
   `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`
   shows your certificate (not the debug one).

## 2. One-time: publish to GitHub

```bash
git remote add origin git@github.com:<your-user>/oneiro.git
git push -u origin main
```

- CI (`.github/workflows/ci.yml`) runs format check, `flutter analyze` and
  the full test suite on every push/PR — no setup needed.
- Optional, for **signed APKs built by GitHub** (so you don't even need a
  local Android SDK): add repo secrets `KEYSTORE_BASE64`
  (`base64 -w0 oneiro-upload-key.jks`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `KEY_PASSWORD`. Without secrets, the release workflow still attaches an
  APK, signed with the debug key — fine for testing, not for stores.

## 3. Per release

1. Update `version:` in `pubspec.yaml` — semantic version + build number
   (`1.0.1+2`: bump the name for users, the number for Android).
2. Add `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
3. `flutter analyze && flutter test` (CI will re-check).
4. Commit, tag, push:
   ```bash
   git commit -am "chore(release): v1.0.1"
   git tag v1.0.1
   git push origin main --tags
   ```
5. The Release workflow builds the APK and attaches it to a GitHub Release
   with auto-generated notes. Review and publish.

## 4. Optional: F-Droid inclusion

The `fastlane/metadata/android/en-US/` tree (short/full description,
changelogs, icon) is already in the F-Droid/ Fastlane-supply format.

1. Make sure a tagged release exists on GitHub.
2. Open an RFP at https://gitlab.com/fdroid/rfp/-/issues (bot checks the repo).
3. If accepted, open a merge request to `fdroiddata` adding
   `metadata/io.github.lightbala.oneiro.yml`. Flutter apps use the standard
   `flutter` srclib recipe — copy from an existing Flutter app entry and
   adjust name/version/tag. Requirements Oneiro already satisfies: no
   proprietary deps, no tracking, license file present, tagged releases.
4. F-Droid builds from source with its own signature — your keystore is not
   needed (and reproducible-build matching is a later optional step).

## 5. Optional: Play Store later

- Create a Play developer account, enroll in Play App Signing, upload the
  AAB (`flutter build appbundle --release`), complete the data-safety form:
  no data collected; optional user-initiated encrypted sync only.
