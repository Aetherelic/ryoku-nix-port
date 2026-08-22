// Ryoku Theme popup: single toggle for the optional global recolor.
const api = globalThis.browser || globalThis.chrome;
const box = document.getElementById("recolor");

api.storage.local.get("recolorSites", (d) => {
  box.checked = !!(d && d.recolorSites);
});

box.addEventListener("change", () => {
  api.storage.local.set({ recolorSites: box.checked }, () => {
    api.runtime.sendMessage({ type: "ryoku-rebroadcast" }); // refresh open tabs now
  });
});
