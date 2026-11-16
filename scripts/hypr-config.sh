#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${HOME}/.config/minimalarch-hypr.json"
CUSTOM_DIR="${HOME}/.config/hypr/config/custom"

python3 - "$STATE_FILE" "$CUSTOM_DIR" "$@" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys

state_file = sys.argv[1]
custom_dir = sys.argv[2]
args = sys.argv[3:]

STATIC_THEMES = {
    "black": {
        "col_bg": "#000000",
        "col_surface": "#0c0c0e",
        "col_surface_high": "#17171b",
        "col_fg": "#f4f4f5",
        "col_dim": "#a1a1aa",
        "col_muted": "#63636e",
        "col_accent": "#ffffff",
        "col_accent_alt": "#a1a1aa",
        "col_danger": "#f87171",
    },
    "white": {
        "col_bg": "#f4f5f7",
        "col_surface": "#e6e8ec",
        "col_surface_high": "#d8dce2",
        "col_fg": "#111318",
        "col_dim": "#474d59",
        "col_muted": "#7a8291",
        "col_accent": "#2563eb",
        "col_accent_alt": "#4f46e5",
        "col_danger": "#dc2626",
    },
    "mono": {
        "col_bg": "#101012",
        "col_surface": "#18181b",
        "col_surface_high": "#232328",
        "col_fg": "#ededec",
        "col_dim": "#a8a8a3",
        "col_muted": "#6e6e6a",
        "col_accent": "#e2e2df",
        "col_accent_alt": "#9c9c96",
        "col_danger": "#d96b6b",
    },
    "espresso": {
        "col_bg": "#14100e",
        "col_surface": "#1f1916",
        "col_surface_high": "#2c2420",
        "col_fg": "#eee6df",
        "col_dim": "#bfb2a6",
        "col_muted": "#7e7166",
        "col_accent": "#ddb892",
        "col_accent_alt": "#b08968",
        "col_danger": "#d9776c",
    },
    "forest": {
        "col_bg": "#0e1310",
        "col_surface": "#161e19",
        "col_surface_high": "#202b24",
        "col_fg": "#e4ebe6",
        "col_dim": "#a7b8ad",
        "col_muted": "#6b7d72",
        "col_accent": "#9cc5a1",
        "col_accent_alt": "#73a580",
        "col_danger": "#d97a7a",
    },
    "nord": {
        "col_bg": "#161920",
        "col_surface": "#1f242e",
        "col_surface_high": "#2b3240",
        "col_fg": "#eceff4",
        "col_dim": "#b8c2d1",
        "col_muted": "#707c91",
        "col_accent": "#88c0d0",
        "col_accent_alt": "#81a1c1",
        "col_danger": "#bf616a",
    },
    "crimson": {
        "col_bg": "#130f11",
        "col_surface": "#1d171a",
        "col_surface_high": "#2a2126",
        "col_fg": "#f0e7ea",
        "col_dim": "#bfa9b1",
        "col_muted": "#7d6870",
        "col_accent": "#d9778b",
        "col_accent_alt": "#b5838d",
        "col_danger": "#e06c75",
    },
    "ocean": {
        "col_bg": "#0b141a",
        "col_surface": "#12202a",
        "col_surface_high": "#1a2e3b",
        "col_fg": "#e4f0f5",
        "col_dim": "#9ab8c7",
        "col_muted": "#5f7d8c",
        "col_accent": "#56d4dd",
        "col_accent_alt": "#38a3d1",
        "col_danger": "#f07178",
    },
    "violet": {
        "col_bg": "#120f1a",
        "col_surface": "#1b1726",
        "col_surface_high": "#272136",
        "col_fg": "#eee9f7",
        "col_dim": "#b4a8cc",
        "col_muted": "#75698f",
        "col_accent": "#c4a7f5",
        "col_accent_alt": "#9b7ede",
        "col_danger": "#f38ba8",
    },
}

