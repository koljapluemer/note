# note

A minimal Flutter app for triaging a folder of short plain-text notes, each stored as a small `.json` file on disk. Targets Linux desktop and Android (sideload) only.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/install) (stable channel)
- Android SDK + NDK (via `flutter doctor` / Android Studio) for the Android target
- Linux desktop build tools:
  - Ubuntu: `sudo apt install cmake ninja-build clang libgtk-3-dev imagemagick`
  - Fedora: `sudo dnf install cmake ninja-build clang gtk3-devel ImageMagick`
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

## Icon

`icons/icon.png` is the single 512×512 source (attribution in `icons/about.txt`). Android's `mipmap-*/ic_launcher.png` files are pre-generated from it and committed — regenerate them after changing the source with:

```bash
for density_size in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density=${density_size%%:*}; size=${density_size##*:}
  convert icons/icon.png -resize "${size}x${size}" "android/app/src/main/res/mipmap-$density/ic_launcher.png"
done
```

For Linux, `just reinstall` generates the hicolor icon theme set from `icons/icon.png` at install time and points the desktop entry's `Icon=` at it — nothing to regenerate by hand there.

## Analysis

```bash
flutter analyze
```

## Data format

Each note is one `*.json` file directly inside the data folder, a single JSON object:

```json
{
  "body": "the note's single line of text",
  "extra": "optional long-form content",
  "rels": { "arbitrary": "string map" }
}
```

- `body` is always present. Notes are a single line: any newlines typed into a note are collapsed to spaces before the file is written. Content is shown exactly as typed — there's no markdown rendering anywhere in the app.
- `extra` and `rels` are written only when non-empty.
- `rels` is an opaque string→string map the app never reads, renders, or validates. It exists purely so external tooling can hang metadata off a note. **Any other unrecognised top-level keys are preserved verbatim on write too** — nothing a third party adds to a note file is lost on the next edit.
- Writes go through a temp file + atomic rename, so a crash mid-write can't leave a half-written note.

An optional image is **not** stored in the JSON — it stays a real file in a sibling `images/` folder, named `<note-name>-<timestamp><ext>`, and is matched back to its note by name during the folder scan.

See `lib/models/note.dart` for the read/write logic and `lib/repository/note_repository.dart` for the folder scan + in-memory store.

### Migrating an older folder

Folders created before the JSON switch hold `*.txt` notes (plus `*.extra.txt` sidecars). Convert one in place with:

```bash
python3 tools/migrate_txt_to_json.py /path/to/your/notes            # convert
python3 tools/migrate_txt_to_json.py /path/to/your/notes --dry-run  # preview only
```

It's idempotent, leaves `images/` untouched, and moves the original `.txt` files into `migrated-txt-backup/` (pass `--delete-originals` to remove them instead).

## Screens

- **Add** — a full-screen text box. "Add" slugs the first few words of the text, appends a random 6-hex-char suffix for uniqueness, collapses any newlines, and writes a new `.json` file to the data folder. "Clear" just resets the text box.
- **Queue** — draws 3 random notes at a time and lists them, each with an "Edit" icon button (jumps to the same form used by Add, prefilled with that note's text, saving back to its file) and a "Delete" icon button (removes it from the list immediately and shows an "Undo" snackbar; the file is only actually deleted from disk once you've interacted with the app twice more without hitting undo). A single "Next" button loads a fresh batch of 3.
- **List** — every note in the data folder, with a filter box at the top that narrows the list to notes containing the typed text. Each row has the same Edit/Delete icon buttons as Queue.
- **Settings** — shows the current data folder and loaded note count, lets you pick a different folder, and (Android only) lets you (re-)grant full disk access.
