#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CPU_PREV_FILE="${RUNTIME_DIR}/minimalarch-cpu.prev"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/minimalarch"
mkdir -p "$CACHE_DIR"

GH_USER="tek-sys-hub"
GH_CACHE="${CACHE_DIR}/github-${GH_USER}.json"
GH_AVATAR="${CACHE_DIR}/github-${GH_USER}.png"
GH_LOCK="${RUNTIME_DIR}/minimalarch-gh.lock"
WEATHER_CACHE="${CACHE_DIR}/weather-kanchanpur.json"
WEATHER_LOCK="${RUNTIME_DIR}/minimalarch-weather.lock"

refresh_weather_cache() {
    local wx_raw
    wx_raw=$(curl -fsSL --max-time 6 "https://api.open-meteo.com/v1/forecast?latitude=28.9639&longitude=80.1778&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7" 2>/dev/null || true)
    [[ -n "$wx_raw" ]] || return 1

    python3 - "$wx_raw" "${WEATHER_CACHE}.tmp.$$" << 'PY'
import datetime, json, sys

wx_raw, out_path = sys.argv[1:3]
data = json.loads(wx_raw)
cur = data.get("current", {}) if isinstance(data, dict) else {}
temp_val = float(cur.get("temperature_2m", 24.0) or 24.0)
temp_c = int(round(temp_val))
feels_c = int(round(float(cur.get("apparent_temperature", temp_val) or temp_val)))
humidity = int(round(float(cur.get("relative_humidity_2m", 0) or 0)))
wind_kmh = int(round(float(cur.get("wind_speed_10m", 0) or 0)))
code = int(cur.get("weather_code", 0) or 0)
is_day = int(cur.get("is_day", 1) or 1)

def decode_wmo(c, day_flag=1):
    if c == 0:
        return ("󰖙" if day_flag else "󰖔"), "Clear"
    if c in (1, 2, 3):
        return ("󰖕" if day_flag else "󰼱"), ("Mainly Clear" if c == 1 else ("Partly Cloudy" if c == 2 else "Cloudy"))
    if c in (45, 48):
        return "󰖑", "Fog"
    if c in (51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82):
        return "󰖗", "Rain"
    if c in (71, 73, 75, 77, 85, 86):
        return "󰖘", "Snow"
    if c in (95, 96, 99):
        return "󰖓", "Storm"
    return "󰖕", "Fair"

icon, desc = decode_wmo(code, is_day)

daily = data.get("daily", {}) if isinstance(data, dict) else {}
dates = daily.get("time") or []
codes = daily.get("weather_code") or []
highs = daily.get("temperature_2m_max") or []
lows = daily.get("temperature_2m_min") or []
rains = daily.get("precipitation_probability_max") or []

forecast = []
for i in range(min(7, len(dates))):
    try:
        dt = datetime.date.fromisoformat(str(dates[i]))
        day_lbl = "Today" if i == 0 else ("Tomorrow" if i == 1 else dt.strftime("%a"))
        date_lbl = dt.strftime("%b %-d")
    except Exception:
        day_lbl = f"Day {i + 1}"
        date_lbl = str(dates[i])
    d_code = int(codes[i] or 0) if i < len(codes) and codes[i] is not None else 0
    d_icon, d_desc = decode_wmo(d_code, 1)
    hi = int(round(float(highs[i]))) if i < len(highs) and highs[i] is not None else temp_c
    lo = int(round(float(lows[i]))) if i < len(lows) and lows[i] is not None else temp_c
    rain_p = int(round(float(rains[i]))) if i < len(rains) and rains[i] is not None else 0
    forecast.append({
        "day": day_lbl,
        "date": date_lbl,
        "icon": d_icon,
        "desc": d_desc,
        "high": hi,
        "low": lo,
        "rain": rain_p,
    })

payload = {
    "temp": f"{temp_c}°C",
    "temp_c": temp_c,
    "feels_like": f"{feels_c}°C",
    "humidity": humidity,
    "wind": f"{wind_kmh} km/h",
    "desc": desc,
    "icon": icon,
    "city": "Kanchanpur",
    "forecast": forecast,
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False)
PY
    if [[ -s "${WEATHER_CACHE}.tmp.$$" ]]; then
        mv -f "${WEATHER_CACHE}.tmp.$$" "$WEATHER_CACHE"
    else
        rm -f "${WEATHER_CACHE}.tmp.$$"
        return 1
    fi
}

