(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const SHEETS = /\.(cue|gdi)$/i;
  const PLAYLISTS = /\.m3u8?$/i;
  const TRACKS = /\.(bin|img|raw|sub|wav)$/i;
  const DISCS = /\.(cue|gdi|chd|iso|pbp|cso|cdi|ccd|mds|rvz)$/i;
  const IGNORED = /\.(txt|nfo|png|jpe?g|gif|srm|sav|state\d*|cfg|ini|xml|dat|db|json)$/i;
  const DISC_TAG = /\((?:dis[ck]|cd)\s*([0-9]+)[^)]*\)/i;
  const naturalOrder = (a, b) => a.localeCompare(b, undefined, {numeric: true, sensitivity: "base"});
  const emptyText = $("#library-empty").textContent;

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function setStatus(text, kind = "") {
    $("#library-status").textContent = text;
    $("#library-status").className = `status ${kind}`.trim();
  }

  function setProgress(text) {
    const empty = $("#library-empty");
    if (text) {
      $("#library-summary").hidden = true;
      $("#library-results").replaceChildren();
    }
    empty.textContent = text || emptyText;
    empty.classList.toggle("busy", Boolean(text));
    empty.hidden = false;
  }

  function size(bytes) {
    const units = ["B", "KB", "MB", "GB"];
    let value = bytes;
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    return `${unit ? value.toFixed(1) : value} ${units[unit]}`;
  }

  const folderOf = path => path.includes("/") ? path.slice(0, path.lastIndexOf("/")) : "";
  const leafOf = path => path.slice(path.lastIndexOf("/") + 1);
  const join = (folder, name) => folder ? `${folder}/${name}` : name;
  const hidden = path => path.split("/").some(part => part.startsWith("."));
  const external = entry => /^(?:[a-z][a-z0-9+.-]*:|\/)/i.test(entry);

  function normalise(path) {
    const parts = [];
    for (const part of path.replace(/\\/g, "/").split("/")) {
      if (!part || part === ".") continue;
      if (part === "..") parts.pop();
      else parts.push(part);
    }
    return parts.join("/");
  }

  function title(name) {
    const stem = name.replace(/\.[^.]+$/, "");
    const disc = stem.match(DISC_TAG);
    const base = stem.replace(/\([^)]*\)|\[[^\]]*\]/g, " ")
      .replace(/(?:\s*-\s*|\s+)copy(?:\s*\d+)?\s*$/i, " ")
      .replace(/[\s_.-]+/g, " ").trim().toLowerCase();
    return {base, disc: disc ? Number(disc[1]) : 0};
  }

  function sheetEntries(path, text) {
    const gdi = /\.gdi$/i.test(path);
    const entries = [];
    for (const line of text.replace(/^﻿/, "").split(/\r?\n/)) {
      const match = gdi
        ? line.match(/^\s*\d+\s+\d+\s+\d+\s+\d+\s+(?:"([^"]+)"|(\S+))/)
        : line.match(/^\s*FILE\s+(?:"([^"]+)"|(\S+))/i);
      if (match) entries.push(match[1] || match[2]);
    }
    return entries;
  }

  function playlistEntries(text) {
    return text.replace(/^﻿/, "").split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith("#"));
  }

  function groups(items, key) {
    const grouped = new Map();
    for (const item of items) {
      const value = key(item);
      if (!value) continue;
      if (!grouped.has(value)) grouped.set(value, []);
      grouped.get(value).push(item);
    }
    return [...grouped.values()].filter(group => group.length > 1);
  }

  function check(files) {
    const byPath = new Map(files.map(file => [file.path, file]));
    const byLower = new Map();
    for (const file of files) if (!byLower.has(file.path.toLowerCase())) byLower.set(file.path.toLowerCase(), file);

    const tracks = new Set();
    const listed = new Set();
    const sheetFolders = new Set();
    const problems = [];

    for (const file of files) {
      const sheet = SHEETS.test(file.path);
      if (!sheet && !PLAYLISTS.test(file.path)) continue;
      if (sheet) sheetFolders.add(folderOf(file.path));
      if (file.text === null) {
        problems.push({path: file.path, state: "bad", note: "Could not be read"});
        continue;
      }

      const entries = sheet ? sheetEntries(file.path, file.text) : playlistEntries(file.text);
      if (!entries.length) problems.push({path: file.path, state: "bad", note: sheet ? "Lists no track files" : "Lists no files"});

      for (const entry of entries.filter(entry => !external(entry))) {
        const target = normalise(join(folderOf(file.path), entry));
        const found = byPath.get(target) || byLower.get(target.toLowerCase());
        if (found) {
          (sheet ? tracks : listed).add(found.path);
          if (found.path !== target)
            problems.push({path: file.path, state: "warn", note: `Points to ${entry}, but the file is named ${leafOf(found.path)}. This only works on cards that ignore letter case`});
        } else if (!hidden(target)) {
          problems.push({path: file.path, state: "bad", note: `Missing ${sheet ? "track" : "file"} ${entry}`});
        }
      }
    }

    const unused = files.filter(file => TRACKS.test(file.path) && sheetFolders.has(folderOf(file.path)) && !tracks.has(file.path));

    const content = files.filter(file => !IGNORED.test(file.path) && !tracks.has(file.path) && !listed.has(file.path));
    const sameFile = groups(files.filter(file => !IGNORED.test(file.path)), file => `${leafOf(file.path).toLowerCase()}|${file.size}`)
      .filter(group => new Set(group.map(file => folderOf(file.path))).size > 1);
    const sameTitle = groups(content, file => {
      const name = title(leafOf(file.path));
      return name.base ? `${folderOf(file.path)}|${name.base}|${name.disc}` : "";
    });

    const unlisted = groups(files.filter(file => DISCS.test(file.path) && !listed.has(file.path) && title(leafOf(file.path)).disc),
      file => `${folderOf(file.path)}|${title(leafOf(file.path)).base}`)
      .filter(group => new Set(group.map(file => title(leafOf(file.path)).disc)).size > 1);

    return {count: files.length, sameFile, sameTitle, problems, unused, unlisted};
  }

  function section(holder, heading, help, rows) {
    if (!rows.length) return;
    const panel = element("section", "panel library-section");
    const head = element("div", "section-head");
    head.append(element("h2", "", heading), element("span", "status", rows.length.toLocaleString()));
    panel.append(head, element("p", "help", help));
    const list = element("ul", "library-files");
    for (const row of rows) list.append(row);
    panel.append(list);
    holder.append(panel);
  }

  function row(state, paths, note) {
    const item = element("li", state ? `library-${state}` : "");
    paths.forEach((path, index) => {
      if (index) item.append(element("br"));
      item.append(element("code", "", path));
    });
    if (note) item.append(element("span", "", ` ${note}`));
    return item;
  }

  const sortPaths = group => group.map(file => file.path).sort(naturalOrder);
  const byFirst = (a, b) => naturalOrder(a[0], b[0]);

  function render(report) {
    const summary = $("#library-summary");
    summary.replaceChildren();
    for (const [label, value] of [["Files checked", report.count], ["Same file in more than one place", report.sameFile.length],
      ["Same title in one folder", report.sameTitle.length], ["Disc sheet and playlist problems", report.problems.length],
      ["Unused track files", report.unused.length], ["Multi-disc games without a playlist", report.unlisted.length]])
      summary.append(element("dt", "", label), element("dd", "", value.toLocaleString()));
    summary.hidden = false;

    const holder = $("#library-results");
    holder.replaceChildren();

    section(holder, "Same file in more than one place",
      "These files have the same name and size in different folders, so one copy can usually be removed.",
      report.sameFile.map(group => ({paths: sortPaths(group), bytes: group[0].size}))
        .sort((a, b) => naturalOrder(a.paths[0], b.paths[0]))
        .map(group => row("warn", group.paths, `(${size(group.bytes)} each)`)));

    section(holder, "Same title in one folder",
      "These files look like the same game in a different format, region, revision or as a copy. Keep the ones you want.",
      report.sameTitle.map(sortPaths).sort(byFirst).map(paths => row("warn", paths)));

    section(holder, "Disc sheet and playlist problems",
      "A cue or gdi sheet must name every track file exactly, and a playlist must name files that exist, or the content will not start.",
      report.problems.sort((a, b) => naturalOrder(a.path, b.path)).map(problem => row(problem.state, [problem.path], problem.note)));

    section(holder, "Unused track files",
      "No cue or gdi sheet in the same folder uses these files. They may belong to a missing sheet or be left over.",
      report.unused.map(file => file.path).sort(naturalOrder).map(path => row("warn", [path])));

    section(holder, "Multi-disc games without a playlist",
      "Each disc shows as its own game. A playlist lets the game change discs and shows it once.",
      report.unlisted.map(sortPaths).sort(byFirst).map(paths => row("", paths)));

    const clean = !report.sameFile.length && !report.sameTitle.length && !report.problems.length && !report.unused.length
      && !report.unlisted.length;
    if (clean) holder.append(element("p", "status good", "No duplicates or disc layout problems found."));
    $("#library-empty").hidden = true;
  }

  async function run(files) {
    if (!files.length) {
      setProgress("");
      setStatus("No files were found to check.", "bad");
      return;
    }

    const readable = files.filter(file => SHEETS.test(file.path) || PLAYLISTS.test(file.path));
    for (let index = 0; index < readable.length; index++) {
      setProgress(`Reading ${index + 1} of ${readable.length}: ${readable[index].path}`);
      try {
        readable[index].text = await readable[index].read();
      } catch (error) {
        readable[index].text = null;
      }
    }

    render(check(files));
    $("#library-empty").classList.remove("busy");
    setStatus(`Checked ${files.length.toLocaleString()} ${files.length === 1 ? "file" : "files"}.`, "good");
  }

  function relativePath(file) {
    const parts = (file.webkitRelativePath || file.name).split("/");
    return parts.length > 1 ? parts.slice(1).join("/") : parts[0];
  }

  $("#library-folder").addEventListener("change", event => run([...event.target.files]
    .filter(file => !file.name.startsWith("."))
    .map(file => ({path: relativePath(file), size: file.size, read: () => file.text()}))));

  const device = window.MUTool;
  if (device) {
    device.bar($("#library-tool .toolbar"), [
      ["Check This Device", async () => {
        try {
          const files = [];
          for (const root of await device.contentRoots()) {
            const label = root.path.replace(/\/ROMS\/?$/i, "").split("/").pop() || String(root.index);
            const queue = [""];
            while (queue.length) {
              const dir = queue.shift();
              setProgress(`Reading ${join(label, dir)}`);
              const listing = await device.folder(root.index, dir);
              for (const name of listing.folders || []) queue.push(join(dir, name));
              for (const file of listing.files || []) {
                const path = join(dir, file.name);
                files.push({path: join(label, path), size: file.size, read: () => device.readPlaylist(root.index, path)});
              }
            }
          }
          await run(files);
        } catch (error) {
          setProgress("");
          setStatus(`Could not read the content on the device: ${error.message}`, "bad");
        }
      }, true]
    ]);
  }
})();
