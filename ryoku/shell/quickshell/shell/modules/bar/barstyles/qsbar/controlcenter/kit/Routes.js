.pragma library

// The Shell Studio's routes, in rail order. One entry per page: its Latin name,
// its kanji seal (a real word, per the desktop's language, never decoration), the
// one-line summary the head prints, and the words search matches on.
//
// The rail groups these into BAR / DESK / SHELL (see CcRail); this file stays the
// single source of what a route is called. Plugins and diagnostics are
// deliberately absent: Ryoku owns plugins through the shell plugin runtime plus
// ryostore, and health through `ryoku doctor`.
var ROUTES = [
    { id: "bars",     label: "Bar",      gloss: "\u5e2f",       file: "BarsRoute",
      desc: "Where the bar sits, what shape it takes, how its surface reads.",
      icon: "view_agenda",
      keywords: "position top bottom form full fit dock notch islands surface border panel tooltip corners depth frost gap accent colour layout edit restore animation drift" },
    { id: "widgets",  label: "Widgets",  gloss: "\u90e8\u54c1", file: "AppearanceRoute",
      desc: "Which widgets the bar carries, and how each one is drawn.",
      icon: "brush",
      keywords: "widget icon fill colour visibility hide show compact density split island ai claude codex opencode temperature sensor" },
    { id: "logo",     label: "Logo",     gloss: "\u5370",       file: "LogoRoute",
      desc: "The mark in the launcher pill: a wordmark or a glyph.",
      icon: "flag",
      keywords: "launcher ryoku kanji wordmark brand mark glyph icon distro arch nixos debian" },
    { id: "spaces",   label: "Spaces",   gloss: "\u9593",       file: "WorkspacesRoute",
      desc: "How many workspaces the bar shows, and the marker each one wears.",
      icon: "grid_view",
      keywords: "workspace space active five ten marker dots numbers glyph kanji rings aurora pacman" },
    { id: "pickers",  label: "Pickers",  gloss: "\u9078",       file: "PickersRoute",
      desc: "The layout the wallpaper and screenshot pickers open in.",
      icon: "image",
      keywords: "picker wallpaper theme screenshot video carousel hearthstone tanzaku layout" },
    { id: "dock",     label: "Dock",     gloss: "\u53f0",       file: "DockRoute",
      desc: "The app dock on the edge opposite the bar.",
      icon: "dock_to_bottom",
      keywords: "dock app pinned pin edge autohide auto hide magnify frost depth shadow label media chip peek" },
    { id: "desktop",  label: "Desktop",  gloss: "\u5353\u4e0a", file: "DesktopRoute",
      desc: "What rides the wallpaper: widgets, the spectrum and depth.",
      icon: "desktop_windows",
      keywords: "desktop widget clock calendar music all-in-one stats weather notes visualiser visualizer spectrum place depth cutout foreground subject compose okuyuki" },
    { id: "system",   label: "System",   gloss: "\u5236\u5fa1", file: "SystemRoute",
      desc: "The switches you reach for mid-work, and the shell's own actions.",
      icon: "tune",
      keywords: "do not disturb dnd keep awake caffeine game mode night light low power reduce motion reload shell settings wallpaper switch" },
    { id: "session",  label: "Session",  gloss: "\u7d42",       file: "SessionRoute",
      desc: "Lock, sleep, restart, power off.",
      icon: "power_settings_new",
      keywords: "lock session suspend sleep reboot restart shutdown power off logout" }
];

function byId(id) {
    for (var i = 0; i < ROUTES.length; i++)
        if (ROUTES[i].id === id) return ROUTES[i];
    return null;
}

function labelFor(id) {
    var r = byId(id);
    return r ? r.label : id;
}

function fileFor(id) {
    var r = byId(id);
    return r ? r.file : "";
}

function indexOf(id) {
    for (var i = 0; i < ROUTES.length; i++)
        if (ROUTES[i].id === id) return i;
    return -1;
}