refresh_github_cache() {
    local user_json repos_json avatar_url contrib_tmp
    contrib_tmp="${GH_CACHE}.contrib.$$"
    user_json=$(curl -fsSL --max-time 5 -H "Accept: application/vnd.github+json" "https://api.github.com/users/${GH_USER}" 2>/dev/null || true)
    repos_json=$(curl -fsSL --max-time 5 -H "Accept: application/vnd.github+json" "https://api.github.com/users/${GH_USER}/repos?per_page=100&sort=updated" 2>/dev/null || echo "[]")
    curl -fsSL --max-time 6 "https://github.com/users/${GH_USER}/contributions" -o "$contrib_tmp" 2>/dev/null || rm -f "$contrib_tmp"

    avatar_url=$(python3 -c '
import json, sys
try:
    u = json.loads(sys.argv[1])
    print(u.get("avatar_url", "") or "")
except Exception:
    print("")
' "$user_json" 2>/dev/null || true)

    local avatar_path=""
    if [[ -n "$avatar_url" ]]; then
        if curl -fsSL --max-time 5 "$avatar_url" -o "${GH_AVATAR}.tmp.$$" 2>/dev/null && [[ -s "${GH_AVATAR}.tmp.$$" ]]; then
            mv -f "${GH_AVATAR}.tmp.$$" "$GH_AVATAR"
            avatar_path="$GH_AVATAR"
        else
            rm -f "${GH_AVATAR}.tmp.$$"
        fi
    fi
    if [[ -z "$avatar_path" && -s "$GH_AVATAR" ]]; then
        avatar_path="$GH_AVATAR"
    fi

    python3 - "$user_json" "$repos_json" "$avatar_path" "$GH_USER" "${GH_CACHE}.tmp.$$" "$contrib_tmp" "$GH_CACHE" << 'PY'
import json, os, re, sys

user_raw, repos_raw, avatar_path, gh_user, out_path, contrib_path, old_cache = sys.argv[1:8]

u = {}
try:
    if user_raw.strip():
        parsed_u = json.loads(user_raw)
        if isinstance(parsed_u, dict) and parsed_u.get("login"):
            u = parsed_u
except Exception:
    u = {}

if not u and os.path.isfile(old_cache):
    try:
        with open(old_cache, "r", encoding="utf-8") as f:
            old = json.load(f)
        if isinstance(old, dict):
            u = old
    except Exception:
        pass

if not u:
    u = {"login": gh_user, "name": "Tek Raj Awasthi", "bio": "", "public_repos": 24, "followers": 38, "following": 37, "stars": 60}

try:
    repos = json.loads(repos_raw)
    if not isinstance(repos, list):
        repos = []
except Exception:
    repos = []

contrib_total = str(u.get("contrib_total") or "")
contrib_levels = u.get("contrib_levels") if isinstance(u.get("contrib_levels"), list) else []
if os.path.isfile(contrib_path):
    try:
        with open(contrib_path, "r", encoding="utf-8", errors="ignore") as f:
            contrib_html = f.read()
        m = re.search(r"([\d,]+)\s+contributions?\s+in\s+the\s+last\s+year", contrib_html)
        if m:
            contrib_total = m.group(1)
        cells = re.findall(r'data-date="(\d{4}-\d{2}-\d{2})"[^>]*data-level="(\d)"|data-level="(\d)"[^>]*data-date="(\d{4}-\d{2}-\d{2})"', contrib_html)
        parsed_cells = []
        for a, b, c, d in cells:
            dt = a or d
            lv = int(b or c)
            parsed_cells.append((dt, lv))
        if parsed_cells:
            parsed_cells.sort(key=lambda x: x[0])
            contrib_levels = [lv for _, lv in parsed_cells]
    except Exception:
        pass

stars = sum(int(r.get("stargazers_count", 0) or 0) for r in repos if isinstance(r, dict)) if repos else int(u.get("stars") or 0)
payload = {
    "login": str(u.get("login") or gh_user),
    "name": str(u.get("name") or u.get("login") or gh_user),
    "bio": str(u.get("bio") or ""),
    "public_repos": int(u.get("public_repos") or 0),
    "followers": int(u.get("followers") or 0),
    "following": int(u.get("following") or 0),
    "stars": int(stars),
    "html_url": str(u.get("html_url") or f"https://github.com/{gh_user}"),
    "avatar": avatar_path or str(u.get("avatar") or ""),
    "contrib_total": contrib_total,
    "contrib_levels": contrib_levels,
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False)
PY
    rm -f "$contrib_tmp"
    if [[ -s "${GH_CACHE}.tmp.$$" ]]; then
        mv -f "${GH_CACHE}.tmp.$$" "$GH_CACHE"
    else
        rm -f "${GH_CACHE}.tmp.$$"
        return 1
    fi
}

kill_user_task() {
    local target_pid="${1:-}"
    [[ "$target_pid" =~ ^[0-9]+$ ]] || return 0
    [[ "$target_pid" -gt 1 && "$target_pid" -ne "$$" ]] || return 0
    local info owner comm
    info=$(ps -p "$target_pid" -o user=,comm= 2>/dev/null || true)
    [[ -n "$info" ]] || return 0
    read -r owner comm <<< "$info"
    [[ "$owner" == "$USER" ]] || return 0
    case "$comm" in
        Hyprland|qs|quickshell|systemd|"(sd-pam)"|dbus-daemon|dbus-broker|pipewire|pipewire-pulse|wireplumber|awww-daemon|systemd-inhibit|coffeemode)
            return 0
            ;;
    esac
    kill -15 "$target_pid" 2>/dev/null || true
    sleep 0.15
    if kill -0 "$target_pid" 2>/dev/null; then
        kill -9 "$target_pid" 2>/dev/null || true
    fi
}

