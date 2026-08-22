// Ryoku Theme content script: exposes palette CSS vars and an optional recolor.
// Runs at document_start on all pages.
const api = globalThis.browser || globalThis.chrome;
const STYLE_ID = "ryoku-recolor";

let current = null; // last palette colors {role: "#rrggbb"}
let recolorOn = false;

function kebab(s) {
  return s.replace(/_/g, "-");
}

// :root vars for every role the host sent, plus the guarded global recolor.
function buildCss(colors, recolor) {
  let vars = "";
  for (const k in colors) if (colors[k]) vars += "--ryoku-" + kebab(k) + ":" + colors[k] + ";";
  let css = ":root{" + vars + "}";
  if (recolor) {
    css += "html,body{background-color:var(--ryoku-surface)!important;color:var(--ryoku-on-surface)!important;}";
    css += "a,a:link,a:visited{color:var(--ryoku-primary)!important;}";
  }
  return css;
}

function apply() {
  if (!current) return;
  const root = document.documentElement;
  if (!root) return;
  let style = document.getElementById(STYLE_ID);
  if (!style) {
    style = document.createElement("style");
    style.id = STYLE_ID;
    root.appendChild(style); // valid before <head> exists at document_start
  }
  style.textContent = buildCss(current, recolorOn);
}

function init() {
  api.storage.local.get(["ryokuPalette", "recolorSites"], (d) => {
    recolorOn = !!(d && d.recolorSites);
    if (d && d.ryokuPalette) current = d.ryokuPalette.colors;
    apply();
  });
  api.runtime.onMessage.addListener((m) => {
    if (m && m.type === "ryoku-palette") {
      current = m.colors;
      apply();
    }
  });
  if (api.storage.onChanged) {
    api.storage.onChanged.addListener((changes, area) => {
      if (area !== "local") return;
      if (changes.recolorSites) recolorOn = !!changes.recolorSites.newValue;
      if (changes.ryokuPalette && changes.ryokuPalette.newValue) current = changes.ryokuPalette.newValue.colors;
      apply();
    });
  }
}

// Never recolor the extension's own pages.
if (location.protocol !== "moz-extension:" && location.protocol !== "chrome-extension:") init();
