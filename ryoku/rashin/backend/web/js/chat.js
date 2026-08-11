// Chat panel: a pure reducer (applyEvent) that the node tests drive directly,
// plus a DOM layer that only wakes when a document exists. The reducer owns all
// protocol state so rendering stays a dumb projection of it. v2 adds models,
// commands, session info, usage, history and replay to the v1 message stream.

import { mdToHtml } from "./markdown.js";
import { wsUrl } from "./api.js";

export function initialState() {
  return {
    items: [], // ordered stream: {kind:'msg'|'tool', ...}
    permissions: [], // pending permission requests
    banner: { state: "starting", model: "", error: "" },
    busy: false,
    seq: 0,
    models: [], // [{id,name,description}]
    currentModel: "", // "provider:model"
    commands: [], // [{name,description,hint}]
    session: { id: "", title: "" },
    usage: null, // {size,used} once the daemon reports it
    history: [], // [{id,title,updatedAt,cwd}]
    replaying: false,
    activity: "", // what the agent is doing right now ("" = idle)
  };
}

// activityFor derives the passive working-strip label from a live frame:
// tool starts name the tool, thoughts read as thinking, streaming text as
// writing. Cleared on turn_end/idle.
function activityFor(ev, state) {
  switch (ev.type) {
    case "tool":
      if (ev.status === "pending" || ev.status === "in_progress") {
        return ev.title || "running a tool";
      }
      return state.activity; // completion keeps the last label until turn_end
    case "agent_thought":
      return "thinking";
    case "agent_text":
      return "writing";
    case "permission":
      return "waiting for your approval";
    default:
      return state.activity;
  }
}

function lastOpenAgentMsg(items) {
  for (let i = items.length - 1; i >= 0; i--) {
    const it = items[i];
    if (it.kind === "msg" && it.role === "agent" && it.open) return it;
  }
  return null;
}

// applyEvent(state, ev) -> next state. Never mutates the input; always returns a
// fresh object so the DOM layer can diff cheaply. ev is a daemon->client frame
// (chat WS protocol) or the local {type:'permission_reply'} echo.
export function applyEvent(state, ev) {
  const s = Object.assign({}, state);
  if (!state.replaying) s.activity = activityFor(ev, state);
  switch (ev.type) {
    case "user":
    case "user_text": {
      s.items = state.items.concat({
        kind: "msg", role: "user", text: ev.text || "",
        images: ev.images || [], open: false, id: "u" + ++s.seq,
      });
      return s;
    }
    case "agent_text": {
      let msg = lastOpenAgentMsg(state.items);
      if (!msg) {
        msg = { kind: "msg", role: "agent", text: "", thought: "", open: true, id: "a" + ++s.seq };
        s.items = state.items.concat(msg);
      } else {
        s.items = state.items.slice();
      }
      const idx = s.items.indexOf(msg);
      s.items[idx] = Object.assign({}, msg, { text: msg.text + (ev.text || "") });
      return s;
    }
    case "agent_thought": {
      let msg = lastOpenAgentMsg(state.items);
      if (!msg) {
        msg = { kind: "msg", role: "agent", text: "", thought: "", open: true, id: "a" + ++s.seq };
        s.items = state.items.concat(msg);
      } else {
        s.items = state.items.slice();
      }
      const idx = s.items.indexOf(msg);
      s.items[idx] = Object.assign({}, msg, { thought: (msg.thought || "") + (ev.text || "") });
      return s;
    }
    case "tool": {
      const at = state.items.findIndex((it) => it.kind === "tool" && it.id === ev.id);
      if (at === -1) {
        s.items = state.items.concat({
          kind: "tool", id: ev.id, title: ev.title || "", kind2: ev.kind || "",
          status: ev.status || "pending",
        });
      } else {
        s.items = state.items.slice();
        const prev = s.items[at];
        s.items[at] = Object.assign({}, prev, {
          title: ev.title != null ? ev.title : prev.title,
          kind2: ev.kind != null ? ev.kind : prev.kind2,
          status: ev.status != null ? ev.status : prev.status,
        });
      }
      return s;
    }
    case "permission": {
      s.permissions = state.permissions.concat({
        requestId: ev.requestId, title: ev.title || "", options: ev.options || [],
      });
      return s;
    }
    case "permission_reply": {
      s.permissions = state.permissions.filter((p) => p.requestId !== ev.requestId);
      return s;
    }
    case "turn_end": {
      const msg = lastOpenAgentMsg(state.items);
      if (msg) {
        s.items = state.items.slice();
        s.items[s.items.indexOf(msg)] = Object.assign({}, msg, { open: false });
      }
      // During replay a turn_end is historical: it must not clear the live busy
      // flag or trip the "response ready" toast, so leave busy as-is.
      if (!state.replaying) {
        s.busy = false;
        s.activity = "";
      }
      return s;
    }
    case "state": {
      s.banner = { state: ev.state || "", model: ev.model || state.banner.model || "", error: ev.error || "" };
      s.busy = ev.state === "busy" || ev.state === "starting";
      if (!s.busy) s.activity = "";
      return s;
    }
    case "models": {
      s.models = ev.models || [];
      s.currentModel = ev.current || "";
      return s;
    }
    case "commands": {
      s.commands = ev.commands || [];
      return s;
    }
    case "session_info": {
      s.session = { id: ev.sessionId || "", title: ev.title || "" };
      return s;
    }
    case "usage": {
      s.usage = { size: ev.size || 0, used: ev.used || 0 };
      return s;
    }
    case "history": {
      s.history = ev.sessions || [];
      return s;
    }
    case "replay_start": {
      // A load/new replays a fresh transcript: clear the stream and suppress
      // animations while historical frames stream back in.
      s.items = [];
      s.replaying = true;
      return s;
    }
    case "replay_end": {
      s.replaying = false;
      return s;
    }
    default:
      return state;
  }
}