control_coffee_mode() {
    local mode="${1:-toggle}"
    if [[ -x "$HOME/.local/bin/coffeemode" ]]; then
        "$HOME/.local/bin/coffeemode" "$mode" >/dev/null 2>&1 || true
    else
        case "$mode" in
            on|start)
                if ! pgrep -u "${USER:-$(id -un)}" -f "systemd-inhibit.*CoffeeMode" >/dev/null 2>&1; then
                    nohup systemd-inhibit --what=idle:sleep --who=CoffeeMode --why="Coffee Mode active" sleep infinity >/dev/null 2>&1 &
                fi
                ;;
            off|stop)
                pkill -u "${USER:-$(id -un)}" -f "systemd-inhibit.*CoffeeMode" >/dev/null 2>&1 || true
                ;;
            toggle)
                if pgrep -u "${USER:-$(id -un)}" -f "systemd-inhibit.*CoffeeMode" >/dev/null 2>&1; then
                    pkill -u "${USER:-$(id -un)}" -f "systemd-inhibit.*CoffeeMode" >/dev/null 2>&1 || true
                else
                    nohup systemd-inhibit --what=idle:sleep --who=CoffeeMode --why="Coffee Mode active" sleep infinity >/dev/null 2>&1 &
                fi
                ;;
        esac
    fi
    if [[ "$mode" == "on" || "$mode" == "start" ]] || pgrep -u "${USER:-$(id -un)}" -f "systemd-inhibit.*CoffeeMode" >/dev/null 2>&1; then
        command -v hyprctl >/dev/null 2>&1 && hyprctl dispatch dpms on >/dev/null 2>&1 || true
    fi
}

