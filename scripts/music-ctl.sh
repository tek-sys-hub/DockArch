#!/usr/bin/env bash
set -euo pipefail

get_status_json() {
    local st
    st=$(playerctl status 2>/dev/null || true)
    if [[ "$st" == "Playing" || "$st" == "Paused" ]]; then
        local pos meta loop_st
        pos=$(playerctl position 2>/dev/null || echo 0)
        meta=$(playerctl metadata --format '{{playerName}}	{{title}}	{{artist}}	{{album}}	{{mpris:artUrl}}	{{mpris:length}}' 2>/dev/null || echo "")
        loop_st=$(playerctl loop 2>/dev/null || echo "None")
        python3 - "$st" "$pos" "$meta" "$loop_st" <<'PY'
import json, sys

st, pos_s, meta, loop_st = sys.argv[1:5]
parts = meta.split("\t")
while len(parts) < 6:
    parts.append("")
try:
    pos = max(0.0, float(pos_s or 0))
except Exception:
    pos = 0.0
try:
    raw_len = float(parts[5] or 0)
    dur = raw_len / 1000000.0 if raw_len > 1000000 else raw_len
except Exception:
    dur = 0.0

print(json.dumps({
    "active": True,
    "playing": (st == "Playing"),
    "title": parts[1] or "Unknown Track",
    "artist": parts[2] or "",
    "album": parts[3] or "",
    "art": parts[4] or "",
    "player": parts[0] or "Media",
    "pos": pos,
    "len": max(0.0, dur),
    "loop": loop_st in ("Track", "Playlist"),
}, ensure_ascii=False))
PY
        return 0
    fi

    printf '{"active":false,"playing":false,"title":"","artist":"","album":"","art":"","player":"Media","pos":0,"len":0,"loop":false}\n'
}

cmd="${1:---status}"
case "$cmd" in
    --status)
        get_status_json
        ;;
    --play-pause)
        playerctl play-pause 2>/dev/null || true
        get_status_json
        ;;
    --next)
        playerctl next 2>/dev/null || true
        get_status_json
        ;;
    --prev)
        playerctl previous 2>/dev/null || true
        get_status_json
        ;;
    --stop)
        playerctl stop 2>/dev/null || true
        get_status_json
        ;;
    --seek)
        sec="${2:-0}"
        playerctl position "$sec" 2>/dev/null || true
        get_status_json
        ;;
    --toggle-loop)
        cur=$(playerctl loop 2>/dev/null || echo "None")
        if [[ "$cur" == "Track" || "$cur" == "Playlist" ]]; then
            playerctl loop None 2>/dev/null || true
        else
            playerctl loop Playlist 2>/dev/null || playerctl loop Track 2>/dev/null || true
        fi
        get_status_json
        ;;
esac
