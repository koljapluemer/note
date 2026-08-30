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
    mkdir -p ~/.local/share/calendar
    cp -r build/linux/x64/release/bundle/* ~/.local/share/calendar/
    mkdir -p ~/.local/bin
    ln -sf ~/.local/share/calendar/calendar ~/.local/bin/calendar

    for size in 16 32 48 64 128 256 512; do
        dir=~/.local/share/icons/hicolor/${size}x${size}/apps
        mkdir -p "$dir"
        convert icons/icon.png -resize "${size}x${size}" "$dir/com.koljasam.calendar.png"
    done
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor || true

    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/com.koljasam.calendar.desktop
    [Desktop Entry]
    Type=Application
    Name=calendar
    Exec=$HOME/.local/share/calendar/calendar
    Icon=com.koljasam.calendar
    Categories=Utility;
    StartupWMClass=com.example.calendar
    EOF
    command -v update-desktop-database >/dev/null && update-desktop-database ~/.local/share/applications || true

# Build the debug APK and drop into its output directory (e.g. to run adb install)
apk:
    flutter build apk --debug
    cd build/app/outputs/flutter-apk && exec $SHELL