light_mode=false
skip_bg_gh_refresh=false
skip_bg_wx_refresh=false
case "${1:-}" in
    --light)
        light_mode=true
        skip_bg_gh_refresh=true
        ;;
    --refresh-github)
        refresh_github_cache >/dev/null 2>&1 || true
        skip_bg_gh_refresh=true
        ;;
    --refresh-github-only)
        refresh_github_cache >/dev/null 2>&1 || true
        exit 0
        ;;
    --refresh-weather)
        refresh_weather_cache >/dev/null 2>&1 || true
        skip_bg_wx_refresh=true
        ;;
    --refresh-weather-only)
        refresh_weather_cache >/dev/null 2>&1 || true
        exit 0
        ;;
    --kill)
        kill_user_task "${2:-}"
        ;;
    --coffee)
        control_coffee_mode "${2:-toggle}"
        ;;
esac

if [[ "$skip_bg_gh_refresh" == "false" ]]; then
    need_gh_refresh=false
    if [[ ! -s "$GH_CACHE" ]] || [[ -n "$(find "$GH_CACHE" -mmin +15 2>/dev/null || true)" ]]; then
        need_gh_refresh=true
    fi
    if [[ "$need_gh_refresh" == "true" ]]; then
        now_ts=$(date +%s)
        prev_ts=0
        [[ -f "$GH_LOCK" ]] && prev_ts=$(cat "$GH_LOCK" 2>/dev/null || echo 0)
        [[ "$prev_ts" =~ ^[0-9]+$ ]] || prev_ts=0
        if (( now_ts - prev_ts > 30 )); then
            printf '%s\n' "$now_ts" > "$GH_LOCK"
            ("$0" --refresh-github-only >/dev/null 2>&1 &) || true
        fi
    fi
fi

if [[ "$skip_bg_wx_refresh" == "false" ]]; then
    need_wx_refresh=false
    if [[ ! -s "$WEATHER_CACHE" ]] || [[ -n "$(find "$WEATHER_CACHE" -mmin +15 2>/dev/null || true)" ]]; then
        need_wx_refresh=true
    fi
    if [[ "$need_wx_refresh" == "true" ]]; then
        now_ts=$(date +%s)
        prev_wx_ts=0
        [[ -f "$WEATHER_LOCK" ]] && prev_wx_ts=$(cat "$WEATHER_LOCK" 2>/dev/null || echo 0)
        [[ "$prev_wx_ts" =~ ^[0-9]+$ ]] || prev_wx_ts=0
        if (( now_ts - prev_wx_ts > 30 )); then
            printf '%s\n' "$now_ts" > "$WEATHER_LOCK"
            ("$0" --refresh-weather-only >/dev/null 2>&1 &) || true
        fi
    fi
fi

# CPU usage from /proc/stat delta (instantaneous across polls)
read_cpu_stat() {
    awk '/^cpu / {
        idle = $5 + $6;
        total = 0;
        for (i = 2; i <= NF; i++) total += $i;
        print total, idle;
        exit
    }' /proc/stat
}

read -r cur_total cur_idle < <(read_cpu_stat)
if [[ -f "$CPU_PREV_FILE" ]]; then
    read -r prev_total prev_idle < "$CPU_PREV_FILE" || { prev_total=$cur_total; prev_idle=$cur_idle; }
else
    sleep 0.12
    prev_total=$cur_total
    prev_idle=$cur_idle
    read -r cur_total cur_idle < <(read_cpu_stat)
fi
printf '%s %s\n' "$cur_total" "$cur_idle" > "$CPU_PREV_FILE"

cpu_pct=$(awk -v ct="$cur_total" -v ci="$cur_idle" -v pt="$prev_total" -v pi="$prev_idle" 'BEGIN {
    dt = ct - pt;
    di = ci - pi;
    if (dt <= 0) { print 0; exit }
    val = int(((dt - di) * 100.0 / dt) + 0.5);
    if (val < 0) val = 0;
    if (val > 100) val = 100;
    print val;
}')

