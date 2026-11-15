#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/cherry/main/minimalarch"
QS_TARGET="/home/cherry/.config/quickshell/metaarch"
QS_BACKUP="/home/cherry/.config/quickshell/metaarch.backup"
QS_MINIMAL="${BASE_DIR}/quickshell"

start_qs() {
    systemctl --user stop minimalarch-qs.service >/dev/null 2>&1 || true
    systemctl --user reset-failed minimalarch-qs.service >/dev/null 2>&1 || true
    pkill -x qs >/dev/null 2>&1 || true
    systemd-run --user --collect --unit=minimalarch-qs \
        -E MANGOHUD=0 \
        -E WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
        qs -n -p "$QS_TARGET" >/dev/null 2>&1
}

enable_minimal() {
    mkdir -p "$(dirname "$QS_TARGET")"

    if [[ -e "$QS_TARGET" && ! -L "$QS_TARGET" ]]; then
        if [[ ! -e "$QS_BACKUP" ]]; then
            mv "$QS_TARGET" "$QS_BACKUP"
            echo "Backed up previous Quickshell config to $QS_BACKUP"
        else
            echo "Backup already exists at $QS_BACKUP; refusing to overwrite." >&2
            exit 1
        fi
    fi

    ln -sfn "$QS_MINIMAL" "$QS_TARGET"
    echo "Linked $QS_TARGET -> $QS_MINIMAL"

    "${BASE_DIR}/scripts/hypr-config.sh" --apply >/dev/null
    echo "Applied Hyprland spacing, rounding, and border styling"

    "${BASE_DIR}/scripts/wallpaper.sh" --list >/dev/null
    "${BASE_DIR}/scripts/wallpaper.sh" --init
    echo "Initialized awww wallpaper daemon and thumbnail cache"

    start_qs
    echo "MinimalArch Quickshell rice enabled."
}

restore_previous() {
    if [[ ! -e "$QS_BACKUP" ]]; then
        echo "No backup found at $QS_BACKUP" >&2
        exit 1
    fi

    if [[ -L "$QS_TARGET" ]]; then
        rm "$QS_TARGET"
    elif [[ -e "$QS_TARGET" ]]; then
        echo "$QS_TARGET exists and is not a symlink; refusing to overwrite." >&2
        exit 1
    fi

    mv "$QS_BACKUP" "$QS_TARGET"
    echo "Restored $QS_TARGET from $QS_BACKUP"

    systemctl --user stop minimalarch-awww.service >/dev/null 2>&1 || true
    pkill -x awww-daemon >/dev/null 2>&1 || true
    systemctl --user restart walleclipse.service
    start_qs
    echo "Restored previous Quickshell and WallEclipse setup."
}

case "${1:---enable}" in
    --enable)
        enable_minimal
        ;;
    --reload)
        start_qs
        ;;
    --restore)
        restore_previous
        ;;
    *)
        echo "Usage: $0 [--enable | --reload | --restore]" >&2
        exit 1
        ;;
esac
