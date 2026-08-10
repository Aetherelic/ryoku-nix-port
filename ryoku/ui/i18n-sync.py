#!/usr/bin/env python3
"""Ryoku i18n sync: keep the per-language translation files current from English.

A developer only ever writes English (wrapped in `I18n.tr("...")`, or as a hub
schema label/desc/group). This tool does the rest:

  extract  scan the tree for every English UI string -> translations/en.json
  sync     for each target language, translate ONLY the strings it is missing
           (keeping what is already translated and any human overrides), so a
           normal update translates a handful of new strings, never the file.
           --engine google  keyless Google endpoint (default; free, no secret,
                            but context-blind: "Shell" may become a seashell).
           --engine llm     a configured LLM with a domain prompt + glossary,
                            so word senses ("Shell" = the desktop shell) and
                            length are honoured. Needs an API key.
           --force          re-translate every string, not just the missing
                            ones (a one-time pass to upgrade old translations),
                            overrides still win.
           --strict         exit non-zero if any missing string got no
                            translation (so CI surfaces the gap instead of
                            silently shipping English).
  check    report translations that are much longer than their English source
           (the cause of overflowing/overlapping UI). --strict to fail on them.
  llm      generate a full language into the layered config dir
           (~/.config/ryoku/i18n/<lang>.json), for a higher-quality pass or a
           language Ryoku doesn't ship. Uses the same prompt + glossary.
  ensure   create ~/.config/ryoku/i18n-llm.json from a template if absent, so
           the user has a key file to fill in.

The LLM is configured either by ~/.config/ryoku/i18n-llm.json or by environment
(RYOKU_I18N_PROVIDER / _KEY / _MODEL / _URL), env winning, so CI can drive it
from a repository secret with no committed key. OpenRouter is the recommended
backend (OpenAI-compatible, one key, cheap models); Anthropic and OpenAI work
too. Placeholders (%1, %2, ...) are shielded so they survive translation, and
overrides/<lang>.json always wins, so a human fix is never overwritten.

  python3 i18n-sync.py extract
  python3 i18n-sync.py sync                       # all targets, Google
  python3 i18n-sync.py sync --engine llm          # all targets, LLM
  python3 i18n-sync.py sync --engine llm --force  # full LLM re-translate
  python3 i18n-sync.py check --strict             # length guard
"""

import json
import os
import random
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
TRANS = os.path.join(HERE, "translations")
OVERRIDES = os.path.join(TRANS, "overrides")

# file name -> Google target code. "pt" is Brazilian on the endpoint and "pt-PT"
# is European, so the generic "pt" file takes European and "pt_BR" Brazilian.
TARGETS = {"es": "es", "fr": "fr", "pt": "pt-PT", "pt_BR": "pt"}

# human names for the LLM prompt (the endpoint code is meaningless to a model).
LANG_NAMES = {
    "es": "Spanish",
    "fr": "French",
    "pt": "European Portuguese (pt-PT)",
    "pt_BR": "Brazilian Portuguese (pt-BR)",
}

QML_ROOT = os.path.join(REPO, "ryoku")
SCHEMA_DIR = os.path.join(REPO, "ryoku", "hub", "quickshell", "schema")

TR_CALL = re.compile(r"""I18n\.tr\(\s*(["'])((?:\\.|(?!\1).)*)\1""")
SCHEMA_FIELD = re.compile(r'"(?:tab|label|desc|group)"\s*:\s*"((?:\\.|[^"\\])*)"')

# shield %1..%9 as private-use codepoints so the translator leaves them intact.
PU_BASE = 0xE000


def _unescape(lit):
    """Turn a source string literal body into its runtime value (\\n, \\" ...)."""
    try:
        return json.loads('"' + lit.replace('"', '\\"') + '"')
    except Exception:
        return lit


# schema .js for full-bleed pages is documentation, not rendered copy: its
# label/desc/group hold engineering notes, not UI. These markers drop that noise
# so only real, displayed strings become translation keys.
NOISE = ("SettingSection", "PluginPlacementEditor", "disclosure)", "readout)",
         "Repeater", "bespoke", "transient page state", "(no ", "(none", "(header",
         "(action", "(install", "(bottom", "(plugin", "(embedded", "(field")


def _noise(s):
    return s.startswith("(") or any(n in s for n in NOISE)


def _brand(s):
    return any(ord(c) >= 0x3000 for c in s)          # CJK / kana / kanji