# RAM usage from /proc/meminfo
read -r ram_pct ram_used ram_total < <(awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    END {
        if (total <= 0) { print "0 0.0G 0.0G"; exit }
        used = total - avail;
        pct = int((used * 100.0 / total) + 0.5);
        printf "%d %.1fG %.1fG\n", pct, used / 1048576.0, total / 1048576.0;
    }
' /proc/meminfo)

# Disk usage on /
read -r disk_pct disk_used disk_total < <(df -B1 / | awk 'NR==2 {
    total = $2; used = $3;
    if (total <= 0) { print "0 0G 0G"; exit }
    pct = int((used * 100.0 / total) + 0.5);
    printf "%d %.0fG %.0fG\n", pct, used / 1073741824.0, total / 1073741824.0;
}')

# Wi-Fi status
wifi_on=false
wifi_ssid="Offline"
if command -v nmcli >/dev/null 2>&1; then
    wifi_radio=$(nmcli radio wifi 2>/dev/null || echo "disabled")
    if [[ "$wifi_radio" == "enabled" ]]; then
        wifi_on=true
        active_ssid=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1=="802-11-wireless" { print $2; exit }' || true)
        if [[ -n "$active_ssid" ]]; then
            wifi_ssid="$active_ssid"
        else
            wifi_ssid="On"
        fi
    fi
else
    for state_file in /sys/class/net/wl*/operstate; do
        [[ -e "$state_file" ]] || continue
        wifi_on=true
        if [[ "$(cat "$state_file" 2>/dev/null || echo down)" == "up" ]]; then
            wifi_ssid="Connected"
            break
        fi
        wifi_ssid="Disconnected"
    done
fi

# Bluetooth status
bt_on=false
if command -v bluetoothctl >/dev/null 2>&1; then
    if timeout 0.5 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        bt_on=true
    fi
elif command -v rfkill >/dev/null 2>&1; then
    if ! rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
        bt_on=true
    fi
fi

# Audio output & input (mic) volume & mute via wpctl
vol=0
muted=false
mic_vol=100
mic_muted=false
if command -v wpctl >/dev/null 2>&1; then
    wp_out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
    if [[ -n "$wp_out" ]]; then
        vol=$(awk '{ printf "%d", ($2 * 100) + 0.5 }' <<< "$wp_out")
        if [[ "$wp_out" == *"[MUTED]"* ]]; then
            muted=true
        fi
    fi
    mic_out=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true)
    if [[ -n "$mic_out" ]]; then
        mic_vol=$(awk '{ printf "%d", ($2 * 100) + 0.5 }' <<< "$mic_out")
        if [[ "$mic_out" == *"[MUTED]"* ]]; then
            mic_muted=true
        fi
    fi
fi

# Battery status
bat=100
bat_status="AC"
for bat_dir in /sys/class/power_supply/BAT*; do
    [[ -d "$bat_dir" ]] || continue
    bat=$(cat "$bat_dir/capacity" 2>/dev/null || echo 100)
    bat_status=$(cat "$bat_dir/status" 2>/dev/null || echo "Unknown")
    break
done

# Power profile (power-saver, balanced, performance; fast busctl first to avoid Python CLI startup cost)
power_profile="balanced"
pp_raw=""
if command -v busctl >/dev/null 2>&1; then
    pp_raw=$(busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p' || true)
    if [[ -z "$pp_raw" ]]; then
        pp_raw=$(busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p' || true)
    fi
fi
if [[ -z "$pp_raw" ]] && command -v powerprofilesctl >/dev/null 2>&1; then
    pp_raw=$(powerprofilesctl get 2>/dev/null | tr -d '[:space:]' || true)
fi
case "$pp_raw" in
    power-saver|balanced|performance) power_profile="$pp_raw" ;;
    *)
        if [[ -r /sys/firmware/acpi/platform_profile ]]; then
            pp_raw=$(tr -d '[:space:]' < /sys/firmware/acpi/platform_profile 2>/dev/null || true)
            case "$pp_raw" in
                low-power|quiet|cool) power_profile="power-saver" ;;
                balanced) power_profile="balanced" ;;
                performance) power_profile="performance" ;;
            esac
        fi
        ;;
esac

# Screen brightness percentage
brightness=100
if command -v brightnessctl >/dev/null 2>&1; then
    brightness=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,"",$4); print int($4)}' || echo 100)
