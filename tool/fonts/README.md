# Fonts used by tooling only

`Roboto-{Regular,Medium,Bold}.ttf` are the real Android system font, used by
`tool/screenshots_test.dart` so headlessly rendered screenshots look like the
app on a real device. They are **not** shipped in the app and **not** declared
in `pubspec.yaml`.

Roboto is licensed under the Apache License 2.0 — see `LICENSE.txt` in this
directory (copied from https://github.com/googlefonts/roboto).
