#!/usr/bin/env bash
set -euo pipefail

THUMB_DIR="${HOME}/.cache/minimalarch-thumbs"
CURRENT_FILE="${HOME}/.cache/minimalarch-current-wallpaper"
mkdir -p "${THUMB_DIR}"

ensure_daemon() {
    # Stop walleclipse so only awww owns the wallpaper surface
    systemctl --user stop walleclipse.service >/dev/null 2>&1 || true
    pkill -x walleclipse >/dev/null 2>&1 || true
    pkill -x mpvpaper >/dev/null 2>&1 || true
    pkill -x swaybg >/dev/null 2>&1 || true

    if ! awww query >/dev/null 2>&1; then
        rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/*awww-daemon*.sock 2>/dev/null || true
        systemctl --user stop minimalarch-awww.service >/dev/null 2>&1 || true
        systemctl --user reset-failed minimalarch-awww.service >/dev/null 2>&1 || true
        systemd-run --user --collect --unit=minimalarch-awww \
            -E WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
            awww-daemon >/dev/null 2>&1 || nohup awww-daemon >/dev/null 2>&1 &
        for _ in $(seq 1 30); do
            if awww query >/dev/null 2>&1; then
                break
            fi
            sleep 0.1
        done
    fi
}

list_wallpapers_json() {
    python3 - "${THUMB_DIR}" <<'PY'
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys

thumb_dir = sys.argv[1]
roots = [
    os.path.expanduser("~/.config/wallpapers"),
    os.path.expanduser("~/Pictures"),
]
exts = {".jpg", ".jpeg", ".png", ".webp"}
seen = set()
items = []

for root in roots:
    if not os.path.isdir(root):
        continue
    for dirpath, _, filenames in os.walk(root, followlinks=True):
        # Skip internal thumb/cache dirs if any
        if "/.cache" in dirpath or "/quarantine" in dirpath:
            continue
        for fname in sorted(filenames):
            ext = os.path.splitext(fname)[1].lower()
            if ext not in exts:
                continue
            full_path = os.path.realpath(os.path.join(dirpath, fname))
            if full_path in seen or not os.path.isfile(full_path):
                continue
            seen.add(full_path)

            rel_cat = os.path.relpath(dirpath, root)
            if rel_cat == ".":
                cat = os.path.basename(root)
            else:
                cat = os.path.basename(rel_cat)

            h = hashlib.md5(full_path.encode("utf-8")).hexdigest()
            thumb_path = os.path.join(thumb_dir, f"{h}.jpg")
            items.append({
                "path": full_path,
                "thumb": thumb_path,
                "name": os.path.splitext(fname)[0].replace("_", " "),
                "category": cat,
            })

items.sort(key=lambda x: (x["category"].lower(), x["name"].lower()))

def ensure_thumb(item):
    src = item["path"]
    dst = item["thumb"]
    if os.path.isfile(dst) and os.path.getsize(dst) > 0:
        return
    try:
        res = subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error",
                "-i", src,
                "-vf", "scale=320:180:force_original_aspect_ratio=increase,crop=320:180",
                "-frames:v", "1", "-q:v", "4", dst,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
        if res.returncode == 0 and os.path.isfile(dst) and os.path.getsize(dst) > 0:
            return
    except Exception:
        pass
    try:
        subprocess.run(
            ["magick", f"{src}[0]", "-resize", "320x180^", "-gravity", "center", "-extent", "320x180", "-quality", "82", dst],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except Exception:
        pass

missing = [it for it in items if not (os.path.isfile(it["thumb"]) and os.path.getsize(it["thumb"]) > 0)]
if missing:
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        pool.map(ensure_thumb, missing)

# Fall back to original image if thumbnail creation failed for an entry
for it in items:
    if not (os.path.isfile(it["thumb"]) and os.path.getsize(it["thumb"]) > 0):
        it["thumb"] = it["path"]

print(json.dumps(items))
PY
}

set_wallpaper() {
    local img_path="${1:-}"
    local req_transition="${2:-random}"

    if [[ -z "$img_path" || ! -f "$img_path" ]]; then
        echo "Wallpaper not found: $img_path" >&2
        exit 1
    fi

    ensure_daemon

    local transition="$req_transition"
    if [[ -z "$transition" || "$transition" == "random" ]]; then
        local types=(grow outer wave wipe center)
        transition="${types[RANDOM % ${#types[@]}]}"
    fi

    local positions=(center top-left top-right bottom-left bottom-right top bottom)
    local pos="${positions[RANDOM % ${#positions[@]}]}"
    local angles=(30 45 135 210 315)
    local angle="${angles[RANDOM % ${#angles[@]}]}"

    local args=(
        img "$img_path"
        --transition-type "$transition"
        --transition-fps 60
        --transition-duration 0.9
        --transition-bezier .22,1,.36,1
        --transition-pos "$pos"
        --transition-angle "$angle"
    )
    if [[ "$transition" == "wave" ]]; then
        args+=(--transition-wave 24,18)
    fi

    awww "${args[@]}"
    printf '%s\n' "$img_path" > "$CURRENT_FILE"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -x "${script_dir}/hypr-config.sh" ]]; then
        nohup "${script_dir}/hypr-config.sh" --refresh-palette >/dev/null 2>&1 &
    fi

    if command -v coloreclipse >/dev/null 2>&1; then
        nohup coloreclipse wal "$img_path" >/dev/null 2>&1 &
    fi
}

pick_random_wallpaper() {
    local transition="${1:-random}"
    local current=""
    if [[ -f "$CURRENT_FILE" ]]; then
        current=$(cat "$CURRENT_FILE" 2>/dev/null || true)
    fi

    local chosen
    chosen=$(python3 - "$current" <<'PY'
import os, random, sys

current = os.path.realpath(sys.argv[1]) if sys.argv[1] else ""
roots = [os.path.expanduser("~/.config/wallpapers"), os.path.expanduser("~/Pictures")]
exts = {".jpg", ".jpeg", ".png", ".webp"}
candidates = []
for root in roots:
    if not os.path.isdir(root):
        continue
    for dp, _, fns in os.walk(root, followlinks=True):
        if "/.cache" in dp or "/quarantine" in dp:
            continue
        for fn in fns:
            if os.path.splitext(fn)[1].lower() in exts:
                p = os.path.realpath(os.path.join(dp, fn))
                if os.path.isfile(p):
                    candidates.append(p)

if not candidates:
    sys.exit(1)
filtered = [c for c in candidates if c != current]
print(random.choice(filtered or candidates))
PY
)
    set_wallpaper "$chosen" "$transition"
}

init_wallpaper() {
    ensure_daemon
    local target=""
    if [[ -f "$CURRENT_FILE" ]]; then
        target=$(cat "$CURRENT_FILE" 2>/dev/null || true)
    fi
    if [[ -z "$target" || ! -f "$target" ]]; then
        target=$(find "${HOME}/.config/wallpapers" "${HOME}/Pictures" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | head -n 1 || true)
    fi
    if [[ -n "$target" && -f "$target" ]]; then
        set_wallpaper "$target" "fade"
    fi
}

cmd="${1:---list}"
case "$cmd" in
    --list)
        list_wallpapers_json
        ;;
    --set)
        set_wallpaper "${2:-}" "${3:-random}"
        ;;
    --random)
        pick_random_wallpaper "${2:-random}"
        ;;
    --init)
        init_wallpaper
        ;;
    --current)
        if [[ -f "$CURRENT_FILE" ]]; then
            cat "$CURRENT_FILE"
        fi
        ;;
    *)
        echo "Usage: $0 [--list | --set <path> [transition] | --random [transition] | --init | --current]" >&2
        exit 1
        ;;
esac
