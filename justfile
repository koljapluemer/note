default:
    @just --list

# Run the desktop app with hot reload
dev:
    flutter run -d linux

# Build the Linux release bundle and (re)install it into ~/.local, overriding any existing install
reinstall:
    #!/usr/bin/env bash
    set -euo pipefail
    flutter build linux --release
    mkdir -p ~/.local/share/note
    cp -r build/linux/x64/release/bundle/* ~/.local/share/note/
    mkdir -p ~/.local/bin
    ln -sf ~/.local/share/note/note ~/.local/bin/note
    mkdir -p ~/.local/share/icons/hicolor/512x512/apps
    cp assets/icon/logo.png ~/.local/share/icons/hicolor/512x512/apps/com.koljasam.note.png
    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/com.koljasam.note.desktop
    [Desktop Entry]
    Type=Application
    Name=note
    Exec=$HOME/.local/share/note/note
    Icon=com.koljasam.note
    Categories=Utility;
    StartupWMClass=com.example.note
    EOF
    gtk-update-icon-cache ~/.local/share/icons/hicolor &>/dev/null || true

# Build the debug APK and drop into its output directory (e.g. to run adb install)
apk:
    flutter build apk --debug
    cd build/app/outputs/flutter-apk && exec $SHELL