THEME_MODES = ("wallpaper", "black", "white", "mono", "espresso", "forest", "nord", "ocean", "violet", "crimson")
MATUGEN_SCHEMES = (
    "scheme-tonal-spot",
    "scheme-vibrant",
    "scheme-expressive",
    "scheme-monochrome",
    "scheme-fidelity",
)
FONT_FAMILIES = (
    "Adwaita Sans",
    "Iosevka Nerd Font",
    "NotoSansM Nerd Font Propo",
    "FantasqueSansM Nerd Font Propo",
    "Fira Code",
    "JetBrainsMono Nerd Font",
)

DEFAULTS = {
    "gaps_in": 8,
    "gaps_out": 16,
    "border_size": 2,
    "rounding": 14,
    "active_opacity": 0.94,
    "inactive_opacity": 0.88,
    "dim_inactive": False,
    "dim_strength": 0.20,
    "blur_size": 4,
    "blur_passes": 4,
    "animations_enabled": True,
    "anim_speed": 4.0,
    "shadow_enabled": False,
    "border_preset": "wallpaper",
    "theme_mode": "wallpaper",
    "matugen_scheme": "scheme-tonal-spot",
    "font_family": "Adwaita Sans",
    "font_size": 12,
    "dock_padding": 14,
    "item_spacing": 10,
    "bar_height": 36,
    "frame_thickness": 8,
    "corner_radius": 20,
    "left_dock_width": 330,
    "right_dock_width": 356,
    "frame_opacity": 96,
    "dock_color": "auto",
    "border_line_width": 1,
    "border_glow": 42,
    "border_opacity": 16,
    "col_bg": "#111316",
    "col_surface": "#1a1d21",
    "col_surface_high": "#25292e",
    "col_fg": "#e6e8eb",
    "col_dim": "#a8afb8",
    "col_muted": "#6e7681",
    "col_accent": "#c8d0dc",
    "col_accent_alt": "#9aa6b8",
    "col_danger": "#e06c75",
}

PRESETS = {
    "compact": {"gaps_in": 4, "gaps_out": 8, "border_size": 2, "rounding": 10, "dock_padding": 10, "item_spacing": 7, "bar_height": 32, "frame_thickness": 6},
    "balanced": {"gaps_in": 8, "gaps_out": 16, "border_size": 2, "rounding": 14, "dock_padding": 14, "item_spacing": 10, "bar_height": 36, "frame_thickness": 8},
    "airy": {"gaps_in": 12, "gaps_out": 24, "border_size": 2, "rounding": 16, "dock_padding": 18, "item_spacing": 12, "bar_height": 40, "frame_thickness": 10},
    "zen": {"gaps_in": 16, "gaps_out": 32, "border_size": 3, "rounding": 20, "dock_padding": 20, "item_spacing": 14, "bar_height": 42, "frame_thickness": 12},
}

BORDER_PRESETS = {
    "wallpaper": None,
    "rainbow": None,
    "silver": ("rgba(e5e9f0f0)", "rgba(4c566a66)"),
    "white": ("rgba(ffffffff)", "rgba(585b7055)"),
    "cyan": ("rgba(89dcebf5)", "rgba(45475a66)"),
    "blue": ("rgba(89b4faf5)", "rgba(45475a66)"),
    "indigo": ("rgba(b4befef5)", "rgba(45475a66)"),
    "violet": ("rgba(cba6f7f5)", "rgba(45475a66)"),
    "magenta": ("rgba(f5c2e7f5)", "rgba(45475a66)"),
    "rose": ("rgba(f38ba8f2)", "rgba(45475a66)"),
    "coral": ("rgba(fab387f2)", "rgba(45475a66)"),
    "amber": ("rgba(f9e2aff2)", "rgba(45475a66)"),
    "gold": ("rgba(f2cdcdf2)", "rgba(45475a66)"),
    "emerald": ("rgba(a6e3a1f2)", "rgba(45475a66)"),
    "teal": ("rgba(94e2d5f2)", "rgba(45475a66)"),
}

def to_bool(val):
    if isinstance(val, bool):
        return val
    return str(val).strip().lower() in ("1", "true", "yes", "on")

def lua_bool(val):
    return "true" if val else "false"

