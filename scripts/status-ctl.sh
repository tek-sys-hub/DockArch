#!/usr/bin/env bash
set -euo pipefail

action_ok="true"
action_msg=""

run_cmd() {
    local out
    if ! out=$("$@" 2>&1); then
        action_ok="false"
        action_msg="${out//$'\n'/ }"
        return 1
    fi
    return 0
}

cmd="${1:---status}"
shift || true

case "$cmd" in
    --status)
        ;;
    --wifi-toggle)
        state="${1:-on}"
        run_cmd nmcli radio wifi "$state" || true
        sleep 0.3
        ;;
    --wifi-rescan)
        nmcli dev wifi rescan >/dev/null 2>&1 || true
        sleep 0.5
        ;;
    --wifi-connect)
        ssid="${1:-}"
        password="${2:-}"
        if [[ -n "$ssid" ]]; then
            if [[ -n "$password" ]]; then
                run_cmd nmcli dev wifi connect "$ssid" password "$password" || true
            else
                if ! nmcli con up "$ssid" >/dev/null 2>&1; then
                    run_cmd nmcli dev wifi connect "$ssid" || true
                fi
            fi
        fi
        ;;
    --wifi-disconnect)
        ssid="${1:-}"
        if [[ -n "$ssid" ]]; then
            if ! nmcli con down "$ssid" >/dev/null 2>&1; then
                dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$2=="wifi" && $3=="connected" {print $1; exit}' || true)
                if [[ -n "$dev" ]]; then
                    run_cmd nmcli dev disconnect "$dev" || true
                fi
            fi
        fi
        ;;
    --bt-toggle)
        state="${1:-on}"
        run_cmd bluetoothctl power "$state" || true
        sleep 0.25
        ;;
    --bt-scan)
        timeout 3 bluetoothctl --timeout 3 scan on >/dev/null 2>&1 || true
        ;;
    --bt-connect)
        mac="${1:-}"
        if [[ -n "$mac" ]]; then
            run_cmd timeout 8 bluetoothctl connect "$mac" || true
        fi
        ;;
    --bt-disconnect)
        mac="${1:-}"
        if [[ -n "$mac" ]]; then
            run_cmd timeout 5 bluetoothctl disconnect "$mac" || true
        fi
        ;;
    --set-vol)
        pct="${1:-50}"
        pct=$(( pct < 0 ? 0 : (pct > 100 ? 100 : pct) ))
        run_cmd wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${pct}%" || true
        ;;
    --mute-toggle)
        run_cmd wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle || true
        ;;
    --set-mic-vol)
        pct="${1:-100}"
        pct=$(( pct < 0 ? 0 : (pct > 120 ? 120 : pct) ))
        run_cmd wpctl set-volume -l 1.2 @DEFAULT_AUDIO_SOURCE@ "${pct}%" || true
        ;;
    --mic-mute-toggle)
        run_cmd wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle || true
        ;;
    --set-sink)
        sink_id="${1:-}"
        if [[ -n "$sink_id" ]]; then
            run_cmd wpctl set-default "$sink_id" || true
        fi
        ;;
    --set-source)
        src_id="${1:-}"
        if [[ -n "$src_id" ]]; then
            run_cmd wpctl set-default "$src_id" || true
        fi
        ;;
    --set-power)
        prof="${1:-balanced}"
        case "$prof" in
            power-saver|balanced|performance)
                run_cmd powerprofilesctl set "$prof" || true
                ;;
            *)
                action_ok="false"
                action_msg="Invalid profile: $prof"
                ;;
        esac
        ;;
    *)
        action_ok="false"
        action_msg="Unknown command: $cmd"
        ;;
esac

python3 - "$action_ok" "$action_msg" <<'PY'
import json
import re
import subprocess
import sys

action_ok = sys.argv[1] == "true"
action_msg = sys.argv[2]

def run_out(args, timeout=2.5):
    try:
        res = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return res.stdout or ""
    except Exception:
        return ""

# 1. Wi-Fi radio, active SSID, and visible networks
wifi_on = run_out(["nmcli", "radio", "wifi"]).strip() == "enabled"
wifi_ssid = "Offline"
wifi_networks = []

