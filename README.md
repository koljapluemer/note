# note

A minimal Flutter app for triaging a folder of plain-text notes stored as `.txt` files on disk. Targets Linux desktop and Android (sideload) only.

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

## Analysis

```bash
flutter analyze
```

## Data format

Each note is one `*.txt` file directly inside the data folder, holding nothing but the note's raw text — no JSON wrapper, no metadata. Notes are always a single line: any newlines typed into a note are collapsed to spaces before the file is written. Content is shown exactly as typed — there's no markdown rendering anywhere in the app.

See `lib/models/note.dart` for the read/write logic and `lib/repository/note_repository.dart` for the folder scan + in-memory store.

## Screens

- **Add** — a full-screen text box. "Add" slugs the first few words of the text, appends a random 6-hex-char suffix for uniqueness, collapses any newlines, and writes a new `.txt` file to the data folder. "Clear" just resets the text box.
- **Queue** — draws 3 random notes at a time and lists them, each with an "Edit" icon button (jumps to the same form used by Add, prefilled with that note's text, saving back to its file) and a "Delete" icon button (removes it from the list immediately and shows an "Undo" snackbar; the file is only actually deleted from disk once you've interacted with the app twice more without hitting undo). A single "Next" button loads a fresh batch of 3.
- **List** — every note in the data folder, with a filter box at the top that narrows the list to notes containing the typed text. Each row has the same Edit/Delete icon buttons as Queue.
- **Settings** — shows the current data folder and loaded note count, lets you pick a different folder, and (Android only) lets you (re-)grant full disk access.