elif ls /sys/class/backlight/*/brightness >/dev/null 2>&1; then
    for bl_dir in /sys/class/backlight/*; do
        [[ -d "$bl_dir" ]] || continue
        cur_b=$(cat "$bl_dir/brightness" 2>/dev/null || echo 100)
        max_b=$(cat "$bl_dir/max_brightness" 2>/dev/null || echo 100)
        brightness=$(awk -v c="$cur_b" -v m="$max_b" 'BEGIN { if (m<=0) print 100; else printf "%d", (c*100.0/m)+0.5 }')
        break
    done
fi
[[ "$brightness" =~ ^[0-9]+$ ]] || brightness=100

# CPU temperature in °C (k10temp / coretemp / zenpower -> thermal_zone0 fallback)
cpu_temp=45
for hw in /sys/class/hwmon/hwmon*; do
    [[ -r "$hw/name" ]] || continue
    hw_name=$(tr -d '[:space:]' < "$hw/name" 2>/dev/null || true)
    case "$hw_name" in
        k10temp|coretemp|cpu_thermal|zenpower)
            if [[ -r "$hw/temp1_input" ]]; then
                raw_temp=$(cat "$hw/temp1_input" 2>/dev/null || echo 0)
                if [[ "$raw_temp" =~ ^[0-9]+$ && "$raw_temp" -gt 0 ]]; then
                    cpu_temp=$(( (raw_temp + 500) / 1000 ))
                    break
                fi
            fi
            ;;
    esac
done
if [[ "$cpu_temp" -eq 45 && -r /sys/class/thermal/thermal_zone0/temp ]]; then
    raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
    if [[ "$raw_temp" =~ ^[0-9]+$ && "$raw_temp" -gt 0 ]]; then
        cpu_temp=$(( (raw_temp + 500) / 1000 ))
    fi
fi

# Collect cached weather, GitHub profile & running user tasks (skip heavy ps+python3 in --light mode)
if [[ "$light_mode" == "true" ]]; then
    wx_json='{"location":"Kanchanpur, Nepal","temp_c":null,"icon":"󰖐","condition":"Weather"}'
    if [[ -s "$WEATHER_CACHE" ]]; then
        wx_raw_cache=$(tr -d '\n\r' < "$WEATHER_CACHE" 2>/dev/null || true)
        if [[ "$wx_raw_cache" == \{*\} ]]; then
            wx_json="$wx_raw_cache"
        fi
    fi
    gh_tasks_fragment="\"light\":true,\"weather\":${wx_json}"
else
gh_tasks_fragment=$(ps -u "${USER:-$(id -un)}" -o pid=,pcpu=,pmem=,rss=,comm=,args= --sort=-pcpu 2>/dev/null | python3 -c '
import json, os, sys

gh_cache, gh_avatar, wx_cache, self_pid, parent_pid = sys.argv[1:6]
self_pids = {int(self_pid), int(parent_pid)}

gh = None
try:
    if os.path.isfile(gh_cache) and os.path.getsize(gh_cache) > 0:
        with open(gh_cache, "r", encoding="utf-8") as f:
            gh = json.load(f)
except Exception:
    gh = None

if not isinstance(gh, dict) or not gh.get("login"):
    gh = {
        "login": "tek-sys-hub",
        "name": "Tek Raj Awasthi",
        "bio": "Java Developer · Independent Developer · Systems · Creative Code · Flutter Developer",
        "public_repos": 24,
        "followers": 38,
        "following": 37,
        "stars": 60,
        "html_url": "https://github.com/tek-sys-hub",
        "avatar": gh_avatar if (os.path.isfile(gh_avatar) and os.path.getsize(gh_avatar) > 0) else "",
    }
elif not gh.get("avatar") and os.path.isfile(gh_avatar) and os.path.getsize(gh_avatar) > 0:
    gh["avatar"] = gh_avatar

wx = None
try:
    if os.path.isfile(wx_cache) and os.path.getsize(wx_cache) > 0:
        with open(wx_cache, "r", encoding="utf-8") as f:
            wx = json.load(f)
except Exception:
    wx = None

if not isinstance(wx, dict) or not wx.get("temp"):
    wx = {
        "temp": "24°C",
        "temp_c": 24,
        "desc": "Clear",
        "icon": "󰖙",
        "city": "Kanchanpur",
    }

exclude_comms = {
    "Hyprland", "qs", "quickshell", "systemd", "(sd-pam)",
    "dbus-daemon", "dbus-broker", "pipewire", "pipewire-pulse",
    "wireplumber", "awww-daemon", "xdg-desktop-por", "xdg-document-po",
    "xdg-permission-", "ps", "awk", "bash", "sh", "sysstat.sh",
    "python3", "jq", "curl", "systemd-inhibit", "coffeemode",
}

tasks = []
for raw in sys.stdin:
    line = raw.strip()
    if not line:
        continue
    parts = line.split(None, 5)
    if len(parts) < 5:
        continue
    try:
        pid = int(parts[0])
        cpu = round(float(parts[1]), 1)
        mem_pct = round(float(parts[2]), 1)
        rss_kb = int(parts[3])
    except ValueError:
        continue
    comm = parts[4]
    args = parts[5] if len(parts) > 5 else comm
    if pid in self_pids or comm in exclude_comms:
        continue
    if "--type=zygote" in args or "--type=crashpad-handler" in args or "sysstat.sh" in args or "coffeemode" in args or "CoffeeMode" in args:
        continue
    if rss_kb >= 1048576:
        mem_str = f"{rss_kb / 1048576.0:.1f}G"
    else:
        mem_str = f"{max(1, int(round(rss_kb / 1024.0)))}M"
    short_cmd = args if len(args) <= 64 else (args[:61] + "...")
    tasks.append({
        "pid": pid,
        "name": comm,
        "cpu": cpu,
        "mem_pct": mem_pct,
        "rss_kb": rss_kb,
        "mem": mem_str,
        "cmd": short_cmd,
    })
    if len(tasks) >= 14:
        break

sys.stdout.write("\"weather\":" + json.dumps(wx, ensure_ascii=False) + ",\"github\":" + json.dumps(gh, ensure_ascii=False) + ",\"tasks\":" + json.dumps(tasks, ensure_ascii=False))
' "$GH_CACHE" "$GH_AVATAR" "$WEATHER_CACHE" "$$" "$PPID"
)
fi

# Coffee mode status
coffee_mode=false
if [[ -x "$HOME/.local/bin/coffeemode" ]] && "$HOME/.local/bin/coffeemode" status >/dev/null 2>&1; then
    coffee_mode=true
elif pgrep -u "${USER:-$(id -un)}" -f "systemd-inhibit.*CoffeeMode" >/dev/null 2>&1; then
    coffee_mode=true
fi

# Screen recording status
is_recording=false
if pgrep -f '(^|/)gpu-screen-recorder([[:space:]]|$)' >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1; then
    is_recording=true
fi

# Escape Wi-Fi SSID safely for JSON
wifi_ssid_escaped=${wifi_ssid//\\/\\\\}
wifi_ssid_escaped=${wifi_ssid_escaped//\"/\\\"}

printf '{"cpu":%d,"cpu_temp":%d,"ram_pct":%d,"ram_used":"%s","ram_total":"%s","disk_pct":%d,"disk_used":"%s","disk_total":"%s","wifi_on":%s,"wifi_ssid":"%s","bt_on":%s,"vol":%d,"muted":%s,"mic_vol":%d,"mic_muted":%s,"bat":%d,"bat_status":"%s","power_profile":"%s","brightness":%d,"coffee_mode":%s,"recording":%s,%s}\n' \
    "$cpu_pct" "$cpu_temp" "$ram_pct" "$ram_used" "$ram_total" \
    "$disk_pct" "$disk_used" "$disk_total" \
    "$wifi_on" "$wifi_ssid_escaped" "$bt_on" \
    "$vol" "$muted" "$mic_vol" "$mic_muted" \
    "$bat" "$bat_status" "$power_profile" "$brightness" "$coffee_mode" "$is_recording" "$gh_tasks_fragment"