def valid_hex(c, fallback):
    s = str(c or "").strip()
    return s if re.match(r"^#[0-9a-fA-F]{6}$", s) else fallback

def find_current_wallpaper():
    for path_file in (
        os.path.expanduser("~/.cache/minimalarch-current-wallpaper"),
        os.path.expanduser("~/.config/minimalarch/current_wallpaper"),
    ):
        if os.path.isfile(path_file):
            try:
                p = open(path_file, "r", encoding="utf-8").read().strip()
                if p and os.path.isfile(p):
                    return p
            except Exception:
                pass
    try:
        out = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1.5).stdout
        m = re.search(r"currently displaying:\s*image:\s*(.+)$", out, re.MULTILINE)
        if m:
            p = m.group(1).strip()
            if os.path.isfile(p):
                return p
    except Exception:
        pass
    return ""

def compute_palette(data):
    mode = data.get("theme_mode", "wallpaper")
    if mode in STATIC_THEMES:
        data.update(STATIC_THEMES[mode])
        return data

    wall = find_current_wallpaper()
    if not wall:
        return data

    real_wall = os.path.realpath(wall)
    h = hashlib.md5(real_wall.encode("utf-8")).hexdigest()
    thumb = os.path.expanduser(f"~/.cache/minimalarch-thumbs/{h}.jpg")
    img = thumb if os.path.isfile(thumb) and os.path.getsize(thumb) > 0 else real_wall

    scheme = data.get("matugen_scheme", "scheme-tonal-spot")
    if scheme not in MATUGEN_SCHEMES:
        scheme = "scheme-tonal-spot"

    try:
        res = subprocess.run(
            ["matugen", "image", img, "--source-color-index", "0", "-t", scheme, "-j", "hex", "--dry-run"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if res.returncode == 0 and res.stdout.strip():
            payload = json.loads(res.stdout)
            colors = payload.get("colors", {})
            def get_c(key, fb):
                entry = colors.get(key, {})
                dark = entry.get("dark", {}) if isinstance(entry, dict) else {}
                return valid_hex(dark.get("color", ""), fb)

            data["col_bg"] = get_c("surface_container_lowest", get_c("background", data["col_bg"]))
            data["col_surface"] = get_c("surface_container", data["col_surface"])
            data["col_surface_high"] = get_c("surface_container_high", data["col_surface_high"])
            data["col_fg"] = get_c("on_surface", data["col_fg"])
            data["col_dim"] = get_c("on_surface_variant", data["col_dim"])
            data["col_muted"] = get_c("outline", data["col_muted"])
            data["col_accent"] = get_c("primary", data["col_accent"])
            data["col_accent_alt"] = get_c("tertiary", get_c("secondary", data["col_accent_alt"]))
            data["col_danger"] = get_c("error", data["col_danger"])
    except Exception:
        pass
    return data

def clamp_int(val, lo, hi, fb):
    try:
        return max(lo, min(hi, int(round(float(val)))))
    except Exception:
        return fb

def load_state():
    data = dict(DEFAULTS)
    if os.path.isfile(state_file):
        try:
            with open(state_file, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                data.update(loaded)
        except Exception:
            pass
    data["gaps_in"] = clamp_int(data.get("gaps_in"), 0, 24, 8)
    data["gaps_out"] = clamp_int(data.get("gaps_out"), 0, 40, 16)
    data["border_size"] = clamp_int(data.get("border_size"), 0, 6, 2)
    data["rounding"] = clamp_int(data.get("rounding"), 0, 28, 14)
    try:
        data["active_opacity"] = max(0.5, min(1.0, round(float(data.get("active_opacity", 0.94)), 2)))
    except Exception:
        data["active_opacity"] = 0.94
    try:
        data["inactive_opacity"] = max(0.5, min(1.0, round(float(data.get("inactive_opacity", 0.88)), 2)))
    except Exception:
        data["inactive_opacity"] = 0.88
    data["blur_size"] = clamp_int(data.get("blur_size"), 0, 14, 4)
    data["blur_passes"] = clamp_int(data.get("blur_passes"), 1, 6, 4)
    data["dim_inactive"] = to_bool(data.get("dim_inactive", False))
    try:
        data["dim_strength"] = max(0.0, min(0.5, round(float(data.get("dim_strength", 0.20)), 2)))
    except Exception:
        data["dim_strength"] = 0.20
    data["animations_enabled"] = to_bool(data.get("animations_enabled", True))
    try:
        data["anim_speed"] = max(1.0, min(10.0, round(float(data.get("anim_speed", 4.0)), 1)))
    except Exception:
        data["anim_speed"] = 4.0
    data["shadow_enabled"] = to_bool(data.get("shadow_enabled", False))
    if data.get("border_preset") not in BORDER_PRESETS:
        data["border_preset"] = "wallpaper"
    if data.get("theme_mode") not in THEME_MODES:
        data["theme_mode"] = "wallpaper"
    if data.get("matugen_scheme") not in MATUGEN_SCHEMES:
        data["matugen_scheme"] = "scheme-tonal-spot"
    font = str(data.get("font_family", "Adwaita Sans")).strip()
    data["font_family"] = font if font else "Adwaita Sans"
    data["font_size"] = clamp_int(data.get("font_size"), 10, 16, 12)
    data["dock_padding"] = clamp_int(data.get("dock_padding"), 6, 24, 14)
    data["item_spacing"] = clamp_int(data.get("item_spacing"), 4, 20, 10)
    data["bar_height"] = clamp_int(data.get("bar_height"), 28, 52, 36)
    data["frame_thickness"] = clamp_int(data.get("frame_thickness"), 2, 18, 8)
    data["corner_radius"] = clamp_int(data.get("corner_radius"), 0, 32, 20)
    data["left_dock_width"] = clamp_int(data.get("left_dock_width"), 280, 440, 330)
    data["right_dock_width"] = clamp_int(data.get("right_dock_width"), 300, 480, 356)
    data["frame_opacity"] = clamp_int(data.get("frame_opacity"), 65, 100, 96)
    dc = str(data.get("dock_color", "auto")).strip().lower()
    data["dock_color"] = "auto" if dc in ("", "auto") else valid_hex(dc, "auto")
    data["border_line_width"] = clamp_int(data.get("border_line_width"), 0, 4, 1)
    data["border_glow"] = clamp_int(data.get("border_glow"), 0, 100, 42)
    data["border_opacity"] = clamp_int(data.get("border_opacity"), 0, 100, 16)
    for k in ("col_bg", "col_surface", "col_surface_high", "col_fg", "col_dim", "col_muted", "col_accent", "col_accent_alt", "col_danger"):
        data[k] = valid_hex(data.get(k), DEFAULTS[k])
    return data

def resolve_borders(data):
    preset = data["border_preset"]
    inact = data["col_surface_high"].lstrip("#")
    inact_lua = f'"rgba({inact}88)"'
    if preset == "wallpaper":
        acc = data["col_accent"].lstrip("#")
        acc_alt = data["col_accent_alt"].lstrip("#")
        return (f'{{ colors = {{ "rgba({acc}f2)", "rgba({acc_alt}f2)" }}, angle = 45 }}', inact_lua)
    if preset == "rainbow":
        return (
            '{ colors = { "rgba(89dcebf5)", "rgba(89b4faf5)", "rgba(cba6f7f5)", "rgba(f38ba8f5)", "rgba(fab387f5)", "rgba(f9e2aff5)", "rgba(a6e3a1f5)" }, angle = 45 }',
            inact_lua,
        )
    act, inact_c = BORDER_PRESETS[preset]
    return (f'"{act}"', f'"{inact_c}"')

def animations_lua_block(data):
    en = lua_bool(data["animations_enabled"])
    spd = max(1.0, min(10.0, float(data.get("anim_speed", 4.0))))
    spd_out = max(1.0, round(spd * 0.85, 1))
    border_anim_on = lua_bool(data.get("border_preset") == "rainbow" and data["animations_enabled"])
    return (
        'hl.curve("smoothOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })\n'
        'hl.curve("overshoot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.06 } } })\n'
        'hl.curve("fluentDecel", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })\n'
        'hl.curve("softOut", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })\n'
        'hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })\n'
        f"hl.config({{ animations = {{ enabled = {en} }} }})\n"
        f'hl.animation({{ leaf = "windowsIn", enabled = true, speed = {spd:.1f}, bezier = "overshoot", style = "popin 78%" }})\n'
        f'hl.animation({{ leaf = "windowsOut", enabled = true, speed = {spd_out:.1f}, bezier = "softOut", style = "popin 82%" }})\n'
        f'hl.animation({{ leaf = "windowsMove", enabled = true, speed = {spd:.1f}, bezier = "fluentDecel", style = "slide" }})\n'
        f'hl.animation({{ leaf = "fadeIn", enabled = true, speed = {spd:.1f}, bezier = "smoothOut" }})\n'
        f'hl.animation({{ leaf = "fadeOut", enabled = true, speed = {spd_out:.1f}, bezier = "softOut" }})\n'
        f'hl.animation({{ leaf = "workspaces", enabled = true, speed = {spd:.1f}, bezier = "fluentDecel", style = "slide" }})\n'
        f'hl.animation({{ leaf = "specialWorkspace", enabled = true, speed = {spd:.1f}, bezier = "fluentDecel", style = "slidefadevert 25%" }})\n'
        f'hl.animation({{ leaf = "borderangle", enabled = {border_anim_on}, speed = 30, bezier = "linear", style = "loop" }})\n'
    )

def save_state(data):
    os.makedirs(os.path.dirname(state_file), exist_ok=True)
    with open(state_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def write_lua_files(data):
    os.makedirs(custom_dir, exist_ok=True)
    active_border, inactive_border = resolve_borders(data)
    blur_on = data["blur_size"] > 0
    blur_sz = max(1, data["blur_size"])
    gap_top = data["gaps_out"]
    gap_side = data["frame_thickness"] + data["gaps_out"]
    gaps_out_lua = f"{{ top = {gap_top}, right = {gap_side}, bottom = {gap_side}, left = {gap_side} }}"
    files = {
        "general_gaps_in.lua": f"hl.config({{ general = {{ gaps_in = {data['gaps_in']} }} }})\n",
        "general_gaps_out.lua": f"hl.config({{ general = {{ gaps_out = {gaps_out_lua} }} }})\n",
        "general_border_size.lua": f"hl.config({{ general = {{ border_size = {data['border_size']} }} }})\n",
        "decoration_rounding.lua": f"hl.config({{ decoration = {{ rounding = {data['rounding']} }} }})\n",
        "decoration_active_opacity.lua": f"hl.config({{ decoration = {{ active_opacity = {data['active_opacity']:.2f} }} }})\n",
        "decoration_inactive_opacity.lua": f"hl.config({{ decoration = {{ inactive_opacity = {data['inactive_opacity']:.2f} }} }})\n",
        "decoration_blur.lua": (
            "hl.config({ decoration = { "
            f"dim_inactive = {lua_bool(data['dim_inactive'])}, "
            f"dim_strength = {data['dim_strength']:.2f}, "
            f"blur = {{ enabled = {lua_bool(blur_on)}, size = {blur_sz}, passes = {data['blur_passes']} }}, "
            f"shadow = {{ enabled = {lua_bool(data['shadow_enabled'])} }} "
            "} })\n"
        ),
        "animations_enabled.lua": animations_lua_block(data),
        "minimalarch_borders.lua": (
            "hl.config({ general = { "
            f'["col.active_border"] = {active_border}, '
            f'["col.inactive_border"] = {inactive_border} '
            "} })\n"
        ),
    }
    for fname, content in files.items():
        with open(os.path.join(custom_dir, fname), "w", encoding="utf-8") as f:
            f.write(content)

def apply_live(data):
    active_border, inactive_border = resolve_borders(data)
    blur_on = data["blur_size"] > 0
    blur_sz = max(1, data["blur_size"])
    gap_top = data["gaps_out"]
    gap_side = data["frame_thickness"] + data["gaps_out"]
    gaps_out_lua = f"{{ top = {gap_top}, right = {gap_side}, bottom = {gap_side}, left = {gap_side} }}"
    lua_expr = (
        "hl.config({ "
        "general = { "
        f"gaps_in = {data['gaps_in']}, "
        f"gaps_out = {gaps_out_lua}, "
        f"border_size = {data['border_size']}, "
        f'["col.active_border"] = {active_border}, '
        f'["col.inactive_border"] = {inactive_border} '
        "}, "
        "decoration = { "
        f"rounding = {data['rounding']}, "
        f"active_opacity = {data['active_opacity']:.2f}, "
        f"inactive_opacity = {data['inactive_opacity']:.2f}, "
        f"dim_inactive = {lua_bool(data['dim_inactive'])}, "
        f"dim_strength = {data['dim_strength']:.2f}, "
        f"blur = {{ enabled = {lua_bool(blur_on)}, size = {blur_sz}, passes = {data['blur_passes']} }}, "
        f"shadow = {{ enabled = {lua_bool(data['shadow_enabled'])} }} "
        "} "
        "})\n"
        + animations_lua_block(data)
    )
    subprocess.run(["hyprctl", "eval", lua_expr], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

cmd = args[0] if args else "--get"
state = load_state()

if cmd == "--get":
    if state.get("theme_mode") == "wallpaper" and state.get("col_bg") == DEFAULTS["col_bg"]:
        state = compute_palette(state)
        save_state(state)
    print(json.dumps(state))
    sys.exit(0)

if cmd == "--set":
    if len(args) < 3:
        print("Usage: --set <key> <value>", file=sys.stderr)
        sys.exit(1)
    key, raw_val = args[1], args[2]
    if key not in DEFAULTS:
        print(f"Unknown key: {key}", file=sys.stderr)
        sys.exit(1)
    if key == "border_preset":
        state[key] = raw_val if raw_val in BORDER_PRESETS else "wallpaper"
    elif key == "theme_mode":
        state[key] = raw_val if raw_val in THEME_MODES else "wallpaper"
        state = compute_palette(state)
    elif key == "matugen_scheme":
        state[key] = raw_val if raw_val in MATUGEN_SCHEMES else "scheme-tonal-spot"
        state = compute_palette(state)
    elif key == "font_family":
        state[key] = raw_val.strip() or "Adwaita Sans"
    elif key == "dock_color":
        dc = raw_val.strip().lower()
        state[key] = "auto" if dc in ("", "auto") else valid_hex(dc, "auto")
    elif key in ("animations_enabled", "shadow_enabled", "dim_inactive"):
        state[key] = to_bool(raw_val)
    elif key in ("active_opacity", "inactive_opacity", "dim_strength"):
        state[key] = round(float(raw_val), 2)
    elif key == "anim_speed":
        state[key] = round(float(raw_val), 1)
    else:
        state[key] = int(round(float(raw_val)))
elif cmd == "--reset":
    state = dict(DEFAULTS)
    state = compute_palette(state)
elif cmd == "--preset":
    if len(args) < 2 or args[1] not in PRESETS:
        print(f"Usage: --preset <{'|'.join(PRESETS)}>", file=sys.stderr)
        sys.exit(1)
    state.update(PRESETS[args[1]])
elif cmd == "--border-preset":
    if len(args) < 2 or args[1] not in BORDER_PRESETS:
        print(f"Usage: --border-preset <{'|'.join(BORDER_PRESETS)}>", file=sys.stderr)
        sys.exit(1)
    state["border_preset"] = args[1]
elif cmd == "--refresh-palette":
    state = compute_palette(state)
elif cmd == "--apply":
    state = compute_palette(state)
else:
    print(f"Unknown command: {cmd}", file=sys.stderr)
    sys.exit(1)

save_state(state)
state = load_state()
save_state(state)
write_lua_files(state)
apply_live(state)
print(json.dumps(state))
PY
