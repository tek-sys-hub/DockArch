//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Services.Pam

ShellRoot {
    id: appRoot

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string scriptsDir: homeDir + "/main/minimalarch/scripts"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property string fontFamily: String(hyprConfig.font_family || "Adwaita Sans")
    readonly property int baseFontSize: Math.max(10, Math.min(16, Number(hyprConfig.font_size || 12)))
    function fs(delta) {
        return Math.max(9, appRoot.baseFontSize + (delta || 0));
    }
    function sc(basePx) {
        return Math.max(1, Math.round(basePx * (appRoot.baseFontSize / 12.0)));
    }

    // Configurable dock & frame geometry tokens (live-adjustable in Right Settings Panel)
    readonly property int dockPadding: Math.max(6, Math.min(24, Number(hyprConfig.dock_padding !== undefined ? hyprConfig.dock_padding : 14)))
    readonly property int itemSpacing: Math.max(4, Math.min(20, Number(hyprConfig.item_spacing !== undefined ? hyprConfig.item_spacing : 10)))
    readonly property int barHeightCfg: Math.max(28, Math.min(52, Number(hyprConfig.bar_height !== undefined ? hyprConfig.bar_height : 36)))
    readonly property int frameThicknessCfg: Math.max(2, Math.min(18, Number(hyprConfig.frame_thickness !== undefined ? hyprConfig.frame_thickness : 8)))
    readonly property int cornerRadiusCfg: Math.max(0, Math.min(32, Number(hyprConfig.corner_radius !== undefined ? hyprConfig.corner_radius : 20)))
    readonly property int leftDockWidthCfg: Math.max(280, Math.min(440, Number(hyprConfig.left_dock_width !== undefined ? hyprConfig.left_dock_width : 330)))
    readonly property int rightDockWidthCfg: Math.max(300, Math.min(480, Number(hyprConfig.right_dock_width !== undefined ? hyprConfig.right_dock_width : 356)))
    readonly property real frameOpacityFrac: Math.max(0.65, Math.min(1.0, Number(hyprConfig.frame_opacity !== undefined ? hyprConfig.frame_opacity : 96) / 100.0))
    readonly property real borderLineWidth: Math.max(0, Math.min(4, Number(hyprConfig.border_line_width !== undefined ? hyprConfig.border_line_width : 1)))
    readonly property real borderGlowFrac: Math.max(0.0, Math.min(1.0, Number(hyprConfig.border_glow !== undefined ? hyprConfig.border_glow : 42) / 100.0))
    readonly property real borderOpacityFrac: Math.max(0.0, Math.min(1.0, Number(hyprConfig.border_opacity !== undefined ? hyprConfig.border_opacity : 16) / 100.0))
    readonly property string borderPreset: String(hyprConfig.border_preset || "wallpaper")
    readonly property bool borderAnimated: borderPreset === "rainbow"
    property real borderAnimPhase: 0.0
    Timer {
        id: borderAnimTimer
        interval: 33
        repeat: true
        running: appRoot.borderAnimated && appRoot.borderLineWidth > 0.05
        onTriggered: {
            appRoot.borderAnimPhase = (appRoot.borderAnimPhase + 0.012) % 1.0;
        }
    }
    readonly property color frameBorderColor: {
        const p = borderPreset;
        if (p === "silver") return "#e5e9f0";
        if (p === "white") return "#ffffff";
        if (p === "cyan") return "#89dceb";
        if (p === "blue") return "#89b4fa";
        if (p === "indigo") return "#b4befe";
        if (p === "violet") return "#cba6f7";
        if (p === "magenta") return "#f5c2e7";
        if (p === "rose") return "#f38ba8";
        if (p === "coral") return "#fab387";
        if (p === "amber") return "#f9e2af";
        if (p === "gold") return "#f2cdcd";
        if (p === "emerald") return "#a6e3a1";
        if (p === "teal") return "#94e2d5";
        return colAccent;
    }

    // Dynamic wallpaper-extracted / curated editorial palette tokens
    readonly property color rawBg: hyprConfig.col_bg || "#111316"
    property color colFrame: Qt.rgba(rawBg.r, rawBg.g, rawBg.b, frameOpacityFrac)
    property color colBg: Qt.rgba(rawBg.r, rawBg.g, rawBg.b, Math.min(1.0, frameOpacityFrac + 0.02))
    property color colSurface: hyprConfig.col_surface || "#1a1d21"
    property color colSurfaceHover: hyprConfig.col_surface_high || "#25292e"
    property color colFg: hyprConfig.col_fg || "#e6e8eb"
    property color colDim: hyprConfig.col_dim || "#a8afb8"
    property color colMuted: hyprConfig.col_muted || "#6e7681"
    property color colAccent: hyprConfig.col_accent || "#c8d0dc"
    property color colAccentAlt: hyprConfig.col_accent_alt || "#9aa6b8"
    property color colRed: hyprConfig.col_danger || "#e06c75"
    readonly property color colLine: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.09)
    readonly property color colLineStrong: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.16)
    readonly property color colBorder: Qt.rgba(frameBorderColor.r, frameBorderColor.g, frameBorderColor.b, borderOpacityFrac)
    readonly property color colBorderGlow: Qt.rgba(frameBorderColor.r, frameBorderColor.g, frameBorderColor.b, borderGlowFrac)
    readonly property color colGreen: "#8fbf7f"
    readonly property color colAmber: "#d9b06a"

    Behavior on colFrame { ColorAnimation { duration: 240 } }
    Behavior on colSurface { ColorAnimation { duration: 240 } }
    Behavior on colSurfaceHover { ColorAnimation { duration: 240 } }
    Behavior on colFg { ColorAnimation { duration: 240 } }
    Behavior on colDim { ColorAnimation { duration: 240 } }
    Behavior on colMuted { ColorAnimation { duration: 240 } }
    Behavior on colAccent { ColorAnimation { duration: 240 } }
    Behavior on colAccentAlt { ColorAnimation { duration: 240 } }
    Behavior on colRed { ColorAnimation { duration: 240 } }

    // Shared per-monitor 4-border UI state
    property var islandByMonitor: ({})
    property var leftDockByMonitor: ({})
    property var bottomDockByMonitor: ({})
    property var rightDockByMonitor: ({})
    property var barShownByMonitor: ({})

    function effectiveMonitor(mon) {
        if (mon && mon !== "")
            return mon;
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name;
        const vals = Hyprland.monitors.values;
        if (vals && vals.length > 0 && vals[0].name)
            return vals[0].name;
        return "eDP-1";
    }

    function islandFor(mon) {
        return islandByMonitor[effectiveMonitor(mon)] || "default";
    }

    function setIslandFor(mon, state) {
        const key = effectiveMonitor(mon);
        const next = Object.assign({}, islandByMonitor);
        next[key] = state;
        islandByMonitor = next;
        if (state === "search" && bottomDockByMonitor[key] === true) {
            const bNext = Object.assign({}, bottomDockByMonitor);
            bNext[key] = false;
            bottomDockByMonitor = bNext;
        }
        return state;
    }

    function toggleIslandFor(mon, name) {
        const key = effectiveMonitor(mon);
        const cur = islandFor(key);
        const nextState = (cur === name) ? "default" : name;
        setIslandFor(key, nextState);
        return nextState;
    }

    function leftDockFor(mon) {
        return leftDockByMonitor[effectiveMonitor(mon)] === true;
    }

    function setLeftDockFor(mon, open) {
        const key = effectiveMonitor(mon);
        const next = Object.assign({}, leftDockByMonitor);
        next[key] = !!open;
        leftDockByMonitor = next;
        if (open)
            appRoot.refreshSysStat();
        return next[key];
    }

    function toggleLeftDockFor(mon) {
        const key = effectiveMonitor(mon);
        return setLeftDockFor(key, !leftDockFor(key));
    }

    function bottomDockFor(mon) {
        return bottomDockByMonitor[effectiveMonitor(mon)] === true;
    }

    function setBottomDockFor(mon, open) {
        const key = effectiveMonitor(mon);
        const next = Object.assign({}, bottomDockByMonitor);
        next[key] = !!open;
        bottomDockByMonitor = next;
        if (open) {
            if (islandByMonitor[key] === "search") {
                const iNext = Object.assign({}, islandByMonitor);
                iNext[key] = "default";
                islandByMonitor = iNext;
            }
            appRoot.refreshWallpapers();
        }
        return next[key];
    }

    function toggleBottomDockFor(mon) {
        const key = effectiveMonitor(mon);
        return setBottomDockFor(key, !bottomDockFor(key));
    }

    function rightDockFor(mon) {
        return rightDockByMonitor[effectiveMonitor(mon)] === true;
    }

    function setRightDockFor(mon, open) {
        const key = effectiveMonitor(mon);
        const next = Object.assign({}, rightDockByMonitor);
        next[key] = !!open;
        rightDockByMonitor = next;
        if (open) {
            appRoot.refreshSysStat();
            appRoot.refreshHyprConfig();
        }
        return next[key];
    }

    function toggleRightDockFor(mon) {
        const key = effectiveMonitor(mon);
        return setRightDockFor(key, !rightDockFor(key));
    }

    function barShownFor(mon) {
        const key = effectiveMonitor(mon);
        return barShownByMonitor[key] !== false;
    }

    function toggleBarShownFor(mon) {
        const key = effectiveMonitor(mon);
        const next = Object.assign({}, barShownByMonitor);
        next[key] = !barShownFor(key);
        barShownByMonitor = next;
        return next[key];
    }

    readonly property bool anyLeftDockOpen: {
        for (const k in leftDockByMonitor) {
            if (leftDockByMonitor[k] === true)
                return true;
        }
        return false;
    }

    // Shared telemetry state + rolling 24-sample histories for CPU & RAM graphs
    property var sysInfo: ({
        cpu: 0,
        cpu_temp: 48,
        ram_pct: 0,
        ram_used: "0.0G",
        ram_total: "0.0G",
        disk_pct: 0,
        disk_used: "0G",
        disk_total: "0G",
        wifi_on: false,
        wifi_ssid: "Offline",
        bt_on: false,
        vol: 0,
        muted: false,
        mic_vol: 100,
        mic_muted: false,
        bat: 100,
        bat_status: "AC",
        power_profile: "balanced",
        brightness: 100,
        coffee_mode: true,
        recording: false,
        weather: ({
            temp: "24°C",
            temp_c: 24,
            feels_like: "24°C",
            humidity: 0,
            wind: "0 km/h",
            desc: "Clear",
            icon: "󰖙",
            city: "Kanchanpur",
            forecast: []
        }),
        github: ({
            login: "tek-sys-hub",
            name: "Tek Raj Awasthi",
            bio: "Java Developer · Independent Developer · Systems · Creative Code · Flutter Developer",
            public_repos: 24,
            followers: 38,
            following: 37,
            stars: 60,
            html_url: "https://github.com/tek-sys-hub",
            avatar: ""
        }),
        tasks: []
    })
    property var cpuHistory: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property var ramHistory: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property string taskSortBy: "cpu" // "cpu" | "ram"
    property bool leftActionBusy: false
    property bool coffeeActive: true
    property string rightMenuSection: "theme" // "theme" | "bar" | "border" | "windows" | "keybinds"
    property string keybindFilter: ""
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()
    signal toggleStatusPopupRequested(string mon, string kind)

    function resetCalendarToToday() {
        const d = new Date();
        appRoot.calYear = d.getFullYear();
        appRoot.calMonth = d.getMonth();
    }

    function stepCalendarMonth(delta) {
        let m = appRoot.calMonth + delta;
        let y = appRoot.calYear;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        appRoot.calMonth = m;
        appRoot.calYear = y;
    }

    function runCaptureAction(cmdStr) {
        Quickshell.execDetached(["bash", "-c", cmdStr]);
        capturePollDelayTimer.restart();
    }

    Timer {
        id: capturePollDelayTimer
        interval: 600
        repeat: false
        onTriggered: appRoot.refreshSysStat()
    }

    // Bottom-right in-frame OSD & notification state
    property bool _sysInitialized: false
    property int _prevVol: -1
    property bool _prevMuted: false
    property int _prevMicVol: -1
    property bool _prevMicMuted: false
    property int _prevBrightness: -1

    property bool osdActive: false
    property bool dndActive: false
    property string osdKind: "" // "volume", "mic", "brightness", "notify"
    property string osdIcon: "󰕾"
    property string osdTitle: ""
    property string osdSubtitle: ""
    property int osdValue: 0
    property bool osdHasBar: true

    function toggleDnd() {
        appRoot.dndActive = !appRoot.dndActive;
        if (appRoot.dndActive) {
            appRoot.osdActive = false;
        } else {
            appRoot.showNotificationOsd("Notifications", "Do Not Disturb Off", "Notifications resumed");
        }
    }

    function showValueOsd(kind, icon, title, val, sub) {
        appRoot.osdKind = kind;
        appRoot.osdIcon = icon;
        appRoot.osdTitle = title;
        appRoot.osdValue = Math.max(0, Math.min(100, Math.round(val)));
        appRoot.osdSubtitle = sub !== undefined && sub !== "" ? sub : (appRoot.osdValue + "%");
        appRoot.osdHasBar = true;
        appRoot.osdActive = true;
        osdHideTimer.interval = 2400;
        osdHideTimer.restart();
    }

    function showNotificationOsd(appName, summary, body) {
        if (appRoot.dndActive)
            return;
        appRoot.osdKind = "notify";
        appRoot.osdIcon = "󰂚";
        appRoot.osdTitle = (summary && summary.trim() !== "") ? summary.trim() : (appName || "Notification");
        const cleanBody = (body || "").replace(/\s+/g, " ").trim();
        appRoot.osdSubtitle = cleanBody !== "" ? cleanBody : (appName || "");
        appRoot.osdHasBar = false;
        appRoot.osdActive = true;
        osdHideTimer.interval = 4400;
        osdHideTimer.restart();
    }

    Timer {
        id: osdHideTimer
        interval: 2400
        repeat: false
        onTriggered: appRoot.osdActive = false
    }

    NotificationServer {
        id: notifServer
        keepOnReload: false
        onNotification: notif => {
            if (appRoot.dndActive)
                return;
            appRoot.showNotificationOsd(notif.appName || "", notif.summary || "", notif.body || "");
        }
    }

    // Detailed top-bar hover status state (Wi-Fi networks, Bluetooth devices, Audio sinks/sources, Power profile)
    property var statusDetail: ({
        wifi_networks: [],
        bt_devices: [],
        audio_sinks: [],
        audio_sources: [],
        action_ok: true,
        action_msg: ""
    })
    property bool statusBusy: false
    property string statusErrorMsg: ""
    property string wifiPasswordTarget: ""
    property int _pendingSinkVol: -1
    property int _pendingSourceVol: -1

    // Shared wallpaper state
    property var wallpapers: []
    property string currentWallpaper: ""
    readonly property string currentWallpaperBackdrop: {
        const cur = appRoot.currentWallpaper;
        if (!cur)
            return "";
        const found = appRoot.wallpapers.find(w => w.path === cur);
        if (found && found.is_live)
            return found.thumb || "";
        return cur;
    }
    property string selectedTransition: "random"

    // Shared Hyprland rice & theme/font/padding config state
    property var hyprConfig: ({
        gaps_in: 8,
        gaps_out: 16,
        border_size: 2,
        rounding: 14,
        active_opacity: 0.94,
        inactive_opacity: 0.88,
        dim_inactive: false,
        dim_strength: 0.20,
        blur_size: 4,
        blur_passes: 4,
        animations_enabled: true,
        anim_speed: 4.0,
        shadow_enabled: false,
        border_preset: "wallpaper",
        theme_mode: "wallpaper",
        matugen_scheme: "scheme-tonal-spot",
        font_family: "Adwaita Sans",
        font_size: 12,
        dock_padding: 14,
        item_spacing: 10,
        bar_height: 36,
        frame_thickness: 8,
        corner_radius: 20,
        left_dock_width: 330,
        right_dock_width: 356,
        frame_opacity: 96,
        border_line_width: 1,
        border_glow: 42,
        border_opacity: 16,
        col_bg: "#111316",
        col_surface: "#1a1d21",
        col_surface_high: "#25292e",
        col_fg: "#e6e8eb",
        col_dim: "#a8afb8",
        col_muted: "#6e7681",
        col_accent: "#c8d0dc",
        col_accent_alt: "#9aa6b8",
        col_danger: "#e06c75"
    })

    function refreshSysStat() {
        if (!sysStatProc.running)
            sysStatProc.running = true;
    }

    function refreshWallpapers() {
        if (!wallListProc.running)
            wallListProc.running = true;
    }

    function refreshHyprConfig() {
        if (!hyprGetProc.running)
            hyprGetProc.running = true;
    }

    function applyWallpaper(path, transition) {
        if (!path || path === "")
            return;
        appRoot.currentWallpaper = path;
        const anim = transition && transition !== "" ? transition : "random";
        Quickshell.execDetached([appRoot.scriptsDir + "/wallpaper.sh", "--set", path, anim]);
        wallPaletteRefreshTimer.restart();
    }

    function randomizeWallpaper(transition) {
        const anim = transition && transition !== "" ? transition : "random";
        if (wallRandomProc.running)
            wallRandomProc.running = false;
        wallRandomProc.command = [appRoot.scriptsDir + "/wallpaper.sh", "--random", anim];
        wallRandomProc.running = true;
    }

    Timer {
        id: wallPaletteRefreshTimer
        interval: 450
        repeat: false
        onTriggered: {
            appRoot.refreshHyprConfig();
            wallPaletteRefreshFollowupTimer.restart();
        }
    }

    Timer {
        id: wallPaletteRefreshFollowupTimer
        interval: 1200
        repeat: false
        onTriggered: appRoot.refreshHyprConfig()
    }

    Timer {
        id: noteVolumeDelayTimer
        interval: 110
        repeat: false
        onTriggered: appRoot.refreshSysStat()
    }

    property string _pendingHyprKey: ""
    property string _pendingHyprVal: ""

    function setHyprValue(key, value) {
        const updated = Object.assign({}, appRoot.hyprConfig);
        updated[key] = value;
        appRoot.hyprConfig = updated;
        _pendingHyprKey = key;
        _pendingHyprVal = String(value);
        hyprCoalesceTimer.restart();
    }

    function setHyprPreset(presetName) {
        runHyprAction(["--preset", presetName]);
    }

    function setBorderPreset(presetName) {
        runHyprAction(["--border-preset", presetName]);
    }

    function runHyprAction(args) {
        if (hyprSetProc.running)
            hyprSetProc.running = false;
        hyprSetProc.command = [appRoot.scriptsDir + "/hypr-config.sh"].concat(args);
        hyprSetProc.running = true;
    }

    Timer {
        id: hyprCoalesceTimer
        interval: 45
        repeat: false
        onTriggered: {
            if (appRoot._pendingHyprKey !== "")
                appRoot.runHyprAction(["--set", appRoot._pendingHyprKey, appRoot._pendingHyprVal]);
        }
    }

    Timer {
        id: sysPollTimer
        interval: appRoot.anyLeftDockOpen ? 1200 : 4000
        repeat: true
        running: true
        onTriggered: appRoot.refreshSysStat()
    }

    function applySysStatPayload(parsed, updateHistory) {
        if (!parsed || typeof parsed !== "object")
            return;
        const newVol = Number(parsed.vol || 0);
        const newMuted = !!parsed.muted;
        const newMicVol = Number(parsed.mic_vol || 0);
        const newMicMuted = !!parsed.mic_muted;
        const newBri = Number(parsed.brightness !== undefined ? parsed.brightness : 100);

        if (appRoot._sysInitialized && updateHistory) {
            if (newVol !== appRoot._prevVol || newMuted !== appRoot._prevMuted) {
                appRoot.showValueOsd(
                    "volume",
                    newMuted ? "󰖁" : (newVol > 60 ? "󰕾" : (newVol > 20 ? "󰖀" : "󰕿")),
                    "Volume",
                    newVol,
                    newMuted ? "Muted" : (newVol + "%")
                );
            } else if (newBri !== appRoot._prevBrightness) {
                appRoot.showValueOsd(
                    "brightness",
                    newBri > 65 ? "󰃠" : (newBri > 30 ? "󰃟" : "󰃞"),
                    "Brightness",
                    newBri,
                    newBri + "%"
                );
            } else if (newMicMuted !== appRoot._prevMicMuted) {
                appRoot.showValueOsd(
                    "mic",
                    newMicMuted ? "󰍭" : "󰍬",
                    "Microphone",
                    newMicVol,
                    newMicMuted ? "Muted" : (newMicVol + "%")
                );
            }
        }

        appRoot._prevVol = newVol;
        appRoot._prevMuted = newMuted;
        appRoot._prevMicVol = newMicVol;
        appRoot._prevMicMuted = newMicMuted;
        appRoot._prevBrightness = newBri;
        appRoot._sysInitialized = true;

        if (parsed.light === true && appRoot.sysInfo) {
            if (!parsed.github && appRoot.sysInfo.github)
                parsed.github = appRoot.sysInfo.github;
            if (!parsed.tasks && appRoot.sysInfo.tasks)
                parsed.tasks = appRoot.sysInfo.tasks;
        }

        appRoot.sysInfo = parsed;
        if (parsed.coffee_mode !== undefined)
            appRoot.coffeeActive = !!parsed.coffee_mode;
        if (updateHistory) {
            const cVal = Math.max(0, Math.min(100, Number(parsed.cpu || 0)));
            const rVal = Math.max(0, Math.min(100, Number(parsed.ram_pct || 0)));
            appRoot.cpuHistory = appRoot.cpuHistory.slice(1).concat([cVal]);
            appRoot.ramHistory = appRoot.ramHistory.slice(1).concat([rVal]);
        }
    }

    function sortedTasks() {
        const raw = (appRoot.sysInfo && Array.isArray(appRoot.sysInfo.tasks)) ? appRoot.sysInfo.tasks : [];
        const copy = raw.slice();
        if (appRoot.taskSortBy === "ram") {
            copy.sort((a, b) => Number(b.rss_kb || 0) - Number(a.rss_kb || 0));
        } else {
            copy.sort((a, b) => {
                const dc = Number(b.cpu || 0) - Number(a.cpu || 0);
                return dc !== 0 ? dc : (Number(b.rss_kb || 0) - Number(a.rss_kb || 0));
            });
        }
        return copy;
    }

    function refreshGithubProfile() {
        if (leftActionProc.running)
            leftActionProc.running = false;
        appRoot.leftActionBusy = true;
        leftActionProc.command = [appRoot.scriptsDir + "/sysstat.sh", "--refresh-github"];
        leftActionProc.running = true;
    }

    function refreshWeather() {
        if (leftActionProc.running)
            leftActionProc.running = false;
        appRoot.leftActionBusy = true;
        leftActionProc.command = [appRoot.scriptsDir + "/sysstat.sh", "--refresh-weather"];
        leftActionProc.running = true;
    }

    function killUserTask(pid, name) {
        const pidNum = Number(pid || 0);
        if (pidNum <= 1)
            return;
        if (leftActionProc.running)
            leftActionProc.running = false;
        appRoot.leftActionBusy = true;
        leftActionProc.command = [appRoot.scriptsDir + "/sysstat.sh", "--kill", String(pidNum)];
        leftActionProc.running = true;
        appRoot.showNotificationOsd("Task Manager", "Killed " + (name || "task"), "Terminated PID " + pidNum);
    }

    function setCoffeeMode(mode) {
        const act = (mode === "on" || mode === "start")
            ? true
            : ((mode === "off" || mode === "stop") ? false : !appRoot.coffeeActive);
        appRoot.coffeeActive = act;
        const next = Object.assign({}, appRoot.sysInfo);
        next.coffee_mode = act;
        appRoot.sysInfo = next;
        if (coffeeActionProc.running)
            coffeeActionProc.running = false;
        coffeeActionProc.command = [appRoot.scriptsDir + "/sysstat.sh", "--coffee", act ? "on" : "off"];
        coffeeActionProc.running = true;
        appRoot.showNotificationOsd(
            "Coffee Mode",
            act ? "Coffee Mode Active ☕" : "Coffee Mode Off",
            act ? "Laptop will stay awake (idle, lock & sleep disabled)" : "Normal idle and sleep restored"
        );
    }

    Process {
        id: coffeeActionProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applySysStatPayload(parsed, false);
                } catch (e) {}
            }
        }
    }

    Process {
        id: coffeeStartupProc
        command: [appRoot.scriptsDir + "/sysstat.sh", "--coffee", "on"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applySysStatPayload(parsed, false);
                } catch (e) {}
            }
        }
    }

    Process {
        id: leftActionProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                appRoot.leftActionBusy = false;
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applySysStatPayload(parsed, false);
                } catch (e) {}
            }
        }
    }

    Process {
        id: sysStatProc
        command: appRoot.anyLeftDockOpen
            ? [appRoot.scriptsDir + "/sysstat.sh"]
            : [appRoot.scriptsDir + "/sysstat.sh", "--light"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applySysStatPayload(parsed, true);
                } catch (e) {}
            }
        }
    }

    Process {
        id: wallListProc
        command: [appRoot.scriptsDir + "/wallpaper.sh", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text.trim());
                    if (Array.isArray(list))
                        appRoot.wallpapers = list;
                } catch (e) {}
            }
        }
    }

    Process {
        id: wallCurProc
        command: [appRoot.scriptsDir + "/wallpaper.sh", "--current"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "")
                    appRoot.currentWallpaper = p;
            }
        }
    }

    Process {
        id: wallRandomProc
        command: ["true"]
        onExited: {
            wallCurProc.running = true;
            wallPaletteRefreshTimer.restart();
        }
    }

    Process {
        id: hyprGetProc
        command: [appRoot.scriptsDir + "/hypr-config.sh", "--get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    if (parsed && typeof parsed === "object")
                        appRoot.hyprConfig = parsed;
                } catch (e) {}
            }
        }
    }

    Process {
        id: hyprSetProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    if (parsed && typeof parsed === "object")
                        appRoot.hyprConfig = parsed;
                } catch (e) {}
            }
        }
    }

    property var _lastStatusArgs: []

    function applyStatusPayload(parsed) {
        if (!parsed || typeof parsed !== "object")
            return;
        appRoot.statusDetail = {
            wifi_networks: Array.isArray(parsed.wifi_networks) ? parsed.wifi_networks : [],
            bt_devices: Array.isArray(parsed.bt_devices) ? parsed.bt_devices : [],
            audio_sinks: Array.isArray(parsed.audio_sinks) ? parsed.audio_sinks : [],
            audio_sources: Array.isArray(parsed.audio_sources) ? parsed.audio_sources : [],
            action_ok: parsed.action_ok !== false,
            action_msg: String(parsed.action_msg || "")
        };
        const synced = Object.assign({}, appRoot.sysInfo);
        if (parsed.wifi_on !== undefined) synced.wifi_on = !!parsed.wifi_on;
        if (parsed.wifi_ssid !== undefined) synced.wifi_ssid = String(parsed.wifi_ssid);
        if (parsed.bt_on !== undefined) synced.bt_on = !!parsed.bt_on;
        if (parsed.vol !== undefined) synced.vol = Number(parsed.vol);
        if (parsed.muted !== undefined) synced.muted = !!parsed.muted;
        if (parsed.mic_vol !== undefined) synced.mic_vol = Number(parsed.mic_vol);
        if (parsed.mic_muted !== undefined) synced.mic_muted = !!parsed.mic_muted;
        if (parsed.power_profile !== undefined) synced.power_profile = String(parsed.power_profile);
        appRoot.sysInfo = synced;
    }

    function refreshStatusDetail() {
        if (!statusDetailProc.running)
            statusDetailProc.running = true;
    }

    function runStatusAction(args) {
        if (statusActionProc.running)
            statusActionProc.running = false;
        appRoot.statusBusy = true;
        appRoot.statusErrorMsg = "";
        appRoot._lastStatusArgs = args;
        statusActionProc.command = [appRoot.scriptsDir + "/status-ctl.sh"].concat(args);
        statusActionProc.running = true;
    }

    function setSinkVolume(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));
        appRoot._prevVol = clamped;
        const next = Object.assign({}, appRoot.sysInfo);
        next.vol = clamped;
        appRoot.sysInfo = next;
        appRoot._pendingSinkVol = clamped;
        sinkVolCoalesceTimer.restart();
    }

    function setSourceVolume(pct) {
        const clamped = Math.max(0, Math.min(120, Math.round(pct)));
        appRoot._prevMicVol = clamped;
        const next = Object.assign({}, appRoot.sysInfo);
        next.mic_vol = clamped;
        appRoot.sysInfo = next;
        appRoot._pendingSourceVol = clamped;
        sourceVolCoalesceTimer.restart();
    }

    Timer {
        id: sinkVolCoalesceTimer
        interval: 45
        repeat: false
        onTriggered: {
            if (appRoot._pendingSinkVol >= 0) {
                if (sinkVolSetProc.running)
                    sinkVolSetProc.running = false;
                sinkVolSetProc.command = [appRoot.scriptsDir + "/status-ctl.sh", "--set-vol", String(appRoot._pendingSinkVol)];
                sinkVolSetProc.running = true;
            }
        }
    }

    Timer {
        id: sourceVolCoalesceTimer
        interval: 45
        repeat: false
        onTriggered: {
            if (appRoot._pendingSourceVol >= 0) {
                if (sourceVolSetProc.running)
                    sourceVolSetProc.running = false;
                sourceVolSetProc.command = [appRoot.scriptsDir + "/status-ctl.sh", "--set-mic-vol", String(appRoot._pendingSourceVol)];
                sourceVolSetProc.running = true;
            }
        }
    }

    Process {
        id: sinkVolSetProc
        command: ["true"]
    }

    Process {
        id: sourceVolSetProc
        command: ["true"]
    }

    Process {
        id: statusDetailProc
        command: [appRoot.scriptsDir + "/status-ctl.sh", "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applyStatusPayload(parsed);
                } catch (e) {}
            }
        }
    }

    Process {
        id: statusActionProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                appRoot.statusBusy = false;
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applyStatusPayload(parsed);
                    if (parsed && parsed.action_ok === false) {
                        appRoot.statusErrorMsg = String(parsed.action_msg || "Action failed");
                        if (appRoot._lastStatusArgs.length >= 2 && appRoot._lastStatusArgs[0] === "--wifi-connect") {
                            appRoot.wifiPasswordTarget = String(appRoot._lastStatusArgs[1]);
                        }
                    } else {
                        appRoot.statusErrorMsg = "";
                        if (appRoot._lastStatusArgs.length >= 1 && appRoot._lastStatusArgs[0] === "--wifi-connect") {
                            appRoot.wifiPasswordTarget = "";
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // ========== MUSIC PLAYER & CAVA STATE ==========
    property bool musicHasPlayer: false
    property bool musicPlaying: false
    property string musicStatus: ""
    property string musicTitle: ""
    property string musicArtist: ""
    property string musicAlbum: ""
    property string musicArtUrl: ""
    property string musicPlayerName: "Media"
    property bool musicLoop: false
    property real musicPosition: 0
    property real musicLength: 0
    property bool musicDrawerPinned: false
    property var cavaBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    function formatMusicTime(sec) {
        const s = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" + r : r);
    }

    function applyMusicStatusPayload(parsed) {
        if (!parsed || typeof parsed !== "object")
            return;
        const active = !!parsed.active;
        appRoot.musicHasPlayer = active;
        if (!active)
            appRoot.musicDrawerPinned = false;
        appRoot.musicPlaying = !!parsed.playing;
        appRoot.musicStatus = active ? (parsed.playing ? "Playing" : "Paused") : "";
        appRoot.musicTitle = String(parsed.title || "");
        appRoot.musicArtist = String(parsed.artist || "");
        appRoot.musicAlbum = String(parsed.album || "");
        appRoot.musicArtUrl = String(parsed.art || "");
        appRoot.musicPlayerName = String(parsed.player || "Media");
        appRoot.musicLoop = !!parsed.loop;
        appRoot.musicPosition = Math.max(0, Number(parsed.pos || 0));
        appRoot.musicLength = Math.max(0, Number(parsed.len || 0));
    }

    function musicCmd(args) {
        if (musicActionProc.running)
            musicActionProc.running = false;
        musicActionProc.command = [appRoot.scriptsDir + "/music-ctl.sh"].concat(args);
        musicActionProc.running = true;
    }

    Timer {
        id: musicPollTimer
        interval: appRoot.musicHasPlayer ? 2000 : 3500
        repeat: true
        running: true
        onTriggered: {
            if (!musicPollProc.running)
                musicPollProc.running = true;
        }
    }

    Timer {
        id: musicPosTickTimer
        interval: 1000
        repeat: true
        running: appRoot.musicPlaying
        onTriggered: {
            if (appRoot.musicLength > 0 && appRoot.musicPosition < appRoot.musicLength) {
                appRoot.musicPosition = Math.min(appRoot.musicLength, appRoot.musicPosition + 1);
            }
        }
    }

    Process {
        id: musicActionProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applyMusicStatusPayload(parsed);
                } catch (e) {}
            }
        }
    }

    Process {
        id: musicPollProc
        command: [appRoot.scriptsDir + "/music-ctl.sh", "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim());
                    appRoot.applyMusicStatusPayload(parsed);
                } catch (e) {}
            }
        }
    }

    Process {
        id: cavaProc
        running: appRoot.musicPlaying
        command: ["bash", "-c", "cfg=\"/tmp/minimalarch-cava-$USER.conf\"; printf '[general]\\nbars = 20\\nframerate = 20\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' > \"$cfg\"; exec stdbuf -oL cava -p \"$cfg\""]
        stdout: SplitParser {
            onRead: data => {
                const raw = data.trim();
                if (!raw) return;
                const parts = raw.split(";");
                const arr = [];
                for (let i = 0; i < 20; i++) {
                    const v = parseInt(parts[i], 10);
                    arr.push(isNaN(v) ? 0 : Math.max(0, Math.min(100, v)));
                }
                appRoot.cavaBars = arr;
            }
        }
        onRunningChanged: {
            if (!running) {
                appRoot.cavaBars = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
            }
        }
    }

    Component.onCompleted: {
        coffeeStartupProc.running = true;
        musicPollProc.running = true;
        refreshSysStat();
        refreshStatusDetail();
        refreshWallpapers();
        refreshHyprConfig();
        wallCurProc.running = true;
    }

    // IPC handlers matching existing ~/.config/hypr/config/bind.lua keybinds
    IpcHandler {
        target: "bar"

        function toggleSearch(monitor: string): string {
            const st = appRoot.toggleIslandFor(monitor, "search");
            return "state=" + st;
        }

        function toggleWallpaper(): string {
            const open = appRoot.toggleBottomDockFor("");
            return "bottomOpen=" + open;
        }

        function togglePanel(name: string, monitor: string): string {
            if (name === "wallpaper-switcher") {
                const open = appRoot.toggleBottomDockFor(monitor);
                return "bottomOpen=" + open;
            }
            if (name === "left-panel" || name === "leftPanel") {
                const open = appRoot.toggleLeftDockFor(monitor);
                return "leftOpen=" + open;
            }
            if (name === "right-panel" || name === "rightPanel") {
                const open = appRoot.toggleRightDockFor(monitor);
                return "rightOpen=" + open;
            }
            return "ignored:" + name;
        }

        function toggleLeftPanel(monitor: string): string {
            const open = appRoot.toggleLeftDockFor(monitor);
            return "leftOpen=" + open;
        }

        function setRightSection(section: string): string {
            const valid = ["theme", "bar", "border", "windows", "keybinds"];
            const target = valid.indexOf(section) >= 0 ? section : "theme";
            appRoot.rightMenuSection = target;
            appRoot.setRightDockFor("", true);
            return "section=" + target;
        }

        function toggleRightPanel(monitor: string): string {
            const open = appRoot.toggleRightDockFor(monitor);
            return "rightOpen=" + open;
        }

        function toggleBar(monitor: string): string {
            const shown = appRoot.toggleBarShownFor(monitor);
            return "barShown=" + shown;
        }

        function toggleOverview(monitor: string): string {
            const st = appRoot.toggleIslandFor(monitor, "search");
            return "state=" + st;
        }

        function toggleWeather(monitor: string): string {
            appRoot.refreshWeather();
            appRoot.toggleStatusPopupRequested(appRoot.effectiveMonitor(monitor), "weather");
            return "weather";
        }

        function toggleCalendar(monitor: string): string {
            appRoot.resetCalendarToToday();
            appRoot.toggleStatusPopupRequested(appRoot.effectiveMonitor(monitor), "calendar");
            return "calendar";
        }

        function toggleDnd(): string {
            appRoot.toggleDnd();
            return "dnd=" + appRoot.dndActive;
        }

        function noteVolumeTarget(monitor: string): string {
            noteVolumeDelayTimer.restart();
            return "volume scheduled";
        }

        function triggerOsd(kind: string, title: string, subtitle: string): string {
            if (kind === "notify") {
                appRoot.showNotificationOsd("System", title || "Notification", subtitle || "");
                return "osd=notify";
            }
            if (kind === "brightness") {
                const b = Number(appRoot.sysInfo.brightness !== undefined ? appRoot.sysInfo.brightness : 100);
                appRoot.showValueOsd("brightness", "󰃠", title || "Brightness", b, subtitle || (b + "%"));
                return "osd=brightness";
            }
            const v = Number(appRoot.sysInfo.vol || 0);
            const m = !!appRoot.sysInfo.muted;
            appRoot.showValueOsd("volume", m ? "󰖁" : "󰕾", title || "Volume", v, subtitle || (m ? "Muted" : (v + "%")));
            return "osd=volume";
        }

        function clipboard(monitor: string): string {
            appRoot.setIslandFor(monitor, "search");
            return "search open";
        }

        function emojis(monitor: string): string {
            appRoot.setIslandFor(monitor, "search");
            return "search open";
        }

        function notes(monitor: string): string {
            appRoot.setIslandFor(monitor, "search");
            return "search open";
        }

        function apps(monitor: string): string {
            appRoot.setIslandFor(monitor, "search");
            return "search open";
        }

        function toggleCoffee(): string {
            appRoot.setCoffeeMode("toggle");
            return "coffee=" + appRoot.coffeeActive;
        }

        function setCoffee(state: string): string {
            appRoot.setCoffeeMode(state || "on");
            return "coffee=" + appRoot.coffeeActive;
        }

        function barDiag(query: string): string {
            const mon = appRoot.effectiveMonitor("");
            const state = "island=" + appRoot.islandFor(mon)
                + " leftOpen=" + appRoot.leftDockFor(mon)
                + " bottomOpen=" + appRoot.bottomDockFor(mon)
                + " rightOpen=" + appRoot.rightDockFor(mon)
                + " osdActive=" + appRoot.osdActive
                + " coffee=" + appRoot.coffeeActive;
            if (query === "state")
                return state;
            return "mon=" + mon + " " + state;
        }
    }

    // ========== ANIMATED WAYLAND SESSION LOCK SCREEN ==========
    property bool lockActive: false
    property string lockPassword: ""
    property string lockError: ""
    property bool lockChecking: false
    property bool lockUnlocking: false
    property int lockFailCount: 0
    readonly property string lockUser: Quickshell.env("USER") || "user"

    function activateLock() {
        appRoot.lockPassword = "";
        appRoot.lockError = "";
        appRoot.lockChecking = false;
        appRoot.lockUnlocking = false;
        appRoot.lockActive = true;
    }

    function submitLockPassword() {
        if (appRoot.lockChecking || appRoot.lockUnlocking)
            return;
        if (appRoot.lockPassword.length === 0) {
            appRoot.lockFailCount += 1;
            appRoot.lockError = "Enter password";
            return;
        }
        appRoot.lockError = "";
        appRoot.lockChecking = true;
        lockPam.start();
    }

    Timer {
        id: lockUnlockDelayTimer
        interval: 260
        repeat: false
        onTriggered: {
            appRoot.lockActive = false;
            appRoot.lockUnlocking = false;
            appRoot.lockPassword = "";
            appRoot.lockError = "";
        }
    }

    PamContext {
        id: lockPam
        config: "login"
        user: appRoot.lockUser
        onPamMessage: {
            if (responseRequired)
                respond(appRoot.lockPassword);
        }
        onCompleted: result => {
            appRoot.lockChecking = false;
            if (result === PamResult.Success) {
                appRoot.lockError = "";
                appRoot.lockUnlocking = true;
                lockUnlockDelayTimer.restart();
            } else {
                appRoot.lockFailCount += 1;
                appRoot.lockPassword = "";
                appRoot.lockError = "Incorrect password";
            }
        }
    }

    IpcHandler {
        target: "lock"

        function activate(): string {
            appRoot.activateLock();
            return "locked";
        }

        function toggle(): string {
            if (!appRoot.lockActive)
                appRoot.activateLock();
            return "locked=" + appRoot.lockActive;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: appRoot.lockActive

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"

            Item {
                id: lockRoot
                anchors.fill: parent
                property bool entered: false
                property bool showPass: false
                property real shakeX: 0
                property string timeMain: Qt.formatDateTime(new Date(), "h:mm")
                property string timeAmPm: Qt.formatDateTime(new Date(), "AP")
                property string dateLine: Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")

                Component.onCompleted: {
                    entered = true;
                    lockInput.forceActiveFocus();
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: appRoot.lockActive
                    onTriggered: {
                        const now = new Date();
                        lockRoot.timeMain = Qt.formatDateTime(now, "h:mm");
                        lockRoot.timeAmPm = Qt.formatDateTime(now, "AP");
                        lockRoot.dateLine = Qt.formatDateTime(now, "dddd, MMMM d, yyyy");
                    }
                }

                Connections {
                    target: appRoot
                    function onLockFailCountChanged() {
                        if (appRoot.lockActive && appRoot.lockFailCount > 0) {
                            shakeAnim.restart();
                            lockInput.text = "";
                            lockInput.forceActiveFocus();
                        }
                    }
                }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: lockRoot; property: "shakeX"; to: -12; duration: 45; easing.type: Easing.OutQuad }
                    NumberAnimation { target: lockRoot; property: "shakeX"; to: 12; duration: 60; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: lockRoot; property: "shakeX"; to: -8; duration: 55; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: lockRoot; property: "shakeX"; to: 8; duration: 55; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: lockRoot; property: "shakeX"; to: 0; duration: 50; easing.type: Easing.OutQuad }
                }

                readonly property bool visiblePhase: lockRoot.entered && !appRoot.lockUnlocking

                // Animated Wallpaper Backdrop
                Image {
                    anchors.fill: parent
                    source: appRoot.currentWallpaperBackdrop !== "" ? ("file://" + appRoot.currentWallpaperBackdrop) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    scale: lockRoot.visiblePhase ? 1.0 : 1.08
                    opacity: lockRoot.visiblePhase ? 1.0 : 0.0
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                }

                // Frosted Dark Scrim + Subtle Vignette
                Rectangle {
                    anchors.fill: parent
                    opacity: lockRoot.visiblePhase ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(appRoot.rawBg.r, appRoot.rawBg.g, appRoot.rawBg.b, 0.72) }
                        GradientStop { position: 0.5; color: Qt.rgba(appRoot.rawBg.r, appRoot.rawBg.g, appRoot.rawBg.b, 0.62) }
                        GradientStop { position: 1.0; color: Qt.rgba(appRoot.rawBg.r, appRoot.rawBg.g, appRoot.rawBg.b, 0.86) }
                    }
                }

                // Animated Accent Perimeter Frame
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: appRoot.sc(10)
                    radius: appRoot.cornerRadiusCfg
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, 0.32)
                    opacity: lockRoot.visiblePhase ? 1.0 : 0.0
                    scale: lockRoot.visiblePhase ? 1.0 : 0.96
                    Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                }

                // Top Status Bar on Lock Screen
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: appRoot.sc(28)
                    width: lockTopRow.implicitWidth + appRoot.sc(24)
                    height: appRoot.sc(32)
                    radius: Math.round(height / 2)
                    color: Qt.rgba(appRoot.colSurface.r, appRoot.colSurface.g, appRoot.colSurface.b, 0.78)
                    border.width: 1
                    border.color: appRoot.colLineStrong
                    opacity: lockRoot.visiblePhase ? 1.0 : 0.0
                    transform: Translate {
                        y: lockRoot.visiblePhase ? 0 : -16
                        Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                    }
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                    Row {
                        id: lockTopRow
                        anchors.centerIn: parent
                        spacing: appRoot.sc(12)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰌾  Locked"
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(-1)
                            font.bold: true
                            color: appRoot.colAccent
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1; height: appRoot.sc(12)
                            color: appRoot.colLineStrong
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (appRoot.sysInfo.wifi_on ? "󰤨 " + (appRoot.sysInfo.wifi_ssid || "Wi-Fi") : "󰤭 Offline")
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(-1)
                            color: appRoot.colDim
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1; height: appRoot.sc(12)
                            color: appRoot.colLineStrong
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (appRoot.sysInfo.bat_status === "Charging" ? "󰂄 " : "󰁹 ") + (appRoot.sysInfo.bat || 100) + "%"
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(-1)
                            color: appRoot.colGreen
                        }
                    }
                }

                // Center Hero Column (Clock, Weather, Avatar, Password Card, Music)
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(appRoot.sc(380), parent.width - appRoot.sc(48))
                    spacing: appRoot.sc(18)
                    opacity: lockRoot.visiblePhase ? 1.0 : 0.0
                    scale: lockRoot.visiblePhase ? 1.0 : 0.92
                    transform: Translate {
                        y: lockRoot.visiblePhase ? 0 : 28
                        Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                    }
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                    // Hero Clock + Date + Weather
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: appRoot.sc(4)

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: appRoot.sc(6)

                            Text {
                                text: lockRoot.timeMain
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.sc(64)
                                font.bold: true
                                color: appRoot.colFg
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: appRoot.sc(12)
                                text: lockRoot.timeAmPm
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(4)
                                font.bold: true
                                color: appRoot.colAccent
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: lockRoot.dateLine
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(1)
                            color: appRoot.colDim
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: appRoot.sc(6)
                            readonly property var wx: appRoot.sysInfo.weather || ({})
                            Text {
                                text: parent.wx.icon || "󰖙"
                                font.family: appRoot.iconFont
                                font.pixelSize: appRoot.fs(1)
                                color: appRoot.colAmber
                            }
                            Text {
                                text: (parent.wx.temp || "24°C") + " • " + (parent.wx.desc || "Clear") + " • " + (parent.wx.city || "Kanchanpur")
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-1)
                                color: appRoot.colMuted
                            }
                        }
                    }

                    // User Avatar + Name
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: appRoot.sc(8)

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: appRoot.sc(68)
                            height: appRoot.sc(68)
                            radius: Math.round(width / 2)
                            color: appRoot.colSurface
                            border.width: 2
                            border.color: appRoot.colAccent
                            clip: true

                            Image {
                                id: lockAvatarImg
                                anchors.fill: parent
                                anchors.margins: 2
                                source: (appRoot.sysInfo.github && appRoot.sysInfo.github.avatar) ? ("file://" + appRoot.sysInfo.github.avatar) : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: source !== "" && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !lockAvatarImg.visible
                                text: "󰀄"
                                font.family: appRoot.iconFont
                                font.pixelSize: appRoot.sc(28)
                                color: appRoot.colAccent
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (appRoot.sysInfo.github && appRoot.sysInfo.github.name) ? appRoot.sysInfo.github.name : appRoot.lockUser
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(2)
                            font.bold: true
                            color: appRoot.colFg
                        }
                    }

                    // Password Input Pill
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: appRoot.sc(6)

                        Rectangle {
                            Layout.fillWidth: true
                            height: appRoot.sc(44)
                            radius: Math.round(height / 2)
                            color: Qt.rgba(appRoot.colSurface.r, appRoot.colSurface.g, appRoot.colSurface.b, 0.88)
                            border.width: 1.5
                            border.color: appRoot.lockError !== ""
                                ? appRoot.colRed
                                : (lockInput.activeFocus ? appRoot.colAccent : appRoot.colLineStrong)
                            transform: Translate { x: lockRoot.shakeX }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: appRoot.sc(14)
                                anchors.rightMargin: appRoot.sc(6)
                                spacing: appRoot.sc(8)

                                Text {
                                    text: "󰌋"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(1)
                                    color: appRoot.lockError !== "" ? appRoot.colRed : appRoot.colAccent
                                }

                                TextInput {
                                    id: lockInput
                                    Layout.fillWidth: true
                                    color: appRoot.colFg
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(1)
                                    echoMode: lockRoot.showPass ? TextInput.Normal : TextInput.Password
                                    passwordCharacter: "•"
                                    selectByMouse: true
                                    clip: true
                                    enabled: !appRoot.lockChecking && !appRoot.lockUnlocking
                                    onTextChanged: {
                                        if (appRoot.lockPassword !== text)
                                            appRoot.lockPassword = text;
                                        if (appRoot.lockError !== "" && text.length > 0)
                                            appRoot.lockError = "";
                                    }
                                    Keys.onReturnPressed: appRoot.submitLockPassword()
                                    Keys.onEnterPressed: appRoot.submitLockPassword()

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appRoot.lockChecking ? "Unlocking..." : "Enter password..."
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(0)
                                        color: appRoot.colMuted
                                        visible: lockInput.text.length === 0
                                    }
                                }

                                Text {
                                    text: lockRoot.showPass ? "󰈉" : "󰈈"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(1)
                                    color: eyeMouse.containsMouse ? appRoot.colFg : appRoot.colMuted
                                    MouseArea {
                                        id: eyeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: lockRoot.showPass = !lockRoot.showPass
                                    }
                                }

                                Rectangle {
                                    width: appRoot.sc(32)
                                    height: appRoot.sc(32)
                                    radius: Math.round(width / 2)
                                    color: unlockBtnMouse.containsMouse ? appRoot.colAccent : Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, 0.22)
                                    Text {
                                        anchors.centerIn: parent
                                        text: appRoot.lockChecking ? "󰔟" : "󰁔"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(2)
                                        color: unlockBtnMouse.containsMouse ? appRoot.colBg : appRoot.colAccent
                                    }
                                    MouseArea {
                                        id: unlockBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.submitLockPassword()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: appRoot.lockError !== ""
                            text: appRoot.lockError
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(-1)
                            font.bold: true
                            color: appRoot.colRed
                        }
                    }

                    // Now Playing Mini-Pill (if music active)
                    Rectangle {
                        visible: appRoot.musicHasPlayer
                        Layout.fillWidth: true
                        height: appRoot.sc(42)
                        radius: Math.round(height / 2)
                        color: Qt.rgba(appRoot.colSurface.r, appRoot.colSurface.g, appRoot.colSurface.b, 0.78)
                        border.width: 1
                        border.color: appRoot.colLineStrong

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: appRoot.sc(14)
                            anchors.rightMargin: appRoot.sc(10)
                            spacing: appRoot.sc(8)

                            Text {
                                text: "󰎈"
                                font.family: appRoot.iconFont
                                font.pixelSize: appRoot.fs(2)
                                color: appRoot.colAccent
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (appRoot.musicTitle || "Playing") + (appRoot.musicArtist ? (" — " + appRoot.musicArtist) : "")
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-1)
                                color: appRoot.colFg
                                elide: Text.ElideRight
                            }

                            PillIconBtn {
                                iconText: appRoot.musicPlaying ? "󰏤" : "󰐊"
                                active: true
                                iconPixelSize: appRoot.fs(1)
                                onClicked: appRoot.musicCmd(["--play-pause"])
                            }
                        }
                    }
                }

                // Bottom Quick Power Actions
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: appRoot.sc(26)
                    spacing: appRoot.sc(10)
                    opacity: lockRoot.visiblePhase ? 1.0 : 0.0
                    transform: Translate {
                        y: lockRoot.visiblePhase ? 0 : 16
                        Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                    }
                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: [
                            { icon: "󰤄", label: "Suspend", cmd: "systemctl suspend" },
                            { icon: "󰜉", label: "Reboot", cmd: "systemctl reboot" },
                            { icon: "󰐥", label: "Shutdown", cmd: "systemctl poweroff" }
                        ]
                        delegate: Rectangle {
                            id: lockPwrBtn
                            required property var modelData
                            width: lockPwrRow.implicitWidth + appRoot.sc(20)
                            height: appRoot.sc(30)
                            radius: Math.round(height / 2)
                            color: lockPwrMouse.containsMouse
                                ? Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, 0.22)
                                : Qt.rgba(appRoot.colSurface.r, appRoot.colSurface.g, appRoot.colSurface.b, 0.72)
                            border.width: 1
                            border.color: lockPwrMouse.containsMouse ? appRoot.colAccent : appRoot.colLineStrong

                            Row {
                                id: lockPwrRow
                                anchors.centerIn: parent
                                spacing: appRoot.sc(6)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: lockPwrBtn.modelData.icon
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(0)
                                    color: lockPwrMouse.containsMouse ? appRoot.colAccent : appRoot.colDim
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: lockPwrBtn.modelData.label
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(-1)
                                    color: lockPwrMouse.containsMouse ? appRoot.colFg : appRoot.colDim
                                }
                            }

                            MouseArea {
                                id: lockPwrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["bash", "-c", lockPwrBtn.modelData.cmd])
                            }
                        }
                    }
                }
            }
        }
    }

    function stepBrightness(arg) {
        if (brightStepProc.running)
            brightStepProc.running = false;
        brightStepProc.command = ["bash", "-c", "brightnessctl set " + arg + " >/dev/null 2>&1 && brightnessctl -m 2>/dev/null"];
        brightStepProc.running = true;
    }

    Process {
        id: brightStepProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length >= 4) {
                    const pct = Math.max(0, Math.min(100, parseInt(parts[3].replace("%", ""), 10) || 0));
                    appRoot._prevBrightness = pct;
                    const next = Object.assign({}, appRoot.sysInfo);
                    next.brightness = pct;
                    appRoot.sysInfo = next;
                    appRoot.showValueOsd(
                        "brightness",
                        pct > 65 ? "󰃠" : (pct > 30 ? "󰃟" : "󰃞"),
                        "Brightness",
                        pct,
                        pct + "%"
                    );
                }
            }
        }
    }

    IpcHandler {
        target: "brightness"

        function increment(): string {
            appRoot.stepBrightness("+5%");
            return "ok";
        }

        function incrementFor(monitor: string): string {
            appRoot.stepBrightness("+5%");
            return "ok";
        }

        function decrement(): string {
            appRoot.stepBrightness("5%-");
            return "ok";
        }

        function decrementFor(monitor: string): string {
            appRoot.stepBrightness("5%-");
            return "ok";
        }
    }

    component PillIconBtn: Rectangle {
        id: btnRoot
        property string iconText: ""
        property bool active: false
        property bool repeatable: false
        property color baseColor: "transparent"
        property color activeColor: "transparent"
        property color hoverColor: "transparent"
        property color iconColor: active ? appRoot.colAccent : appRoot.colFg
        property int btnWidth: appRoot.sc(26)
        property int btnHeight: appRoot.sc(24)
        property int iconPixelSize: appRoot.fs(1)
        property int activeBorderWidth: 0
        signal clicked()

        width: btnWidth
        height: btnHeight
        radius: appRoot.sc(6)
        color: "transparent"
        border.width: 0
        border.color: "transparent"

        Text {
            anchors.centerIn: parent
            text: btnRoot.iconText
            font.family: appRoot.iconFont
            font.pixelSize: btnRoot.iconPixelSize
            color: (btnRoot.active || btnMouse.containsMouse) ? appRoot.colAccent : btnRoot.iconColor

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Timer {
            id: repeatDelayTimer
            interval: 340
            repeat: false
            onTriggered: {
                if (btnRoot.repeatable && btnMouse.pressed)
                    repeatStepTimer.start();
            }
        }

        Timer {
            id: repeatStepTimer
            interval: 75
            repeat: true
            onTriggered: {
                if (btnRoot.repeatable && btnMouse.pressed)
                    btnRoot.clicked();
                else
                    stop();
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                if (btnRoot.repeatable)
                    repeatDelayTimer.restart();
            }
            onReleased: {
                repeatDelayTimer.stop();
                repeatStepTimer.stop();
            }
            onCanceled: {
                repeatDelayTimer.stop();
                repeatStepTimer.stop();
            }
            onClicked: btnRoot.clicked()
        }
    }

    component AreaLineGraph: Rectangle {
        id: graphBox
        property var samples: []
        property color lineColor: appRoot.colAccent
        property color gridColor: appRoot.colLine

        height: appRoot.sc(72)
        radius: appRoot.sc(9)
        color: "transparent"
        border.width: 0

        onSamplesChanged: graphCanvas.requestPaint()
        onLineColorChanged: graphCanvas.requestPaint()
        onGridColorChanged: graphCanvas.requestPaint()

        Canvas {
            id: graphCanvas
            anchors.fill: parent
            anchors.margins: appRoot.sc(5)

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                const w = width;
                const h = height;
                ctx.clearRect(0, 0, w, h);
                if (w <= 4 || h <= 4)
                    return;

                // Horizontal reference grid lines (25%, 50%, 75%)
                ctx.strokeStyle = graphBox.gridColor;
                ctx.lineWidth = 1;
                for (let g = 1; g <= 3; g++) {
                    const gy = Math.round(h * (g / 4.0)) + 0.5;
                    ctx.beginPath();
                    ctx.moveTo(0, gy);
                    ctx.lineTo(w, gy);
                    ctx.stroke();
                }

                const arr = (Array.isArray(graphBox.samples) && graphBox.samples.length > 1)
                    ? graphBox.samples
                    : [0, 0];
                const n = arr.length;
                const padY = 4;
                const usableH = Math.max(4, h - padY * 2);
                const pts = [];
                for (let i = 0; i < n; i++) {
                    const val = Math.max(0, Math.min(100, Number(arr[i] || 0)));
                    pts.push({
                        x: (i * w) / (n - 1),
                        y: padY + (1.0 - val / 100.0) * usableH
                    });
                }

                function traceSpline(c, p) {
                    for (let i = 1; i < p.length - 1; i++) {
                        const midX = (p[i].x + p[i + 1].x) * 0.5;
                        const midY = (p[i].y + p[i + 1].y) * 0.5;
                        c.quadraticCurveTo(p[i].x, p[i].y, midX, midY);
                    }
                    const last = p[p.length - 1];
                    c.lineTo(last.x, last.y);
                }

                const lastPt = pts[pts.length - 1];

                // Area gradient fill under smooth curve
                ctx.beginPath();
                ctx.moveTo(pts[0].x, h);
                ctx.lineTo(pts[0].x, pts[0].y);
                traceSpline(ctx, pts);
                ctx.lineTo(lastPt.x, h);
                ctx.closePath();

                const grad = ctx.createLinearGradient(0, 0, 0, h);
                grad.addColorStop(0.0, Qt.rgba(graphBox.lineColor.r, graphBox.lineColor.g, graphBox.lineColor.b, 0.34));
                grad.addColorStop(1.0, Qt.rgba(graphBox.lineColor.r, graphBox.lineColor.g, graphBox.lineColor.b, 0.02));
                ctx.fillStyle = grad;
                ctx.fill();

                // Crisp spline stroke
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                traceSpline(ctx, pts);
                ctx.strokeStyle = graphBox.lineColor;
                ctx.lineWidth = 2.0;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.stroke();

                // Latest sample indicator dot
                ctx.beginPath();
                ctx.arc(Math.max(3, lastPt.x - 1.5), lastPt.y, 3.0, 0, Math.PI * 2);
                ctx.fillStyle = graphBox.lineColor;
                ctx.fill();
            }
        }
    }

    // Reusable compact +/- stepper row for Rice Studio & Controls (no slider)
    component SettingSliderRow: RowLayout {
        id: ssrRoot
        property string label: ""
        property string valueText: ""
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real value: 0

        signal movedValue(real val)
        signal stepBy(real delta)

        Layout.fillWidth: true
        spacing: appRoot.sc(8)

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: ssrRoot.label
            font.family: appRoot.fontFamily
            font.pixelSize: appRoot.fs(0)
            color: appRoot.colFg
        }

        Row {
            spacing: appRoot.sc(4)

            PillIconBtn {
                iconText: "−"
                repeatable: true
                btnWidth: appRoot.sc(24)
                btnHeight: appRoot.sc(24)
                iconPixelSize: appRoot.fs(0)
                onClicked: ssrRoot.stepBy(-ssrRoot.stepSize)
            }

            Text {
                width: appRoot.sc(52)
                height: appRoot.sc(24)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: ssrRoot.valueText
                font.family: appRoot.fontFamily
                font.pixelSize: appRoot.fs(-1)
                font.bold: true
                color: appRoot.colAccent
            }

            PillIconBtn {
                iconText: "+"
                repeatable: true
                btnWidth: appRoot.sc(24)
                btnHeight: appRoot.sc(24)
                iconPixelSize: appRoot.fs(0)
                onClicked: ssrRoot.stepBy(ssrRoot.stepSize)
            }
        }
    }

    // Reusable Output / Input Audio control card for the Audio hover dropdown (no slider)
    component AudioSectionCard: Rectangle {
        id: audioCardRoot
        property string sectionTitle: "Output Audio"
        property string iconOn: "󰕾"
        property string iconMuted: "󰖁"
        property int volPct: 100
        property bool muted: false
        property int maxVol: 100
        property var devices: []

        signal toggleMute()
        signal volumeMoved(int newPct)
        signal selectDevice(int devId)

        Layout.fillWidth: true
        implicitHeight: audioCardCol.implicitHeight + appRoot.sc(8)
        radius: appRoot.sc(10)
        color: "transparent"
        border.width: 0

        ColumnLayout {
            id: audioCardCol
            anchors.fill: parent
            anchors.margins: appRoot.sc(2)
            spacing: appRoot.sc(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: appRoot.sc(8)

                PillIconBtn {
                    iconText: audioCardRoot.muted ? audioCardRoot.iconMuted : audioCardRoot.iconOn
                    iconColor: audioCardRoot.muted ? appRoot.colRed : appRoot.colAccent
                    active: !audioCardRoot.muted
                    btnWidth: appRoot.sc(26)
                    btnHeight: appRoot.sc(24)
                    iconPixelSize: appRoot.fs(1)
                    onClicked: audioCardRoot.toggleMute()
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: audioCardRoot.sectionTitle
                    font.family: appRoot.fontFamily
                    font.pixelSize: appRoot.fs(0)
                    font.weight: Font.Medium
                    color: appRoot.colFg
                }

                PillIconBtn {
                    iconText: "−"
                    repeatable: true
                    btnWidth: appRoot.sc(24)
                    btnHeight: appRoot.sc(24)
                    iconPixelSize: appRoot.fs(0)
                    onClicked: audioCardRoot.volumeMoved(Math.max(0, Math.min(audioCardRoot.maxVol, audioCardRoot.volPct - 5)))
                }

                Text {
                    width: appRoot.sc(46)
                    horizontalAlignment: Text.AlignHCenter
                    text: audioCardRoot.muted ? "Muted" : (audioCardRoot.volPct + "%")
                    font.family: appRoot.fontFamily
                    font.pixelSize: appRoot.fs(-1)
                    font.bold: true
                    color: audioCardRoot.muted ? appRoot.colRed : appRoot.colAccent
                }

                PillIconBtn {
                    iconText: "+"
                    repeatable: true
                    btnWidth: appRoot.sc(24)
                    btnHeight: appRoot.sc(24)
                    iconPixelSize: appRoot.fs(0)
                    onClicked: audioCardRoot.volumeMoved(Math.max(0, Math.min(audioCardRoot.maxVol, audioCardRoot.volPct + 5)))
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: appRoot.sc(8)
                visible: Array.isArray(audioCardRoot.devices) && audioCardRoot.devices.length > 0

                Repeater {
                    model: audioCardRoot.devices || []
                    delegate: Rectangle {
                        id: devItemRect
                        required property var modelData
                        readonly property bool isDefault: !!modelData.default

                        Layout.fillWidth: true
                        height: Math.max(appRoot.sc(34), devRowInner.implicitHeight + appRoot.sc(12))
                        radius: appRoot.sc(6)
                        color: "transparent"
                        border.width: 0

                        RowLayout {
                            id: devRowInner
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: devItemRect.isDefault ? "󰄬" : "󰝚"
                                font.family: appRoot.iconFont
                                font.pixelSize: appRoot.fs(0)
                                color: devItemRect.isDefault ? appRoot.colAccent : (devRowMouse.containsMouse ? appRoot.colFg : appRoot.colMuted)
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: devItemRect.modelData.name || "Audio Device"
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-1)
                                font.bold: devItemRect.isDefault
                                color: devItemRect.isDefault ? appRoot.colAccent : (devRowMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                            }
                        }

                        MouseArea {
                            id: devRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: audioCardRoot.selectDevice(Number(devItemRect.modelData.id))
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData

            readonly property string monitorName: {
                const hm = Hyprland.monitorFor(screen);
                return (hm && hm.name) ? hm.name : ((screen && screen.name) ? screen.name : "eDP-1");
            }

            readonly property string activeIsland: appRoot.islandFor(win.monitorName)
            readonly property bool leftDockOpen: appRoot.leftDockFor(win.monitorName)
            readonly property bool bottomDockOpen: appRoot.bottomDockFor(win.monitorName)
            readonly property bool rightDockOpen: appRoot.rightDockFor(win.monitorName)
            readonly property bool barShown: appRoot.barShownFor(win.monitorName)
            property bool musicHovered: false
            Timer {
                id: musicUnhoverTimer
                interval: 280
                repeat: false
                onTriggered: win.musicHovered = false
            }
            readonly property string bottomDrawerMode: win.activeIsland === "search"
                ? "search"
                : (win.bottomDockOpen
                    ? "wallpaper"
                    : (appRoot.musicHasPlayer
                        ? ((win.musicHovered || appRoot.musicDrawerPinned) ? "music_player" : "cava")
                        : ""))

            property bool leftDockPinned: false
            property bool rightDockPinned: false
            property string activeStatusPopup: "" // "", "wifi", "bt", "audio", "battery"
            property string activeCenterPopup: "" // "", "weather", "calendar"

            function openStatusPopup(kind) {
                statusPopupCloseTimer.stop();
                win.activeCenterPopup = "";
                if (win.activeStatusPopup !== kind)
                    appRoot.wifiPasswordTarget = "";
                win.activeStatusPopup = kind;
                appRoot.refreshStatusDetail();
                appRoot.refreshSysStat();
            }

            function openCenterPopup(kind) {
                statusPopupCloseTimer.stop();
                centerPopupCloseTimer.stop();
                win.activeStatusPopup = "";
                win.activeCenterPopup = kind;
                if (kind === "weather")
                    appRoot.refreshWeather();
                else if (kind === "calendar")
                    appRoot.resetCalendarToToday();
                appRoot.refreshSysStat();
            }

            // Continuous 4-border frame extents (bottom border remains frameThicknessCfg; compact launcher emerges only for needed space)
            readonly property real baseBorder: appRoot.frameThicknessCfg
            readonly property real topBarHeight: appRoot.barHeightCfg
            readonly property real leftOpenWidth: appRoot.sc(appRoot.leftDockWidthCfg)
            readonly property real rightOpenWidth: appRoot.sc(appRoot.rightDockWidthCfg)
            property real topExtent: win.barShown ? topBarHeight : 0
            property real leftExtent: !win.barShown ? 0 : (win.leftDockOpen ? leftOpenWidth : baseBorder)
            property real rightExtent: !win.barShown ? 0 : (win.rightDockOpen ? rightOpenWidth : baseBorder)
            property real bottomExtent: !win.barShown ? 0 : baseBorder

            Behavior on topExtent {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on leftExtent {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on rightExtent {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on bottomExtent {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Inner viewport cutout coordinates
            readonly property real innerX: leftExtent
            readonly property real innerY: topExtent
            readonly property real innerRight: Math.max(innerX + 40, stripRoot.width - rightExtent)
            readonly property real innerBottom: Math.max(innerY + 40, stripRoot.height - bottomExtent)
            readonly property real innerW: Math.max(40, innerRight - innerX)
            readonly property real innerH: Math.max(40, innerBottom - innerY)
            readonly property real innerRadius: appRoot.cornerRadiusCfg

            onInnerXChanged: unifiedFrameCanvas.requestPaint()
            onInnerYChanged: unifiedFrameCanvas.requestPaint()
            onInnerRightChanged: unifiedFrameCanvas.requestPaint()
            onInnerBottomChanged: unifiedFrameCanvas.requestPaint()
            onInnerRadiusChanged: unifiedFrameCanvas.requestPaint()

            Connections {
                target: appRoot
                function onColFrameChanged() { unifiedFrameCanvas.requestPaint(); }
                function onColBorderChanged() { unifiedFrameCanvas.requestPaint(); }
                function onColBorderGlowChanged() { unifiedFrameCanvas.requestPaint(); }
                function onBorderLineWidthChanged() { unifiedFrameCanvas.requestPaint(); }
                function onBorderPresetChanged() { unifiedFrameCanvas.requestPaint(); }
                function onBorderAnimPhaseChanged() { unifiedFrameCanvas.requestPaint(); }
                function onColAccentChanged() { unifiedFrameCanvas.requestPaint(); }
                function onColAccentAltChanged() { unifiedFrameCanvas.requestPaint(); }
                function onToggleStatusPopupRequested(mon, kind) {
                    if (mon === "" || mon === win.monitorName) {
                        if (kind === "weather" || kind === "calendar") {
                            if (win.activeCenterPopup === kind)
                                win.activeCenterPopup = "";
                            else
                                win.openCenterPopup(kind);
                        } else {
                            if (win.activeStatusPopup === kind)
                                win.activeStatusPopup = "";
                            else
                                win.openStatusPopup(kind);
                        }
                    }
                }
            }

            readonly property int focusedWsId: {
                Hyprland.monitors.values;
                Hyprland.focusedMonitor;
                Hyprland.focusedWorkspace;
                const hm = Hyprland.monitors.values.find(m => m.name === win.monitorName);
                if (hm && hm.activeWorkspace)
                    return hm.activeWorkspace.id;
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === win.monitorName && Hyprland.focusedWorkspace)
                    return Hyprland.focusedWorkspace.id;
                return 1;
            }

            readonly property string activeTitle: {
                Hyprland.activeToplevel;
                const top = Hyprland.activeToplevel;
                if (!top || !top.title || top.title.trim() === "")
                    return "Desktop";
                return top.title;
            }

            function wsOccupied(wid) {
                Hyprland.toplevels.values;
                return Hyprland.toplevels.values.some(t => ((t.workspace && t.workspace.id != null) ? t.workspace.id : -1) === wid);
            }

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: screen ? screen.height : 1080
            color: "transparent"
            WlrLayershell.exclusiveZone: win.barShown ? Math.round(appRoot.barHeightCfg) : 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: (activeIsland === "search" || bottomDockOpen || (activeStatusPopup === "wifi" && appRoot.wifiPasswordTarget !== ""))
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.OnDemand

            // Mask covers the connected 4 border strips + compact bottom Launcher + top-right Status dropdown + bottom-right OSD/Notification corner
            mask: Region {
                item: win.barShown ? topFrameStrip : null
                Region { item: win.barShown ? bottomFrameStrip : null }
                Region { item: win.barShown ? leftFrameStrip : null }
                Region { item: win.barShown ? rightFrameStrip : null }
                Region { item: (win.barShown && win.bottomDrawerMode !== "") ? bottomLauncherDrawer : null }
                Region { item: (win.barShown && win.activeStatusPopup !== "") ? statusDropdownDrawer : null }
                Region { item: (win.barShown && win.activeCenterPopup !== "") ? centerDropdownDrawer : null }
                Region { item: (win.barShown && appRoot.osdActive && cornerOsdNotif.height > 1) ? cornerOsdNotif : null }
            }

            IdleInhibitor {
                enabled: appRoot.coffeeActive
                window: win
            }

            Item {
                id: stripRoot
                anchors.fill: parent
                visible: win.barShown

                // ========== UNIFIED SINGLE-PATH FRAME & INTEGRATED DRAWER CANVAS ==========
                Canvas {
                    id: unifiedFrameCanvas
                    anchors.fill: parent
                    antialiasing: true
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    function traceInnerContour(ctx, L, T, R, B, cr) {
                        const W = Math.max(40, R - L);
                        const H = Math.max(40, B - T);

                        const hasStatus = (win.activeStatusPopup !== "" && statusDropdownDrawer.height > 1 && statusDropdownDrawer.width > 1);
                        const sW = hasStatus ? Math.min(statusDropdownDrawer.width, W * 0.65) : 0;
                        const sH = hasStatus ? Math.min(statusDropdownDrawer.height, H * 0.78) : 0;
                        const sL = R - sW;
                        const sBottom = T + sH;

                        const cRawW = centerDropdownDrawer.width;
                        const cRawH = centerDropdownDrawer.height;
                        const hasCenter = (win.activeCenterPopup !== "" && cRawH > 1 && cRawW > 1);
                        let cL = hasCenter ? Math.max(L + 8, centerDropdownDrawer.x) : 0;
                        let cR = hasCenter ? Math.min((hasStatus ? sL - 8 : R - 8), centerDropdownDrawer.x + cRawW) : 0;
                        const cActive = hasCenter && (cR - cL > 24);
                        const cH = cActive ? Math.min(cRawH, H * 0.78) : 0;
                        const cBottom = T + cH;

                        const hasOsd = (cornerOsdNotif.height > 1 && cornerOsdNotif.width > 1);
                        const nW = hasOsd ? Math.min(cornerOsdNotif.width, W * 0.60) : 0;
                        const nH = hasOsd ? Math.min(cornerOsdNotif.height, H * 0.40) : 0;
                        const nL = R - nW;
                        const nTop = B - nH;

                        const bRawW = bottomLauncherDrawer.width;
                        const bRawH = bottomLauncherDrawer.height;
                        const hasBottom = (bRawH > 1 && bRawW > 1);
                        let bL = hasBottom ? Math.max(L + 8, bottomLauncherDrawer.x) : 0;
                        let bR = hasBottom ? Math.min((hasOsd ? nL - 8 : R - 8), bottomLauncherDrawer.x + bRawW) : 0;
                        const bActive = hasBottom && (bR - bL > 24);
                        const bH = bActive ? Math.min(bRawH, H * 0.78) : 0;
                        const bTop = B - bH;

                        const rightGap = Math.max(0, (hasOsd ? nTop : B) - (hasStatus ? sBottom : T));
                        const sr = hasStatus ? Math.min(cr, 18, sW * 0.45, sH * 0.45, ((cActive ? (sL - cR) : (sL - L))) * 0.45, rightGap * 0.45) : 0;
                        const cRad = cActive ? Math.min(cr, 18, (cR - cL) * 0.45, cH * 0.45, (cL - L) * 0.45, ((hasStatus ? sL : R) - cR) * 0.45) : 0;
                        const nr = hasOsd ? Math.min(cr, 18, nW * 0.45, nH * 0.45, rightGap * 0.45, (bActive ? (nL - bR) * 0.45 : (nL - L) * 0.45)) : 0;
                        const br = bActive ? Math.min(cr, 18, (bR - bL) * 0.45, bH * 0.45, (bL - L) * 0.45, ((hasOsd ? nL : R) - bR) * 0.45) : 0;

                        const blR = Math.min(cr, H * 0.45, (bActive ? (bL - L) * 0.45 : (hasOsd ? (nL - L) * 0.45 : W * 0.45)));
                        const brR = Math.min(cr, H * 0.45, W * 0.45, (bActive ? (R - bR) * 0.45 : W * 0.45), (hasStatus ? (B - sBottom) * 0.45 : H * 0.45));
                        const trR = Math.min(cr, W * 0.45, H * 0.45, (hasOsd ? (nTop - T) * 0.45 : H * 0.45), (cActive ? (R - cR) * 0.45 : W * 0.45));
                        const tlR = Math.min(cr, H * 0.45, (cActive ? (cL - L) * 0.45 : (hasStatus ? (sL - L) * 0.45 : W * 0.45)));

                        // Counter-clockwise inner contour starting from left-edge midpoint
                        const midY = (T + B) * 0.5;
                        ctx.moveTo(L, midY);

                        // Bottom-Left inner corner -> moving right along y = B
                        ctx.arcTo(L, B, R, B, blR);

                        // Optional Bottom-Center Launcher / Wallpaper drawer
                        if (bActive) {
                            ctx.arcTo(bL, B, bL, bTop, br);
                            ctx.arcTo(bL, bTop, bR, bTop, br);
                            ctx.arcTo(bR, bTop, bR, B, br);
                            ctx.arcTo(bR, B, R, B, br);
                        }

                        // Optional Bottom-Right OSD / Notification corner -> or standard Bottom-Right corner
                        if (hasOsd) {
                            ctx.arcTo(nL, B, nL, nTop, nr);
                            ctx.arcTo(nL, nTop, R, nTop, nr);
                            ctx.arcTo(R, nTop, R, T, nr);
                        } else {
                            ctx.arcTo(R, B, R, T, brR);
                        }

                        // Optional Top-Right Status dropdown -> or standard Top-Right corner
                        if (hasStatus) {
                            ctx.arcTo(R, sBottom, sL, sBottom, sr);
                            ctx.arcTo(sL, sBottom, sL, T, sr);
                            ctx.arcTo(sL, T, L, T, sr);
                        } else {
                            ctx.arcTo(R, T, L, T, trR);
                        }

                        // Optional Top-Center Weather / Calendar & Capture drawer
                        if (cActive) {
                            ctx.arcTo(cR, T, cR, cBottom, cRad);
                            ctx.arcTo(cR, cBottom, cL, cBottom, cRad);
                            ctx.arcTo(cL, cBottom, cL, T, cRad);
                            ctx.arcTo(cL, T, L, T, cRad);
                        }

                        // Top-Left inner corner -> close back to left-edge midpoint
                        ctx.arcTo(L, T, L, B, tlR);
                        ctx.closePath();
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const W = width;
                        const H = height;
                        if (W < 40 || H < 40)
                            return;

                        const L = win.innerX;
                        const T = win.innerY;
                        const R = win.innerRight;
                        const B = win.innerBottom;
                        const cr = Math.min(win.innerRadius, (R - L) * 0.25, (B - T) * 0.25);

                        // 1. Continuous filled frame + attached drawers (outer CW + inner CCW)
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(W, 0);
                        ctx.lineTo(W, H);
                        ctx.lineTo(0, H);
                        ctx.closePath();
                        traceInnerContour(ctx, L, T, R, B, cr);
                        ctx.fillStyle = appRoot.colFrame;
                        ctx.fill();

                        // 2. Single unified inner hairline / shining border
                        const bw = appRoot.borderLineWidth;
                        if (bw > 0.05) {
                            function makeBorderStroke(alpha) {
                                const p = appRoot.borderPreset;
                                if (p === "rainbow") {
                                    const ang = appRoot.borderAnimPhase * Math.PI * 2;
                                    const cx = W * 0.5;
                                    const cy = H * 0.5;
                                    const rad = Math.hypot(W, H) * 0.5;
                                    const g = ctx.createLinearGradient(
                                        cx - Math.cos(ang) * rad, cy - Math.sin(ang) * rad,
                                        cx + Math.cos(ang) * rad, cy + Math.sin(ang) * rad
                                    );
                                    g.addColorStop(0.00, Qt.rgba(0.54, 0.86, 0.92, alpha)); // cyan
                                    g.addColorStop(0.17, Qt.rgba(0.54, 0.71, 0.98, alpha)); // blue
                                    g.addColorStop(0.33, Qt.rgba(0.80, 0.65, 0.97, alpha)); // violet
                                    g.addColorStop(0.50, Qt.rgba(0.95, 0.55, 0.66, alpha)); // rose
                                    g.addColorStop(0.67, Qt.rgba(0.98, 0.70, 0.53, alpha)); // coral
                                    g.addColorStop(0.83, Qt.rgba(0.98, 0.89, 0.69, alpha)); // amber
                                    g.addColorStop(1.00, Qt.rgba(0.65, 0.89, 0.63, alpha)); // emerald
                                    return g;
                                }
                                if (p === "wallpaper") {
                                    const g = ctx.createLinearGradient(0, 0, W, H);
                                    g.addColorStop(0.0, Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, alpha));
                                    g.addColorStop(1.0, Qt.rgba(appRoot.colAccentAlt.r, appRoot.colAccentAlt.g, appRoot.colAccentAlt.b, alpha));
                                    return g;
                                }
                                const c = appRoot.frameBorderColor;
                                return Qt.rgba(c.r, c.g, c.b, alpha);
                            }

                            ctx.beginPath();
                            traceInnerContour(ctx, L, T, R, B, cr);
                            ctx.lineJoin = "round";
                            ctx.lineCap = "round";
                            ctx.lineWidth = bw + 1.4;
                            ctx.strokeStyle = makeBorderStroke(appRoot.borderGlowFrac);
                            ctx.stroke();

                            ctx.lineWidth = bw;
                            ctx.strokeStyle = makeBorderStroke(appRoot.borderOpacityFrac);
                            ctx.stroke();
                        }
                    }
                }

                // ========== 4 CONNECTED OUTER BORDER STRIPS (TRANSPARENT CONTENT SHELLS) ==========

                // 1. TOP FRAME STRIP (Full-Width Connected Top Bar)
                Rectangle {
                    id: topFrameStrip
                    x: 0
                    y: 0
                    width: stripRoot.width
                    height: win.innerY
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(10, appRoot.dockPadding)
                        anchors.rightMargin: Math.max(10, appRoot.dockPadding)
                        spacing: appRoot.itemSpacing

                        // Left: Launcher icon + 5 Dot Workspaces + Active Window Title
                        Row {
                            id: leftBarRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: appRoot.itemSpacing

                            Item {
                                width: 22
                                height: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰣇"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(4)
                                    color: (win.activeIsland === "search" || launcherIconMouse.containsMouse)
                                        ? appRoot.colAccent
                                        : appRoot.colFg

                                    Behavior on color {
                                        ColorAnimation { duration: 130 }
                                    }
                                }

                                MouseArea {
                                    id: launcherIconMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appRoot.toggleIslandFor(win.monitorName, "search")
                                }
                            }

                            // 5 Minimal Dot Workspaces (no box background)
                            Rectangle {
                                height: 24
                                width: wsDotsRow.implicitWidth + 6
                                color: "transparent"

                                Row {
                                    id: wsDotsRow
                                    anchors.centerIn: parent
                                    spacing: 7

                                    Repeater {
                                        model: [1, 2, 3, 4, 5]
                                        delegate: Item {
                                            required property int modelData
                                            readonly property int wid: modelData
                                            readonly property bool isFocused: win.focusedWsId === wid
                                            readonly property bool isOccupied: win.wsOccupied(wid)

                                            width: dotRect.width + 2
                                            height: 18

                                            Rectangle {
                                                id: dotRect
                                                anchors.centerIn: parent
                                                width: isFocused ? 18 : 7
                                                height: 7
                                                radius: 3.5
                                                color: isFocused ? appRoot.colAccent : (isOccupied ? appRoot.colAccentAlt : appRoot.colMuted)
                                                opacity: isFocused ? 1.0 : (isOccupied ? 0.85 : 0.4)

                                                Behavior on width {
                                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                                }
                                                Behavior on color {
                                                    ColorAnimation { duration: 160 }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Hyprland.dispatch(`hl.dsp.focus({workspace=${wid}})`)
                                            }
                                        }

                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: wheel => {
                                        if (wheel.angleDelta.y > 0)
                                            Hyprland.dispatch('hl.dsp.focus({workspace="e-1"})');
                                        else if (wheel.angleDelta.y < 0)
                                            Hyprland.dispatch('hl.dsp.focus({workspace="e+1"})');
                                    }
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: 14
                                color: appRoot.colLineStrong
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 220)
                                elide: Text.ElideRight
                                text: win.activeTitle
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-1)
                                font.weight: Font.Medium
                                color: appRoot.colDim
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Center: Kanchanpur Weather | Clock / Date | CPU Temperature
                        Row {
                            id: centerClusterRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: appRoot.itemSpacing

                            // Weather for Kanchanpur, Nepal
                            Rectangle {
                                id: weatherCenterBtn
                                readonly property var wx: appRoot.sysInfo.weather || ({ temp: "24°C", desc: "Clear", icon: "󰖙", city: "Kanchanpur" })
                                implicitWidth: weatherCenterRow.implicitWidth + 6
                                width: implicitWidth
                                height: topFrameStrip.height
                                color: "transparent"

                                Row {
                                    id: weatherCenterRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: weatherCenterBtn.wx.icon || "󰖙"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(2)
                                        color: appRoot.colAmber
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (weatherCenterBtn.wx.temp || "24°C") + " Kanchanpur"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.weight: Font.Medium
                                        color: weatherCenterMouse.containsMouse ? appRoot.colAccent : appRoot.colDim
                                    }
                                }

                                MouseArea {
                                    id: weatherCenterMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.openCenterPopup("weather")
                                    onExited: centerPopupCloseTimer.restart()
                                    onClicked: {
                                        if (win.activeCenterPopup === "weather")
                                            win.activeCenterPopup = "";
                                        else
                                            win.openCenterPopup("weather");
                                    }
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: appRoot.sc(12)
                                color: appRoot.colLineStrong
                            }

                            // Clock (shows full day, date, year & AM/PM time; left-click toggles Calendar & Capture panel; right-click toggles compact time)
                            Rectangle {
                                id: centerClockBtn
                                property bool showDate: true
                                property string timeStr: Qt.formatDateTime(new Date(), showDate ? "dddd, MMM d, yyyy • h:mm AP" : "h:mm AP")

                                Timer {
                                    interval: 15000
                                    repeat: true
                                    running: true
                                    onTriggered: centerClockBtn.timeStr = Qt.formatDateTime(new Date(), centerClockBtn.showDate ? "dddd, MMM d, yyyy • h:mm AP" : "h:mm AP")
                                }
                                onShowDateChanged: timeStr = Qt.formatDateTime(new Date(), showDate ? "dddd, MMM d, yyyy • h:mm AP" : "h:mm AP")

                                implicitWidth: clockTxt.implicitWidth + 8
                                width: implicitWidth
                                height: topFrameStrip.height
                                color: "transparent"

                                Text {
                                    id: clockTxt
                                    anchors.centerIn: parent
                                    text: centerClockBtn.timeStr
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(0)
                                    font.weight: Font.DemiBold
                                    color: (clockMouse.containsMouse || win.activeCenterPopup === "calendar") ? appRoot.colAccent : appRoot.colFg

                                    Behavior on color {
                                        ColorAnimation { duration: 130 }
                                    }
                                }

                                MouseArea {
                                    id: clockMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.openCenterPopup("calendar")
                                    onExited: centerPopupCloseTimer.restart()
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            centerClockBtn.showDate = !centerClockBtn.showDate;
                                        } else {
                                            if (win.activeCenterPopup === "calendar")
                                                win.activeCenterPopup = "";
                                            else
                                                win.openCenterPopup("calendar");
                                        }
                                    }
                                }
                            }

                            // Live Recording Pill (visible when screen recording is active)
                            Rectangle {
                                visible: !!appRoot.sysInfo.recording
                                implicitWidth: recRow.implicitWidth + appRoot.sc(10)
                                width: implicitWidth
                                height: appRoot.sc(20)
                                radius: Math.round(height / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(appRoot.colRed.r, appRoot.colRed.g, appRoot.colRed.b, 0.22)
                                border.width: 1
                                border.color: appRoot.colRed

                                Row {
                                    id: recRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰑊"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(-1)
                                        color: appRoot.colRed
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "REC"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-2)
                                        font.bold: true
                                        color: appRoot.colRed
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appRoot.runCaptureAction(appRoot.homeDir + "/.config/hypr/scripts/screenrecord.sh stop")
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: appRoot.sc(12)
                                color: appRoot.colLineStrong
                            }

                            // CPU Temperature (click toggles Left System Monitor)
                            Rectangle {
                                id: cpuTempBarBtn
                                readonly property int tempC: Number(appRoot.sysInfo.cpu_temp !== undefined ? appRoot.sysInfo.cpu_temp : 48)
                                readonly property color tempCol: tempC >= 80 ? appRoot.colRed : (tempC >= 65 ? appRoot.colAmber : appRoot.colGreen)

                                implicitWidth: cpuTempBarRow.implicitWidth + 6
                                width: implicitWidth
                                height: topFrameStrip.height
                                color: "transparent"

                                Row {
                                    id: cpuTempBarRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰔏"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(1)
                                        color: cpuTempBarBtn.tempCol
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cpuTempBarBtn.tempC + "°C"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.weight: Font.Medium
                                        color: cpuTempMouse.containsMouse ? appRoot.colAccent : appRoot.colFg
                                    }
                                }

                                MouseArea {
                                    id: cpuTempMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appRoot.toggleLeftDockFor(win.monitorName)
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Right: Flat background-free Coffee Mode, Wi-Fi, Bluetooth, Volume, and Battery with hover dropdowns
                        Row {
                            id: rightBarRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: appRoot.itemSpacing + 2

                            // Coffee Mode toggle (keeps laptop awake: idle, lock & sleep disabled)
                            Rectangle {
                                id: coffeeBarItem
                                height: topFrameStrip.height
                                width: coffeeBarRow.implicitWidth + 4
                                color: "transparent"
                                border.width: 0

                                Row {
                                    id: coffeeBarRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appRoot.coffeeActive ? "󰅶" : "󰛊"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(2)
                                        color: appRoot.coffeeActive
                                            ? (coffeeBarMouse.containsMouse ? appRoot.colAccent : appRoot.colAmber)
                                            : (coffeeBarMouse.containsMouse ? appRoot.colAccent : appRoot.colMuted)
                                    }
                                    Text {
                                        visible: appRoot.coffeeActive
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Awake"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.bold: true
                                        color: coffeeBarMouse.containsMouse ? appRoot.colAccent : appRoot.colAmber
                                    }
                                }

                                MouseArea {
                                    id: coffeeBarMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appRoot.setCoffeeMode("toggle")
                                }
                            }

                            // Do Not Disturb toggle
                            Rectangle {
                                id: dndBarItem
                                height: topFrameStrip.height
                                width: dndBarRow.implicitWidth + 4
                                color: "transparent"
                                border.width: 0

                                Row {
                                    id: dndBarRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appRoot.dndActive ? "󰂛" : "󰂚"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(2)
                                        color: appRoot.dndActive
                                            ? (dndBarMouse.containsMouse ? appRoot.colAccent : appRoot.colRed)
                                            : (dndBarMouse.containsMouse ? appRoot.colAccent : appRoot.colMuted)
                                    }
                                    Text {
                                        visible: appRoot.dndActive
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "DND"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.bold: true
                                        color: dndBarMouse.containsMouse ? appRoot.colAccent : appRoot.colRed
                                    }
                                }

                                MouseArea {
                                    id: dndBarMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appRoot.toggleDnd()
                                }
                            }

                            // Wi-Fi status (no background; hover opens network switcher)
                            Rectangle {
                                id: wifiBarItem
                                height: topFrameStrip.height
                                width: wifiRow.implicitWidth + 4
                                color: "transparent"

                                Row {
                                    id: wifiRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appRoot.sysInfo.wifi_on ? "󰤨" : "󰤭"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(2)
                                        color: appRoot.sysInfo.wifi_on ? appRoot.colAccent : appRoot.colRed
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 92)
                                        elide: Text.ElideRight
                                        text: appRoot.sysInfo.wifi_ssid || (appRoot.sysInfo.wifi_on ? "On" : "Off")
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: (wifiMouse.containsMouse || win.activeStatusPopup === "wifi") ? appRoot.colAccent : appRoot.colFg
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: appRoot.colAccent
                                    visible: win.activeStatusPopup === "wifi"
                                }

                                MouseArea {
                                    id: wifiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.openStatusPopup("wifi")
                                    onExited: statusPopupCloseTimer.restart()
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton)
                                            Quickshell.execDetached(["nm-connection-editor"]);
                                        else
                                            appRoot.runStatusAction(["--wifi-toggle", appRoot.sysInfo.wifi_on ? "off" : "on"]);
                                    }
                                }
                            }

                            // Bluetooth icon (no background; hover opens device switcher)
                            Item {
                                id: btBarItem
                                width: 22
                                height: topFrameStrip.height

                                Text {
                                    anchors.centerIn: parent
                                    text: appRoot.sysInfo.bt_on ? "󰂯" : "󰂲"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(2)
                                    color: (btIconMouse.containsMouse || win.activeStatusPopup === "bt")
                                        ? appRoot.colAccent
                                        : (appRoot.sysInfo.bt_on ? appRoot.colAccentAlt : appRoot.colMuted)
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: appRoot.colAccent
                                    visible: win.activeStatusPopup === "bt"
                                }

                                MouseArea {
                                    id: btIconMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.openStatusPopup("bt")
                                    onExited: statusPopupCloseTimer.restart()
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton)
                                            Quickshell.execDetached(["blueman-manager"]);
                                        else
                                            appRoot.runStatusAction(["--bt-toggle", appRoot.sysInfo.bt_on ? "off" : "on"]);
                                    }
                                }
                            }

                            // Volume indicator (no background; hover opens Output + Input audio panel)
                            Rectangle {
                                id: volBarItem
                                height: topFrameStrip.height
                                width: volRow.implicitWidth + 4
                                color: "transparent"

                                Row {
                                    id: volRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appRoot.sysInfo.muted ? "󰖁" : "󰕾"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(2)
                                        color: appRoot.sysInfo.muted ? appRoot.colRed : ((volMouse.containsMouse || win.activeStatusPopup === "audio") ? appRoot.colAccent : appRoot.colFg)
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (appRoot.sysInfo.vol ?? 0) + "%"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: (volMouse.containsMouse || win.activeStatusPopup === "audio") ? appRoot.colFg : appRoot.colDim
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: appRoot.colAccent
                                    visible: win.activeStatusPopup === "audio"
                                }

                                MouseArea {
                                    id: volMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.openStatusPopup("audio")
                                    onExited: statusPopupCloseTimer.restart()
                                    onClicked: {
                                        appRoot.runStatusAction(["--mute-toggle"]);
                                    }
                                    onWheel: wheel => {
                                        const curVol = Number(appRoot.sysInfo.vol || 0);
                                        const delta = wheel.angleDelta.y > 0 ? 5 : (wheel.angleDelta.y < 0 ? -5 : 0);
                                        if (delta !== 0) {
                                            const nextVol = Math.max(0, Math.min(100, curVol + delta));
                                            appRoot.setSinkVolume(nextVol);
                                            const muted = !!appRoot.sysInfo.muted;
                                            appRoot.showValueOsd("volume", muted ? "󰖁" : "󰕾", "Volume", nextVol, muted ? "Muted" : (nextVol + "%"));
                                        }
                                    }
                                }
                            }

                            // Battery indicator (no background; hover opens power profile switcher)
                            Rectangle {
                                id: batBarItem
                                height: topFrameStrip.height
                                width: batRow.implicitWidth + 4
                                color: "transparent"

                                Row {
                                    id: batRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (appRoot.sysInfo.bat_status === "Charging") ? "󰂄" : "󰁹"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(1)
                                        color: (appRoot.sysInfo.bat <= 20 && appRoot.sysInfo.bat_status !== "Charging")
                                            ? appRoot.colRed
                                            : ((batMouse.containsMouse || win.activeStatusPopup === "battery") ? appRoot.colAccent : appRoot.colGreen)
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (appRoot.sysInfo.bat ?? 100) + "%"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: (batMouse.containsMouse || win.activeStatusPopup === "battery") ? appRoot.colFg : appRoot.colDim
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: appRoot.colAccent
                                    visible: win.activeStatusPopup === "battery"
                                }

                                MouseArea {
                                    id: batMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.openStatusPopup("battery")
                                    onExited: statusPopupCloseTimer.restart()
                                    onClicked: {
                                        const modes = ["power-saver", "balanced", "performance"];
                                        const curIdx = modes.indexOf(appRoot.sysInfo.power_profile || "balanced");
                                        const nextMode = modes[(curIdx + 1) % modes.length];
                                        appRoot.runStatusAction(["--set-power", nextMode]);
                                    }
                                }
                            }
                        }
                    }

                    Timer {
                        id: sysRefreshDelay
                        interval: 150
                        repeat: false
                        onTriggered: appRoot.refreshSysStat()
                    }

                    Timer {
                        id: statusPopupCloseTimer
                        interval: 300
                        repeat: false
                        onTriggered: {
                            if (!wifiMouse.containsMouse
                                && !btIconMouse.containsMouse
                                && !volMouse.containsMouse
                                && !batMouse.containsMouse
                                && !statusDrawerHover.hovered
                                && appRoot.wifiPasswordTarget === "") {
                                win.activeStatusPopup = "";
                            }
                        }
                    }

                    Timer {
                        id: centerPopupCloseTimer
                        interval: 300
                        repeat: false
                        onTriggered: {
                            if (!weatherCenterMouse.containsMouse
                                && !clockMouse.containsMouse
                                && !centerDrawerHover.hovered) {
                                win.activeCenterPopup = "";
                            }
                        }
                    }
                } // topFrameStrip

                // 2. LEFT FRAME STRIP (frameThicknessCfg Border -> Extends to 330px on Hover or Super+L)
                Rectangle {
                    id: leftFrameStrip
                    x: 0
                    y: win.innerY
                    width: win.innerX
                    height: win.innerH
                    color: "transparent"
                    clip: true

                    HoverHandler {
                        id: leftHover
                        onHoveredChanged: {
                            if (hovered) {
                                leftAutoHideTimer.stop();
                                if (!win.leftDockOpen)
                                    leftOpenDelayTimer.restart();
                            } else {
                                leftOpenDelayTimer.stop();
                                if (win.leftDockOpen && !win.leftDockPinned)
                                    leftAutoHideTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: leftOpenDelayTimer
                        interval: 140
                        repeat: false
                        onTriggered: {
                            if (leftHover.hovered)
                                appRoot.setLeftDockFor(win.monitorName, true);
                        }
                    }

                    Timer {
                        id: leftAutoHideTimer
                        interval: 450
                        repeat: false
                        onTriggered: {
                            if (win.leftDockOpen && !win.leftDockPinned && !leftHover.hovered)
                                appRoot.setLeftDockFor(win.monitorName, false);
                        }
                    }

                    // Click collapsed thin border to open immediately
                    MouseArea {
                        anchors.fill: parent
                        enabled: !win.leftDockOpen
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appRoot.setLeftDockFor(win.monitorName, true)
                    }

                    // Telemetry Graph Content sliding smoothly inside Left Border
                    Item {
                        id: leftDockContent
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: appRoot.dockPadding
                        width: Math.max(200, win.leftOpenWidth - appRoot.dockPadding * 2)
                        visible: win.leftExtent > 40
                        opacity: Math.max(0, Math.min(1, (win.leftExtent - 120) / 180))

                        Flickable {
                            id: leftDockFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: leftDockCol.implicitHeight + 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: leftDockCol
                                width: leftDockFlick.width
                                spacing: appRoot.itemSpacing + 2

                                // Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: appRoot.itemSpacing
                                    Text {
                                        text: "System Monitor"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(3)
                                        font.bold: true
                                        color: appRoot.colFg
                                    }
                                    Rectangle {
                                        width: liveTxt.implicitWidth + appRoot.sc(12)
                                        height: liveTxt.implicitHeight + appRoot.sc(6)
                                        radius: Math.round(height / 2)
                                        color: "transparent"
                                        border.width: 0
                                        Text {
                                            id: liveTxt
                                            anchors.centerIn: parent
                                            text: "live"
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-2)
                                            font.weight: Font.Medium
                                            color: appRoot.colGreen
                                        }
                                    }
                                    Item { Layout.fillWidth: true }

                                    PillIconBtn {
                                        iconText: win.leftDockPinned ? "󰐃" : "󰤱"
                                        active: win.leftDockPinned
                                        onClicked: win.leftDockPinned = !win.leftDockPinned
                                    }
                                    PillIconBtn {
                                        iconText: "✕"
                                        iconPixelSize: appRoot.fs(-1)
                                        onClicked: appRoot.setLeftDockFor(win.monitorName, false)
                                    }
                                }

                                // GitHub Account Card (tek-sys-hub)
                                Rectangle {
                                    id: githubCard
                                    readonly property var gh: appRoot.sysInfo.github || ({
                                        login: "tek-sys-hub",
                                        name: "Tek Raj Awasthi",
                                        bio: "",
                                        public_repos: 24,
                                        followers: 38,
                                        following: 37,
                                        stars: 60,
                                        html_url: "https://github.com/tek-sys-hub",
                                        avatar: ""
                                    })

                                    Layout.fillWidth: true
                                    implicitHeight: ghCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: ghCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(6)

                                            Text {
                                                text: "󰊤"
                                                font.family: appRoot.iconFont
                                                font.pixelSize: appRoot.fs(2)
                                                color: appRoot.colAccent
                                            }
                                            Text {
                                                text: "GITHUB • @" + (githubCard.gh.login || "tek-sys-hub")
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                font.bold: true
                                                color: appRoot.colDim
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            PillIconBtn {
                                                iconText: appRoot.leftActionBusy ? "..." : "󰑐"
                                                btnWidth: appRoot.sc(24)
                                                btnHeight: appRoot.sc(22)
                                                iconPixelSize: appRoot.fs(-1)
                                                onClicked: appRoot.refreshGithubProfile()
                                            }
                                            PillIconBtn {
                                                iconText: "󰏌"
                                                btnWidth: appRoot.sc(24)
                                                btnHeight: appRoot.sc(22)
                                                iconPixelSize: appRoot.fs(-1)
                                                onClicked: Quickshell.execDetached(["xdg-open", String(githubCard.gh.html_url || "https://github.com/tek-sys-hub")])
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(10)

                                            Rectangle {
                                                width: appRoot.sc(44)
                                                height: appRoot.sc(44)
                                                radius: appRoot.sc(10)
                                                color: "transparent"
                                                border.width: 0
                                                clip: true

                                                Image {
                                                    id: ghAvatarImg
                                                    anchors.fill: parent
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    sourceSize: Qt.size(96, 96)
                                                    source: githubCard.gh.avatar ? ("file://" + githubCard.gh.avatar) : ""
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: ghAvatarImg.status !== Image.Ready
                                                    text: "󰊤"
                                                    font.family: appRoot.iconFont
                                                    font.pixelSize: appRoot.fs(6)
                                                    color: appRoot.colAccent
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    text: githubCard.gh.name || "Tek Raj Awasthi"
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(1)
                                                    font.bold: true
                                                    color: appRoot.colFg
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: githubCard.gh.bio || ""
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-2)
                                                    color: appRoot.colDim
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(6)

                                            Repeater {
                                                model: [
                                                    { label: "Repos", val: Number(githubCard.gh.public_repos || 0), tint: appRoot.colAccent },
                                                    { label: "Stars", val: Number(githubCard.gh.stars || 0), tint: appRoot.colAmber },
                                                    { label: "Followers", val: Number(githubCard.gh.followers || 0), tint: appRoot.colGreen },
                                                    { label: "Following", val: Number(githubCard.gh.following || 0), tint: appRoot.colAccentAlt }
                                                ]
                                                delegate: Rectangle {
                                                    id: ghStatTile
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    height: Math.max(appRoot.sc(42), ghStatCol.implicitHeight + appRoot.sc(10))
                                                    radius: appRoot.sc(8)
                                                    color: "transparent"
                                                    border.width: 0

                                                    Column {
                                                        id: ghStatCol
                                                        anchors.centerIn: parent
                                                        spacing: 1
                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: String(ghStatTile.modelData.val)
                                                            font.family: appRoot.fontFamily
                                                            font.pixelSize: appRoot.fs(0)
                                                            font.bold: true
                                                            color: ghStatTile.modelData.tint
                                                        }
                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: ghStatTile.modelData.label
                                                            font.family: appRoot.fontFamily
                                                            font.pixelSize: appRoot.fs(-3)
                                                            color: appRoot.colMuted
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // GitHub Contribution Graph (22 weeks x 7 days)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(5)
                                            visible: Array.isArray(githubCard.gh.contrib_levels) && githubCard.gh.contrib_levels.length > 0

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "CONTRIBUTIONS"
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-2)
                                                    font.bold: true
                                                    color: appRoot.colMuted
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: githubCard.gh.contrib_total ? (githubCard.gh.contrib_total + " in last year") : ""
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-2)
                                                    color: appRoot.colDim
                                                }
                                            }

                                            Flickable {
                                                id: ghContribFlick
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ghContribCanvas.gridH
                                                clip: true
                                                flickableDirection: Flickable.HorizontalFlick
                                                boundsBehavior: Flickable.StopAtBounds
                                                contentWidth: Math.max(width, ghContribCanvas.gridW)
                                                contentHeight: ghContribCanvas.gridH

                                                function scrollToLatest() {
                                                    if (contentWidth > width)
                                                        contentX = contentWidth - width;
                                                }
                                                Component.onCompleted: scrollToLatest()
                                                onContentWidthChanged: scrollToLatest()
                                                onWidthChanged: scrollToLatest()

                                                MouseArea {
                                                    anchors.fill: parent
                                                    acceptedButtons: Qt.NoButton
                                                    onWheel: wheel => {
                                                        const delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
                                                        if (delta !== 0 && ghContribFlick.contentWidth > ghContribFlick.width) {
                                                            ghContribFlick.contentX = Math.max(
                                                                0,
                                                                Math.min(
                                                                    ghContribFlick.contentWidth - ghContribFlick.width,
                                                                    ghContribFlick.contentX - delta * 0.6
                                                                )
                                                            );
                                                            wheel.accepted = true;
                                                        }
                                                    }
                                                }

                                                Canvas {
                                                    id: ghContribCanvas
                                                    readonly property var levels: Array.isArray(githubCard.gh.contrib_levels) ? githubCard.gh.contrib_levels : []
                                                    readonly property int rows: 7
                                                    readonly property int cols: Math.max(1, Math.ceil(levels.length / rows))
                                                    readonly property real cell: Math.max(7, Math.round(appRoot.sc(9)))
                                                    readonly property real gap: Math.max(2, Math.round(appRoot.sc(2)))
                                                    readonly property real gridW: cols * cell + (cols - 1) * gap
                                                    readonly property real gridH: rows * cell + (rows - 1) * gap
                                                    width: Math.max(ghContribFlick.width, gridW)
                                                    height: gridH
                                                    onLevelsChanged: requestPaint()
                                                    onWidthChanged: requestPaint()
                                                    onHeightChanged: requestPaint()

                                                    Connections {
                                                        target: appRoot
                                                        function onColAccentChanged() { ghContribCanvas.requestPaint(); }
                                                        function onColSurfaceChanged() { ghContribCanvas.requestPaint(); }
                                                    }

                                                    onPaint: {
                                                        const ctx = getContext("2d");
                                                        ctx.clearRect(0, 0, width, height);
                                                        const data = levels;
                                                        if (!data || data.length === 0 || width <= 20 || height <= 20)
                                                            return;

                                                        const startX = Math.max(0, Math.round((width - gridW) / 2));
                                                        const rad = Math.max(2, Math.round(cell * 0.22));
                                                        const sf = appRoot.colSurface;

                                                        for (let i = 0; i < data.length; i++) {
                                                            const c = Math.floor(i / rows);
                                                            const r = i % rows;
                                                            const x = startX + c * (cell + gap);
                                                            const y = r * (cell + gap);
                                                            const lv = Number(data[i] || 0);

                                                            if (lv <= 0) {
                                                                ctx.fillStyle = Qt.rgba(sf.r, sf.g, sf.b, 0.72);
                                                            } else if (lv === 1) {
                                                                ctx.fillStyle = "#0e4429";
                                                            } else if (lv === 2) {
                                                                ctx.fillStyle = "#006d32";
                                                            } else if (lv === 3) {
                                                                ctx.fillStyle = "#26a641";
                                                            } else {
                                                                ctx.fillStyle = "#39d353";
                                                            }

                                                            ctx.beginPath();
                                                            ctx.roundedRect(x, y, cell, cell, rad, rad);
                                                            ctx.fill();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // CPU Load Smooth Area-Line Graph Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: cpuCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: cpuCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "CPU LOAD"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: (appRoot.sysInfo.cpu_temp !== undefined ? appRoot.sysInfo.cpu_temp : 48) + "°C • " + (appRoot.sysInfo.cpu ?? 0) + "%"
                                                font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(0); font.bold: true; color: appRoot.colAccent
                                            }
                                        }

                                        AreaLineGraph {
                                            Layout.fillWidth: true
                                            samples: appRoot.cpuHistory
                                            lineColor: appRoot.colAccent
                                        }
                                    }
                                }

                                // RAM / Memory Smooth Area-Line Graph Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: ramCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: ramCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "RAM / MEMORY"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: (appRoot.sysInfo.ram_used || "0G") + " / " + (appRoot.sysInfo.ram_total || "0G") + " (" + (appRoot.sysInfo.ram_pct ?? 0) + "%)"
                                                font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colGreen
                                            }
                                        }

                                        AreaLineGraph {
                                            Layout.fillWidth: true
                                            samples: appRoot.ramHistory
                                            lineColor: appRoot.colGreen
                                        }
                                    }
                                }

                                // Power & Session Icon Buttons (Lock, Suspend, Logout, Restart, Shutdown, Reload)
                                Item {
                                    id: leftPwrWrap
                                    Layout.fillWidth: true
                                    implicitHeight: leftPwrRow.implicitHeight
                                    property string hoveredLabel: ""
                                    property bool hoveredDanger: false
                                    property real hoveredCenterX: 0

                                    RowLayout {
                                        id: leftPwrRow
                                        width: parent.width
                                        spacing: appRoot.sc(6)

                                        Repeater {
                                            model: [
                                                { id: "lock", icon: "󰌾", label: "Lock", danger: false },
                                                { id: "suspend", icon: "󰤄", label: "Suspend", danger: false },
                                                { id: "logout", icon: "󰍃", label: "Logout", danger: false },
                                                { id: "restart", icon: "󰜉", label: "Restart", danger: false },
                                                { id: "shutdown", icon: "󰐥", label: "Shutdown", danger: true },
                                                { id: "reload", icon: "󰑓", label: "Reload", danger: false }
                                            ]
                                            delegate: Rectangle {
                                                id: leftPwrBtn
                                                required property var modelData
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: width
                                                height: width
                                                radius: appRoot.sc(8)
                                                color: leftPwrMouse.containsMouse
                                                    ? (leftPwrBtn.modelData.danger
                                                        ? Qt.rgba(appRoot.colRed.r, appRoot.colRed.g, appRoot.colRed.b, 0.22)
                                                        : appRoot.colSurfaceHover)
                                                    : appRoot.colSurface
                                                border.width: leftPwrMouse.containsMouse ? 1 : 0
                                                border.color: leftPwrBtn.modelData.danger ? appRoot.colRed : appRoot.colAccent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: leftPwrBtn.modelData.icon
                                                    font.family: appRoot.iconFont
                                                    font.pixelSize: appRoot.fs(3)
                                                    color: leftPwrBtn.modelData.danger
                                                        ? appRoot.colRed
                                                        : (leftPwrMouse.containsMouse ? appRoot.colAccent : appRoot.colFg)
                                                }

                                                MouseArea {
                                                    id: leftPwrMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: {
                                                        leftPwrWrap.hoveredLabel = leftPwrBtn.modelData.label;
                                                        leftPwrWrap.hoveredDanger = leftPwrBtn.modelData.danger;
                                                        leftPwrWrap.hoveredCenterX = leftPwrBtn.x + leftPwrBtn.width * 0.5;
                                                    }
                                                    onExited: {
                                                        if (leftPwrWrap.hoveredLabel === leftPwrBtn.modelData.label)
                                                            leftPwrWrap.hoveredLabel = "";
                                                    }
                                                    onClicked: {
                                                        const act = leftPwrBtn.modelData.id;
                                                        appRoot.setLeftDockFor(win.monitorName, false);
                                                        if (act === "lock") {
                                                            appRoot.activateLock();
                                                        } else if (act === "suspend") {
                                                            Quickshell.execDetached(["systemctl", "suspend"]);
                                                        } else if (act === "logout") {
                                                            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
                                                        } else if (act === "restart") {
                                                            Quickshell.execDetached(["systemctl", "reboot"]);
                                                        } else if (act === "shutdown") {
                                                            Quickshell.execDetached(["systemctl", "poweroff"]);
                                                        } else if (act === "reload") {
                                                            Quickshell.execDetached(["hyprctl", "reload"]);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Floating hover tooltip pill
                                    Rectangle {
                                        z: 20
                                        visible: opacity > 0.01
                                        opacity: leftPwrWrap.hoveredLabel !== "" ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 110 } }
                                        width: leftPwrTipTxt.implicitWidth + appRoot.sc(14)
                                        height: appRoot.sc(22)
                                        radius: Math.round(height / 2)
                                        x: Math.max(0, Math.min(leftPwrWrap.width - width, leftPwrWrap.hoveredCenterX - width * 0.5))
                                        y: -height - appRoot.sc(5)
                                        color: appRoot.colBg
                                        border.width: 1
                                        border.color: leftPwrWrap.hoveredDanger ? appRoot.colRed : appRoot.colAccent

                                        Text {
                                            id: leftPwrTipTxt
                                            anchors.centerIn: parent
                                            text: leftPwrWrap.hoveredLabel
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-2)
                                            font.bold: true
                                            color: leftPwrWrap.hoveredDanger ? appRoot.colRed : appRoot.colFg
                                        }
                                    }
                                }

                                // Running Tasks Card (Live Processes + Kill)
                                Rectangle {
                                    id: runningTasksCard
                                    readonly property var taskRows: win.leftDockOpen ? appRoot.sortedTasks() : []

                                    Layout.fillWidth: true
                                    implicitHeight: tasksCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: tasksCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(6)

                                            Text {
                                                text: "RUNNING TASKS"
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                font.bold: true
                                                color: appRoot.colDim
                                            }

                                            Rectangle {
                                                width: taskCountTxt.implicitWidth + appRoot.sc(10)
                                                height: taskCountTxt.implicitHeight + appRoot.sc(4)
                                                radius: Math.round(height / 2)
                                                color: "transparent"
                                                border.width: 0
                                                Text {
                                                    id: taskCountTxt
                                                    anchors.centerIn: parent
                                                    text: String(runningTasksCard.taskRows.length)
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-2)
                                                    font.bold: true
                                                    color: appRoot.colAccent
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Repeater {
                                                model: [
                                                    { id: "cpu", label: "CPU" },
                                                    { id: "ram", label: "RAM" }
                                                ]
                                                delegate: Rectangle {
                                                    id: taskSortChip
                                                    required property var modelData
                                                    readonly property bool active: appRoot.taskSortBy === modelData.id
                                                    width: sortChipTxt.implicitWidth + appRoot.sc(12)
                                                    height: Math.max(appRoot.sc(22), sortChipTxt.implicitHeight + appRoot.sc(6))
                                                    radius: appRoot.sc(6)
                                                    color: "transparent"
                                                    border.width: 0

                                                    Text {
                                                        id: sortChipTxt
                                                        anchors.centerIn: parent
                                                        text: taskSortChip.modelData.label
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-2)
                                                        font.bold: taskSortChip.active
                                                        color: taskSortChip.active ? appRoot.colAccent : (sortChipMouse.containsMouse ? appRoot.colFg : appRoot.colMuted)
                                                    }

                                                    MouseArea {
                                                        id: sortChipMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: appRoot.taskSortBy = taskSortChip.modelData.id
                                                    }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(5)

                                            Repeater {
                                                model: runningTasksCard.taskRows
                                                delegate: Rectangle {
                                                    id: taskRowCard
                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    height: Math.max(appRoot.sc(40), taskRowInner.implicitHeight + appRoot.sc(10))
                                                    radius: appRoot.sc(8)
                                                    color: "transparent"
                                                    border.width: 0

                                                    RowLayout {
                                                        id: taskRowInner
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.leftMargin: appRoot.sc(4)
                                                        anchors.rightMargin: appRoot.sc(4)
                                                        spacing: appRoot.sc(8)

                                                        Column {
                                                            Layout.fillWidth: true
                                                            spacing: 1
                                                            Text {
                                                                width: parent.width
                                                                elide: Text.ElideRight
                                                                text: taskRowCard.modelData.name || "task"
                                                                font.family: appRoot.fontFamily
                                                                font.pixelSize: appRoot.fs(0)
                                                                font.bold: true
                                                                color: appRoot.colFg
                                                            }
                                                            Text {
                                                                width: parent.width
                                                                elide: Text.ElideRight
                                                                text: "PID " + (taskRowCard.modelData.pid || 0)
                                                                    + " • " + Number(taskRowCard.modelData.cpu || 0).toFixed(1) + "%"
                                                                    + " • " + (taskRowCard.modelData.mem || "0M")
                                                                font.family: appRoot.fontFamily
                                                                font.pixelSize: appRoot.fs(-2)
                                                                color: appRoot.colDim
                                                            }
                                                        }

                                                        Rectangle {
                                                            width: killBtnTxt.implicitWidth + appRoot.sc(12)
                                                            height: Math.max(appRoot.sc(24), killBtnTxt.implicitHeight + appRoot.sc(8))
                                                            radius: appRoot.sc(6)
                                                            color: "transparent"
                                                            border.width: 0

                                                            Text {
                                                                id: killBtnTxt
                                                                anchors.centerIn: parent
                                                                text: "󰅖 Kill"
                                                                font.family: appRoot.iconFont
                                                                font.pixelSize: appRoot.fs(-2)
                                                                font.bold: true
                                                                color: taskKillMouse.containsMouse ? appRoot.colFg : appRoot.colRed
                                                            }

                                                            MouseArea {
                                                                id: taskKillMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: appRoot.killUserTask(taskRowCard.modelData.pid, taskRowCard.modelData.name)
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                visible: runningTasksCard.taskRows.length === 0
                                                horizontalAlignment: Text.AlignHCenter
                                                text: "No active user tasks"
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                color: appRoot.colMuted
                                                topPadding: appRoot.sc(8)
                                                bottomPadding: appRoot.sc(8)
                                            }
                                        }

                                    }
                                }

                                // Root Disk & Hardware Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: hwCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: hwCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(10)

                                        Text { text: "ROOT DISK & HARDWARE"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Root Storage (/)"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(0); color: appRoot.colFg }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: (appRoot.sysInfo.disk_used || "0G") + " / " + (appRoot.sysInfo.disk_total || "0G") + " (" + (appRoot.sysInfo.disk_pct ?? 0) + "%)"
                                                    font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); color: appRoot.colAmber
                                                }
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true; height: appRoot.sc(5); radius: Math.max(2, Math.round(height / 2)); color: appRoot.colLineStrong
                                                Rectangle {
                                                    width: parent.width * Math.max(0, Math.min(1, (appRoot.sysInfo.disk_pct ?? 0) / 100))
                                                    height: parent.height; radius: parent.radius; color: appRoot.colAmber
                                                    Behavior on width { NumberAnimation { duration: 250 } }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: Math.max(appRoot.sc(46), batStatCol.implicitHeight + appRoot.sc(14))
                                                radius: appRoot.sc(9)
                                                color: "transparent"
                                                border.width: 0
                                                Column {
                                                    id: batStatCol
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: (appRoot.sysInfo.bat ?? 100) + "%"
                                                        font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(0); font.bold: true; color: appRoot.colGreen
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: appRoot.sysInfo.bat_status || "AC"
                                                        font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-2); color: appRoot.colDim
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: Math.max(appRoot.sc(46), audStatCol.implicitHeight + appRoot.sc(14))
                                                radius: appRoot.sc(9)
                                                color: "transparent"
                                                border.width: 0
                                                Column {
                                                    id: audStatCol
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: appRoot.sysInfo.muted ? "Muted" : ((appRoot.sysInfo.vol ?? 0) + "%")
                                                        font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(0); font.bold: true; color: appRoot.sysInfo.muted ? appRoot.colRed : appRoot.colAccent
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "Audio"
                                                        font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-2); color: appRoot.colDim
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: Math.max(appRoot.sc(46), netStatCol.implicitHeight + appRoot.sc(14))
                                                radius: appRoot.sc(9)
                                                color: "transparent"
                                                border.width: 0
                                                Column {
                                                    id: netStatCol
                                                    anchors.centerIn: parent
                                                    width: parent.width - 10
                                                    spacing: 2
                                                    Text {
                                                        width: parent.width
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        text: appRoot.sysInfo.wifi_on ? (appRoot.sysInfo.wifi_ssid || "Wi-Fi") : "Offline"
                                                        font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.sysInfo.wifi_on ? appRoot.colFg : appRoot.colRed
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "Network"
                                                        font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-2); color: appRoot.colDim
                                                    }
                                                }
                                            }
                                        }

                                    }
                                }

                            }
                        }
                    }
                } // leftFrameStrip

                // 3. RIGHT FRAME STRIP (frameThicknessCfg Border -> Extends to 356px on Hover or Super+R)
                Rectangle {
                    id: rightFrameStrip
                    x: win.innerRight
                    y: win.innerY
                    width: stripRoot.width - win.innerRight
                    height: win.innerH
                    color: "transparent"
                    clip: true

                    HoverHandler {
                        id: rightHover
                        onHoveredChanged: {
                            if (hovered) {
                                rightAutoHideTimer.stop();
                                if (!win.rightDockOpen)
                                    rightOpenDelayTimer.restart();
                            } else {
                                rightOpenDelayTimer.stop();
                                if (win.rightDockOpen && !win.rightDockPinned)
                                    rightAutoHideTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: rightOpenDelayTimer
                        interval: 140
                        repeat: false
                        onTriggered: {
                            if (rightHover.hovered)
                                appRoot.setRightDockFor(win.monitorName, true);
                        }
                    }

                    Timer {
                        id: rightAutoHideTimer
                        interval: 450
                        repeat: false
                        onTriggered: {
                            if (win.rightDockOpen && !win.rightDockPinned && !rightHover.hovered)
                                appRoot.setRightDockFor(win.monitorName, false);
                        }
                    }

                    // Click collapsed thin border to open immediately
                    MouseArea {
                        anchors.fill: parent
                        enabled: !win.rightDockOpen
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appRoot.setRightDockFor(win.monitorName, true)
                    }

                    // Rice Studio Content sliding smoothly inside Right Border
                    Item {
                        id: rightDockContent
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: appRoot.dockPadding
                        width: Math.max(220, win.rightOpenWidth - appRoot.dockPadding * 2)
                        visible: win.rightExtent > 40
                        opacity: Math.max(0, Math.min(1, (win.rightExtent - 120) / 180))

                        Flickable {
                            id: rightDockFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: rightDockCol.implicitHeight + 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: rightDockCol
                                width: rightDockFlick.width
                                spacing: appRoot.itemSpacing + 6

                                // Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: appRoot.itemSpacing
                                    Text {
                                        text: "Rice Studio"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(3)
                                        font.bold: true
                                        color: appRoot.colFg
                                    }
                                    Rectangle {
                                        width: hyprBadgeTxt.implicitWidth + appRoot.sc(12)
                                        height: hyprBadgeTxt.implicitHeight + appRoot.sc(6)
                                        radius: Math.round(height / 2)
                                        color: "transparent"
                                        border.width: 0
                                        Text {
                                            id: hyprBadgeTxt
                                            anchors.centerIn: parent
                                            text: (appRoot.hyprConfig.theme_mode || "wallpaper") === "wallpaper" ? "matugen" : (appRoot.hyprConfig.theme_mode || "theme")
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-2)
                                            color: appRoot.colAccent
                                        }
                                    }
                                    Item { Layout.fillWidth: true }

                                    PillIconBtn {
                                        iconText: "󰁯"
                                        iconColor: appRoot.colDim
                                        onClicked: appRoot.runHyprAction(["--reset"])
                                    }
                                    PillIconBtn {
                                        iconText: win.rightDockPinned ? "󰐃" : "󰤱"
                                        active: win.rightDockPinned
                                        onClicked: win.rightDockPinned = !win.rightDockPinned
                                    }
                                    PillIconBtn {
                                        iconText: "✕"
                                        iconPixelSize: appRoot.fs(-1)
                                        onClicked: appRoot.setRightDockFor(win.monitorName, false)
                                    }
                                }

                                // Classified Option Menu
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: appRoot.sc(6)

                                    Repeater {
                                        model: [
                                            { id: "theme",   icon: "󰸉", label: "Theme" },
                                            { id: "bar",     icon: "󰕮", label: "Bar" },
                                            { id: "border",  icon: "󰦨", label: "Border" },
                                            { id: "windows", icon: "󰖲", label: "Win" },
                                            { id: "keybinds",icon: "󰌌", label: "Keys" }
                                        ]
                                        delegate: Rectangle {
                                            id: rightMenuTab
                                            required property var modelData
                                            readonly property bool sel: appRoot.rightMenuSection === modelData.id

                                            Layout.fillWidth: true
                                            height: appRoot.sc(32)
                                            color: "transparent"
                                            border.width: 0

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: appRoot.sc(4)
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: rightMenuTab.modelData.icon
                                                    font.family: appRoot.iconFont
                                                    font.pixelSize: appRoot.fs(0)
                                                    color: rightMenuTab.sel ? appRoot.colAccent : (rmtMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: rightMenuTab.modelData.label
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-2)
                                                    font.bold: rightMenuTab.sel
                                                    color: rightMenuTab.sel ? appRoot.colAccent : (rmtMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                }
                                            }

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: parent.width * 0.72
                                                height: 2
                                                radius: 1
                                                color: appRoot.colAccent
                                                visible: rightMenuTab.sel
                                            }

                                            MouseArea {
                                                id: rmtMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appRoot.rightMenuSection = rightMenuTab.modelData.id
                                            }
                                        }

                                    }
                                }

                                // 1. Theme & Wallpaper Palette Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "theme"
                                    Layout.fillWidth: true
                                    implicitHeight: themeCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: themeCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "THEME & PALETTE"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                visible: (appRoot.hyprConfig.theme_mode || "wallpaper") === "wallpaper"
                                                height: refreshPalTxt.implicitHeight + appRoot.sc(6)
                                                width: refreshPalTxt.implicitWidth + appRoot.sc(12)
                                                radius: appRoot.sc(6)
                                                color: "transparent"
                                                border.width: 0
                                                Text {
                                                    id: refreshPalTxt
                                                    anchors.centerIn: parent
                                                    text: "󰑓 Sync Wall"
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-2)
                                                    color: refPalMouse.containsMouse ? appRoot.colFg : appRoot.colAccent
                                                }
                                                MouseArea {
                                                    id: refPalMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: appRoot.runHyprAction(["--refresh-palette"])
                                                }
                                            }
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 3
                                            columnSpacing: 5
                                            rowSpacing: 5

                                            Repeater {
                                                model: [
                                                    { id: "wallpaper", label: "Wallpaper" },
                                                    { id: "mono", label: "Mono" },
                                                    { id: "espresso", label: "Espresso" },
                                                    { id: "forest", label: "Forest" },
                                                    { id: "nord", label: "Nord" },
                                                    { id: "crimson", label: "Crimson" }
                                                ]
                                                delegate: Rectangle {
                                                    id: themeModeChip
                                                    required property var modelData
                                                    readonly property bool sel: (appRoot.hyprConfig.theme_mode || "wallpaper") === modelData.id
                                                    Layout.fillWidth: true
                                                    height: appRoot.sc(26)
                                                    radius: appRoot.sc(7)
                                                    color: "transparent"
                                                    border.width: 0
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: themeModeChip.modelData.label
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-1)
                                                        font.bold: themeModeChip.sel
                                                        color: themeModeChip.sel ? appRoot.colAccent : (tmMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                    }
                                                    MouseArea {
                                                        id: tmMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: appRoot.setHyprValue("theme_mode", themeModeChip.modelData.id)
                                                    }
                                                }
                                            }
                                        }

                                        // Matugen Scheme Selector when Wallpaper Auto-Theme is active
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            visible: (appRoot.hyprConfig.theme_mode || "wallpaper") === "wallpaper"

                                            Repeater {
                                                model: [
                                                    { id: "scheme-tonal-spot", label: "Tonal" },
                                                    { id: "scheme-vibrant", label: "Vibrant" },
                                                    { id: "scheme-expressive", label: "Expressive" },
                                                    { id: "scheme-monochrome", label: "Monochrome" },
                                                    { id: "scheme-fidelity", label: "Fidelity" }
                                                ]
                                                delegate: Rectangle {
                                                    id: matChip
                                                    required property var modelData
                                                    readonly property bool sel: (appRoot.hyprConfig.matugen_scheme || "scheme-tonal-spot") === modelData.id
                                                    width: matChipTxt.implicitWidth + appRoot.sc(14)
                                                    height: appRoot.sc(22)
                                                    radius: appRoot.sc(6)
                                                    color: "transparent"
                                                    border.width: 0
                                                    Text {
                                                        id: matChipTxt
                                                        anchors.centerIn: parent
                                                        text: matChip.modelData.label
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-2)
                                                        font.bold: matChip.sel
                                                        color: matChip.sel ? appRoot.colAccent : (matMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                    }
                                                    MouseArea {
                                                        id: matMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: appRoot.setHyprValue("matugen_scheme", matChip.modelData.id)
                                                    }
                                                }
                                            }
                                        }

                                    }
                                }

                                // 2. Typography Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "theme"
                                    Layout.fillWidth: true
                                    implicitHeight: typoCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: typoCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        Text { text: "TYPOGRAPHY"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 2
                                            columnSpacing: 5
                                            rowSpacing: 5

                                            Repeater {
                                                model: [
                                                    { id: "Adwaita Sans", label: "Adwaita Sans" },
                                                    { id: "Iosevka Nerd Font", label: "Iosevka" },
                                                    { id: "NotoSansM Nerd Font Propo", label: "Noto Sans" },
                                                    { id: "FantasqueSansM Nerd Font Propo", label: "Fantasque" },
                                                    { id: "Fira Code", label: "Fira Code" },
                                                    { id: "JetBrainsMono Nerd Font", label: "JetBrains" }
                                                ]
                                                delegate: Rectangle {
                                                    id: fontChip
                                                    required property var modelData
                                                    readonly property bool sel: (appRoot.hyprConfig.font_family || "Adwaita Sans") === modelData.id
                                                    Layout.fillWidth: true
                                                    height: appRoot.sc(26)
                                                    radius: appRoot.sc(7)
                                                    color: "transparent"
                                                    border.width: 0
                                                    Text {
                                                        anchors.centerIn: parent
                                                        width: parent.width - 10
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        text: fontChip.modelData.label
                                                        font.family: fontChip.modelData.id
                                                        font.pixelSize: appRoot.fs(-1)
                                                        font.bold: fontChip.sel
                                                        color: fontChip.sel ? appRoot.colAccent : (fcMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                    }
                                                    MouseArea {
                                                        id: fcMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: appRoot.setHyprValue("font_family", fontChip.modelData.id)
                                                    }
                                                }
                                            }
                                        }

                                        SettingSliderRow {
                                            label: "Base Font Size"
                                            valueText: appRoot.baseFontSize + " px"
                                            from: 10; to: 16; stepSize: 1
                                            value: appRoot.baseFontSize
                                            onMovedValue: val => appRoot.setHyprValue("font_size", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("font_size", Math.max(10, Math.min(16, appRoot.baseFontSize + delta)))
                                        }
                                    }
                                }

                                // 3. Dock & Frame Padding Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "bar"
                                    Layout.fillWidth: true
                                    implicitHeight: dockPadCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: dockPadCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        Text { text: "DOCK & FRAME PADDING"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        SettingSliderRow {
                                            label: "Dock Padding"
                                            valueText: appRoot.dockPadding + " px"
                                            from: 6; to: 24; stepSize: 1
                                            value: appRoot.dockPadding
                                            onMovedValue: val => appRoot.setHyprValue("dock_padding", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("dock_padding", Math.max(6, Math.min(24, appRoot.dockPadding + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Item Spacing"
                                            valueText: appRoot.itemSpacing + " px"
                                            from: 4; to: 20; stepSize: 1
                                            value: appRoot.itemSpacing
                                            onMovedValue: val => appRoot.setHyprValue("item_spacing", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("item_spacing", Math.max(4, Math.min(20, appRoot.itemSpacing + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Top Bar Height"
                                            valueText: appRoot.barHeightCfg + " px"
                                            from: 28; to: 52; stepSize: 1
                                            value: appRoot.barHeightCfg
                                            onMovedValue: val => appRoot.setHyprValue("bar_height", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("bar_height", Math.max(28, Math.min(52, appRoot.barHeightCfg + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Frame Border Thickness"
                                            valueText: appRoot.frameThicknessCfg + " px"
                                            from: 2; to: 18; stepSize: 1
                                            value: appRoot.frameThicknessCfg
                                            onMovedValue: val => appRoot.setHyprValue("frame_thickness", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("frame_thickness", Math.max(2, Math.min(18, appRoot.frameThicknessCfg + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Inner Corner Radius"
                                            valueText: appRoot.cornerRadiusCfg + " px"
                                            from: 0; to: 32; stepSize: 1
                                            value: appRoot.cornerRadiusCfg
                                            onMovedValue: val => appRoot.setHyprValue("corner_radius", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("corner_radius", Math.max(0, Math.min(32, appRoot.cornerRadiusCfg + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Dock Opacity"
                                            valueText: Math.round(appRoot.frameOpacityFrac * 100) + "%"
                                            from: 65; to: 100; stepSize: 1
                                            value: Math.round(appRoot.frameOpacityFrac * 100)
                                            onMovedValue: val => appRoot.setHyprValue("frame_opacity", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("frame_opacity", Math.max(65, Math.min(100, Math.round(appRoot.frameOpacityFrac * 100) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Hairline Stroke"
                                            valueText: appRoot.borderLineWidth + " px"
                                            from: 0; to: 4; stepSize: 1
                                            value: appRoot.borderLineWidth
                                            onMovedValue: val => appRoot.setHyprValue("border_line_width", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("border_line_width", Math.max(0, Math.min(4, appRoot.borderLineWidth + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Border Opacity"
                                            valueText: Math.round(appRoot.borderOpacityFrac * 100) + "%"
                                            from: 0; to: 100; stepSize: 5
                                            value: Math.round(appRoot.borderOpacityFrac * 100)
                                            onStepBy: delta => appRoot.setHyprValue("border_opacity", Math.max(0, Math.min(100, Math.round(appRoot.borderOpacityFrac * 100) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Border Glow"
                                            valueText: Math.round(appRoot.borderGlowFrac * 100) + "%"
                                            from: 0; to: 100; stepSize: 5
                                            value: Math.round(appRoot.borderGlowFrac * 100)
                                            onStepBy: delta => appRoot.setHyprValue("border_glow", Math.max(0, Math.min(100, Math.round(appRoot.borderGlowFrac * 100) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Left Dock Width"
                                            valueText: appRoot.leftDockWidthCfg + " px"
                                            from: 280; to: 440; stepSize: 10
                                            value: appRoot.leftDockWidthCfg
                                            onMovedValue: val => appRoot.setHyprValue("left_dock_width", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("left_dock_width", Math.max(280, Math.min(440, appRoot.leftDockWidthCfg + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Right Dock Width"
                                            valueText: appRoot.rightDockWidthCfg + " px"
                                            from: 300; to: 480; stepSize: 10
                                            value: appRoot.rightDockWidthCfg
                                            onMovedValue: val => appRoot.setHyprValue("right_dock_width", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("right_dock_width", Math.max(300, Math.min(480, appRoot.rightDockWidthCfg + delta)))
                                        }
                                    }
                                }

                                // 4. Layout Presets Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "windows"
                                    Layout.fillWidth: true
                                    implicitHeight: presetCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: presetCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(6)

                                        Text { text: "LAYOUT PRESETS"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            Repeater {
                                                model: ["compact", "balanced", "airy", "zen"]
                                                delegate: Rectangle {
                                                    id: preChip
                                                    required property string modelData
                                                    Layout.fillWidth: true
                                                    height: appRoot.sc(26)
                                                    radius: appRoot.sc(7)
                                                    color: "transparent"
                                                    border.width: 0
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: preChip.modelData.charAt(0).toUpperCase() + preChip.modelData.slice(1)
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-1)
                                                        color: preMouse.containsMouse ? appRoot.colAccent : appRoot.colFg
                                                    }
                                                    MouseArea {
                                                        id: preMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: appRoot.setHyprPreset(preChip.modelData)
                                                    }
                                                }
                                            }
                                        }

                                    }
                                }

                                // 5. Geometry & Spacing (Hyprland Windows) Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "windows"
                                    Layout.fillWidth: true
                                    implicitHeight: geoCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: geoCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        Text { text: "WINDOW GEOMETRY"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        SettingSliderRow {
                                            label: "Window Spacing"
                                            valueText: (appRoot.hyprConfig.gaps_in ?? 8) + " px"
                                            from: 0; to: 24; stepSize: 1
                                            value: appRoot.hyprConfig.gaps_in ?? 8
                                            onMovedValue: val => appRoot.setHyprValue("gaps_in", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("gaps_in", Math.max(0, Math.min(24, (appRoot.hyprConfig.gaps_in ?? 8) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Dock Outer Margin"
                                            valueText: (appRoot.hyprConfig.gaps_out ?? 16) + " px"
                                            from: 0; to: 40; stepSize: 1
                                            value: appRoot.hyprConfig.gaps_out ?? 16
                                            onMovedValue: val => appRoot.setHyprValue("gaps_out", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("gaps_out", Math.max(0, Math.min(40, (appRoot.hyprConfig.gaps_out ?? 16) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Window Border Width"
                                            valueText: (appRoot.hyprConfig.border_size ?? 2) + " px"
                                            from: 0; to: 6; stepSize: 1
                                            value: appRoot.hyprConfig.border_size ?? 2
                                            onMovedValue: val => appRoot.setHyprValue("border_size", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("border_size", Math.max(0, Math.min(6, (appRoot.hyprConfig.border_size ?? 2) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Window Corner Radius"
                                            valueText: (appRoot.hyprConfig.rounding ?? 14) + " px"
                                            from: 0; to: 28; stepSize: 1
                                            value: appRoot.hyprConfig.rounding ?? 14
                                            onMovedValue: val => appRoot.setHyprValue("rounding", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("rounding", Math.max(0, Math.min(28, (appRoot.hyprConfig.rounding ?? 14) + delta)))
                                        }
                                    }
                                }

                                // 6. Glass, Blur & Effects Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "windows"
                                    Layout.fillWidth: true
                                    implicitHeight: fxCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: fxCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(8)

                                        Text { text: "GLASS, BLUR & EFFECTS"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        SettingSliderRow {
                                            label: "Active Opacity"
                                            valueText: Math.round((appRoot.hyprConfig.active_opacity ?? 0.94) * 100) + "%"
                                            from: 0.5; to: 1.0; stepSize: 0.05
                                            value: appRoot.hyprConfig.active_opacity ?? 0.94
                                            onMovedValue: val => appRoot.setHyprValue("active_opacity", Number(val.toFixed(2)))
                                            onStepBy: delta => appRoot.setHyprValue("active_opacity", Math.max(0.5, Math.min(1.0, Number(((appRoot.hyprConfig.active_opacity ?? 0.94) + delta).toFixed(2)))))
                                        }

                                        SettingSliderRow {
                                            label: "Inactive Opacity"
                                            valueText: Math.round((appRoot.hyprConfig.inactive_opacity ?? 0.88) * 100) + "%"
                                            from: 0.5; to: 1.0; stepSize: 0.05
                                            value: appRoot.hyprConfig.inactive_opacity ?? 0.88
                                            onMovedValue: val => appRoot.setHyprValue("inactive_opacity", Number(val.toFixed(2)))
                                            onStepBy: delta => appRoot.setHyprValue("inactive_opacity", Math.max(0.5, Math.min(1.0, Number(((appRoot.hyprConfig.inactive_opacity ?? 0.88) + delta).toFixed(2)))))
                                        }

                                        SettingSliderRow {
                                            label: "Dim Strength"
                                            valueText: Math.round((appRoot.hyprConfig.dim_strength ?? 0.20) * 100) + "%"
                                            from: 0.0; to: 0.5; stepSize: 0.05
                                            value: appRoot.hyprConfig.dim_strength ?? 0.20
                                            onMovedValue: val => appRoot.setHyprValue("dim_strength", Number(val.toFixed(2)))
                                            onStepBy: delta => appRoot.setHyprValue("dim_strength", Math.max(0.0, Math.min(0.5, Number(((appRoot.hyprConfig.dim_strength ?? 0.20) + delta).toFixed(2)))))
                                        }

                                        SettingSliderRow {
                                            label: "Blur Size"
                                            valueText: (appRoot.hyprConfig.blur_size ?? 4) === 0 ? "Off" : ((appRoot.hyprConfig.blur_size ?? 4) + " px")
                                            from: 0; to: 14; stepSize: 1
                                            value: appRoot.hyprConfig.blur_size ?? 4
                                            onMovedValue: val => appRoot.setHyprValue("blur_size", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("blur_size", Math.max(0, Math.min(14, (appRoot.hyprConfig.blur_size ?? 4) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Blur Passes"
                                            valueText: String(appRoot.hyprConfig.blur_passes ?? 4)
                                            from: 1; to: 6; stepSize: 1
                                            value: appRoot.hyprConfig.blur_passes ?? 4
                                            onMovedValue: val => appRoot.setHyprValue("blur_passes", Math.round(val))
                                            onStepBy: delta => appRoot.setHyprValue("blur_passes", Math.max(1, Math.min(6, (appRoot.hyprConfig.blur_passes ?? 4) + delta)))
                                        }

                                        SettingSliderRow {
                                            label: "Animation Speed"
                                            valueText: Number(appRoot.hyprConfig.anim_speed ?? 4.0).toFixed(1)
                                            from: 1.0; to: 10.0; stepSize: 0.5
                                            value: appRoot.hyprConfig.anim_speed ?? 4.0
                                            onMovedValue: val => appRoot.setHyprValue("anim_speed", Number(val.toFixed(1)))
                                            onStepBy: delta => appRoot.setHyprValue("anim_speed", Math.max(1.0, Math.min(10.0, Number(((appRoot.hyprConfig.anim_speed ?? 4.0) + delta).toFixed(1)))))
                                        }

                                        SettingSliderRow {
                                            label: "Screen Brightness"
                                            valueText: Number(appRoot.sysInfo.brightness !== undefined ? appRoot.sysInfo.brightness : 100) + "%"
                                            from: 5; to: 100; stepSize: 5
                                            value: Number(appRoot.sysInfo.brightness !== undefined ? appRoot.sysInfo.brightness : 100)
                                            onStepBy: delta => appRoot.stepBrightness(delta > 0 ? "+5%" : "5%-")
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(8)

                                            Rectangle {
                                                id: animToggleChip
                                                readonly property bool enabledVal: appRoot.hyprConfig.animations_enabled !== false
                                                Layout.fillWidth: true; height: appRoot.sc(26); radius: appRoot.sc(7)
                                                color: "transparent"
                                                border.width: 0
                                                Text { anchors.centerIn: parent; text: "Animations"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: animToggleChip.enabledVal; color: animToggleChip.enabledVal ? appRoot.colAccent : (anMouse.containsMouse ? appRoot.colFg : appRoot.colDim) }
                                                MouseArea { id: anMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRoot.setHyprValue("animations_enabled", !animToggleChip.enabledVal) }
                                            }

                                            Rectangle {
                                                id: shadowToggleChip
                                                readonly property bool enabledVal: appRoot.hyprConfig.shadow_enabled === true
                                                Layout.fillWidth: true; height: appRoot.sc(26); radius: appRoot.sc(7)
                                                color: "transparent"
                                                border.width: 0
                                                Text { anchors.centerIn: parent; text: "Shadow"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: shadowToggleChip.enabledVal; color: shadowToggleChip.enabledVal ? appRoot.colAccent : (shMouse.containsMouse ? appRoot.colFg : appRoot.colDim) }
                                                MouseArea { id: shMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRoot.setHyprValue("shadow_enabled", !shadowToggleChip.enabledVal) }
                                            }

                                            Rectangle {
                                                id: dimToggleChip
                                                readonly property bool enabledVal: appRoot.hyprConfig.dim_inactive === true
                                                Layout.fillWidth: true; height: appRoot.sc(26); radius: appRoot.sc(7)
                                                color: "transparent"
                                                border.width: 0
                                                Text { anchors.centerIn: parent; text: "Dim Idle"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: dimToggleChip.enabledVal; color: dimToggleChip.enabledVal ? appRoot.colAccent : (dmMouse.containsMouse ? appRoot.colFg : appRoot.colDim) }
                                                MouseArea { id: dmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRoot.setHyprValue("dim_inactive", !dimToggleChip.enabledVal) }
                                            }
                                        }

                                    }
                                }

                                // 7. Border Accent Theme Card
                                Rectangle {
                                    visible: appRoot.rightMenuSection === "border"
                                    Layout.fillWidth: true
                                    implicitHeight: borderCardCol.implicitHeight + appRoot.sc(6)
                                    radius: appRoot.sc(12)
                                    color: "transparent"
                                    border.width: 0

                                    ColumnLayout {
                                        id: borderCardCol
                                        anchors.fill: parent
                                        anchors.margins: appRoot.sc(2)
                                        spacing: appRoot.sc(6)

                                        Text { text: "BORDER ACCENT"; font.family: appRoot.fontFamily; font.pixelSize: appRoot.fs(-1); font.bold: true; color: appRoot.colDim }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Rectangle {
                                                readonly property bool sel: appRoot.borderPreset === "wallpaper"
                                                Layout.fillWidth: true
                                                height: appRoot.sc(28)
                                                radius: appRoot.sc(8)
                                                color: sel ? Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, 0.14) : appRoot.colSurface
                                                border.width: sel ? 1 : 0
                                                border.color: appRoot.colAccent

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: appRoot.sc(9)
                                                        height: appRoot.sc(9)
                                                        radius: Math.round(width / 2)
                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: appRoot.colAccent }
                                                            GradientStop { position: 1.0; color: appRoot.colAccentAlt }
                                                        }
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Auto (Wallpaper)"
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-1)
                                                        font.bold: parent.parent.sel
                                                        color: parent.parent.sel ? appRoot.colAccent : (autoBpMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                    }
                                                }
                                                MouseArea {
                                                    id: autoBpMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: appRoot.setBorderPreset("wallpaper")
                                                }
                                            }

                                            Rectangle {
                                                readonly property bool sel: appRoot.borderPreset === "rainbow"
                                                Layout.fillWidth: true
                                                height: appRoot.sc(28)
                                                radius: appRoot.sc(8)
                                                color: sel ? Qt.rgba(appRoot.colAccent.r, appRoot.colAccent.g, appRoot.colAccent.b, 0.14) : appRoot.colSurface
                                                border.width: sel ? 1 : 0
                                                border.color: appRoot.colAccent

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: appRoot.sc(9)
                                                        height: appRoot.sc(9)
                                                        radius: Math.round(width / 2)
                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: "#89dceb" }
                                                            GradientStop { position: 0.35; color: "#cba6f7" }
                                                            GradientStop { position: 0.7; color: "#f38ba8" }
                                                            GradientStop { position: 1.0; color: "#f9e2af" }
                                                        }
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Multi Animated"
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-1)
                                                        font.bold: parent.parent.sel
                                                        color: parent.parent.sel ? appRoot.colAccent : (rainbowBpMouse.containsMouse ? appRoot.colFg : appRoot.colDim)
                                                    }
                                                }
                                                MouseArea {
                                                    id: rainbowBpMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: appRoot.setBorderPreset("rainbow")
                                                }
                                            }
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 7
                                            columnSpacing: 6
                                            rowSpacing: 6

                                            Repeater {
                                                model: [
                                                    { id: "silver", label: "Silver", swatch: "#e5e9f0" },
                                                    { id: "white", label: "White", swatch: "#ffffff" },
                                                    { id: "cyan", label: "Cyan", swatch: "#89dceb" },
                                                    { id: "blue", label: "Blue", swatch: "#89b4fa" },
                                                    { id: "indigo", label: "Indigo", swatch: "#b4befe" },
                                                    { id: "violet", label: "Violet", swatch: "#cba6f7" },
                                                    { id: "magenta", label: "Magenta", swatch: "#f5c2e7" },
                                                    { id: "rose", label: "Rose", swatch: "#f38ba8" },
                                                    { id: "coral", label: "Coral", swatch: "#fab387" },
                                                    { id: "amber", label: "Amber", swatch: "#f9e2af" },
                                                    { id: "gold", label: "Gold", swatch: "#f2cdcd" },
                                                    { id: "emerald", label: "Emerald", swatch: "#a6e3a1" },
                                                    { id: "teal", label: "Teal", swatch: "#94e2d5" }
                                                ]
                                                delegate: Item {
                                                    id: bpSwatch
                                                    required property var modelData
                                                    readonly property bool sel: appRoot.borderPreset === modelData.id
                                                    Layout.fillWidth: true
                                                    implicitHeight: appRoot.sc(24)

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: appRoot.sc(20)
                                                        height: appRoot.sc(20)
                                                        radius: Math.round(width / 2)
                                                        color: "transparent"
                                                        border.width: bpSwatch.sel ? 2 : (bpMouse.containsMouse ? 1 : 0)
                                                        border.color: bpSwatch.sel ? appRoot.colFg : appRoot.colDim

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: appRoot.sc(13)
                                                            height: appRoot.sc(13)
                                                            radius: Math.round(width / 2)
                                                            color: bpSwatch.modelData.swatch
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: bpMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: appRoot.setBorderPreset(bpSwatch.modelData.id)
                                                    }
                                                }
                                            }
                                        }

                                        SettingSliderRow {
                                            label: "Frame Thickness"
                                            valueText: appRoot.frameThicknessCfg + " px"
                                            from: 2; to: 18; stepSize: 1
                                            value: appRoot.frameThicknessCfg
                                            onStepBy: delta => appRoot.setHyprValue("frame_thickness", Math.max(2, Math.min(18, appRoot.frameThicknessCfg + delta)))
                                        }
                                        SettingSliderRow {
                                            label: "Hairline Stroke"
                                            valueText: appRoot.borderLineWidth + " px"
                                            from: 0; to: 4; stepSize: 1
                                            value: appRoot.borderLineWidth
                                            onStepBy: delta => appRoot.setHyprValue("border_line_width", Math.max(0, Math.min(4, appRoot.borderLineWidth + delta)))
                                        }
                                        SettingSliderRow {
                                            label: "Border Opacity"
                                            valueText: Math.round(appRoot.borderOpacityFrac * 100) + "%"
                                            from: 0; to: 100; stepSize: 5
                                            value: Math.round(appRoot.borderOpacityFrac * 100)
                                            onStepBy: delta => appRoot.setHyprValue("border_opacity", Math.max(0, Math.min(100, Math.round(appRoot.borderOpacityFrac * 100) + delta)))
                                        }
                                        SettingSliderRow {
                                            label: "Border Glow"
                                            valueText: Math.round(appRoot.borderGlowFrac * 100) + "%"
                                            from: 0; to: 100; stepSize: 5
                                            value: Math.round(appRoot.borderGlowFrac * 100)
                                            onStepBy: delta => appRoot.setHyprValue("border_glow", Math.max(0, Math.min(100, Math.round(appRoot.borderGlowFrac * 100) + delta)))
                                        }
                                    }
                                }

                                // 7b. Keybinds Section
                                ColumnLayout {
                                    visible: appRoot.rightMenuSection === "keybinds"
                                    Layout.fillWidth: true
                                    spacing: appRoot.sc(12)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: appRoot.sc(8)

                                        TextField {
                                            id: rightKeybindSearchInput
                                            Layout.fillWidth: true
                                            placeholderText: "Filter keybinds..."
                                            placeholderTextColor: appRoot.colMuted
                                            color: appRoot.colFg
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-1)
                                            background: Item {}
                                            onTextChanged: appRoot.keybindFilter = text.toLowerCase().trim()
                                        }

                                        Rectangle {
                                            width: rEditBindTxt.implicitWidth + appRoot.sc(12)
                                            height: appRoot.sc(26)
                                            color: "transparent"
                                            border.width: 0
                                            Text {
                                                id: rEditBindTxt
                                                anchors.centerIn: parent
                                                text: "󰏫 Edit"
                                                font.family: appRoot.iconFont
                                                font.pixelSize: appRoot.fs(-1)
                                                font.bold: true
                                                color: rEditBindMouse.containsMouse ? appRoot.colFg : appRoot.colAccent
                                            }
                                            MouseArea {
                                                id: rEditBindMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Quickshell.execDetached(["foot", "-e", "nvim", appRoot.homeDir + "/.config/hypr/config/bind.lua"])
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: [
                                            { cat: "BAR & PANELS", keys: "Super + A", desc: "App Launcher" },
                                            { cat: "BAR & PANELS", keys: "Super + W", desc: "Wallpaper Switcher" },
                                            { cat: "BAR & PANELS", keys: "Super + L", desc: "Left System Monitor" },
                                            { cat: "BAR & PANELS", keys: "Super + R", desc: "Right Rice Studio" },
                                            { cat: "BAR & PANELS", keys: "Super + Shift + C", desc: "Calendar & Capture" },
                                            { cat: "BAR & PANELS", keys: "Super + Shift + W", desc: "Weather Forecast" },
                                            { cat: "BAR & PANELS", keys: "Super + Alt + Backspace", desc: "Toggle Top Bar" },
                                            { cat: "WINDOWS", keys: "Super + Q / C", desc: "Close Window" },
                                            { cat: "WINDOWS", keys: "Super + Shift + Q", desc: "Kill Window" },
                                            { cat: "WINDOWS", keys: "Super + F", desc: "Fullscreen" },
                                            { cat: "WINDOWS", keys: "Super + Space", desc: "Toggle Float" },
                                            { cat: "WINDOWS", keys: "Super + S", desc: "Scratchpad" },
                                            { cat: "WINDOWS", keys: "Super + 1..5", desc: "Switch Workspace" },
                                            { cat: "APPS & MEDIA", keys: "Super + Return", desc: "Open Terminal" },
                                            { cat: "APPS & MEDIA", keys: "Super + P", desc: "System btop" },
                                            { cat: "APPS & MEDIA", keys: "Alt + F11 / F12", desc: "Volume - / +" },
                                            { cat: "APPS & MEDIA", keys: "Alt + F2 / F3", desc: "Brightness - / +" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Shift + S", desc: "Screenshot Area" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Ctrl + Shift + S", desc: "Screenshot Screen" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Shift + R", desc: "Record Screen" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Ctrl + Shift + R", desc: "Record Area" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Alt + C", desc: "Color Picker" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Escape", desc: "Lock Screen" },
                                            { cat: "CAPTURE & POWER", keys: "Super + Shift + P", desc: "Power Menu" }
                                        ].filter(item => appRoot.keybindFilter === ""
                                            || item.cat.toLowerCase().includes(appRoot.keybindFilter)
                                            || item.keys.toLowerCase().includes(appRoot.keybindFilter)
                                            || item.desc.toLowerCase().includes(appRoot.keybindFilter))
                                        delegate: RowLayout {
                                            id: rKbRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: appRoot.sc(8)

                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: rKbRow.modelData.desc
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-1)
                                                    color: appRoot.colFg
                                                }
                                                Text {
                                                    text: rKbRow.modelData.cat
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(-3)
                                                    color: appRoot.colMuted
                                                }
                                            }

                                            Text {
                                                text: rKbRow.modelData.keys
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                font.bold: true
                                                color: appRoot.colAccent
                                            }
                                        }

                                    }
                                }

                                // 8. Quick Actions Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Rectangle {
                                        Layout.fillWidth: true; height: appRoot.sc(32); radius: appRoot.sc(9)
                                        color: "transparent"
                                        border.width: 0
                                        Text { anchors.centerIn: parent; text: "󰸉 Walls"; font.family: appRoot.iconFont; font.pixelSize: appRoot.fs(-1); color: qa0Mouse.containsMouse ? appRoot.colAccent : appRoot.colFg }
                                        MouseArea { id: qa0Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRoot.toggleBottomDockFor(win.monitorName) }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: appRoot.sc(32); radius: appRoot.sc(9)
                                        color: "transparent"
                                        border.width: 0
                                        Text { anchors.centerIn: parent; text: "󰒝 Rand"; font.family: appRoot.iconFont; font.pixelSize: appRoot.fs(-1); color: qa1Mouse.containsMouse ? appRoot.colAccent : appRoot.colFg }
                                        MouseArea { id: qa1Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRoot.randomizeWallpaper("random") }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: appRoot.sc(32); radius: appRoot.sc(9)
                                        color: "transparent"
                                        border.width: 0
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅶 Coffee"
                                            font.family: appRoot.iconFont
                                            font.pixelSize: appRoot.fs(-1)
                                            font.bold: appRoot.coffeeActive
                                            color: appRoot.coffeeActive ? appRoot.colAmber : (qaCoffeeMouse.containsMouse ? appRoot.colAccent : appRoot.colFg)
                                        }
                                        MouseArea { id: qaCoffeeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appRoot.setCoffeeMode("toggle") }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: appRoot.sc(32); radius: appRoot.sc(9)
                                        color: "transparent"
                                        border.width: 0
                                        Text { anchors.centerIn: parent; text: "󰑓 Reload"; font.family: appRoot.iconFont; font.pixelSize: appRoot.fs(-1); color: qa2Mouse.containsMouse ? appRoot.colAccent : appRoot.colFg }
                                        MouseArea { id: qa2Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached([appRoot.homeDir + "/main/minimalarch/switch.sh", "--reload"]) }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: appRoot.sc(32); radius: appRoot.sc(9)
                                        color: "transparent"
                                        border.width: 0
                                        Text { anchors.centerIn: parent; text: "󰌾 Lock"; font.family: appRoot.iconFont; font.pixelSize: appRoot.fs(-1); color: qa3Mouse.containsMouse ? appRoot.colRed : appRoot.colFg }
                                        MouseArea { id: qa3Mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["hyprlock"]) }
                                    }
                                }
                            }
                        }
                    }
                } // rightFrameStrip

                // 4. BOTTOM FRAME STRIP (frameThicknessCfg Continuous Border — bottom-center hover opens Music Player; Super+A / Super+W opens Launcher/Wallpaper)
                Rectangle {
                    id: bottomFrameStrip
                    x: 0
                    y: win.innerBottom
                    width: stripRoot.width
                    height: stripRoot.height - win.innerBottom
                    color: "transparent"
                    clip: true

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: appRoot.sc(180)

                        HoverHandler {
                            id: bottomEdgeMusicHover
                            enabled: appRoot.musicHasPlayer
                            onHoveredChanged: {
                                if (hovered && appRoot.musicHasPlayer) {
                                    musicUnhoverTimer.stop();
                                    win.musicHovered = true;
                                } else if (!bottomMusicHover.hovered) {
                                    musicUnhoverTimer.restart();
                                }
                            }
                        }
                    }
                } // bottomFrameStrip

                // Subtle Collapsed Edge Accent Indicators (follow configured frameThicknessCfg)
                Rectangle {
                    visible: appRoot.frameThicknessCfg >= 4
                    width: Math.min(3, Math.max(1.5, appRoot.frameThicknessCfg * 0.35))
                    height: 68
                    x: Math.max(0.5, (win.leftExtent - width) * 0.5)
                    y: Math.round((stripRoot.height - height) / 2)
                    radius: 2
                    color: leftHover.hovered ? appRoot.colAccent : appRoot.colLineStrong
                    opacity: win.leftDockOpen ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    visible: appRoot.frameThicknessCfg >= 4
                    width: Math.min(3, Math.max(1.5, appRoot.frameThicknessCfg * 0.35))
                    height: 68
                    x: stripRoot.width - (win.rightExtent + width) * 0.5
                    y: Math.round((stripRoot.height - height) / 2)
                    radius: 2
                    color: rightHover.hovered ? appRoot.colAccent : appRoot.colLineStrong
                    opacity: win.rightDockOpen ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    visible: appRoot.frameThicknessCfg >= 4
                    width: 68
                    height: Math.min(3, Math.max(1.5, appRoot.frameThicknessCfg * 0.35))
                    x: Math.round((stripRoot.width - width) / 2)
                    y: stripRoot.height - (win.bottomExtent + height) * 0.5
                    radius: 2
                    color: appRoot.colLineStrong
                    opacity: win.bottomDrawerMode !== "" ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // ========== BOTTOM-EMERGING COMPACT LAUNCHER (APPS: SUPER+A | WALLPAPERS: SUPER+W | MUSIC: CAVA / HOVER PLAYER) ==========
                Rectangle {
                    id: bottomLauncherDrawer
                    anchors.bottom: bottomFrameStrip.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: win.bottomDrawerMode === "wallpaper"
                        ? Math.min(appRoot.sc(980), win.innerW - 48)
                        : (win.bottomDrawerMode === "search"
                            ? Math.min(appRoot.sc(540), win.innerW - 60)
                            : (win.bottomDrawerMode === "music_player"
                                ? Math.min(appRoot.sc(440), win.innerW - 60)
                                : Math.min(appRoot.sc(240), win.innerW - 60)))
                    height: win.bottomDrawerMode === "search"
                        ? Math.min(appRoot.sc(390), Math.max(appRoot.sc(150), appRoot.sc(88) + searchBody.filteredApps.length * appRoot.sc(52)))
                        : (win.bottomDrawerMode === "wallpaper"
                            ? Math.min(Math.round(win.innerH * 0.62), Math.min(appRoot.sc(560), Math.max(appRoot.sc(220), appRoot.sc(78) + Math.ceil(bottomDockContent.filteredWalls.length / 4) * appRoot.sc(126))))
                            : (win.bottomDrawerMode === "music_player"
                                ? appRoot.sc(132)
                                : (win.bottomDrawerMode === "cava" ? appRoot.sc(28) : 0)))
                    visible: height > 1
                    radius: 0
                    color: "transparent"
                    border.width: 0
                    clip: true

                    HoverHandler {
                        id: bottomMusicHover
                        enabled: win.bottomDrawerMode === "cava" || win.bottomDrawerMode === "music_player"
                        onHoveredChanged: {
                            if (hovered) {
                                musicUnhoverTimer.stop();
                                win.musicHovered = true;
                            } else if (!bottomEdgeMusicHover.hovered) {
                                musicUnhoverTimer.restart();
                            }
                        }
                    }

                    onXChanged: unifiedFrameCanvas.requestPaint()
                    onWidthChanged: unifiedFrameCanvas.requestPaint()
                    onHeightChanged: unifiedFrameCanvas.requestPaint()

                    Behavior on width {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    // Swallow pointer events on drawer background
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => { wheel.accepted = true; }
                    }

                    Item {
                        id: searchBody
                        anchors.fill: parent
                        anchors.margins: appRoot.dockPadding
                        visible: win.bottomDrawerMode === "search"

                        property string queryText: ""
                        property int selectedIdx: 0

                        readonly property var filteredApps: {
                            DesktopEntries.applications.values;
                            const q = searchBody.queryText.toLowerCase().trim();
                            const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
                            if (q === "")
                                return all.slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                            const scored = [];
                            for (const e of all) {
                                const name = (e.name || "").toLowerCase();
                                const desc = (e.comment || "").toLowerCase();
                                const exec = (e.executable || "").toLowerCase();
                                let score = 0;
                                if (name === q) score = 100;
                                else if (name.startsWith(q)) score = 80;
                                else if (name.includes(q)) score = 60;
                                else if (exec.includes(q)) score = 40;
                                else if (desc.includes(q)) score = 20;
                                if (score > 0)
                                    scored.push({ e, score });
                            }
                            scored.sort((a, b) => b.score - a.score || (a.e.name || "").localeCompare(b.e.name || ""));
                            return scored.map(x => x.e);
                        }

                        function launchSelected() {
                            const list = searchBody.filteredApps;
                            if (list.length === 0)
                                return;
                            const idx = Math.max(0, Math.min(searchBody.selectedIdx, list.length - 1));
                            const entry = list[idx];
                            if (entry && entry.execute)
                                entry.execute();
                            appRoot.setIslandFor(win.monitorName, "default");
                        }

                        Connections {
                            target: win
                            function onBottomDrawerModeChanged() {
                                if (win.bottomDrawerMode === "search") {
                                    searchBody.queryText = "";
                                    searchBody.selectedIdx = 0;
                                    searchInput.text = "";
                                    Qt.callLater(() => searchInput.forceActiveFocus());
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: appRoot.itemSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                height: appRoot.sc(38)
                                radius: appRoot.sc(10)
                                color: "transparent"
                                border.width: 0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: "󰍉"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(3)
                                        color: appRoot.colAccent
                                    }

                                    TextField {
                                        id: searchInput
                                        Layout.fillWidth: true
                                        placeholderText: "Search applications..."
                                        placeholderTextColor: appRoot.colMuted
                                        color: appRoot.colFg
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(1)
                                        background: Item {}
                                        onTextChanged: {
                                            searchBody.queryText = text;
                                            searchBody.selectedIdx = 0;
                                            appListView.positionViewAtBeginning();
                                        }
                                        Keys.onEscapePressed: appRoot.setIslandFor(win.monitorName, "default")
                                        Keys.onDownPressed: {
                                            if (searchBody.selectedIdx < searchBody.filteredApps.length - 1) {
                                                searchBody.selectedIdx++;
                                                appListView.positionViewAtIndex(searchBody.selectedIdx, ListView.Contain);
                                            }
                                        }
                                        Keys.onUpPressed: {
                                            if (searchBody.selectedIdx > 0) {
                                                searchBody.selectedIdx--;
                                                appListView.positionViewAtIndex(searchBody.selectedIdx, ListView.Contain);
                                            }
                                        }
                                        Keys.onReturnPressed: searchBody.launchSelected()
                                        Keys.onEnterPressed: searchBody.launchSelected()
                                    }

                                    Text {
                                        text: searchBody.filteredApps.length + " apps"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: appRoot.colMuted
                                    }

                                    PillIconBtn {
                                        iconText: "󰸉"
                                        btnWidth: appRoot.sc(26)
                                        btnHeight: appRoot.sc(24)
                                        iconPixelSize: appRoot.fs(1)
                                        onClicked: appRoot.setBottomDockFor(win.monitorName, true)
                                    }

                                    PillIconBtn {
                                        iconText: "✕"
                                        btnWidth: appRoot.sc(24)
                                        btnHeight: appRoot.sc(24)
                                        iconPixelSize: appRoot.fs(-1)
                                        onClicked: appRoot.setIslandFor(win.monitorName, "default")
                                    }
                                }
                            }

                            ListView {
                                id: appListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: Math.max(appRoot.sc(8), appRoot.itemSpacing)
                                model: win.bottomDrawerMode === "search" ? searchBody.filteredApps : []
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                delegate: Rectangle {
                                    id: appItemCard
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSel: index === searchBody.selectedIdx
                                    readonly property string iconSrc: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""

                                    width: appListView.width
                                    height: appRoot.sc(46)
                                    radius: appRoot.sc(9)
                                    color: "transparent"
                                    border.width: 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Item {
                                            Layout.preferredWidth: appRoot.sc(28)
                                            Layout.preferredHeight: appRoot.sc(28)

                                            IconImage {
                                                anchors.centerIn: parent
                                                width: appRoot.sc(24)
                                                height: appRoot.sc(24)
                                                source: appItemCard.iconSrc
                                                visible: appItemCard.iconSrc !== ""
                                                asynchronous: true
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: appRoot.sc(24)
                                                height: appRoot.sc(24)
                                                radius: appRoot.sc(7)
                                                visible: appItemCard.iconSrc === ""
                                                color: "transparent"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (appItemCard.modelData.name || "?").charAt(0).toUpperCase()
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: appRoot.fs(0)
                                                    font.bold: true
                                                    color: appRoot.colAccent
                                                }
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: appItemCard.modelData.name || ""
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(0)
                                                font.bold: appItemCard.isSel
                                                color: (appItemCard.isSel || rowMouse.containsMouse) ? appRoot.colAccent : appRoot.colFg
                                            }
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                visible: (appItemCard.modelData.comment || "") !== ""
                                                text: appItemCard.modelData.comment || ""
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                color: appRoot.colMuted
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: searchBody.selectedIdx = appItemCard.index
                                        onClicked: {
                                            if (appItemCard.modelData && appItemCard.modelData.execute)
                                                appItemCard.modelData.execute();
                                            appRoot.setIslandFor(win.monitorName, "default");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Wallpaper Switcher Content emerging cleanly from bottom border (Super+W)
                    Item {
                        id: bottomDockContent
                        anchors.fill: parent
                        anchors.margins: appRoot.dockPadding
                        visible: win.bottomDrawerMode === "wallpaper"

                        property string filterQuery: ""

                        readonly property var filteredWalls: {
                            appRoot.wallpapers;
                            const q = bottomDockContent.filterQuery.toLowerCase().trim();
                            if (q === "")
                                return appRoot.wallpapers;
                            return appRoot.wallpapers.filter(w =>
                                (w.name || "").toLowerCase().includes(q)
                                || (w.category || "").toLowerCase().includes(q)
                            );
                        }

                        Connections {
                            target: win
                            function onBottomDrawerModeChanged() {
                                if (win.bottomDrawerMode === "wallpaper") {
                                    bottomDockContent.filterQuery = "";
                                    wallSearchInput.text = "";
                                    Qt.callLater(() => wallSearchInput.forceActiveFocus());
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: appRoot.itemSpacing

                            // Header: Apps switch + Filter + Auto-Randomize + Close
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                PillIconBtn {
                                    iconText: "󰣇"
                                    btnWidth: appRoot.sc(32)
                                    btnHeight: appRoot.sc(34)
                                    iconPixelSize: appRoot.fs(3)
                                    onClicked: appRoot.setIslandFor(win.monitorName, "search")
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: appRoot.sc(34)
                                    radius: appRoot.sc(9)
                                    color: "transparent"
                                    border.width: 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 6

                                        Text {
                                            text: "󰸉"
                                            font.family: appRoot.iconFont
                                            font.pixelSize: appRoot.fs(2)
                                            color: appRoot.colAccent
                                        }

                                        TextField {
                                            id: wallSearchInput
                                            Layout.fillWidth: true
                                            placeholderText: "Filter wallpapers (Esc or Super+W to close)..."
                                            placeholderTextColor: appRoot.colMuted
                                            color: appRoot.colFg
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(0)
                                            background: Item {}
                                            onTextChanged: bottomDockContent.filterQuery = text
                                            Keys.onEscapePressed: appRoot.setBottomDockFor(win.monitorName, false)
                                            Keys.onReturnPressed: {
                                                if (bottomDockContent.filteredWalls.length > 0)
                                                    appRoot.applyWallpaper(bottomDockContent.filteredWalls[0].path, "random");
                                            }
                                        }

                                        Text {
                                            text: bottomDockContent.filteredWalls.length + " imgs"
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-1)
                                            color: appRoot.colMuted
                                        }
                                    }
                                }

                                // Randomize button (transitions chosen automatically at random)
                                Rectangle {
                                    height: Math.max(appRoot.sc(32), randRow.implicitHeight + appRoot.sc(10))
                                    width: randRow.implicitWidth + appRoot.sc(16)
                                    radius: appRoot.sc(9)
                                    color: "transparent"
                                    border.width: 0

                                    Row {
                                        id: randRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Randomize"
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(0)
                                            font.weight: Font.DemiBold
                                            color: randMouse.containsMouse ? appRoot.colAccent : appRoot.colFg
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰒝"
                                            font.family: appRoot.iconFont
                                            font.pixelSize: appRoot.fs(1)
                                            color: appRoot.colAccent
                                        }
                                    }

                                    MouseArea {
                                        id: randMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.randomizeWallpaper("random")
                                    }
                                }

                                PillIconBtn {
                                    iconText: "✕"
                                    iconPixelSize: appRoot.fs(-1)
                                    onClicked: appRoot.setBottomDockFor(win.monitorName, false)
                                }
                            }

                            // 4-Column Thumbnail GridView
                            GridView {
                                id: wallGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                cellWidth: Math.floor(width / 4)
                                cellHeight: appRoot.sc(118)
                                model: win.bottomDrawerMode === "wallpaper" ? bottomDockContent.filteredWalls : []
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                delegate: Item {
                                    id: wallTileCard
                                    required property var modelData
                                    readonly property bool isCurrent: appRoot.currentWallpaper === modelData.path
                                    width: wallGrid.cellWidth
                                    height: wallGrid.cellHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: appRoot.sc(10)
                                        color: "transparent"
                                        border.width: 0
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: wallTileCard.modelData.thumb !== "" ? ("file://" + wallTileCard.modelData.thumb) : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: 320
                                            sourceSize.height: 180
                                        }

                                        Rectangle {
                                            visible: !!wallTileCard.modelData.is_live
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: appRoot.sc(5)
                                            width: liveBadgeRow.implicitWidth + appRoot.sc(8)
                                            height: appRoot.sc(16)
                                            radius: Math.round(height / 2)
                                            color: Qt.rgba(appRoot.colBg.r, appRoot.colBg.g, appRoot.colBg.b, 0.85)
                                            border.width: 1
                                            border.color: appRoot.colAccent

                                            Row {
                                                id: liveBadgeRow
                                                anchors.centerIn: parent
                                                spacing: 3
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "󰕧"
                                                    font.family: appRoot.iconFont
                                                    font.pixelSize: appRoot.fs(-3)
                                                    color: appRoot.colAccent
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "LIVE"
                                                    font.family: appRoot.fontFamily
                                                    font.pixelSize: Math.max(8, appRoot.fs(-4))
                                                    font.bold: true
                                                    color: appRoot.colFg
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: appRoot.sc(22)
                                            color: Qt.rgba(0, 0, 0, 0.58)

                                            Text {
                                                anchors.fill: parent
                                                anchors.leftMargin: 7
                                                anchors.rightMargin: 7
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                text: wallTileCard.modelData.name || ""
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                font.bold: wallTileCard.isCurrent
                                                color: wallTileCard.isCurrent ? appRoot.colAccent : (tileMouse.containsMouse ? appRoot.colAccent : appRoot.colFg)
                                            }
                                        }

                                        MouseArea {
                                            id: tileMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: appRoot.applyWallpaper(wallTileCard.modelData.path, "random")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Compact CAVA Visualizer Pill (visible when music is active & unhovered)
                    Item {
                        id: bottomCavaView
                        anchors.fill: parent
                        anchors.leftMargin: appRoot.sc(12)
                        anchors.rightMargin: appRoot.sc(12)
                        visible: win.bottomDrawerMode === "cava"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: appRoot.sc(8)

                            Text {
                                text: appRoot.musicPlaying ? "󰎈" : "󰏤"
                                font.family: appRoot.iconFont
                                font.pixelSize: appRoot.fs(-1)
                                color: appRoot.musicPlaying ? appRoot.colAccent : appRoot.colMuted
                            }

                            Row {
                                id: cavaBarsRow
                                spacing: appRoot.sc(3)
                                Layout.alignment: Qt.AlignVCenter
                                height: appRoot.sc(16)

                                Repeater {
                                    model: 20
                                    delegate: Item {
                                        width: appRoot.sc(4)
                                        height: cavaBarsRow.height
                                        readonly property real barVal: (win.bottomDrawerMode === "cava" && appRoot.cavaBars && index < appRoot.cavaBars.length) ? Number(appRoot.cavaBars[index] || 0) : 0

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.width
                                            height: appRoot.musicPlaying
                                                ? Math.max(appRoot.sc(3), Math.round((parent.barVal / 100.0) * parent.height))
                                                : appRoot.sc(3)
                                            radius: Math.max(1, Math.round(width / 2))
                                            color: appRoot.musicPlaying
                                                ? (parent.barVal > 55 ? appRoot.colAccent : appRoot.colAccentAlt)
                                                : appRoot.colMuted
                                            opacity: appRoot.musicPlaying ? (0.45 + 0.55 * (parent.barVal / 100.0)) : 0.45
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Expanded Music Player (MPRIS)
                    Item {
                        id: bottomMusicPlayerView
                        anchors.fill: parent
                        anchors.margins: appRoot.sc(10)
                        visible: win.bottomDrawerMode === "music_player"

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: appRoot.sc(5)

                            // Header: Icon + Player Name + Pin
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appRoot.sc(6)

                                Text {
                                    text: "󰎈"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(1)
                                    color: appRoot.colAccent
                                }

                                Text {
                                    text: appRoot.musicPlayerName || "Music Player"
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(-1)
                                    font.bold: true
                                    color: appRoot.colFg
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                PillIconBtn {
                                    iconText: appRoot.musicDrawerPinned ? "󰐃" : "󰐄"
                                    active: appRoot.musicDrawerPinned
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: appRoot.musicDrawerPinned = !appRoot.musicDrawerPinned
                                }
                            }

                            // Active Track View
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: appRoot.sc(4)
                                visible: appRoot.musicHasPlayer

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: appRoot.sc(8)

                                        Rectangle {
                                            Layout.preferredWidth: appRoot.sc(40)
                                            Layout.preferredHeight: appRoot.sc(40)
                                            radius: appRoot.sc(8)
                                            color: appRoot.colSurface
                                            border.width: 0
                                            clip: true

                                            Image {
                                                id: musicArtImg
                                                anchors.fill: parent
                                                source: appRoot.musicArtUrl || ""
                                                sourceSize: Qt.size(96, 96)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                visible: appRoot.musicArtUrl !== "" && status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !musicArtImg.visible
                                                text: "󰎈"
                                                font.family: appRoot.iconFont
                                                font.pixelSize: appRoot.fs(6)
                                                color: appRoot.colAccent
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: appRoot.musicTitle || "Unknown Track"
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(0)
                                                font.bold: true
                                                color: appRoot.colFg
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: (appRoot.musicArtist !== "" ? appRoot.musicArtist : (appRoot.musicPlayerName || "Media")) + " • " + (appRoot.musicPlaying ? "Playing" : "Paused")
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                color: appRoot.colDim
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            spacing: appRoot.sc(2)
                                            Layout.alignment: Qt.AlignVCenter
                                            height: appRoot.sc(18)

                                            Repeater {
                                                model: 8
                                                delegate: Item {
                                                    width: appRoot.sc(3)
                                                    height: appRoot.sc(18)
                                                    readonly property int srcIdx: Math.min(19, index * 2 + 2)
                                                    readonly property real barVal: (win.bottomDrawerMode === "music_player" && appRoot.cavaBars && srcIdx < appRoot.cavaBars.length) ? Number(appRoot.cavaBars[srcIdx] || 0) : 0

                                                    Rectangle {
                                                        anchors.bottom: parent.bottom
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: parent.width
                                                        height: appRoot.musicPlaying
                                                            ? Math.max(appRoot.sc(2), Math.round((parent.barVal / 100.0) * parent.height))
                                                            : appRoot.sc(2)
                                                        radius: 1
                                                        color: appRoot.musicPlaying ? appRoot.colAccent : appRoot.colMuted
                                                        opacity: appRoot.musicPlaying ? (0.4 + 0.6 * (parent.barVal / 100.0)) : 0.4
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Seek Progress Bar
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: appRoot.sc(8)

                                        Text {
                                            text: appRoot.formatMusicTime(appRoot.musicPosition)
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-2)
                                            color: appRoot.colDim
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: appRoot.sc(12)

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width
                                                height: appRoot.sc(4)
                                                radius: Math.max(2, Math.round(height / 2))
                                                color: appRoot.colSurface

                                                Rectangle {
                                                    width: appRoot.musicLength > 0
                                                        ? Math.max(0, Math.min(parent.width, parent.width * (appRoot.musicPosition / appRoot.musicLength)))
                                                        : 0
                                                    height: parent.height
                                                    radius: parent.radius
                                                    color: appRoot.colAccent
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: appRoot.musicLength > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: mouse => {
                                                    if (appRoot.musicLength > 0 && width > 0) {
                                                        const frac = Math.max(0, Math.min(1, mouse.x / width));
                                                        const targetSec = Math.round(frac * appRoot.musicLength);
                                                        appRoot.musicCmd(["--seek", String(targetSec)]);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: appRoot.formatMusicTime(appRoot.musicLength)
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-2)
                                            color: appRoot.colDim
                                        }
                                    }

                                    // Playback Controls
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Item { Layout.fillWidth: true }

                                        PillIconBtn {
                                            iconText: "󰑖"
                                            active: appRoot.musicLoop
                                            iconPixelSize: appRoot.fs(0)
                                            onClicked: appRoot.musicCmd(["--toggle-loop"])
                                        }

                                        PillIconBtn {
                                            iconText: "󰒮"
                                            active: false
                                            iconPixelSize: appRoot.fs(2)
                                            onClicked: appRoot.musicCmd(["--prev"])
                                        }

                                        PillIconBtn {
                                            iconText: appRoot.musicPlaying ? "󰏤" : "󰐊"
                                            active: true
                                            iconPixelSize: appRoot.fs(4)
                                            btnWidth: appRoot.sc(32)
                                            btnHeight: appRoot.sc(24)
                                            onClicked: appRoot.musicCmd(["--play-pause"])
                                        }

                                        PillIconBtn {
                                            iconText: "󰒭"
                                            active: false
                                            iconPixelSize: appRoot.fs(2)
                                            onClicked: appRoot.musicCmd(["--next"])
                                        }

                                        PillIconBtn {
                                            iconText: "󰓛"
                                            active: false
                                            iconPixelSize: appRoot.fs(0)
                                            onClicked: appRoot.musicCmd(["--stop"])
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                } // bottomLauncherDrawer

                // ========== TOP-RIGHT HOVER STATUS DROPDOWN (SEAMLESS PART OF TOP-RIGHT FRAME) ==========
                Rectangle {
                    id: statusDropdownDrawer
                    x: win.innerRight - width
                    y: win.innerY
                    width: Math.min(appRoot.sc(380), Math.max(240, win.innerW - 24))
                    readonly property real targetHeight: win.activeStatusPopup !== ""
                        ? Math.min(appRoot.sc(540), Math.max(appRoot.sc(190), statusDrawerCol.implicitHeight + appRoot.dockPadding * 2))
                        : 0
                    height: targetHeight
                    visible: height > 1
                    radius: 0
                    color: "transparent"
                    border.width: 0
                    clip: true

                    onXChanged: unifiedFrameCanvas.requestPaint()
                    onYChanged: unifiedFrameCanvas.requestPaint()
                    onWidthChanged: unifiedFrameCanvas.requestPaint()
                    onHeightChanged: unifiedFrameCanvas.requestPaint()

                    Behavior on height {
                        NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
                    }

                    HoverHandler {
                        id: statusDrawerHover
                        onHoveredChanged: {
                            if (hovered)
                                statusPopupCloseTimer.stop();
                            else
                                statusPopupCloseTimer.restart();
                        }
                    }

                    // Capture mouse clicks inside empty areas of the dropdown so desktop behind doesn't receive them
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => { wheel.accepted = true; }
                    }

                    ColumnLayout {
                        id: statusDrawerCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: appRoot.dockPadding
                        spacing: Math.max(appRoot.sc(12), appRoot.itemSpacing + 4)

                        // Error banner (e.g., wrong Wi-Fi password or BT connect failure)
                        Text {
                            Layout.fillWidth: true
                            visible: appRoot.statusErrorMsg !== ""
                            text: appRoot.statusErrorMsg
                            font.family: appRoot.fontFamily
                            font.pixelSize: appRoot.fs(-1)
                            color: appRoot.colRed
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        // ========== VIEW 1: NETWORK (WI-FI) ==========
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appRoot.sc(12)
                            visible: win.activeStatusPopup === "wifi"

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: appRoot.sysInfo.wifi_on ? ("Wi-Fi • " + (appRoot.sysInfo.wifi_ssid || "On")) : "Wi-Fi Off"
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(0)
                                    font.bold: true
                                    color: appRoot.colFg
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: wifiScanTxt.implicitWidth + appRoot.sc(14)
                                    height: Math.max(appRoot.sc(24), wifiScanTxt.implicitHeight + appRoot.sc(8))
                                    radius: appRoot.sc(7)
                                    color: "transparent"
                                    border.width: 0
                                    visible: appRoot.sysInfo.wifi_on
                                    Text {
                                        id: wifiScanTxt
                                        anchors.centerIn: parent
                                        text: appRoot.statusBusy ? "..." : "󰑐 Scan"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(-1)
                                        color: wifiScanMouse.containsMouse ? appRoot.colAccent : appRoot.colFg
                                    }
                                    MouseArea {
                                        id: wifiScanMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.runStatusAction(["--wifi-rescan"])
                                    }
                                }

                                Rectangle {
                                    width: wifiToggleTxt.implicitWidth + appRoot.sc(16)
                                    height: Math.max(appRoot.sc(24), wifiToggleTxt.implicitHeight + appRoot.sc(8))
                                    radius: appRoot.sc(7)
                                    color: "transparent"
                                    border.width: 0
                                    Text {
                                        id: wifiToggleTxt
                                        anchors.centerIn: parent
                                        text: appRoot.sysInfo.wifi_on ? "On" : "Off"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.bold: true
                                        color: appRoot.sysInfo.wifi_on ? appRoot.colGreen : appRoot.colRed
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.runStatusAction(["--wifi-toggle", appRoot.sysInfo.wifi_on ? "off" : "on"])
                                    }
                                }
                            }

                            // Inline Wi-Fi password box when connecting to a new secured network
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: wifiPassCol.implicitHeight + appRoot.sc(6)
                                radius: appRoot.sc(9)
                                color: "transparent"
                                border.width: 0
                                visible: appRoot.wifiPasswordTarget !== ""

                                ColumnLayout {
                                    id: wifiPassCol
                                    anchors.fill: parent
                                    anchors.margins: appRoot.sc(2)
                                    spacing: appRoot.sc(6)

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: "Password for " + appRoot.wifiPasswordTarget
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: appRoot.colAccent
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: appRoot.sc(6)

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: appRoot.sc(28)
                                            radius: appRoot.sc(7)
                                            color: "transparent"
                                            border.width: 0

                                            TextField {
                                                id: wifiPassInput
                                                anchors.fill: parent
                                                anchors.leftMargin: appRoot.sc(4)
                                                anchors.rightMargin: appRoot.sc(4)
                                                placeholderText: "Wi-Fi passphrase..."
                                                placeholderTextColor: appRoot.colMuted
                                                color: appRoot.colFg
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                echoMode: TextInput.Password
                                                background: Item {}
                                                Keys.onEscapePressed: {
                                                    text = "";
                                                    appRoot.wifiPasswordTarget = "";
                                                }
                                                Keys.onReturnPressed: {
                                                    const ssid = appRoot.wifiPasswordTarget;
                                                    const pw = text;
                                                    text = "";
                                                    appRoot.runStatusAction(["--wifi-connect", ssid, pw]);
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: joinBtnTxt.implicitWidth + appRoot.sc(14)
                                            height: appRoot.sc(28)
                                            radius: appRoot.sc(7)
                                            color: "transparent"
                                            border.width: 0
                                            Text {
                                                id: joinBtnTxt
                                                anchors.centerIn: parent
                                                text: "Join"
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                font.bold: true
                                                color: appRoot.colAccent
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const ssid = appRoot.wifiPasswordTarget;
                                                    const pw = wifiPassInput.text;
                                                    wifiPassInput.text = "";
                                                    appRoot.runStatusAction(["--wifi-connect", ssid, pw]);
                                                }
                                            }
                                        }

                                        PillIconBtn {
                                            iconText: "✕"
                                            btnWidth: appRoot.sc(26)
                                            btnHeight: appRoot.sc(28)
                                            iconPixelSize: appRoot.fs(-2)
                                            onClicked: {
                                                wifiPassInput.text = "";
                                                appRoot.wifiPasswordTarget = "";
                                            }
                                        }

                                    }
                                }
                            }

                            Flickable {
                                id: wifiListFlick
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(appRoot.sc(320), Math.max(appRoot.sc(84), wifiListCol.implicitHeight))
                                contentWidth: width
                                contentHeight: wifiListCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: wifiListCol
                                    width: wifiListFlick.width
                                    spacing: Math.max(appRoot.sc(10), appRoot.itemSpacing)

                                    Repeater {
                                        model: appRoot.statusDetail.wifi_networks || []
                                        delegate: Rectangle {
                                            id: wifiNetCard
                                            required property var modelData
                                            readonly property bool connected: !!modelData.in_use
                                            readonly property int sig: Number(modelData.signal || 0)

                                            Layout.fillWidth: true
                                            height: Math.max(appRoot.sc(52), wifiCardRow.implicitHeight + appRoot.sc(16))
                                            radius: appRoot.sc(9)
                                            color: "transparent"
                                            border.width: 0

                                            RowLayout {
                                                id: wifiCardRow
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: appRoot.sc(6)
                                                anchors.rightMargin: appRoot.sc(6)
                                                spacing: appRoot.sc(12)

                                                Text {
                                                    text: wifiNetCard.sig >= 75 ? "󰤨" : (wifiNetCard.sig >= 50 ? "󰤥" : (wifiNetCard.sig >= 25 ? "󰤢" : "󰤟"))
                                                    font.family: appRoot.iconFont
                                                    font.pixelSize: appRoot.fs(3)
                                                    color: wifiNetCard.connected ? appRoot.colGreen : appRoot.colAccent
                                                }

                                                Column {
                                                    Layout.fillWidth: true
                                                    spacing: appRoot.sc(3)
                                                    Text {
                                                        width: parent.width
                                                        elide: Text.ElideRight
                                                        text: wifiNetCard.modelData.ssid || ""
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(0)
                                                        font.bold: wifiNetCard.connected
                                                        color: wifiNetCard.connected ? appRoot.colGreen : (wifiCardMouse.containsMouse ? appRoot.colAccent : appRoot.colFg)
                                                    }
                                                    Text {
                                                        text: (wifiNetCard.modelData.security || "Open") + " • " + wifiNetCard.sig + "%"
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-2)
                                                        color: wifiNetCard.connected ? appRoot.colGreen : appRoot.colMuted
                                                    }
                                                }

                                                PillIconBtn {
                                                    visible: !wifiNetCard.connected && (wifiNetCard.modelData.security || "Open") !== "Open"
                                                    iconText: "󰌋"
                                                    btnWidth: appRoot.sc(24)
                                                    btnHeight: appRoot.sc(24)
                                                    iconPixelSize: appRoot.fs(-1)
                                                    onClicked: {
                                                        appRoot.wifiPasswordTarget = String(wifiNetCard.modelData.ssid || "");
                                                        Qt.callLater(() => wifiPassInput.forceActiveFocus());
                                                    }
                                                }

                                                Rectangle {
                                                    width: netActionTxt.implicitWidth + appRoot.sc(14)
                                                    height: Math.max(appRoot.sc(24), netActionTxt.implicitHeight + appRoot.sc(8))
                                                    radius: appRoot.sc(7)
                                                    color: "transparent"
                                                    border.width: 0
                                                    Text {
                                                        id: netActionTxt
                                                        anchors.centerIn: parent
                                                        text: wifiNetCard.connected ? "Disconnect" : "Connect"
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-2)
                                                        font.bold: true
                                                        color: wifiNetCard.connected ? appRoot.colRed : (wifiCardMouse.containsMouse ? appRoot.colFg : appRoot.colAccent)
                                                    }
                                                    MouseArea {
                                                        id: wifiCardMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            const ssid = String(wifiNetCard.modelData.ssid || "");
                                                            if (wifiNetCard.connected)
                                                                appRoot.runStatusAction(["--wifi-disconnect", ssid]);
                                                            else
                                                                appRoot.runStatusAction(["--wifi-connect", ssid]);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: !appRoot.statusDetail.wifi_networks || appRoot.statusDetail.wifi_networks.length === 0
                                        horizontalAlignment: Text.AlignHCenter
                                        text: appRoot.sysInfo.wifi_on ? "No networks found — click Scan" : "Wi-Fi is turned off"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: appRoot.colMuted
                                        topPadding: 14
                                        bottomPadding: 14
                                    }
                                }
                            }
                        }

                        // ========== VIEW 2: BLUETOOTH ==========
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appRoot.sc(12)
                            visible: win.activeStatusPopup === "bt"

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: appRoot.sysInfo.bt_on ? "Bluetooth Active" : "Bluetooth Off"
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(0)
                                    font.bold: true
                                    color: appRoot.colFg
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: btScanTxt.implicitWidth + appRoot.sc(14)
                                    height: Math.max(appRoot.sc(24), btScanTxt.implicitHeight + appRoot.sc(8))
                                    radius: appRoot.sc(7)
                                    color: "transparent"
                                    border.width: 0
                                    visible: appRoot.sysInfo.bt_on
                                    Text {
                                        id: btScanTxt
                                        anchors.centerIn: parent
                                        text: appRoot.statusBusy ? "..." : "󰑐 Scan"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(-1)
                                        color: btScanMouse.containsMouse ? appRoot.colAccent : appRoot.colFg
                                    }
                                    MouseArea {
                                        id: btScanMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.runStatusAction(["--bt-scan"])
                                    }
                                }

                                Rectangle {
                                    width: btToggleTxt.implicitWidth + appRoot.sc(16)
                                    height: Math.max(appRoot.sc(24), btToggleTxt.implicitHeight + appRoot.sc(8))
                                    radius: appRoot.sc(7)
                                    color: "transparent"
                                    border.width: 0
                                    Text {
                                        id: btToggleTxt
                                        anchors.centerIn: parent
                                        text: appRoot.sysInfo.bt_on ? "On" : "Off"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.bold: true
                                        color: appRoot.sysInfo.bt_on ? appRoot.colAccent : appRoot.colRed
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.runStatusAction(["--bt-toggle", appRoot.sysInfo.bt_on ? "off" : "on"])
                                    }
                                }

                                PillIconBtn {
                                    iconText: "󰒓"
                                    btnWidth: appRoot.sc(26)
                                    btnHeight: appRoot.sc(24)
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: Quickshell.execDetached(["blueman-manager"])
                                }
                            }

                            Flickable {
                                id: btListFlick
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(appRoot.sc(320), Math.max(appRoot.sc(84), btListCol.implicitHeight))
                                contentWidth: width
                                contentHeight: btListCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: btListCol
                                    width: btListFlick.width
                                    spacing: Math.max(appRoot.sc(10), appRoot.itemSpacing)

                                    Repeater {
                                        model: appRoot.statusDetail.bt_devices || []
                                        delegate: Rectangle {
                                            id: btDevCard
                                            required property var modelData
                                            readonly property bool connected: !!modelData.connected

                                            Layout.fillWidth: true
                                            height: Math.max(appRoot.sc(52), btCardRow.implicitHeight + appRoot.sc(16))
                                            radius: appRoot.sc(9)
                                            color: "transparent"
                                            border.width: 0

                                            RowLayout {
                                                id: btCardRow
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: appRoot.sc(6)
                                                anchors.rightMargin: appRoot.sc(6)
                                                spacing: appRoot.sc(12)

                                                Text {
                                                    text: btDevCard.connected ? "󰂱" : "󰂯"
                                                    font.family: appRoot.iconFont
                                                    font.pixelSize: appRoot.fs(3)
                                                    color: btDevCard.connected ? appRoot.colAccent : appRoot.colDim
                                                }

                                                Column {
                                                    Layout.fillWidth: true
                                                    spacing: appRoot.sc(3)
                                                    Text {
                                                        width: parent.width
                                                        elide: Text.ElideRight
                                                        text: btDevCard.modelData.name || btDevCard.modelData.mac || "Device"
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(0)
                                                        font.bold: btDevCard.connected
                                                        color: btDevCard.connected ? appRoot.colAccent : appRoot.colFg
                                                    }
                                                    Text {
                                                        text: btDevCard.connected ? "Connected" : (btDevCard.modelData.paired ? "Paired • " + btDevCard.modelData.mac : btDevCard.modelData.mac)
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-2)
                                                        color: btDevCard.connected ? appRoot.colAccent : appRoot.colMuted
                                                    }
                                                }

                                                Rectangle {
                                                    width: btActTxt.implicitWidth + appRoot.sc(14)
                                                    height: Math.max(appRoot.sc(24), btActTxt.implicitHeight + appRoot.sc(8))
                                                    radius: appRoot.sc(7)
                                                    color: "transparent"
                                                    border.width: 0
                                                    Text {
                                                        id: btActTxt
                                                        anchors.centerIn: parent
                                                        text: btDevCard.connected ? "Disconnect" : "Connect"
                                                        font.family: appRoot.fontFamily
                                                        font.pixelSize: appRoot.fs(-2)
                                                        font.bold: true
                                                        color: btDevCard.connected ? appRoot.colRed : (btActMouse.containsMouse ? appRoot.colFg : appRoot.colAccent)
                                                    }
                                                    MouseArea {
                                                        id: btActMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            const mac = String(btDevCard.modelData.mac || "");
                                                            if (btDevCard.connected)
                                                                appRoot.runStatusAction(["--bt-disconnect", mac]);
                                                            else
                                                                appRoot.runStatusAction(["--bt-connect", mac]);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: !appRoot.statusDetail.bt_devices || appRoot.statusDetail.bt_devices.length === 0
                                        horizontalAlignment: Text.AlignHCenter
                                        text: appRoot.sysInfo.bt_on ? "No paired/discovered devices — click Scan" : "Bluetooth is turned off"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        color: appRoot.colMuted
                                        topPadding: 14
                                        bottomPadding: 14
                                    }
                                }
                            }
                        }

                        // ========== VIEW 3: AUDIO (OUTPUT + INPUT MICROPHONE) ==========
                        Flickable {
                            id: audioPanelFlick
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(appRoot.sc(420), audioCardsCol.implicitHeight)
                            contentWidth: width
                            contentHeight: audioCardsCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: win.activeStatusPopup === "audio"

                            ColumnLayout {
                                id: audioCardsCol
                                width: audioPanelFlick.width
                                spacing: appRoot.sc(14)

                                AudioSectionCard {
                                    sectionTitle: "Output Audio"
                                    iconOn: "󰕾"
                                    iconMuted: "󰖁"
                                    volPct: Number(appRoot.sysInfo.vol || 0)
                                    muted: !!appRoot.sysInfo.muted
                                    maxVol: 100
                                    devices: appRoot.statusDetail.audio_sinks || []
                                    onToggleMute: appRoot.runStatusAction(["--mute-toggle"])
                                    onVolumeMoved: newPct => appRoot.setSinkVolume(newPct)
                                    onSelectDevice: devId => appRoot.runStatusAction(["--set-sink", String(devId)])
                                }

                                AudioSectionCard {
                                    sectionTitle: "Input Audio (Mic)"
                                    iconOn: "󰍬"
                                    iconMuted: "󰍭"
                                    volPct: Number(appRoot.sysInfo.mic_vol || 100)
                                    muted: !!appRoot.sysInfo.mic_muted
                                    maxVol: 120
                                    devices: appRoot.statusDetail.audio_sources || []
                                    onToggleMute: appRoot.runStatusAction(["--mic-mute-toggle"])
                                    onVolumeMoved: newPct => appRoot.setSourceVolume(newPct)
                                    onSelectDevice: devId => appRoot.runStatusAction(["--set-source", String(devId)])
                                }
                            }
                        }

                        // ========== VIEW 4: BATTERY & POWER PROFILES ==========
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appRoot.sc(12)
                            visible: win.activeStatusPopup === "battery"

                            Rectangle {
                                Layout.fillWidth: true
                                height: Math.max(appRoot.sc(34), batHeadRow.implicitHeight + appRoot.sc(8))
                                radius: appRoot.sc(9)
                                color: "transparent"
                                border.width: 0

                                RowLayout {
                                    id: batHeadRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: appRoot.sc(4)
                                    anchors.rightMargin: appRoot.sc(4)
                                    spacing: appRoot.sc(8)

                                    Text {
                                        text: (appRoot.sysInfo.bat_status === "Charging") ? "󰂄" : "󰁹"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(4)
                                        color: appRoot.colGreen
                                    }

                                    Text {
                                        text: "Battery " + (appRoot.sysInfo.bat || 100) + "% • " + (appRoot.sysInfo.bat_status || "AC")
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(0)
                                        font.bold: true
                                        color: appRoot.colFg
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            Rectangle {
                                id: coffeeStatusCard
                                Layout.fillWidth: true
                                height: Math.max(appRoot.sc(44), coffeeCardRow.implicitHeight + appRoot.sc(10))
                                radius: appRoot.sc(9)
                                color: "transparent"
                                border.width: 0

                                RowLayout {
                                    id: coffeeCardRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: appRoot.sc(4)
                                    anchors.rightMargin: appRoot.sc(4)
                                    spacing: appRoot.sc(10)

                                    Text {
                                        text: appRoot.coffeeActive ? "󰅶" : "󰛊"
                                        font.family: appRoot.iconFont
                                        font.pixelSize: appRoot.fs(4)
                                        color: appRoot.coffeeActive ? appRoot.colAmber : appRoot.colDim
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Coffee Mode (Keep Awake)"
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(0)
                                            font.bold: appRoot.coffeeActive
                                            color: appRoot.coffeeActive ? appRoot.colAmber : (coffeeCardMouse.containsMouse ? appRoot.colAccent : appRoot.colFg)
                                        }
                                        Text {
                                            text: appRoot.coffeeActive
                                                ? "Active · Laptop will not idle, lock or sleep"
                                                : "Inactive · Click to keep laptop awake"
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-2)
                                            color: appRoot.coffeeActive ? appRoot.colAmber : appRoot.colMuted
                                        }
                                    }

                                    Text {
                                        text: appRoot.coffeeActive ? "ON" : "OFF"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-1)
                                        font.bold: true
                                        color: appRoot.coffeeActive ? appRoot.colAmber : (coffeeCardMouse.containsMouse ? appRoot.colAccent : appRoot.colMuted)
                                    }
                                }

                                MouseArea {
                                    id: coffeeCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appRoot.setCoffeeMode("toggle")
                                }
                            }

                            Text {
                                text: "POWER PROFILE"
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-2)
                                font.bold: true
                                color: appRoot.colMuted
                                topPadding: 2
                            }

                            Repeater {
                                model: [
                                    { id: "power-saver", name: "Power Saving", desc: "Max battery life & cool thermals", icon: "󰌪" },
                                    { id: "balanced", name: "Balanced", desc: "Adaptive everyday performance", icon: "󰾅" },
                                    { id: "performance", name: "Performance", desc: "Maximum CPU & system speed", icon: "󰓅" }
                                ]
                                delegate: Rectangle {
                                    id: pwrProfileCard
                                    required property var modelData
                                    readonly property bool active: (appRoot.sysInfo.power_profile || "balanced") === modelData.id
                                    readonly property color tintCol: modelData.id === "power-saver" ? appRoot.colGreen : (modelData.id === "performance" ? appRoot.colRed : appRoot.colAccent)

                                    Layout.fillWidth: true
                                    height: Math.max(appRoot.sc(44), pwrCardRow.implicitHeight + appRoot.sc(10))
                                    radius: appRoot.sc(9)
                                    color: "transparent"
                                    border.width: 0

                                    RowLayout {
                                        id: pwrCardRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: appRoot.sc(4)
                                        anchors.rightMargin: appRoot.sc(4)
                                        spacing: appRoot.sc(10)

                                        Text {
                                            text: pwrProfileCard.modelData.icon
                                            font.family: appRoot.iconFont
                                            font.pixelSize: appRoot.fs(4)
                                            color: pwrProfileCard.active ? pwrProfileCard.tintCol : appRoot.colDim
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: pwrProfileCard.modelData.name
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(0)
                                                font.bold: pwrProfileCard.active
                                                color: pwrProfileCard.active ? pwrProfileCard.tintCol : (pwrCardMouse.containsMouse ? appRoot.colAccent : appRoot.colFg)
                                            }
                                            Text {
                                                text: pwrProfileCard.modelData.desc
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                color: pwrProfileCard.active ? pwrProfileCard.tintCol : appRoot.colMuted
                                            }
                                        }

                                        Text {
                                            visible: pwrProfileCard.active
                                            text: "󰄬"
                                            font.family: appRoot.iconFont
                                            font.pixelSize: appRoot.fs(2)
                                            color: pwrProfileCard.tintCol
                                        }
                                    }

                                    MouseArea {
                                        id: pwrCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.runStatusAction(["--set-power", pwrProfileCard.modelData.id])
                                    }
                                }
                            }
                        }
                    } // statusDrawerCol
                } // statusDropdownDrawer

                // ========== TOP-CENTER EMERGING DRAWER (WEATHER & CALENDAR + CAPTURE) ==========
                Rectangle {
                    id: centerDropdownDrawer
                    anchors.top: topFrameStrip.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(appRoot.sc(380), Math.max(240, win.innerW - 40))
                    readonly property real targetHeight: win.activeCenterPopup !== ""
                        ? Math.min(appRoot.sc(540), Math.max(appRoot.sc(190), centerDrawerCol.implicitHeight + appRoot.dockPadding * 2))
                        : 0
                    height: targetHeight
                    visible: height > 1
                    radius: 0
                    color: "transparent"
                    border.width: 0
                    clip: true

                    onXChanged: unifiedFrameCanvas.requestPaint()
                    onYChanged: unifiedFrameCanvas.requestPaint()
                    onWidthChanged: unifiedFrameCanvas.requestPaint()
                    onHeightChanged: unifiedFrameCanvas.requestPaint()

                    Behavior on height {
                        NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onWheel: wheel => { wheel.accepted = true; }
                    }

                    HoverHandler {
                        id: centerDrawerHover
                        onHoveredChanged: {
                            if (hovered)
                                centerPopupCloseTimer.stop();
                            else
                                centerPopupCloseTimer.restart();
                        }
                    }

                    ColumnLayout {
                        id: centerDrawerCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: appRoot.dockPadding
                        spacing: appRoot.sc(10)

                        // ========== VIEW 5: WEATHER & 7-DAY FORECAST ==========
                        ColumnLayout {
                            id: weatherPopupCol
                            Layout.fillWidth: true
                            spacing: appRoot.sc(10)
                            visible: win.activeCenterPopup === "weather"
                            readonly property var wx: appRoot.sysInfo.weather || ({})
                            readonly property var days: Array.isArray(wx.forecast) ? wx.forecast : []

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appRoot.sc(8)

                                Text {
                                    text: weatherPopupCol.wx.icon || "󰖙"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(6)
                                    color: appRoot.colAmber
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: (weatherPopupCol.wx.city || "Kanchanpur") + " • " + (weatherPopupCol.wx.temp || "24°C")
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(1)
                                        font.bold: true
                                        color: appRoot.colFg
                                    }
                                    Text {
                                        text: (weatherPopupCol.wx.desc || "Clear")
                                            + (weatherPopupCol.wx.feels_like ? (" • Feels " + weatherPopupCol.wx.feels_like) : "")
                                            + (weatherPopupCol.wx.humidity !== undefined ? (" • " + weatherPopupCol.wx.humidity + "%") : "")
                                            + (weatherPopupCol.wx.wind ? (" • " + weatherPopupCol.wx.wind) : "")
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-2)
                                        color: appRoot.colDim
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                PillIconBtn {
                                    iconText: "󰑐"
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: appRoot.refreshWeather()
                                }

                                PillIconBtn {
                                    iconText: "󰅖"
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: win.activeCenterPopup = ""
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: appRoot.colLine
                            }

                            Text {
                                text: "7-DAY FORECAST"
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-2)
                                font.bold: true
                                color: appRoot.colMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: appRoot.sc(4)

                                Repeater {
                                    model: weatherPopupCol.days
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: appRoot.sc(30)
                                        radius: appRoot.sc(7)
                                        color: appRoot.colSurface

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: appRoot.sc(8)
                                            anchors.rightMargin: appRoot.sc(8)
                                            spacing: appRoot.sc(8)

                                            Text {
                                                Layout.preferredWidth: appRoot.sc(66)
                                                text: modelData.day || ""
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                font.bold: modelData.day === "Today"
                                                color: modelData.day === "Today" ? appRoot.colAccent : appRoot.colFg
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.preferredWidth: appRoot.sc(44)
                                                text: modelData.date || ""
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                color: appRoot.colMuted
                                            }

                                            Text {
                                                text: modelData.icon || "󰖙"
                                                font.family: appRoot.iconFont
                                                font.pixelSize: appRoot.fs(2)
                                                color: appRoot.colAmber
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.desc || ""
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                color: appRoot.colDim
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: Number(modelData.rain || 0) > 0
                                                text: "󰖗 " + modelData.rain + "%"
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                color: appRoot.colAccentAlt
                                            }

                                            Text {
                                                text: (modelData.low !== undefined ? modelData.low : "--") + "° / " + (modelData.high !== undefined ? modelData.high : "--") + "°"
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-1)
                                                font.bold: true
                                                color: appRoot.colFg
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: weatherPopupCol.days.length === 0
                                    text: "Fetching forecast..."
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(-1)
                                    color: appRoot.colMuted
                                }
                            }
                        }

                        // ========== VIEW 6: CALENDAR & CAPTURE / RECORDING PANEL ==========
                        ColumnLayout {
                            id: calCaptureCol
                            Layout.fillWidth: true
                            spacing: appRoot.sc(10)
                            visible: win.activeCenterPopup === "calendar"

                            readonly property var monthNames: [
                                "January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December"
                            ]
                            readonly property var calCells: {
                                const y = appRoot.calYear;
                                const m = appRoot.calMonth;
                                const now = new Date();
                                const isCurMonth = (now.getFullYear() === y && now.getMonth() === m);
                                const todayDate = now.getDate();
                                const firstDow = new Date(y, m, 1).getDay();
                                const daysInMonth = new Date(y, m + 1, 0).getDate();
                                const prevMonthDays = new Date(y, m, 0).getDate();
                                const cells = [];
                                for (let i = firstDow - 1; i >= 0; i--) {
                                    cells.push({ day: prevMonthDays - i, inMonth: false, isToday: false });
                                }
                                for (let d = 1; d <= daysInMonth; d++) {
                                    cells.push({ day: d, inMonth: true, isToday: isCurMonth && d === todayDate });
                                }
                                while (cells.length < 42) {
                                    cells.push({ day: cells.length - (firstDow + daysInMonth) + 1, inMonth: false, isToday: false });
                                }
                                return cells;
                            }

                            // Calendar Header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appRoot.sc(6)

                                Text {
                                    text: "󰃭"
                                    font.family: appRoot.iconFont
                                    font.pixelSize: appRoot.fs(3)
                                    color: appRoot.colAccent
                                }

                                Text {
                                    text: calCaptureCol.monthNames[appRoot.calMonth] + " " + appRoot.calYear
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(1)
                                    font.bold: true
                                    color: appRoot.colFg
                                    Layout.fillWidth: true
                                }

                                PillIconBtn {
                                    iconText: "󰅁"
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: appRoot.stepCalendarMonth(-1)
                                }

                                PillIconBtn {
                                    iconText: "󰃰"
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: appRoot.resetCalendarToToday()
                                }

                                PillIconBtn {
                                    iconText: "󰅂"
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: appRoot.stepCalendarMonth(1)
                                }

                                PillIconBtn {
                                    iconText: "󰅖"
                                    iconPixelSize: appRoot.fs(0)
                                    onClicked: win.activeCenterPopup = ""
                                }
                            }

                            // Weekday Headers
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 7
                                columnSpacing: 2

                                Repeater {
                                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                    delegate: Text {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-2)
                                        font.bold: true
                                        color: appRoot.colMuted
                                    }
                                }
                            }

                            // Calendar Grid
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 7
                                columnSpacing: 2
                                rowSpacing: 2

                                Repeater {
                                    model: calCaptureCol.calCells
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: appRoot.sc(24)
                                        radius: appRoot.sc(6)
                                        color: modelData.isToday
                                            ? appRoot.colAccent
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(modelData.day)
                                            font.family: appRoot.fontFamily
                                            font.pixelSize: appRoot.fs(-1)
                                            font.bold: modelData.isToday
                                            color: modelData.isToday
                                                ? appRoot.colBg
                                                : (modelData.inMonth ? appRoot.colFg : appRoot.colMuted)
                                            opacity: modelData.inMonth ? 1.0 : 0.45
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: appRoot.colLine
                            }

                            // Capture & Recording Section
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appRoot.sc(6)

                                Text {
                                    text: "CAPTURE & RECORDING"
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(-2)
                                    font.bold: true
                                    color: appRoot.colMuted
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    visible: !!appRoot.sysInfo.recording
                                    implicitWidth: stopRecTxt.implicitWidth + appRoot.sc(12)
                                    height: appRoot.sc(22)
                                    radius: appRoot.sc(6)
                                    color: appRoot.colRed
                                    Text {
                                        id: stopRecTxt
                                        anchors.centerIn: parent
                                        text: "󰓛 Stop Rec"
                                        font.family: appRoot.fontFamily
                                        font.pixelSize: appRoot.fs(-2)
                                        font.bold: true
                                        color: appRoot.colBg
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appRoot.runCaptureAction(appRoot.homeDir + "/.config/hypr/scripts/screenrecord.sh stop")
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: appRoot.sc(6)
                                rowSpacing: appRoot.sc(6)

                                Repeater {
                                    model: [
                                        { icon: "󰩭", label: "Shot Area", cmd: appRoot.homeDir + "/.config/hypr/scripts/screenshot.sh --area" },
                                        { icon: "󰍹", label: "Shot Screen", cmd: appRoot.homeDir + "/.config/hypr/scripts/screenshot.sh --now" },
                                        { icon: "󰍺", label: "Shot All", cmd: appRoot.homeDir + "/.config/hypr/scripts/screenshot.sh --now --all" },
                                        { icon: "󰑊", label: "Rec Area", cmd: appRoot.homeDir + "/.config/hypr/scripts/screenrecord.sh toggle --area" },
                                        { icon: "󰕧", label: "Rec Screen", cmd: appRoot.homeDir + "/.config/hypr/scripts/screenrecord.sh toggle" },
                                        { icon: "󰹑", label: "Rec All", cmd: appRoot.homeDir + "/.config/hypr/scripts/screenrecord.sh toggle --all" },
                                        { icon: "󰈊", label: "Color Pick", cmd: "c=$(hyprpicker -a); [ -n \"$c\" ] && notify-send -a 'Color Picker' 'Copied' \"$c\"" },
                                        { icon: "󰏫", label: "Annotate", cmd: "g=$(slurp); [ -n \"$g\" ] && grim -g \"$g\" - | swappy -f -" },
                                        { icon: "󰉋", label: "Captures", cmd: "xdg-open \"$HOME/Pictures/Screenshots\"" }
                                    ]
                                    delegate: Rectangle {
                                        id: capBtn
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: appRoot.sc(34)
                                        radius: appRoot.sc(8)
                                        color: capMouse.containsMouse ? appRoot.colSurfaceHover : appRoot.colSurface

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: appRoot.sc(5)
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: capBtn.modelData.icon
                                                font.family: appRoot.iconFont
                                                font.pixelSize: appRoot.fs(0)
                                                color: capBtn.modelData.label.startsWith("Rec") && appRoot.sysInfo.recording ? appRoot.colRed : appRoot.colAccent
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: capBtn.modelData.label
                                                font.family: appRoot.fontFamily
                                                font.pixelSize: appRoot.fs(-2)
                                                font.bold: capMouse.containsMouse
                                                color: capMouse.containsMouse ? appRoot.colFg : appRoot.colDim
                                            }
                                        }

                                        MouseArea {
                                            id: capMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.activeCenterPopup = "";
                                                appRoot.runCaptureAction(capBtn.modelData.cmd);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } // centerDrawerCol
                } // centerDropdownDrawer

                // ========== BOTTOM-RIGHT IN-FRAME OSD & NOTIFICATION CORNER ==========
                Rectangle {
                    id: cornerOsdNotif
                    x: win.innerRight - width
                    y: win.innerBottom - height
                    width: appRoot.osdHasBar ? appRoot.sc(268) : appRoot.sc(316)
                    height: (appRoot.osdActive && win.innerW > width + appRoot.sc(40))
                        ? (appRoot.osdHasBar ? appRoot.sc(64) : Math.min(appRoot.sc(124), Math.max(appRoot.sc(66), osdNotifCol.implicitHeight + appRoot.dockPadding * 2)))
                        : 0
                    visible: height > 1
                    color: "transparent"
                    border.width: 0
                    clip: true

                    onXChanged: unifiedFrameCanvas.requestPaint()
                    onYChanged: unifiedFrameCanvas.requestPaint()
                    onWidthChanged: unifiedFrameCanvas.requestPaint()
                    onHeightChanged: unifiedFrameCanvas.requestPaint()

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                osdHideTimer.stop();
                            else if (appRoot.osdActive)
                                osdHideTimer.restart();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appRoot.osdActive = false
                    }

                    RowLayout {
                        id: osdNotifCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Math.max(appRoot.sc(10), appRoot.dockPadding)
                        anchors.rightMargin: Math.max(appRoot.sc(10), appRoot.dockPadding)
                        spacing: appRoot.sc(10)

                        Rectangle {
                            Layout.preferredWidth: appRoot.sc(32)
                            Layout.preferredHeight: appRoot.sc(32)
                            radius: appRoot.sc(9)
                            color: "transparent"
                            border.width: 0

                            Text {
                                anchors.centerIn: parent
                                text: appRoot.osdIcon
                                font.family: appRoot.iconFont
                                font.pixelSize: appRoot.fs(3)
                                color: appRoot.osdKind === "brightness"
                                    ? appRoot.colAmber
                                    : ((appRoot.osdKind === "volume" && appRoot.sysInfo.muted) || (appRoot.osdKind === "mic" && appRoot.sysInfo.mic_muted)
                                        ? appRoot.colRed
                                        : appRoot.colAccent)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: appRoot.sc(4)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: appRoot.sc(6)

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: appRoot.osdTitle
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(0)
                                    font.bold: true
                                    color: appRoot.colFg
                                }

                                Text {
                                    visible: appRoot.osdHasBar
                                    text: appRoot.osdSubtitle
                                    font.family: appRoot.fontFamily
                                    font.pixelSize: appRoot.fs(-1)
                                    font.bold: true
                                    color: appRoot.colAccent
                                }
                            }

                            Rectangle {
                                visible: appRoot.osdHasBar
                                Layout.fillWidth: true
                                height: appRoot.sc(4)
                                radius: appRoot.sc(2)
                                color: appRoot.colLineStrong

                                Rectangle {
                                    height: parent.height
                                    radius: appRoot.sc(2)
                                    width: parent.width * Math.max(0, Math.min(1, appRoot.osdValue / 100))
                                    color: appRoot.osdKind === "brightness"
                                        ? appRoot.colAmber
                                        : ((appRoot.osdKind === "volume" && appRoot.sysInfo.muted) || (appRoot.osdKind === "mic" && appRoot.sysInfo.mic_muted)
                                            ? appRoot.colRed
                                            : appRoot.colAccent)

                                    Behavior on width {
                                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            Text {
                                visible: !appRoot.osdHasBar && appRoot.osdSubtitle !== ""
                                Layout.fillWidth: true
                                text: appRoot.osdSubtitle
                                font.family: appRoot.fontFamily
                                font.pixelSize: appRoot.fs(-1)
                                color: appRoot.colDim
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                } // cornerOsdNotif
            } // stripRoot
        } // PanelWindow
    } // Variants
}
