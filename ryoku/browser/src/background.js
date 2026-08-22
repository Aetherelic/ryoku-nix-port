// Ryoku Theme background: bridges the desktop palette into the browser.
// MV3 service worker (Chromium) and MV2 background script (Firefox) both run this.
const api = globalThis.browser || globalThis.chrome;
const HOST = "ryoku_theme";

// M3 role -> Firefox theme.colors mapping (ported from caelestia-firefox).
function themeColors(c) {
  return {
    frame: c.surface_dim || c.surface,
    frame_inactive: c.surface_dim || c.surface,
    toolbar: c.surface_container,
    toolbar_text: c.on_surface,
    toolbar_field: c.surface_bright,
    toolbar_field_text: c.on_surface_variant,
    toolbar_field_focus: c.surface_bright,
    toolbar_field_text_focus: c.on_surface,
    toolbar_field_border: c.surface_bright,
    toolbar_field_border_focus: c.primary,
    toolbar_field_highlight: c.primary,
    toolbar_field_highlight_text: c.on_primary,
    toolbar_top_separator: c.surface_container,
    toolbar_bottom_separator: c.surface,
    tab_selected: c.surface_container,
    tab_line: c.surface_container,
    tab_text: c.on_surface,
    tab_background_text: c.outline,
    tab_loading: c.primary,
    icons: c.secondary,
    icons_attention: c.primary,
    popup: c.surface_container,
    popup_text: c.on_surface,
    popup_border: c.outline_variant,
    popup_highlight: c.primary,
    popup_highlight_text: c.on_primary,
    ntp_background: c.surface,
    ntp_text: c.on_surface,
    ntp_card_background: c.surface_container,
    bookmark_text: c.on_surface,
    button_background_hover: c.surface_container_high,
    button_background_active: c.surface_container_highest,
    sidebar: c.surface_container_high,
    sidebar_text: c.on_surface,
    sidebar_highlight: c.secondary_container,
    sidebar_highlight_text: c.on_secondary_container,
  };
}

// Firefox only: live chrome recolor. Chromium has no theme.update at runtime.
function applyFirefoxTheme(msg) {
  if (!api.theme || !api.theme.update) return;
  const map = themeColors(msg.colors || {});
  const colors = {};
  for (const k in map) if (map[k]) colors[k] = map[k]; // drop roles the host omits
  api.theme.update({
    colors,
    properties: { color_scheme: msg.mode, content_color_scheme: msg.mode },
  });
}

// Keep the last palette so MV3 restarts and content scripts can read it.
function persist(msg) {
  api.storage.local.set({ ryokuPalette: { mode: msg.mode, colors: msg.colors } });
}

// Push the palette to every tab so content scripts recolor live.
function broadcast(pal) {
  if (!pal || !pal.colors) return;
  api.tabs.query({}, (tabs) => {
    for (const t of tabs) {
      if (t.id == null) continue;
      api.tabs.sendMessage(
        t.id,
        { type: "ryoku-palette", mode: pal.mode, colors: pal.colors },
        () => void api.runtime.lastError // swallow "no receiver" on tabs without our script
      );
    }
  });
}

function handleMessage(msg) {
  if (!msg || !msg.colors) return; // ignore hello/unknown frames
  applyFirefoxTheme(msg);
  persist(msg);
  broadcast(msg);
}

let port = null;
function connect() {
  try {
    port = api.runtime.connectNative(HOST);
  } catch (e) {
    port = null;
    return;
  }
  port.onMessage.addListener(handleMessage);
  port.onDisconnect.addListener(() => {
    port = null;
    setTimeout(connect, 5000); // host or daemon restarted; retry
  });
  try {
    port.postMessage({ type: "hello" });
  } catch (e) {
    // host may not expect input; harmless
  }
}
function ensureConnected() {
  if (!port) connect();
}

// Popup toggled the recolor: rebroadcast the stored palette to refresh tabs.
api.runtime.onMessage.addListener((m) => {
  if (m && m.type === "ryoku-rebroadcast") {
    api.storage.local.get("ryokuPalette", (d) => {
      if (d && d.ryokuPalette) broadcast(d.ryokuPalette);
    });
  }
});

if (api.runtime.onStartup) api.runtime.onStartup.addListener(ensureConnected);
if (api.runtime.onInstalled) api.runtime.onInstalled.addListener(ensureConnected);
connect();
