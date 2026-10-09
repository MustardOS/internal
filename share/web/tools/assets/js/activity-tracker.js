(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const A = window.MUOS_ACTIVITY;
  let sources = [];
  let items = [];
  let editing = null;
  let sortKey = "total";
  let descending = true;
  let filter = "";

  function setStatus(text, kind = "") { $("#status").textContent = text; $("#status").className = `status ${kind}`.trim(); }

  function renderSummary() {
    const holder = $("#summary");
    holder.replaceChildren();
    for (const [label, value] of A.summaryRows(A.summarise(items))) {
      const term = document.createElement("dt"); term.textContent = label;
      const detail = document.createElement("dd"); detail.textContent = value || "Unknown";
      holder.append(term, detail);
    }
  }

  function renderColumns() {
    const holder = $("#columns");
    holder.replaceChildren();
    for (const column of A.columns) {
      const cell = document.createElement("th");
      cell.scope = "col";
      if (column.key === sortKey) cell.setAttribute("aria-sort", descending ? "descending" : "ascending");
      const button = document.createElement("button");
      button.type = "button";
      button.className = "sort-head";
      button.textContent = column.label + (column.key === sortKey ? (descending ? " ▾" : " ▴") : "");
      button.addEventListener("click", () => {
        descending = column.key === sortKey ? !descending : Boolean(column.number);
        sortKey = column.key;
        render();
      });
      cell.append(button);
      holder.append(cell);
    }
  }

  function renderRows() {
    const query = filter.toLocaleLowerCase();
    const visible = A.sortItems(items, sortKey, descending).filter(item => item.name.toLocaleLowerCase().includes(query));
    const holder = $("#rows");
    holder.replaceChildren();
    for (const item of visible) {
      const row = document.createElement("tr");
      row.className = "selectable";
      row.tabIndex = 0;
      if (editing && editing.item.key === item.key) row.classList.add("selected");
      for (const column of A.columns) {
        const cell = document.createElement("td");
        cell.textContent = column.show(item);
        if (column.number) cell.className = "number";
        row.append(cell);
      }
      row.addEventListener("click", () => openEditor(item));
      row.addEventListener("keydown", event => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        openEditor(item);
      });
      holder.append(row);
    }
    $("#count").textContent = query ? `(${visible.length} of ${items.length})` : `(${items.length})`;
    $("#no-match").hidden = visible.length !== 0;
  }

  function render() { renderColumns(); renderRows(); }

  function renderSessions() {
    const sessions = A.recentSessions(items, 50);
    const head = $("#session-columns");
    const body = $("#sessions");
    head.replaceChildren();
    body.replaceChildren();
    for (const column of A.sessionColumns) {
      const cell = document.createElement("th");
      cell.scope = "col";
      cell.textContent = column.label;
      head.append(cell);
    }
    for (const session of sessions) {
      const row = document.createElement("tr");
      for (const column of A.sessionColumns) {
        const cell = document.createElement("td");
        cell.textContent = column.show(session);
        if (column.number) cell.className = "number";
        row.append(cell);
      }
      body.append(row);
    }
    $("#sessions-panel").hidden = sessions.length === 0;
  }

  function renderAll() {
    renderSummary();
    render();
    renderSessions();
    document.dispatchEvent(new CustomEvent("activity-loaded", {detail: items}));
  }

  function readText(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.addEventListener("load", () => resolve(reader.result));
      reader.addEventListener("error", () => reject(reader.error));
      reader.readAsText(file);
    });
  }

  const isObject = value => value !== null && typeof value === "object" && !Array.isArray(value);
  const isRecord = value => isObject(value) && typeof value.path === "string" && "launches" in value;

  function entriesOf(source) {
    const data = source.data;
    if (Array.isArray(data)) {
      return data.map((value, index) => ({source, path: isRecord(value) ? value.path : "", read: () => data[index]}))
        .filter(entry => entry.path);
    }
    if (isRecord(data)) return [{source, path: data.path, read: () => source.data}];
    return Object.keys(data).filter(path => isObject(data[path]))
      .map(path => ({source, path, legacy: true, read: () => source.data[path]}));
  }

  function buildItems() {
    const lists = sources.map(source => entriesOf(source).map(entry => {
      const raw = entry.read();
      if (!raw) return null;
      const parsed = A.parse(entry.legacy ? {[entry.path]: raw} : raw)[0];
      if (parsed) parsed.entry = entry;
      return parsed;
    }).filter(Boolean));
    items = A.combine(lists);
  }

  const pad = value => String(value).padStart(2, "0");

  function toLocalInput(epoch) {
    if (!epoch) return "";
    const when = new Date(epoch * 1000);
    return `${when.getFullYear()}-${pad(when.getMonth() + 1)}-${pad(when.getDate())}T${pad(when.getHours())}:${pad(when.getMinutes())}`;
  }

  function fromLocalInput(value) {
    if (!value) return 0;
    const time = new Date(value).getTime();
    return Number.isFinite(time) ? Math.floor(time / 1000) : 0;
  }

  function openEditor(item) {
    editing = {item, entry: item.entry};
    $("#edit-title").textContent = item.name;
    $("#edit-path").textContent = item.path;
    $("#edit-name").value = item.name;
    $("#edit-launches").value = String(item.launches);
    $("#edit-hours").value = String(Math.floor(item.total / 3600));
    $("#edit-minutes").value = String(Math.floor((item.total % 3600) / 60));
    $("#edit-first").value = toLocalInput(item.first);
    $("#edit-last").value = toLocalInput(item.started);
    $("#edit-panel").hidden = false;
    renderRows();
    $("#edit-panel").scrollIntoView({behavior: "smooth", block: "nearest"});
    $("#edit-name").focus();
  }

  function closeEditor() {
    editing = null;
    $("#edit-panel").hidden = true;
    renderRows();
  }

  function whole(value) {
    const number = Number(value);
    return Number.isInteger(number) && number >= 0 ? number : NaN;
  }

  function applyEdit() {
    if (!editing) return;
    const name = $("#edit-name").value.trim();
    const launches = whole($("#edit-launches").value);
    const hours = whole($("#edit-hours").value || 0);
    const minutes = whole($("#edit-minutes").value || 0);
    const first = fromLocalInput($("#edit-first").value);
    const last = fromLocalInput($("#edit-last").value);

    if (!name) return setStatus("Give the title a name.", "bad");
    if (Number.isNaN(launches) || launches < 1) return setStatus("Launches must be a whole number of at least 1.", "bad");
    if (Number.isNaN(hours) || Number.isNaN(minutes) || minutes > 59) return setStatus("Play time needs whole hours and 0 to 59 minutes.", "bad");
    if (first && last && first > last) return setStatus("First played cannot be after last played.", "bad");

    const raw = editing.entry.read();
    raw.name = name;
    raw.launches = launches;
    raw.total_time = hours * 3600 + minutes * 60;
    raw.first_played = first;
    raw.last_played = last;
    if (raw.avg_time !== undefined) raw.avg_time = Math.floor(raw.total_time / launches);
    editing.entry.source.dirty = true;

    closeEditor();
    buildItems();
    renderAll();
    $("#download").disabled = false;
    setStatus(`${name} updated. Download to keep the change.`, "good");
  }

  function removeTitle() {
    if (!editing) return;
    const label = editing.item.name;
    if (!window.confirm(`Remove ${label} from the activity history?`)) return;

    const entry = editing.entry;
    if (entry.legacy) {
      delete entry.source.data[entry.path];
    } else {
      Object.assign(entry.read(), {
        launches: 0, total_time: 0, first_played: 0, last_played: 0, last_session: 0, longest_session: 0,
        last_core: "", last_device: "", last_mode: "", last_runtime: "",
        cores: {}, devices: {}, modes: {}, runtimes: {}, endings: {}, sessions: [], active: null
      });
    }
    entry.source.dirty = true;

    closeEditor();
    buildItems();
    renderAll();
    $("#download").disabled = false;
    setStatus(`${label} removed. Download to keep the change.`, "good");
  }

  const CRC_TABLE = (() => {
    const table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c >>> 0;
    }
    return table;
  })();

  function crc32(bytes) {
    let crc = 0xFFFFFFFF;
    for (let i = 0; i < bytes.length; i++) crc = CRC_TABLE[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }

  function zip(files) {
    const encoder = new TextEncoder();
    const now = new Date();
    const time = (now.getHours() << 11) | (now.getMinutes() << 5) | Math.floor(now.getSeconds() / 2);
    const date = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
    const parts = [];
    const central = [];
    let offset = 0;

    for (const file of files) {
      const name = encoder.encode(file.name);
      const data = encoder.encode(file.text);
      const crc = crc32(data);

      const local = new DataView(new ArrayBuffer(30));
      local.setUint32(0, 0x04034b50, true);
      local.setUint16(4, 20, true);
      local.setUint16(6, 0x0800, true);
      local.setUint16(10, time, true);
      local.setUint16(12, date, true);
      local.setUint32(14, crc, true);
      local.setUint32(18, data.length, true);
      local.setUint32(22, data.length, true);
      local.setUint16(26, name.length, true);
      parts.push(local, name, data);

      const record = new DataView(new ArrayBuffer(46));
      record.setUint32(0, 0x02014b50, true);
      record.setUint16(4, 20, true);
      record.setUint16(6, 20, true);
      record.setUint16(8, 0x0800, true);
      record.setUint16(12, time, true);
      record.setUint16(14, date, true);
      record.setUint32(16, crc, true);
      record.setUint32(20, data.length, true);
      record.setUint32(24, data.length, true);
      record.setUint16(28, name.length, true);
      record.setUint32(42, offset, true);
      central.push(record, name);

      offset += 30 + name.length + data.length;
    }

    const size = central.reduce((total, part) => total + part.byteLength, 0);
    const end = new DataView(new ArrayBuffer(22));
    end.setUint32(0, 0x06054b50, true);
    end.setUint16(8, files.length, true);
    end.setUint16(10, files.length, true);
    end.setUint32(12, size, true);
    end.setUint32(16, offset, true);

    return new Blob([...parts, ...central, end], {type: "application/zip"});
  }

  function saveBlob(blob, filename) {
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(link.href), 10000);
  }

  function download() {
    if (!sources.length) return;
    const text = source => `${JSON.stringify(source.data, null, 2)}\n`;

    if (sources.length === 1) {
      saveBlob(new Blob([text(sources[0])], {type: "application/json"}), sources[0].name);
      setStatus(`${sources[0].name} downloaded.`, "good");
      return;
    }

    const changed = sources.filter(source => source.dirty);
    const chosen = changed.length ? changed : sources;
    saveBlob(zip(chosen.map(source => ({name: source.name, text: text(source)}))), "activity-tracker.zip");
    setStatus(`Downloaded ${chosen.length} ${chosen.length === 1 ? "record" : "records"} in activity-tracker.zip.`, "good");
  }

  async function load(fileList) {
    const files = [...(fileList || [])].filter(file => /\.json$/i.test(file.name));
    if (!files.length) { setStatus("Choose a tracker record, a track folder or playtime_data.json.", "bad"); return; }

    const loaded = [];
    let skipped = 0;
    for (const file of files) {
      try {
        const data = JSON.parse(await readText(file));
        if (!isObject(data) && !Array.isArray(data)) throw new Error("not activity");
        loaded.push({name: file.name, data, dirty: false});
      } catch (_) {
        skipped += 1;
      }
    }

    const previous = sources;
    sources = loaded;
    buildItems();
    if (!items.length) {
      sources = previous;
      buildItems();
      setStatus(files.length === 1 && skipped ? "That file is not an Activity Tracker file." : "No recorded activity found.", "bad");
      return;
    }

    editing = null;
    $("#edit-panel").hidden = true;
    $("#download").disabled = true;
    $("#source").textContent = files.length === 1 ? files[0].name : `${files.length} files`;
    $("#empty").hidden = true;
    $("#report").hidden = false;
    renderAll();
    setStatus(`Loaded ${items.length} titles${skipped ? `, skipped ${skipped} unreadable files` : ""}.`, skipped ? "" : "good");
  }

  const device = window.MUTool;
  if (device) {
    device.bar($("#activity-tool .toolbar"), [
      ["Load from Device", async () => {
        try {
          const listed = (await device.list("track")).filter(file => !file.path.includes("/"));
          if (!listed.length) { setStatus("No activity has been recorded on this device yet.", "bad"); return; }
          const files = [];
          for (let index = 0; index < listed.length; index += 8) {
            setStatus(`Reading ${Math.min(index + 8, listed.length)} of ${listed.length} records`);
            files.push(...await Promise.all(listed.slice(index, index + 8).map(file => device.file("track", file.path))));
          }
          await load(files);
        } catch (error) {
          setStatus(`Could not read activity from the device: ${error.message}`, "bad");
        }
      }],
      ["Save Changes to Device", async () => {
        const changed = sources.filter(source => source.dirty);
        if (!changed.length) { setStatus("Nothing has been changed yet.", "bad"); return; }
        if (!window.confirm(`Save ${changed.length} edited ${changed.length === 1 ? "record" : "records"} to the device? Each previous record is kept as a .bak file.`)) return;
        try {
          for (const source of changed) {
            await device.save("track", source.name, `${JSON.stringify(source.data, null, 2)}\n`);
            source.dirty = false;
          }
          setStatus(`Saved ${changed.length} ${changed.length === 1 ? "record" : "records"} to MUOS/info/track.`, "good");
        } catch (error) {
          setStatus(error.message, "bad");
        }
      }, true]
    ]);
  }

  $("#open").addEventListener("change", event => { load(event.target.files); event.target.value = ""; });
  $("#open-folder").addEventListener("change", event => { load(event.target.files); event.target.value = ""; });
  $("#filter").addEventListener("input", event => { filter = event.target.value; renderRows(); });
  $("#download").addEventListener("click", download);
  $("#edit-apply").addEventListener("click", applyEdit);
  $("#edit-cancel").addEventListener("click", closeEditor);
  $("#edit-remove").addEventListener("click", removeTitle);
  $("#edit-panel").addEventListener("keydown", event => {
    if (event.key === "Enter" && event.target.tagName === "INPUT") applyEdit();
    if (event.key === "Escape") closeEditor();
  });

  const tool = $("#activity-tool");
  tool.addEventListener("dragover", event => { event.preventDefault(); tool.classList.add("dropping"); });
  tool.addEventListener("dragleave", () => tool.classList.remove("dropping"));
  tool.addEventListener("drop", event => {
    event.preventDefault();
    tool.classList.remove("dropping");
    load(event.dataTransfer.files);
  });
})();