if wifi_on:
    active_out = run_out(["nmcli", "-t", "-f", "TYPE,NAME", "connection", "show", "--active"])
    active_ssid = ""
    for line in active_out.splitlines():
        parts = line.split(":", 1)
        if len(parts) == 2 and parts[0] == "802-11-wireless":
            active_ssid = parts[1]
            break
    wifi_ssid = active_ssid if active_ssid else "On"

    wifi_raw = run_out(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"])
    by_ssid = {}
    for line in wifi_raw.splitlines():
        if not line:
            continue
        # Split on unescaped colons
        fields = re.split(r"(?<!\\):", line)
        if len(fields) < 4:
            continue
        in_use = fields[0].strip() == "*"
        ssid = fields[1].replace("\\:", ":").strip()
        if not ssid:
            continue
        try:
            signal = int(fields[2].strip())
        except ValueError:
            signal = 0
        sec = fields[3].replace("\\:", ":").strip() or "Open"
        prev = by_ssid.get(ssid)
        if prev is None or in_use or (not prev["in_use"] and signal > prev["signal"]):
            by_ssid[ssid] = {
                "ssid": ssid,
                "signal": signal,
                "security": sec,
                "in_use": in_use or (ssid == active_ssid),
            }
    wifi_networks = sorted(
        by_ssid.values(),
        key=lambda x: (0 if x["in_use"] else 1, -x["signal"], x["ssid"].lower()),
    )[:14]

# 2. Bluetooth power and devices
bt_show = run_out(["bluetoothctl", "show"], timeout=1.5)
bt_on = "Powered: yes" in bt_show
bt_devices = []
dev_out = run_out(["bluetoothctl", "devices"], timeout=1.5)
for line in dev_out.splitlines():
    m = re.match(r"^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$", line.strip())
    if not m:
        continue
    mac, name = m.group(1), m.group(2).strip()
    info = run_out(["bluetoothctl", "info", mac], timeout=1.2)
    connected = "Connected: yes" in info
    paired = "Paired: yes" in info
    bt_devices.append({
        "mac": mac,
        "name": name,
        "connected": connected,
        "paired": paired,
    })
bt_devices.sort(key=lambda d: (0 if d["connected"] else (1 if d["paired"] else 2), d["name"].lower()))

# 3. Audio volumes, mutes, sinks, and sources via wpctl
def parse_wp_vol(target):
    out = run_out(["wpctl", "get-volume", target]).strip()
    vol_pct = 0
    muted = "[MUTED]" in out
    m = re.search(r"Volume:\s*([0-9.]+)", out)
    if m:
        try:
            vol_pct = int(round(float(m.group(1)) * 100))
        except ValueError:
            pass
    return vol_pct, muted

vol, muted = parse_wp_vol("@DEFAULT_AUDIO_SINK@")
mic_vol, mic_muted = parse_wp_vol("@DEFAULT_AUDIO_SOURCE@")

audio_sinks = []
audio_sources = []
wp_status = run_out(["wpctl", "status"])
in_audio = False
section = ""
for raw_line in wp_status.splitlines():
    stripped = raw_line.strip()
    if stripped == "Audio":
        in_audio = True
        section = ""
        continue
    if in_audio and stripped in ("Video", "Settings"):
        break
    if not in_audio:
        continue
    if "Sinks:" in stripped:
        section = "sinks"
        continue
    if "Sources:" in stripped:
        section = "sources"
        continue
    if any(k in stripped for k in ("Devices:", "Filters:", "Streams:")):
        section = ""
        continue
    if section in ("sinks", "sources"):
        clean = re.sub(r"^[│├└─\s]+", "", raw_line)
        m = re.match(r"^(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[vol:.*\])?$", clean)
        if m:
            is_def = bool(m.group(1))
            dev_id = int(m.group(2))
            dev_name = m.group(3).strip()
            item = {"id": dev_id, "name": dev_name, "default": is_def}
            if section == "sinks":
                audio_sinks.append(item)
            else:
                audio_sources.append(item)

# 4. Power profile
pp = run_out(["powerprofilesctl", "get"], timeout=1.5).strip()
if pp not in ("power-saver", "balanced", "performance"):
    pp = "balanced"

print(json.dumps({
    "wifi_on": wifi_on,
    "wifi_ssid": wifi_ssid,
    "wifi_networks": wifi_networks,
    "bt_on": bt_on,
    "bt_devices": bt_devices,
    "vol": vol,
    "muted": muted,
    "mic_vol": mic_vol,
    "mic_muted": mic_muted,
    "audio_sinks": audio_sinks,
    "audio_sources": audio_sources,
    "power_profile": pp,
    "action_ok": action_ok,
    "action_msg": action_msg,
}))
PY