// ---- DOM layer (browser only) ----------------------------------------------

if (typeof document !== "undefined") {
  const STATE_LABEL = {
    starting: "STARTING", ready: "READY", busy: "BUSY", dead: "OFFLINE",
  };
  const STATUS_STAMP = {
    pending: "PENDING", in_progress: "IN PROGRESS", completed: "DONE", failed: "FAILED",
  };
  const MAX_IMAGES = 3;
  const MAX_BYTES = 4 * 1024 * 1024;
  const MAX_EDGE = 1568;
  const RECENT_KEY = "rashin.recentModels";
  const reducedMotion = window.matchMedia
    ? window.matchMedia("(prefers-reduced-motion: reduce)")
    : { matches: false };

  window.initChat = function initChat(root) {
    const stream = root.querySelector("[data-chat-stream]");
    const banner = root.querySelector("[data-chat-banner]");
    const perms = root.querySelector("[data-chat-perms]");
    const form = root.querySelector("[data-chat-form]");
    const input = root.querySelector("[data-chat-input]");
    const sendBtn = root.querySelector("[data-chat-send]");
    const cancelBtn = root.querySelector("[data-chat-cancel]");
    const attachBtn = root.querySelector("[data-chat-attach]");
    const fileInput = root.querySelector("[data-chat-file]");
    const attachRow = root.querySelector("[data-attach-row]");
    const legend = root.querySelector("[data-chat-legend]");
    const modelChip = root.querySelector("[data-chat-model]");
    const modelMenu = root.querySelector("[data-model-menu]");
    const historyBtn = root.querySelector("[data-chat-history]");
    const drawer = root.querySelector("[data-chat-drawer]");
    const drawerList = root.querySelector("[data-drawer-list]");
    const newBtn = root.querySelector("[data-chat-new]");
    const toast = root.querySelector("[data-chat-toast]");
    const usageBox = root.querySelector("[data-chat-usage]");
    const usageFill = root.querySelector("[data-usage-fill]");
    const usageLabel = root.querySelector("[data-usage-label]");
    const workingBox = root.querySelector("[data-chat-working]");
    const workingLabel = root.querySelector("[data-working-label]");
    const chatTop = root.querySelector(".chat-top");

    // The thin REPLAYING banner is not in the static markup; mint it once and
    // toggle its hidden flag from state.
    let replayBanner = null;
    if (chatTop) {
      replayBanner = document.createElement("div");
      replayBanner.className = "chat-replay";
      replayBanner.textContent = "REPLAYING SESSION";
      replayBanner.hidden = true;
      chatTop.appendChild(replayBanner);
    }

    let state = initialState();
    let attachments = []; // [{data,mimeType,url}]
    let legendSel = 0;
    let ws = null;
    let backoff = 500;
    let closed = false;
    let reconnectTimer = null;
    let toastTimer = null;

    function canAnimate() {
      return !state.replaying && !reducedMotion.matches;
    }

    function send(obj) {
      if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj));
    }

    // apply() folds a frame into state, then renders. Streamed agent chunks are
    // appended incrementally (span.token-new) when animating so the whole stream
    // is not rebuilt mid-token; everything else does a full render.
    function apply(ev) {
      const prev = state;
      state = applyEvent(state, ev);
      if (ev.type === "agent_text" && canAnimate() && lastOpenAgentMsg(prev.items) && appendLiveToken(ev.text || "")) {
        return;
      }
      render();
      sideEffects(ev, prev);
    }

    function dispatch(ev) {
      state = applyEvent(state, ev);
      render();
    }

    function sideEffects(ev, prev) {
      if (ev.type === "turn_end" && !prev.replaying && document.hidden) showToast();
    }

    // ---- streaming animation --------------------------------------------
    function liveBody() {
      return stream.querySelector('.msg-agent[data-open="1"] .msg-body');
    }
    function appendLiveToken(text) {
      const body = liveBody();
      if (!body) return false;
      const caret = body.querySelector(".caret");
      const span = document.createElement("span");
      span.className = "token-new";
      span.textContent = text;
      if (caret) body.insertBefore(span, caret);
      else body.appendChild(span);
      stream.scrollTop = stream.scrollHeight;
      return true;
    }

    // ---- render pieces ---------------------------------------------------
    const emptyHTML =
      '<div class="chat-empty">' +
      '<img src="assets/chat-empty.webp" alt="" onerror="this.parentElement.hidden = true">' +
      "<p>The compass is listening. Ask about your machine.</p></div>";

    function thumbStrip(images) {
      if (!images || !images.length) return "";
      return '<div class="msg-thumbs">' + images.map((im) =>
        '<img src="data:' + esc(im.mimeType || "image/jpeg") + ";base64," + esc(im.data) + '" alt="">'
      ).join("") + "</div>";
    }

    function renderStream() {
      if (!state.items.length) {
        stream.innerHTML = emptyHTML;
        return;
      }
      stream.innerHTML = state.items.map((it) => {
        if (it.kind === "tool") {
          return (
            '<div class="tool-card" data-status="' + it.status + '">' +
            '<div class="tool-head"><span class="tool-title">' + esc(it.title) + "</span>" +
            '<span class="tool-kind">' + esc(it.kind2) + "</span></div>" +
            '<span class="stamp stamp-status">' + (STATUS_STAMP[it.status] || it.status) + "</span>" +
            "</div>"
          );
        }
        if (it.role === "user") {
          return (
            '<div class="msg msg-user"><div class="msg-head">YOU</div>' +
            '<div class="msg-body">' + esc(it.text) + thumbStrip(it.images) + "</div></div>"
          );
        }
        const thought = it.thought
          ? '<details class="thinking"><summary>THINKING</summary><div class="thought-body">' +
            esc(it.thought) + "</div></details>"
          : "";
        // Open messages render as escaped plain text so partial markdown never
        // flashes broken; on turn_end the closed message re-renders via mdToHtml
        // (linkified) and the token-new spans collapse back into clean text.
        const caret = it.open ? '<span class="caret">\u25AE</span>' : "";
        const body = it.open ? esc(it.text) + caret : mdToHtml(it.text, { breaks: true });
        return (
          '<div class="msg msg-agent" data-open="' + (it.open ? "1" : "0") + '"><div class="msg-head">\u7F85\u91DD</div>' +
          thought +
          '<div class="msg-body">' + body + "</div></div>"
        );
      }).join("");
      stream.scrollTop = stream.scrollHeight;
    }

    function renderPerms() {
      perms.innerHTML = state.permissions.map((p) => {
        const btns = p.options.map((o) => {
          const allow = /^allow/.test(o.kind || "") || /^allow/i.test(o.id || "");
          return (
            '<button class="hanko ' + (allow ? "hanko-allow" : "hanko-deny") +
            '" data-req="' + esc(p.requestId) + '" data-opt="' + esc(o.id) + '">' +
            esc(o.name || o.id) + "</button>"
          );
        }).join("");
        return (
          '<div class="perm-card"><div class="perm-title">' + esc(p.title) + "</div>" +
          '<div class="hanko-row">' + btns + "</div></div>"
        );
      }).join("");
    }

    function renderBanner() {
      const b = state.banner;
      banner.dataset.state = b.state;
      let txt = STATE_LABEL[b.state] || b.state;
      const model = shortModel(state.currentModel) || b.model;
      if (model) txt += " / " + model;
      if (b.state === "dead") {
        txt += b.error ? " / " + b.error : " / offline";
        txt += " \u2014 send to reconnect";
      } else if (b.error) {
        txt += " / " + b.error;
      }
      banner.textContent = txt;
      // A dead session revives on the next send: the daemon respawns hermes on
      // a user frame once the connection has dropped, so never lock the
      // composer over a dead state (the reported "can't use chat" dead-end).
      input.disabled = false;
      sendBtn.disabled = false;
      cancelBtn.hidden = !state.busy;
      if (replayBanner) replayBanner.hidden = !state.replaying;
    }

    function renderUsage() {
      if (!usageBox) return;
      if (!state.usage || !state.usage.size) {
        usageBox.hidden = true;
        return;
      }
      const pct = Math.min(100, Math.round((state.usage.used / state.usage.size) * 100));
      usageBox.hidden = false;
      const tier = pct < 60 ? "ok" : pct < 85 ? "warn" : "hot";
      usageBox.dataset.tier = tier;
      if (usageFill) usageFill.style.width = pct + "%";
      if (usageLabel) usageLabel.textContent = "CTX " + pct + "%";
    }

    function renderWorking() {
      if (!workingBox) return;
      const show = state.busy && !state.replaying && state.activity;
      workingBox.hidden = !show;
      if (show && workingLabel) workingLabel.textContent = state.activity;
    }

    function renderModelChip() {
      if (!modelChip) return;
      if (!state.models.length && !state.currentModel) {
        modelChip.hidden = true;
        return;
      }
      modelChip.hidden = false;
      modelChip.textContent = shortModel(state.currentModel) || "MODEL";
    }

    function render() {
      renderStream();
      renderPerms();
      renderBanner();
      renderUsage();
      renderWorking();
      renderModelChip();
      renderLegend();
      if (drawer && !drawer.hidden) renderDrawer();
    }

    // ---- slash command legend -------------------------------------------
    function legendActive() {
      const v = input.value;
      return v[0] === "/" && v.indexOf(" ") === -1;
    }
    function fuzzy(query, name) {
      query = query.toLowerCase();
      name = name.toLowerCase();
      let qi = 0;
      for (let i = 0; i < name.length && qi < query.length; i++) {
        if (name[i] === query[qi]) qi++;
      }
      return qi === query.length;
    }
    function legendMatches() {
      const q = input.value.slice(1);
      return state.commands.filter((c) => !q || fuzzy(q, c.name));
    }
    function renderLegend() {
      if (!legend) return;
      if (!legendActive() || !state.commands.length) {
        legend.hidden = true;
        return;
      }
      const matches = legendMatches();
      if (legendSel >= matches.length) legendSel = Math.max(0, matches.length - 1);
      const rows = matches.map((c, i) =>
        '<div class="legend-row' + (i === legendSel ? " is-active" : "") + '" data-cmd="' + esc(c.name) + '">' +
        '<span class="legend-name">/' + esc(c.name) + "</span>" +
        '<span class="legend-desc dim">' + esc(c.description || "") + "</span>" +
        '<span class="legend-hint dim">' + esc(c.hint || "") + "</span></div>"
      ).join("");
      const body = matches.length ? rows : '<div class="legend-row dim">no matching command</div>';
      legend.innerHTML = body +
        '<div class="legend-note dim">commands run text-only: images are dropped on /commands</div>';
      legend.hidden = false;
    }
    function pickCommand(name) {
      input.value = "/" + name + " ";
      legend.hidden = true;
      legendSel = 0;
      input.focus();
      renderLegend();
    }

    // ---- model menu ------------------------------------------------------
    function readRecent() {
      try {
        const raw = localStorage.getItem(RECENT_KEY);
        const arr = raw ? JSON.parse(raw) : [];
        return Array.isArray(arr) ? arr : [];
      } catch (err) { return []; }
    }
    function pushRecent(id) {
      try {
        const arr = [id].concat(readRecent().filter((x) => x !== id)).slice(0, 5);
        localStorage.setItem(RECENT_KEY, JSON.stringify(arr));
      } catch (err) { /* private mode: recents are best-effort */ }
    }
    function renderModelMenu(filter) {
      if (!modelMenu) return;
      const q = (filter || "").toLowerCase();
      const match = (m) => !q || (m.name + " " + m.id).toLowerCase().indexOf(q) !== -1;
      const byId = {};
      state.models.forEach((m) => { byId[m.id] = m; });
      const recent = readRecent().map((id) => byId[id]).filter((m) => m && match(m));
      const rowHTML = (m) =>
        '<button class="model-row' + (m.id === state.currentModel ? " is-current" : "") +
        '" data-model="' + esc(m.id) + '"><span class="model-dot"></span>' +
        '<span class="model-name">' + esc(m.name || m.id) + "</span>" +
        '<span class="model-id dim">' + esc(m.id) + "</span></button>";
      let html = '<input class="model-search" data-model-search placeholder="filter models" value="' + esc(filter || "") + '">';
      if (recent.length) {
        html += '<div class="model-section eyebrow">RECENT</div>' + recent.map(rowHTML).join("");
        html += '<div class="model-section eyebrow">ALL</div>';
      }
      const all = state.models.filter(match);
      html += all.length ? all.map(rowHTML).join("") : '<div class="model-row dim">no models</div>';
      modelMenu.innerHTML = html;
    }
    function openModelMenu() {
      renderModelMenu("");
      modelMenu.hidden = false;
      const search = modelMenu.querySelector("[data-model-search]");
      if (search) search.focus();
    }
    function chooseModel(id) {
      send({ type: "set_model", modelId: id });
      pushRecent(id);
      modelMenu.hidden = true;
    }

    // ---- history drawer --------------------------------------------------
    function renderDrawer() {
      if (!drawerList) return;
      if (!state.history.length) {
        drawerList.innerHTML = '<p class="dim">no sessions yet</p>';
        return;
      }
      drawerList.innerHTML = state.history.map((h) => {
        const label = h.title || (h.id ? h.id.slice(0, 8) : "untitled");
        return '<button class="drawer-row" data-session="' + esc(h.id) + '">' +
          '<span class="drawer-title">' + esc(label) + "</span>" +
          '<span class="drawer-time dim">' + esc(relTime(h.updatedAt)) + "</span></button>";
      }).join("");
    }
    function toggleDrawer() {
      if (!drawer) return;
      const opening = drawer.hidden;
      drawer.hidden = !opening;
      if (opening) {
        drawerList.innerHTML = '<p class="dim">loading...</p>';
        send({ type: "history" });
        renderDrawer();
      }
    }

    // ---- toast -----------------------------------------------------------
    function showToast() {
      if (!toast) return;
      toast.textContent = "RESPONSE READY";
      toast.hidden = false;
      if (toastTimer) clearTimeout(toastTimer);
      toastTimer = setTimeout(() => { toast.hidden = true; }, 8000);
    }

    // ---- image attachments ----------------------------------------------
    function renderAttachRow() {
      if (!attachRow) return;
      if (!attachments.length) {
        attachRow.hidden = true;
        attachRow.innerHTML = "";
        return;
      }
      attachRow.hidden = false;
      attachRow.innerHTML = attachments.map((a, i) =>
        '<span class="attach-chip"><img src="' + a.url + '" alt="">' +
        '<button type="button" class="attach-x" data-attach-i="' + i + '" aria-label="Remove">\u00d7</button></span>'
      ).join("");
    }
    function flashToast(msg) {
      if (!toast) return;
      toast.textContent = msg;
      toast.hidden = false;
      if (toastTimer) clearTimeout(toastTimer);
      toastTimer = setTimeout(() => { toast.hidden = true; }, 4000);
    }
    function downscale(file) {
      return new Promise((resolve, reject) => {
        const url = URL.createObjectURL(file);
        const img = new Image();
        img.onload = () => {
          const scale = Math.min(1, MAX_EDGE / Math.max(img.width, img.height));
          const w = Math.max(1, Math.round(img.width * scale));
          const h = Math.max(1, Math.round(img.height * scale));
          const canvas = document.createElement("canvas");
          canvas.width = w;
          canvas.height = h;
          canvas.getContext("2d").drawImage(img, 0, 0, w, h);
          URL.revokeObjectURL(url);
          const dataUrl = canvas.toDataURL("image/jpeg", 0.85);
          const base64 = dataUrl.slice(dataUrl.indexOf(",") + 1);
          resolve({ data: base64, mimeType: "image/jpeg", url: dataUrl });
        };
        img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("decode failed")); };
        img.src = url;
      });
    }
    async function addFiles(fileList) {
      // Snapshot now: callers (the file input) clear `.files` synchronously
      // after calling us, and the awaited downscale below would otherwise see a
      // truncated live FileList.
      const files = Array.from(fileList || []);
      for (const file of files) {
        if (!file.type || file.type.indexOf("image/") !== 0) continue;
        if (attachments.length >= MAX_IMAGES) { flashToast("MAX 3 IMAGES"); break; }
        let enc;
        try { enc = await downscale(file); }
        catch (err) { flashToast("IMAGE REJECTED"); continue; }
        // base64 is ~4/3 the byte size; check the decoded payload against 4MB.
        if (enc.data.length * 0.75 > MAX_BYTES) { flashToast("IMAGE OVER 4MB"); continue; }
        attachments.push(enc);
      }
      renderAttachRow();
    }

    // ---- events ----------------------------------------------------------
    perms.addEventListener("click", (e) => {
      const btn = e.target.closest(".hanko");
      if (!btn) return;
      const requestId = btn.dataset.req;
      send({ type: "permission", requestId, optionId: btn.dataset.opt });
      dispatch({ type: "permission_reply", requestId });
    });

    form.addEventListener("submit", (e) => {
      e.preventDefault();
      submit();
    });
    input.addEventListener("keydown", (e) => {
      if (legend && !legend.hidden) {
        const matches = legendMatches();
        if (e.key === "ArrowDown") { e.preventDefault(); legendSel = Math.min(legendSel + 1, matches.length - 1); renderLegend(); return; }
        if (e.key === "ArrowUp") { e.preventDefault(); legendSel = Math.max(legendSel - 1, 0); renderLegend(); return; }
        if (e.key === "Enter") { e.preventDefault(); if (matches[legendSel]) pickCommand(matches[legendSel].name); return; }
        if (e.key === "Escape") { e.preventDefault(); legend.hidden = true; return; }
      }
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        submit();
      }
    });
    input.addEventListener("input", () => {
      input.style.height = "auto";
      input.style.height = Math.min(input.scrollHeight, 160) + "px";
      legendSel = 0;
      renderLegend();
    });
    input.addEventListener("paste", (e) => {
      const files = e.clipboardData && e.clipboardData.files;
      if (files && files.length) { e.preventDefault(); addFiles(files); }
    });

    function submit() {
      const text = input.value.trim();
      if ((!text && !attachments.length) || input.disabled) return;
      const images = attachments.map((a) => ({ data: a.data, mimeType: a.mimeType }));
      send({ type: "user", text, images });
      dispatch({ type: "user", text, images });
      state.busy = true;
      attachments = [];
      renderAttachRow();
      renderBanner();
      input.value = "";
      input.style.height = "auto";
      if (legend) legend.hidden = true;
    }
    cancelBtn.addEventListener("click", () => send({ type: "cancel" }));

    if (attachBtn && fileInput) {
      attachBtn.addEventListener("click", () => fileInput.click());
      fileInput.addEventListener("change", () => { addFiles(fileInput.files); fileInput.value = ""; });
    }
    if (attachRow) {
      attachRow.addEventListener("click", (e) => {
        const x = e.target.closest("[data-attach-i]");
        if (!x) return;
        attachments.splice(+x.dataset.attachI, 1);
        renderAttachRow();
      });
    }
    stream.addEventListener("dragover", (e) => { e.preventDefault(); stream.classList.add("is-drop"); });
    stream.addEventListener("dragleave", () => stream.classList.remove("is-drop"));
    stream.addEventListener("drop", (e) => {
      e.preventDefault();
      stream.classList.remove("is-drop");
      if (e.dataTransfer && e.dataTransfer.files.length) addFiles(e.dataTransfer.files);
    });

    if (legend) {
      legend.addEventListener("mousedown", (e) => {
        const row = e.target.closest("[data-cmd]");
        if (!row) return;
        e.preventDefault();
        pickCommand(row.dataset.cmd);
      });
    }

    if (modelChip && modelMenu) {
      modelChip.addEventListener("click", () => {
        if (modelMenu.hidden) openModelMenu();
        else modelMenu.hidden = true;
      });
      modelMenu.addEventListener("input", (e) => {
        if (e.target.matches("[data-model-search]")) renderModelMenu(e.target.value);
      });
      modelMenu.addEventListener("click", (e) => {
        const row = e.target.closest("[data-model]");
        if (row) chooseModel(row.dataset.model);
      });
      document.addEventListener("click", (e) => {
        if (!modelMenu.hidden && !modelMenu.contains(e.target) && e.target !== modelChip && !modelChip.contains(e.target)) {
          modelMenu.hidden = true;
        }
      });
    }

    if (historyBtn) historyBtn.addEventListener("click", toggleDrawer);
    if (drawerList) {
      drawerList.addEventListener("click", (e) => {
        const row = e.target.closest("[data-session]");
        if (!row) return;
        send({ type: "load", sessionId: row.dataset.session });
        drawer.hidden = true;
      });
    }
    if (newBtn) {
      newBtn.addEventListener("click", () => {
        send({ type: "new" });
        drawer.hidden = true;
      });
    }
    if (drawer) {
      // The drawer closes like the model menu: outside click, Escape, or
      // navigating away from the chat panel.
      document.addEventListener("click", (e) => {
        if (drawer.hidden) return;
        if (drawer.contains(e.target)) return;
        if (historyBtn && (e.target === historyBtn || historyBtn.contains(e.target))) return;
        drawer.hidden = true;
      });
      document.addEventListener("keydown", (e) => {
        if (e.key !== "Escape") return;
        if (!drawer.hidden) drawer.hidden = true;
        if (modelMenu && !modelMenu.hidden) modelMenu.hidden = true;
      });
      window.addEventListener("hashchange", () => {
        if (location.hash !== "#/chat") {
          drawer.hidden = true;
          if (modelMenu) modelMenu.hidden = true;
        }
      });
    }
    if (toast) {
      toast.addEventListener("click", () => {
        location.hash = "#/chat";
        toast.hidden = true;
        input.focus();
      });
    }

    // ---- websocket -------------------------------------------------------
    function connect() {
      try {
        ws = new WebSocket(wsUrl("/ws/chat"));
      } catch (err) {
        scheduleReconnect();
        return;
      }
      ws.onopen = () => { backoff = 500; };
      ws.onmessage = (m) => {
        let ev;
        try { ev = JSON.parse(m.data); } catch (err) { return; }
        apply(ev);
      };
      ws.onclose = () => {
        if (!closed) {
          // The daemon replays state+models+commands on reconnect (join), so we
          // request nothing here; just flag OFFLINE and back off.
          apply({ type: "state", state: "dead", error: "connection lost" });
          scheduleReconnect();
        }
      };
      ws.onerror = () => { try { ws.close(); } catch (err) { /* noop */ } };
    }
    function scheduleReconnect() {
      reconnectTimer = setTimeout(connect, backoff);
      backoff = Math.min(backoff * 2, 8000);
    }

    render();
    connect();
    return {
      destroy() {
        closed = true;
        if (reconnectTimer) clearTimeout(reconnectTimer);
        if (toastTimer) clearTimeout(toastTimer);
        if (ws) try { ws.close(); } catch (err) { /* noop */ }
      },
    };
  };

  function shortModel(id) {
    if (!id) return "";
    const at = id.indexOf(":");
    return at === -1 ? id : id.slice(at + 1);
  }

  function relTime(iso) {
    if (!iso) return "";
    const t = Date.parse(iso);
    if (isNaN(t)) return "";
    const s = Math.max(0, (Date.now() - t) / 1000);
    if (s < 60) return "just now";
    const m = Math.floor(s / 60);
    if (m < 60) return m + "m ago";
    const h = Math.floor(m / 60);
    if (h < 24) return h + "h ago";
    const d = Math.floor(h / 24);
    if (d < 7) return d + "d ago";
    return Math.floor(d / 7) + "w ago";
  }

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
}