OPTS_ARR = re.compile(r'"opts"\s*:\s*\[([^\]]*)\]', re.S)
PAGE_OPTS = re.compile(r'\boptions\s*:\s*\[([^\]]*)\]', re.S)   # inline page option arrays
STR_LIT = re.compile(r'"((?:\\.|[^"\\])*)"')
# data-model display fields, key quoted ("label":) or not (label:).
MODEL_LABEL = re.compile(r'\b(?:label|name|desc|altLabel)"?\s*:\s*"((?:\\.|[^"\\])*)"')


def extract_keys():
    keys = set()
    for root, _, files in os.walk(QML_ROOT):
        for f in files:
            if not f.endswith(".qml"):
                continue
            # vendored Qt imports are symlinks into /usr/lib/qt6; on a runner
            # without Qt they dangle, so skip anything that won't open.
            try:
                text = open(os.path.join(root, f), encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for _, body in TR_CALL.findall(text):
                s = _unescape(body).strip()
                if s:
                    keys.add(s)          # explicit tr() calls are always kept
    if os.path.isdir(SCHEMA_DIR):
        for f in os.listdir(SCHEMA_DIR):
            if not f.endswith(".js"):
                continue
            text = open(os.path.join(SCHEMA_DIR, f), encoding="utf-8", errors="ignore").read()
            for body in SCHEMA_FIELD.findall(text):
                s = _unescape(body).strip()
                if s and not _noise(s):
                    keys.add(s)
            # seg/chips option values (the controls translate their display)
            for arr in OPTS_ARR.findall(text):
                for body in STR_LIT.findall(arr):
                    s = _unescape(body).strip()
                    if s and not _noise(s) and not _brand(s):
                        keys.add(s)
    # the Hub rail's nav + group names are data-driven, so I18n.tr() wraps them by
    # variable, not literal; pull them from Hub.qml's groups array (unquoted
    # `name: "..."`, so the quoted-key kanji jpName map is not matched).
    hub = os.path.join(REPO, "ryoku", "hub", "quickshell", "Hub.qml")
    if os.path.isfile(hub):
        text = open(hub, encoding="utf-8", errors="ignore").read()
        for body in re.findall(r'\bname:\s*"([^"]+)"', text):
            s = body.strip()
            if s and not _noise(s):
                keys.add(s)
    # each page declares its title/eyebrow/blurb as string properties, wrapped by
    # variable at render, so pull the literals from the page files.
    pages = os.path.join(REPO, "ryoku", "hub", "quickshell", "pages")
    if os.path.isdir(pages):
        for f in os.listdir(pages):
            if not f.endswith(".qml"):
                continue
            text = open(os.path.join(pages, f), encoding="utf-8", errors="ignore").read()
            for body in re.findall(r'\bp(?:Title|Eyebrow|Blurb)\s*:\s*"((?:\\.|[^"\\])*)"', text):
                s = _unescape(body).strip()
                if s and not _noise(s):
                    keys.add(s)
            # data-model display labels ({key, label} arrays, FnCard names, ...);
            # the controls / render sites translate them, brand kana excluded.
            for body in MODEL_LABEL.findall(text):
                s = _unescape(body).strip()
                if s and not _noise(s) and not _brand(s):
                    keys.add(s)
            # inline option arrays in a page (options: ["FOLLOW","LIGHT",...]);
            # a control translates the display, the value stays the source string.
            for arr in PAGE_OPTS.findall(text):
                for body in STR_LIT.findall(arr):
                    s = _unescape(body).strip()
                    if s and not _noise(s) and not _brand(s):
                        keys.add(s)
    return keys


def load_json(path):
    try:
        return json.load(open(path, encoding="utf-8"))
    except Exception:
        return {}


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(dict(sorted(obj.items())), fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def cmd_extract():
    keys = extract_keys()
    write_json(os.path.join(TRANS, "en.json"), {k: k for k in keys})
    print(f"extract: {len(keys)} strings -> translations/en.json")


def shield(s):
    return re.sub(r"%(\d)", lambda m: chr(PU_BASE + int(m.group(1))), s)


def unshield(s):
    out = []
    for c in s:
        o = ord(c)
        out.append("%" + str(o - PU_BASE) if PU_BASE <= o <= PU_BASE + 9 else c)
    return "".join(out)


def _sanitize(s):
    # the repo's pre-commit forbids em-dashes in text files (and en-dashes read
    # as machine-styled); translators emit both, so normalise them to a hyphen.
    return s.replace("\u2014", "-").replace("\u2013", "-")


def google_translate(text, tl, tries=4):
    q = shield(text)
    url = "https://translate.googleapis.com/translate_a/single?" + urllib.parse.urlencode(
        {"client": "gtx", "sl": "en", "tl": tl, "dt": "t", "q": q})
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            out = "".join(seg[0] for seg in data[0] if seg and seg[0])
            return _sanitize(unshield(out))
        except Exception as e:
            if attempt == tries - 1:
                print(f"  ! translate failed ({tl}): {e}", file=sys.stderr)
                return None
            # exponential backoff + jitter: datacenter IPs (CI) get rate-limited
            # by the keyless endpoint, and the block clears if we back off.
            time.sleep(1.5 * (attempt + 1) + random.random())
    return None


# ── glossary: the domain knowledge Google cannot have and an LLM can ──────────
# Ryoku is a Linux/Wayland desktop shell, so its words carry software senses, not
# everyday ones. KEEP stays verbatim in every language; SENSE disambiguates the
# words a generic translator gets wrong ("Shell" -> command-line shell, never a
# seashell). Both are injected into the LLM prompt.
KEEP = [
    "Ryoku", "Wi-Fi", "Bluetooth", "GPU", "CPU", "RAM", "VPN", "SSID", "DNS",
    "IP", "MAC", "USB", "HDMI", "RGB", "PID", "OSD", "QR", "PipeWire",
    "PulseAudio", "Wayland", "Hyprland", "Niri", "Sway", "systemd",
    "opencode", "codex", "Whisper", "gpu-screen-recorder",
]
SENSE = {
    "Shell": "the desktop shell / Unix command-line shell software, never a seashell",
    "Bar": "the desktop top panel / status bar, not a place that serves drinks",
    "Dock": "the application dock / taskbar",
    "Tray": "the system tray (notification area)",
    "Idle": "the session's idle / inactivity state",
    "Lock": "locking the screen",
    "Sink": "an audio output device",
    "Source": "an audio input device",
    "Mount": "mounting a filesystem / drive",
    "Window": "an application window (window manager)",
    "Workspace": "a virtual desktop / workspace",
    "Tile": "a tiling window layout",
    "Key": "a keyboard key or a config key, not a door key",
    "Launcher": "the application launcher",
    "Hero": "the large feature widget / image / clock area of a page, not a person or superhero",
    "Deck": "a stacked panel of results (e.g. the launcher result deck), not a card deck or a ship deck",
    "Frost": "a frosted-glass blur effect (also frosts / frosted), not weather or ice",
    "Passthrough": "GPU passthrough (a VM gets direct GPU access), not a keyboard shortcut",
    "Dictation": "voice dictation / speech to text, never dictatorship",
    "Clockwork": "a clockwork gears mechanism, not a watchmaker",
    "X-ray": "a see-through blur that reveals the wallpaper, not medical imaging",
    "Snap": "snapping / aligning a window to a screen edge, not attaching",
    "Reflection": "a visual mirror reflection, not contemplation",
    "Passes": "rendering / blur passes (a count), not passages or walkways",
    "Fade-in": "content appearing as opacity rises; fade-out is the reverse, never swap them",
}


def build_prompt(lang_name, chunk):
    senses = "".join(f'    - "{t}": {d}\n' for t, d in SENSE.items())
    return (
        f"You translate UI strings for Ryoku, a Linux/Wayland desktop shell "
        f"(status bars, launcher, control center, notifications, settings). "
        f"Translate from English into {lang_name}.\n"
        "Rules:\n"
        "- Return ONLY a JSON object mapping each English source string to its "
        "translation. No prose, no code fences.\n"
        "- Match the terse tone of a settings app. Keep each translation as short "
        "as the English, and never more than ~1.3x its character length, so the "
        "UI does not overflow.\n"
        "- Preserve %1 %2 ... placeholders exactly, including their order's meaning.\n"
        "- Do not use em dashes or en dashes; use a comma, colon, or parentheses.\n"
        f"- Keep these terms untranslated: {', '.join(KEEP)}.\n"
        "- These words are desktop-software terms, not everyday language:\n"
        f"{senses}"
        "\nStrings to translate:\n"
        + json.dumps({k: k for k in chunk}, ensure_ascii=False)
    )


def _cfg_home():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")


LLM_CFG = os.path.join(_cfg_home(), "ryoku", "i18n-llm.json")
GEN_DIR = os.path.join(_cfg_home(), "ryoku", "i18n")

LLM_CFG_TEMPLATE = {
    "_help": ("Paste your API key into \"key\". The default is OpenRouter "
              "(OpenAI-compatible, one key for every model, cheap): get a key at "
              "https://openrouter.ai/keys and pick a model at "
              "https://openrouter.ai/models . For vanilla OpenAI set provider "
              "\"openai\" and url \"\"; for Anthropic set provider \"anthropic\". "
              "Any field can also be set via env: RYOKU_I18N_PROVIDER / _KEY / "
              "_MODEL / _URL (env wins, used by CI)."),
    "provider": "openai",
    "url": "https://openrouter.ai/api/v1/chat/completions",
    "model": "google/gemini-2.5-flash",
    "key": "",
}


def load_llm_cfg():
    """File config overlaid with environment (env wins), so CI drives it from a
    secret with nothing committed."""
    cfg = load_json(LLM_CFG)
    env = os.environ
    for field, var in (("provider", "RYOKU_I18N_PROVIDER"), ("key", "RYOKU_I18N_KEY"),
                       ("model", "RYOKU_I18N_MODEL"), ("url", "RYOKU_I18N_URL")):
        val = env.get(var)
        if val:
            cfg[field] = val
    return cfg


def seed_llm_cfg():
    """Create the LLM key file from the template if absent. Idempotent."""
    if os.path.exists(LLM_CFG):
        return False
    os.makedirs(os.path.dirname(LLM_CFG), exist_ok=True)
    with open(LLM_CFG, "w", encoding="utf-8") as fh:
        json.dump(LLM_CFG_TEMPLATE, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    os.chmod(LLM_CFG, 0o600)
    return True


def cmd_ensure():
    seed_llm_cfg()
    return 0


def llm_call(cfg, prompt):
    provider = cfg.get("provider", "openai")
    key = cfg.get("key", "")
    if provider == "anthropic":
        model = cfg.get("model") or "claude-3-5-haiku-latest"
        url = "https://api.anthropic.com/v1/messages"
        body = {"model": model, "max_tokens": 4096,
                "messages": [{"role": "user", "content": prompt}]}
        headers = {"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
    else:  # openai-compatible (OpenRouter by default, or vanilla OpenAI)
        model = cfg.get("model") or "gpt-4o-mini"
        url = cfg.get("url") or "https://api.openai.com/v1/chat/completions"
        body = {"model": model, "messages": [{"role": "user", "content": prompt}]}
        headers = {"Authorization": "Bearer " + key, "content-type": "application/json",
                   "X-Title": "Ryoku i18n",
                   "HTTP-Referer": "https://github.com/noctalia-dev"}
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = json.loads(resp.read().decode())
    if provider == "anthropic":
        return data["content"][0]["text"]
    return data["choices"][0]["message"]["content"]


def _extract_json(text):
    a, b = text.find("{"), text.rfind("}")
    return json.loads(text[a:b + 1]) if a >= 0 and b > a else {}


def llm_translate(cfg, lang, keys, batch=40):
    """Translate `keys` into `lang` (a file code or name) via the model, in
    batches with the domain prompt + glossary. A batch whose reply is not valid
    JSON is bisected and retried, so one malformed string never sinks a whole
    batch. Returns {key: translation} for what came back; caller picks fallback."""
    name = LANG_NAMES.get(lang, lang)
    out = {}

    def run(chunk, depth):
        if not chunk:
            return
        try:
            got = _extract_json(llm_call(cfg, build_prompt(name, chunk)))
            out.update({k: _sanitize(v) for k, v in got.items()
                        if k in chunk and isinstance(v, str) and v})
        except Exception as e:
            if len(chunk) > 1 and depth < 6:
                mid = len(chunk) // 2
                run(chunk[:mid], depth + 1)
                run(chunk[mid:], depth + 1)
            else:
                print(f"  ! llm failed ({lang}) on {chunk!r}: {str(e)[:80]}", file=sys.stderr)

    for i in range(0, len(keys), batch):
        run(keys[i:i + batch], 0)
        print(f"  {lang}: {len(out)}/{len(keys)}")
    return out


def _parse_sync_args(argv):
    engine, force, strict, langs = "google", False, False, []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--engine":
            engine = argv[i + 1]
            i += 2
        elif a == "--force":
            force = True
            i += 1
        elif a == "--strict":
            strict = True
            i += 1
        else:
            langs.append(a)
            i += 1
    return engine, force, strict, langs


def cmd_sync(argv):
    engine, force, strict, langs = _parse_sync_args(argv)
    if engine not in ("google", "llm"):
        print(f"sync: unknown engine {engine} (google|llm)", file=sys.stderr)
        return 2
    en = load_json(os.path.join(TRANS, "en.json"))
    if not en:
        print("sync: run extract first (translations/en.json is empty)", file=sys.stderr)
        return 1
    langs = langs or list(TARGETS)

    cfg = None
    if engine == "llm":
        cfg = load_llm_cfg()
        if not cfg.get("key"):
            print("sync --engine llm: no API key. Set RYOKU_I18N_KEY (CI) or edit "
                  f"{LLM_CFG} (run `ensure` to create it).", file=sys.stderr)
            return 1

    unresolved = 0
    for lang in langs:
        tl = TARGETS.get(lang)
        if not tl:
            print(f"sync: unknown language {lang}", file=sys.stderr)
            continue
        existing = load_json(os.path.join(TRANS, f"{lang}.json"))
        overrides = load_json(os.path.join(OVERRIDES, f"{lang}.json"))

        # a string needs translating unless a human override covers it, or (when
        # not forcing) it is already translated (present and not equal to English).
        def done(k):
            return k in overrides or (not force and k in existing and existing[k] != k)
        missing = [k for k in en if not done(k)]

        translated = {}
        if missing:
            if engine == "llm":
                translated = llm_translate(cfg, lang, missing)
            else:
                for k in missing:
                    t = google_translate(k, tl)
                    if t:
                        translated[k] = t
                    time.sleep(0.25)                  # be gentle on the endpoint

        out, failed = {}, []
        for k in en:
            if k in overrides:
                out[k] = overrides[k]
            elif not force and k in existing and existing[k] != k:
                out[k] = existing[k]                  # keep prior translation
            elif k in translated:
                out[k] = translated[k]
            else:
                out[k] = _sanitize(k)                  # unresolved -> English source
                if k in missing:
                    failed.append(k)                  # a real miss, not a kept string
        write_json(os.path.join(TRANS, f"{lang}.json"), out)
        unresolved += len(failed)
        print(f"sync[{engine}] {lang}: {len(out)} strings "
              f"({len(translated)} newly translated, {len(overrides)} overrides, "
              f"{len(failed)} unresolved)")

    if strict and unresolved:
        print(f"strict: {unresolved} string(s) left untranslated", file=sys.stderr)
        return 1
    return 0


def cmd_check(argv):
    """Flag translations far longer than their English source: the cause of
    overflowing/overlapping UI. Advisory by default; --strict fails."""
    strict = "--strict" in argv
    factor, min_src = 1.5, 12
    for a in argv:
        if a.startswith("--factor="):
            factor = float(a.split("=", 1)[1])
    en = load_json(os.path.join(TRANS, "en.json"))
    if not en:
        print("check: run extract first (translations/en.json is empty)", file=sys.stderr)
        return 1
    offenders = []
    for lang in TARGETS:
        m = load_json(os.path.join(TRANS, f"{lang}.json"))
        for k, src in en.items():
            tr = m.get(k)
            if not tr or tr == src or len(src) < min_src:
                continue
            if len(tr) > len(src) * factor:
                offenders.append((len(tr) / len(src), lang, src, tr))
    offenders.sort(reverse=True)
    for ratio, lang, src, tr in offenders:
        print(f"  {lang} {ratio:.2f}x  {src!r} -> {tr!r}")
    print(f"check: {len(offenders)} translation(s) exceed {factor:.2f}x the "
          f"English length (source >= {min_src} chars)")
    return 1 if strict and offenders else 0


def cmd_llm(langs):
    """Full LLM generation into the layered config overlay (~/.config/ryoku/i18n)."""
    seed_llm_cfg()
    cfg = load_llm_cfg()
    if not cfg.get("key"):
        print(f"llm: no API key set. Edit {LLM_CFG} and paste your key into the "
              "\"key\" field (or set RYOKU_I18N_KEY), then try again.", file=sys.stderr)
        return 1
    en = load_json(os.path.join(TRANS, "en.json"))
    if not en:
        cmd_extract()
        en = load_json(os.path.join(TRANS, "en.json"))
    keys = list(en)
    for lang in (langs or [cfg.get("target", "es")]):
        out = llm_translate(cfg, lang, keys)
        os.makedirs(GEN_DIR, exist_ok=True)
        with open(os.path.join(GEN_DIR, f"{lang}.json"), "w", encoding="utf-8") as fh:
            json.dump(dict(sorted(out.items())), fh, ensure_ascii=False, indent=2)
        print(f"llm {lang}: wrote {len(out)} strings -> {GEN_DIR}/{lang}.json")
    return 0


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ("extract", "sync", "check", "llm", "ensure"):
        print(__doc__)
        return 2
    if args[0] == "ensure":
        return cmd_ensure()
    if args[0] == "extract":
        cmd_extract()
        return 0
    if args[0] == "check":
        return cmd_check(args[1:])
    if args[0] == "llm":
        return cmd_llm(args[1:])
    return cmd_sync(args[1:])


if __name__ == "__main__":
    sys.exit(main())
