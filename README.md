# note

A minimal Flutter app for triaging a folder of plain-text notes stored as JSON files on disk. Targets Linux desktop and Android (sideload) only.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/install) (stable channel)
- Android SDK + NDK (via `flutter doctor` / Android Studio) for the Android target
- Linux desktop build tools:
  - Ubuntu: `sudo apt install cmake ninja-build clang libgtk-3-dev`
  - Fedora: `sudo dnf install cmake ninja-build clang gtk3-devel`
- [`just`](https://github.com/casey/just) (optional) — see `justfile` for the dev/build/install shortcuts used below

## Setup

```bash
flutter pub get
```

## Development

```bash
just dev                # or: flutter run -d linux
flutter run -d <device> # Android device/emulator
```

On first launch the app opens straight into Settings and asks you to pick a data folder — nothing is hardcoded. The whole folder is parsed into memory once, in a background isolate (`compute`), so startup stays responsive even as the note count grows into the thousands; the app then works entirely off that in-memory copy for the rest of the session (it assumes nothing else edits the folder concurrently).

- **Android**: on launch the app requests "All files access" (`MANAGE_EXTERNAL_STORAGE`) so it can read/write a folder anywhere on the device, not just app-scoped storage. This is a manual one-time toggle in system Settings; a "Grant full disk access" button is also available on the Settings tab if it was skipped or revoked.
- **Linux**: a native folder picker (`file_picker`), backed by a real filesystem path.

The chosen folder path is persisted via `shared_preferences` (`data_folder` key) and reused on next launch.

## Build

```bash
just apk                    # debug APK, drops you into its output dir
just reinstall              # release Linux bundle, installed to ~/.local + desktop entry
flutter build apk --debug   # equivalent, manual
flutter build linux         # equivalent, manual
```

Install a built APK: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`

### App icon

The source icon is `assets/icon/logo.png`. The Android launcher icon (`android/app/src/main/res/mipmap-*/ic_launcher.png`) is generated from it via [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) (config in `pubspec.yaml`); after changing the source image, regenerate with:

```bash
dart run flutter_launcher_icons
```

On Linux, `just reinstall` installs the same icon into the `hicolor` icon theme and points the desktop entry at it, so it shows up in the app launcher/taskbar.

## Analysis

```bash
flutter analyze
```

## Data format

Each note is one `*.json` file directly inside the data folder, e.g.:

```json
{
  "body": "the note text, may contain markdown",
  "notes": ["a queued annotation", "another one"],
  "rels": [["source", "other-file.json"]],
  "extraData": { "...": "arbitrary extra fields from other tools" }
}
```

- `body` (string) — the note content, rendered as markdown in Queue.
- `notes` (string array, optional) — annotations appended from the Queue screen.
- Everything else (`rels`, `extraData`, or any other top-level key) is opaque to this app: it's read in, kept in memory, and written back byte-for-byte unchanged whenever a file is saved. The app only ever adds/updates `notes`.

See `lib/models/note.dart` for the read/write logic and `lib/repository/note_repository.dart` for the folder scan + in-memory store.

## Screens

- **Add** — a full-screen text box. "Add" slugs the first few words of the text, appends a random 6-hex-char suffix for uniqueness, and writes a new `{"body": "..."}` file to the data folder. "Clear" just resets the text box.
- **Queue** — loads a random note and renders its `body` as markdown. A short text field above it lets you type an annotation; "Save" appends it to that note's `notes` array (writing the file back to disk) and loads the next random note; "Skip" discards the field and loads the next random note without writing anything.
- **Settings** — shows the current data folder and loaded note count, lets you pick a different folder, and (Android only) lets you (re-)grant full disk access.
