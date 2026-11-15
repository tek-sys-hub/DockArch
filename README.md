# MinimalArch (Quickshell + Hyprland)

Minimal full-screen **4-border connected frame shell** built with **Quickshell (`qs`)** on top of your existing Hyprland setup — preserving all keybinds (`~/.config/hypr/config/bind.lua`), terminal settings (`foot`), and SDDM configuration.

## Highlights

- **Unified Single-Path Canvas Frame** (`quickshell/shell.qml`, `unifiedFrameCanvas`):
  - **One Seamless Silhouette**: Full-screen `Canvas` draws the 4 outer borders, top-right status dropdown (`statusDropdownDrawer`), bottom-center compact launcher (`bottomLauncherDrawer`), and bottom-right OSD/notification corner (`cornerOsdNotif`) as one continuous polygon with tangent `arcTo` concave fillets and a single unified inner hairline stroke — no detached floating boxes or seams.
  - **Dock-Counted Window Margins & Hyprland Animations** (`scripts/hypr-config.sh`): Hyprland `general.gaps_out` automatically counts from the dock inner frame (`top = gaps_out` below the exclusive top bar, `right = bottom = left = frame_thickness + gaps_out`), paired with smooth cubic-bezier window open (`popin`), close (`popin`), move, and workspace transition animations (`animations.enabled = true`) and zero config errors.
  - **Dynamic Wallpaper Theming (`matugen`)**: Automatically extracts surface, text, and accent colors from the active wallpaper (`theme_mode: "wallpaper"` with selectable `scheme-tonal-spot`, `scheme-vibrant`, `scheme-expressive`, `scheme-monochrome`, `scheme-fidelity` schemes), or switches to curated static themes (`Mono`, `Espresso`, `Forest`, `Nord`, `Crimson`), synced with Hyprland window borders (`border_preset: "wallpaper"`).
  - **Top Connected Bar & Context-Only Status Dropdown**: Full-width top border with 5 dot workspaces, active window title, a centered cluster featuring **Kanchanpur, Nepal weather**, click-to-toggle clock/date, and live **CPU temperature** (`hwmon`), plus flat background-free Wi-Fi, Bluetooth, Volume, and Battery indicators. Hovering each right-side indicator opens a pure context-specific `statusDropdownDrawer` flush against the top-right inner corner with:
    - **Network**: Pure Wi-Fi radio toggle, scan, SSID list with signal/security, connect/disconnect, and inline passphrase entry.
    - **Bluetooth**: Power toggle, scan, and connect/disconnect paired or discovered devices.
    - **Audio (Output + Input)**: Output volume slider, mute, sink selector, plus Input Microphone gain slider, mic mute, and source selector.
    - **Battery & Power Modes**: Charge status plus **Power Saving**, **Balanced**, and **Performance** switching (`powerprofilesctl`).
  - **Bottom-Right In-Frame OSD & Notification Corner (`cornerOsdNotif`)**: Volume adjustments (`XF86Audio*`, wheel scroll, `qs ipc call bar triggerOsd`), microphone mute changes, brightness changes (`qs ipc call brightness increment|decrement`), weather alerts, task kill notices, and desktop D-Bus notifications (`NotificationServer` / `notify-send`) extrude smoothly from the bottom-right inner frame corner with a unified contour, hover-to-pause timer, and click-to-dismiss.
  - **Left Extending Telemetry, GitHub & Tasks Dock** (`Hover left border` or `Super + L`): Configurable thin border that smoothly extends inward (proportionally scaled with `font_size`), featuring:
    - **GitHub Account Card (`tek-sys-hub`)**: Cached profile with avatar, bio, **Repos / Stars / Followers / Following** stats, refresh button, and quick browser link.
    - **Smooth Area-Line System Graphs**: 24-sample smooth spline area graphs (`Canvas` `AreaLineGraph`) for **CPU Load** (with `cpu_temp`) and **RAM / Memory**.
    - **Interactive Running Tasks Manager**: Live process list sortable by **CPU** or **RAM** with one-click **Kill** (`SIGTERM` + `SIGKILL` fallback) and OSD confirmation.
    - **Root Disk & Hardware**: Root disk usage bar and Battery, Audio, and Network stat tiles.
  - **Bottom Compact Emerging Launcher (Apps & Wallpapers)** (`Super + A` for Apps, `Super + W` for Wallpapers): Bottom border remains thin and does not open on hover; only the compact center space needed for Apps or Wallpapers emerges seamlessly upward (`4-column` thumbnail grid, search filter, and automatic randomized `awww` wallpaper transitions).
  - **Right Extending Rice Studio** (`Hover right border` or `Super + R`): Proportional-scaled drawer offering live **Theme & Wallpaper Palette**, **Typography** (`Adwaita Sans`, `Iosevka Nerd Font`, `NotoSansM Nerd Font Propo`, `FantasqueSansM Nerd Font Propo`, `Fira Code`, `JetBrainsMono Nerd Font`, plus `font_size` scaling all cards and docks), **Dock & Frame Padding** (`dock_padding`, `item_spacing`, `bar_height`, `frame_thickness`, `corner_radius`, `frame_opacity`, `border_line_width`), Layout Presets (`Compact`, `Balanced`, `Airy`, `Zen`), Window Geometry (`gaps_in`, `gaps_out` dock outer margin, `border_size`, `rounding`), Glass/Blur/Effects, Border Accent (`Auto`, `Silver`, `Cyan`, `White`, `Gold`, `Emerald`, `Rose`), and quick actions.

## Files

- [shell.qml](file:///home/cherry/main/minimalarch/quickshell/shell.qml) — Quickshell UI, unified frame `Canvas`, `NotificationServer`, IPC handlers (`bar`, `brightness`), and docks.
- [sysstat.sh](file:///home/cherry/main/minimalarch/scripts/sysstat.sh) — Fast JSON telemetry collector (CPU load & temp, RAM, disk, Kanchanpur weather cache, GitHub `tek-sys-hub` profile cache, running user tasks + `--kill`, network, BT, audio, battery, power profile, brightness).
- [status-ctl.sh](file:///home/cherry/main/minimalarch/scripts/status-ctl.sh) — Interactive JSON status and control helper for Wi-Fi, Bluetooth, Output/Input Audio, and Power Profiles.
- [wallpaper.sh](file:///home/cherry/main/minimalarch/scripts/wallpaper.sh) — `awww` animated wallpaper switcher + thumbnail cache + `matugen` palette refresh trigger.
- [hypr-config.sh](file:///home/cherry/main/minimalarch/scripts/hypr-config.sh) — Live palette (`matugen` + static themes), typography/dock settings, Hyprland Lua custom override writer (`~/.config/hypr/config/custom/`), and `hyprctl eval` applier.
- [switch.sh](file:///home/cherry/main/minimalarch/switch.sh) — Safe non-destructive switcher (`--enable`, `--reload`, `--restore`).

## Usage

```bash
# Enable MinimalArch Quickshell rice
/home/cherry/main/minimalarch/switch.sh --enable

# Reload MinimalArch Quickshell bar cleanly
/home/cherry/main/minimalarch/switch.sh --reload

# Restore previous MetaArch Quickshell + WallEclipse setup
/home/cherry/main/minimalarch/switch.sh --restore
```
