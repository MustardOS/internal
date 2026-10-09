(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  let entries = [];

  function setStatus(text, kind = "") {
    $("#playlist-status").textContent = text;
    $("#playlist-status").className = `status ${kind}`.trim();
  }

  const channels = () => $("#playlist-kind").value === "channels";
  const discs = () => $("#playlist-kind").value === "discs";
  const discPattern = /\.(cue|chd|iso|bin|img|ccd|mds|cdi|gdi|pbp|cso|rvz|wbfs|m3u8?|adf|ipf|dsk|st|msa|d64|t64|tap|fds)$/i;
  const naturalOrder = (a, b) => a.localeCompare(b, undefined, {numeric: true, sensitivity: "base"});

  function discLabel(file) {
    const match = file.match(/\b(dis[ck]|cd|side)\s*([0-9]+|[a-d])\b/i);
    if (!match) return "";
    return `${/^side$/i.test(match[1]) ? "Side" : "Disc"} ${match[2].toUpperCase()}`;
  }
  const quote = value => value.replace(/"/g, "'");

  const discFolder = () => $("#playlist-folder").value.trim().replace(/^[\\/]+|[\\/]+$/g, "");

  function discPath(entry) {
    const location = entry.location.trim();
    const folder = discFolder();
    return folder && !/[\\/]/.test(location) ? `${folder}/${location}` : location;
  }

  function text() {
    if (discs()) {
      const lines = [];
      for (const entry of entries) {
        if (!entry.location.trim()) continue;
        if (entry.name.trim()) lines.push(`#LABEL:${entry.name.trim()}`);
        lines.push(discPath(entry));
      }
      return lines.length ? `${lines.join("\n")}\n` : "";
    }

    const lines = ["#EXTM3U"];
    for (const entry of entries) {
      if (!entry.location.trim()) continue;
      const attributes = [];
      if (channels() && entry.name.trim()) attributes.push(`tvg-name="${quote(entry.name.trim())}"`);
      if (channels() && entry.logo.trim()) attributes.push(`tvg-logo="${quote(entry.logo.trim())}"`);
      if (channels() && entry.group.trim()) attributes.push(`group-title="${quote(entry.group.trim())}"`);
      if (entry.name.trim() || attributes.length)
        lines.push(`#EXTINF:-1${attributes.length ? ` ${attributes.join(" ")}` : ""},${entry.name.trim()}`);
      lines.push(entry.location.trim());
    }
    return `${lines.join("\n")}\n`;
  }

  function field(label, value, onInput, placeholder) {
    const wrapper = document.createElement("label");
    const caption = document.createElement("span");
    caption.textContent = label;
    const input = document.createElement("input");
    input.value = value;
    input.autocomplete = "off";
    if (placeholder) input.placeholder = placeholder;
    input.addEventListener("input", () => { onInput(input.value); refresh(); });
    wrapper.append(caption, input);
    return wrapper;
  }

  function button(label, onClick, className) {
    const node = document.createElement("button");
    node.type = "button";
    node.textContent = label;
    if (className) node.className = className;
    node.addEventListener("click", onClick);
    return node;
  }

  function render() {
    const holder = $("#playlist-entries");
    holder.replaceChildren();
    entries.forEach((entry, index) => {
      const row = document.createElement("div");
      row.className = "panel playlist-entry";
      const grid = document.createElement("div");
      grid.className = "form-grid";
      if (discs()) {
        grid.append(
          field("Disc label", entry.name, value => { entry.name = value; }, `Disc ${index + 1}`),
          field("Disc file", entry.location, value => { entry.location = value; }, `Game (Disc ${index + 1}).chd`)
        );
      } else {
        grid.append(
          field("Name", entry.name, value => { entry.name = value; }, channels() ? "Channel name" : "Shown in Wasabi's list"),
          field(channels() ? "Stream address" : "File path or address", entry.location, value => { entry.location = value; },
            channels() ? "https://example.com/stream.m3u8" : "Episode 01.mkv")
        );
      }
      if (channels()) {
        grid.append(
          field("Logo address", entry.logo, value => { entry.logo = value; }, "https://example.com/logo.png"),
          field("Group", entry.group, value => { entry.group = value; }, "Kept for other players")
        );
      }
      const actions = document.createElement("div");
      actions.className = "row-actions";
      const up = button("Move up", () => move(index, -1));
      up.disabled = index === 0;
      const down = button("Move down", () => move(index, 1));
      down.disabled = index === entries.length - 1;
      actions.append(up, down, button("Remove", () => { entries.splice(index, 1); render(); }, "danger"));
      row.append(grid, actions);
      holder.append(row);
    });
    refresh();
  }

  function refresh() {
    $("#playlist-discs-pick").hidden = !discs();
    $("#playlist-folder-pick").hidden = !discs();
    $("#playlist-folder-field").hidden = !discs();
    $("#playlist-folder-help").hidden = !discs();
    $("#playlist-hide-help").hidden = !discs();
    $("#playlist-add").textContent = discs() ? "Add disc" : "Add entry";
    $("#playlist-count").textContent = `(${entries.length})`;
    $("#playlist-empty").hidden = entries.length > 0;
    $("#playlist-text").value = text();
  }

  function move(index, step) {
    const target = index + step;
    if (target < 0 || target >= entries.length) return;
    [entries[index], entries[target]] = [entries[target], entries[index]];
    render();
  }

  function attribute(line, name) {
    const match = line.match(new RegExp(`${name}="([^"]*)"`, "i"));
    return match ? match[1] : "";
  }

  function parse(source) {
    const parsed = [];
    let pending = null;
    for (const raw of source.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line) continue;
      if (line.toUpperCase().startsWith("#LABEL:")) {
        pending = {name: line.slice(7).trim(), logo: "", group: ""};
        continue;
      }
      if (line.toUpperCase().startsWith("#EXTINF:")) {
        const comma = line.indexOf(",");
        pending = {
          name: comma >= 0 ? line.slice(comma + 1).trim() : attribute(line, "tvg-name"),
          logo: attribute(line, "tvg-logo"),
          group: attribute(line, "group-title")
        };
        if (!pending.name) pending.name = attribute(line, "tvg-name");
        continue;
      }
      if (line.startsWith("#")) continue;
      const bar = line.lastIndexOf("|");
      if (bar > 0 && !/^[a-z]+:\/\//i.test(line)) {
        parsed.push({name: line.slice(bar + 1).trim(), logo: "", group: "", ...pending, location: line.slice(0, bar).trim()});
        pending = null;
        continue;
      }
      parsed.push({name: "", logo: "", group: "", ...pending, location: line});
      pending = null;
    }
    return parsed;
  }

  function defaultName() {
    if (discs()) return "Game.m3u";
    return channels() ? "channels.m3u8" : "playlist.m3u";
  }

  function updateName() {
    const input = $("#playlist-name");
    const extension = channels() ? ".m3u8" : ".m3u";
    input.value = input.value.replace(/\.m3u8?$/i, "") + extension;
  }

  $("#playlist-add").addEventListener("click", () => {
    entries.push({name: "", location: "", logo: "", group: ""});
    render();
    const inputs = document.querySelectorAll("#playlist-entries input");
    if (inputs.length) inputs[inputs.length - (channels() ? 4 : 2)].focus();
  });

  function addDiscs(files, folder) {
    files.sort(naturalOrder);
    if (!files.length) {
      setStatus("No files were found to add.", "bad");
      return;
    }
    const skipped = files.filter(name => !discPattern.test(name)).length;
    const fresh = $("#playlist-name").value === "Game.m3u";
    for (const name of files) entries.push({name: discLabel(name), location: name, logo: "", group: ""});
    if (folder !== undefined) $("#playlist-folder").value = folder;
    if (fresh) {
      const source = folder ? folder.replace(/^[._]+/, "") : files[0].replace(/\.[^.]+$/, "");
      const base = source.replace(/\s*[([]?\b(dis[ck]|cd|side)\s*([0-9]+|[a-d])\b[)\]]?/i, "").trim();
      if (base) $("#playlist-name").value = `${base}.m3u`;
    }
    render();
    setStatus(skipped
      ? `Added ${files.length} files. ${skipped} ${skipped === 1 ? "does" : "do"} not look like a disc image, so check ${skipped === 1 ? "it" : "them"} before downloading.`
      : `Added ${files.length} ${files.length === 1 ? "disc" : "discs"} in disc order.`, skipped ? "bad" : "good");
  }

  $("#playlist-discs").addEventListener("change", event => {
    addDiscs([...event.target.files].map(file => file.name));
    event.target.value = "";
  });

  $("#playlist-folder-open").addEventListener("change", event => {
    const picked = [...event.target.files].filter(file => file.webkitRelativePath.split("/").length === 2);
    const folder = picked.length ? picked[0].webkitRelativePath.split("/")[0] : "";
    addDiscs(picked.map(file => file.name).filter(name => discPattern.test(name)), folder);
    event.target.value = "";
  });

  $("#playlist-folder").addEventListener("input", refresh);

  $("#playlist-new").addEventListener("click", () => {
    entries = [];
    $("#playlist-folder").value = "";
    $("#playlist-name").value = defaultName();
    render();
    setStatus("Started a new playlist.");
  });

  $("#playlist-kind").addEventListener("change", () => { updateName(); render(); });

  function openText(fileName, source) {
    entries = parse(source);
    const isChannels = /\.m3u8$/i.test(file.name) || entries.some(entry => entry.logo || /^https?:/i.test(entry.location));
    const isDiscs = !isChannels && !/^#EXTM3U/i.test(source.trim()) && entries.length > 0
      && entries.every(entry => discPattern.test(entry.location));
    if (/#EXT-X-/i.test(source)) setStatus("This file is a single HLS stream, not a playlist. Add its address as one channel instead.", "bad");
    else setStatus(`Opened ${entries.length} ${entries.length === 1 ? "entry" : "entries"} from ${fileName}.`, "good");
    $("#playlist-kind").value = isChannels ? "channels" : isDiscs ? "discs" : "media";
    $("#playlist-folder").value = "";
    if (isDiscs) {
      const folders = entries.map(entry => {
        const slash = Math.max(entry.location.lastIndexOf("/"), entry.location.lastIndexOf("\\"));
        return slash > 0 ? entry.location.slice(0, slash) : "";
      });
      if (folders[0] && folders.every(folder => folder === folders[0])) {
        $("#playlist-folder").value = folders[0];
        for (const entry of entries) entry.location = entry.location.slice(folders[0].length + 1);
      }
    }
    $("#playlist-name").value = fileName;
    render();
  }

  $("#playlist-open").addEventListener("change", async event => {
    const file = event.target.files[0];
    if (!file) return;
    openText(file.name, await file.text());
    event.target.value = "";
  });

  $("#playlist-download").addEventListener("click", () => {
    const usable = entries.filter(entry => entry.location.trim()).length;
    if (!usable) {
      setStatus("Add at least one entry with a path or address first.", "bad");
      return;
    }
    const blob = new Blob([text()], {type: "audio/x-mpegurl"});
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = $("#playlist-name").value.trim() || defaultName();
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(link.href), 5000);
    setStatus(`Downloaded ${link.download} with ${usable} ${usable === 1 ? "entry" : "entries"}.`, "good");
  });

  const device = window.MUTool;
  if (device) {
    let place = null;
    const placeLabel = () => place ? `${place.rootPath}${place.dir ? `/${place.dir}` : ""}` : "";

    async function browse() {
      const roots = await device.contentRoots();
      if (!roots.length) throw new Error("No content folders are set up on this device");
      let root = roots[0];
      if (roots.length > 1) {
        root = await device.choose("Choose a storage", roots.map(entry => ({label: entry.path, value: entry})));
        if (!root) return null;
      }
      let dir = "";
      for (;;) {
        const listing = await device.folder(root.index, dir);
        const items = [{label: "Use this folder", value: {use: true}, hint: `${root.path}${dir ? `/${dir}` : ""}`}];
        if (dir) items.push({label: "Up one folder", value: {up: true}});
        for (const name of listing.folders.sort(naturalOrder)) items.push({label: name, value: {into: name}, hint: "Folder"});
        const picked = await device.choose("Choose the folder for the playlist", items);
        if (!picked) return null;
        if (picked.use) return {root: root.index, rootPath: root.path, dir, listing};
        if (picked.up) dir = dir.includes("/") ? dir.slice(0, dir.lastIndexOf("/")) : "";
        else dir = dir ? `${dir}/${picked.into}` : picked.into;
      }
    }

    async function ensurePlace() {
      if (place) return place;
      place = await browse();
      if (place) setStatus(`Working in ${placeLabel()}.`, "good");
      return place;
    }

    device.bar($("#playlist-tool .toolbar"), [
      ["Choose Folder", async () => {
        try {
          const chosen = await browse();
          if (chosen) { place = chosen; setStatus(`Working in ${placeLabel()}.`, "good"); }
        } catch (error) { setStatus(error.message, "bad"); }
      }],
      ["Add Discs from Folder", async () => {
        try {
          if (!await ensurePlace()) return;
          const listing = await device.folder(place.root, place.dir);
          const options = [{label: "Discs beside the playlist", value: ""}];
          for (const name of listing.folders.sort(naturalOrder)) options.push({label: name, value: name, hint: "Disc folder next to the playlist"});
          const folder = options.length > 1 ? await device.choose("Where are the discs?", options) : "";
          if (folder === null) return;
          const files = folder ? (await device.folder(place.root, place.dir ? `${place.dir}/${folder}` : folder)).files : listing.files;
          addDiscs(files.map(file => file.name).filter(name => discPattern.test(name) && !/\.m3u8?$/i.test(name)), folder || undefined);
        } catch (error) { setStatus(error.message, "bad"); }
      }],
      ["Open from Device", async () => {
        try {
          if (!await ensurePlace()) return;
          const listing = await device.folder(place.root, place.dir);
          const lists = listing.files.filter(file => /\.m3u8?$/i.test(file.name)).map(file => ({label: file.name, value: file.name}));
          const picked = await device.choose("Open a playlist from this folder", lists);
          if (!picked) return;
          openText(picked, await device.readPlaylist(place.root, place.dir ? `${place.dir}/${picked}` : picked));
        } catch (error) { setStatus(error.message, "bad"); }
      }],
      ["Save to Device", async () => {
        const usable = entries.filter(entry => entry.location.trim()).length;
        if (!usable) { setStatus("Add at least one entry with a path or address first.", "bad"); return; }
        const name = $("#playlist-name").value.trim() || defaultName();
        if (!/\.m3u8?$/i.test(name) || /[\\/]/.test(name)) { setStatus("The file name must end in .m3u or .m3u8 and cannot include a folder.", "bad"); return; }
        try {
          if (!await ensurePlace()) return;
          await device.savePlaylist(place.root, place.dir ? `${place.dir}/${name}` : name, text());
          setStatus(`Saved ${name} to ${placeLabel()}.`, "good");
        } catch (error) { setStatus(error.message, "bad"); }
      }, true]
    ]);
  }

  render();
})();
