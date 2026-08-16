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

    for size in 16 32 48 64 128 256 512; do
        dir=~/.local/share/icons/hicolor/${size}x${size}/apps
        mkdir -p "$dir"
        convert icons/icon.png -resize "${size}x${size}" "$dir/com.koljasam.note.png"
    done
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor || true

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
    command -v update-desktop-database >/dev/null && update-desktop-database ~/.local/share/applications || true

# Build the debug APK and drop into its output directory (e.g. to run adb install)
apk:
    flutter build apk --debug
    cd build/app/outputs/flutter-apk && exec $SHELL
