// Minimal escape-first markdown renderer for vault docs and agent replies.
// Every byte is HTML-escaped before any transform runs, so hostile input can
// never break out of the escaped text; the span/block rules only ever add
// trusted markup around already-neutralised content. Pure logic, node-tested.

export function escapeHtml(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function splitRow(line) {
  let s = line.trim();
  if (s.startsWith("|")) s = s.slice(1);
  if (s.endsWith("|")) s = s.slice(0, -1);
  return s.split("|").map((c) => c.trim());
}

function isTableSep(line) {
  if (line.indexOf("|") === -1) return false;
  const cells = splitRow(line);
  return cells.length > 0 && cells.every((c) => /^:?-{1,}:?$/.test(c));
}

// Spans run on already-escaped text. Inline code and finished links are lifted
// out into sentinels first so later passes (bold/italic, bare-URL autolinking)
// can never reach inside them; everything is spliced back at the end.
function inline(s) {
  const holds = [];
  const stash = (html) => "\u0000" + (holds.push(html) - 1) + "\u0000";

  s = s.replace(/`([^`]+)`/g, (_, c) => stash("<code>" + c + "</code>"));

  // Markdown links. http(s) open a new tab hardened with rel=noopener; in-page
  // #anchors stay same-tab; anything else (javascript:, data:) is left as text.
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (whole, text, href) => {
    href = href.trim();
    if (/^https?:\/\//i.test(href)) {
      return stash('<a href="' + href.replace(/"/g, "%22") +
        '" target="_blank" rel="noopener">' + text + "</a>");
    }
    if (href[0] === "#") {
      return stash('<a href="' + href.replace(/"/g, "%22") + '">' + text + "</a>");
    }
    return whole;
  });

  // Bare http(s) URLs in the remaining text. Stops at whitespace, a sentinel,
  // or an escaped angle bracket; trailing sentence punctuation ).,;:!? is
  // peeled off the match and left as plain text after the link.
  s = s.replace(/https?:\/\/[^\s\u0000<]+/gi, (url) => {
    let tail = "";
    while (/[).,;:!?]$/.test(url)) {
      tail = url.slice(-1) + tail;
      url = url.slice(0, -1);
    }
    if (!url) return tail;
    return stash('<a href="' + url.replace(/"/g, "%22") +
      '" target="_blank" rel="noopener">' + url + "</a>") + tail;
  });

  s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  s = s.replace(/\*([^*]+)\*/g, "<em>$1</em>");

  // Splice sentinels back. Loop because a stashed link's text may itself hold
  // an inline-code sentinel, and one replace pass does not rescan its output.
  let prev;
  do {
    prev = s;
    s = s.replace(/\u0000(\d+)\u0000/g, (_, n) => holds[+n]);
  } while (s !== prev);
  return s;
}

export function mdToHtml(src, opts) {
  const lines = escapeHtml(src).split(/\r?\n/);
  const out = [];
  let para = [];
  let list = null;
  // Agent replies opt into hard line breaks so a line-structured answer (a
  // /tools list, terse notes) keeps its shape; vault docs stay soft-wrapped.
  const brk = opts && opts.breaks ? "<br>" : " ";

  const flushPara = () => {
    if (para.length) {
      out.push("<p>" + inline(para.join(brk)) + "</p>");
      para = [];
    }
  };
  const flushList = () => {
    if (list) {
      out.push(
        "<" + list.type + ">" +
        list.items.map((it) => "<li>" + inline(it) + "</li>").join("") +
        "</" + list.type + ">"
      );
      list = null;
    }
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // HTML comment-only lines (the vault's generated-fence markers) are
    // plumbing, not content; hide them. They arrive escaped by this point.
    if (/^\s*&lt;!--.*--&gt;\s*$/.test(line)) {
      continue;
    }

    if (/^\s*```/.test(line)) {
      flushPara();
      flushList();
      const buf = [];
      i++;
      while (i < lines.length && !/^\s*```/.test(lines[i])) buf.push(lines[i++]);
      out.push("<pre><code>" + buf.join("\n") + "</code></pre>");
      continue;
    }

    if (/^\s*-{3,}\s*$/.test(line)) {
      flushPara();
      flushList();
      out.push("<hr>");
      continue;
    }

    const h = /^(#{1,4})\s+(.*)$/.exec(line);
    if (h) {
      flushPara();
      flushList();
      const level = h[1].length;
      out.push("<h" + level + ">" + inline(h[2].trim()) + "</h" + level + ">");
      continue;
    }

    if (line.indexOf("|") !== -1 && i + 1 < lines.length && isTableSep(lines[i + 1])) {
      flushPara();
      flushList();
      const header = splitRow(line);
      i += 2;
      const rows = [];
      while (i < lines.length && lines[i].indexOf("|") !== -1 && lines[i].trim() !== "") {
        rows.push(splitRow(lines[i++]));
      }
      i--;
      let t = "<table><thead><tr>" +
        header.map((c) => "<th>" + inline(c) + "</th>").join("") +
        "</tr></thead>";
      if (rows.length) {
        t += "<tbody>" +
          rows.map((r) => "<tr>" + r.map((c) => "<td>" + inline(c) + "</td>").join("") + "</tr>").join("") +
          "</tbody>";
      }
      out.push(t + "</table>");
      continue;
    }

    let m = /^\s*[-*]\s+(.*)$/.exec(line);
    if (m) {
      flushPara();
      if (!list || list.type !== "ul") {
        flushList();
        list = { type: "ul", items: [] };
      }
      list.items.push(m[1]);
      continue;
    }
    m = /^\s*\d+\.\s+(.*)$/.exec(line);
    if (m) {
      flushPara();
      if (!list || list.type !== "ol") {
        flushList();
        list = { type: "ol", items: [] };
      }
      list.items.push(m[1]);
      continue;
    }

    if (line.trim() === "") {
      flushPara();
      flushList();
      continue;
    }

    flushList();
    para.push(line.trim());
  }
  flushPara();
  flushList();
  return out.join("\n");
}
