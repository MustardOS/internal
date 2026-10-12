(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const CHUNK = 2 * 1024 * 1024;
  let systems = [];
  let report = [];
  let unknown = [];
  let skipped = new Map();

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function setStatus(text, kind = "") {
    $("#bios-status").textContent = text;
    $("#bios-status").className = `status ${kind}`.trim();
  }

  // Scan progress shows in the empty results area, where the eye already is
  const emptyText = $("#bios-empty").textContent;

  function setProgress(text) {
    const empty = $("#bios-empty");
    if (text) {
      $("#bios-summary").hidden = true;
      $("#bios-results").replaceChildren();
    }
    empty.textContent = text || emptyText;
    empty.classList.toggle("busy", Boolean(text));
    empty.hidden = false;
  }

  const naturalOrder = (a, b) => a.localeCompare(b, undefined, {numeric: true, sensitivity: "base"});

  function relativePath(file) {
    const path = file.webkitRelativePath || file.relativePath || file.name;
    const parts = path.split("/");
    return parts.length > 1 ? parts.slice(1).join("/") : parts[0];
  }

  function knownFolders() {
    const folders = new Set();
    for (const system of systems)
      for (const expected of system.bios)
        if (expected.file.includes("/")) folders.add(expected.file.split("/")[0].toLowerCase());
    return folders;
  }

  function dataFolder(path, known) {
    if (!path.includes("/")) return "";
    const folder = path.split("/")[0];
    return known.has(folder.toLowerCase()) ? "" : folder;
  }

  async function md5(file) {
    const spark = new SparkMD5.ArrayBuffer();
    for (let offset = 0; offset < file.size; offset += CHUNK)
      spark.append(await file.slice(offset, offset + CHUNK).arrayBuffer());
    return spark.end();
  }

  function check(found) {
    const byPath = new Map(found.map(entry => [entry.path, entry]));
    const byLower = new Map(found.map(entry => [entry.path.toLowerCase(), entry]));
    const byHash = new Map(found.map(entry => [entry.hash, entry]));
    const used = new Set();

    report = systems.map(system => {
      const rows = system.bios.map(expected => {
        const want = (expected.hash || "").toLowerCase();
        const exact = byPath.get(expected.file);
        if (exact) {
          used.add(exact.path);
          if (!want || exact.hash === want) return {expected, state: "good", note: want ? "Correct" : "Present"};
          return {expected, state: "bad", note: "Wrong version: the checksum does not match"};
        }
        const caseOnly = byLower.get(expected.file.toLowerCase());
        if (caseOnly) {
          used.add(caseOnly.path);
          return {expected, state: "warn", note: `Rename ${caseOnly.path} to ${expected.file}`};
        }
        const renamed = want ? byHash.get(want) : null;
        if (renamed) {
          used.add(renamed.path);
          return {expected, state: "warn", note: `Found as ${renamed.path}. Rename it to ${expected.file}`};
        }
        return {expected, state: "missing", note: "Missing"};
      });
      return {system, rows};
    }).filter(entry => entry.rows.length);

    unknown = found.filter(entry => !used.has(entry.path));
    render();
  }

  function render() {
    const extras = unknown;
    const showEmpty = $("#bios-problems").checked;
    const holder = $("#bios-results");
    holder.replaceChildren();

    const totals = {good: 0, warn: 0, bad: 0, missing: 0};
    let untouched = 0;
    for (const entry of report) {
      if (entry.rows.every(row => row.state === "missing")) {
        untouched += 1;
        continue;
      }
      for (const row of entry.rows) totals[row.state] += 1;
    }

    const summary = $("#bios-summary");
    summary.replaceChildren();
    for (const [label, value] of [["Correct", totals.good], ["Need renaming", totals.warn],
      ["Wrong version", totals.bad], ["Other files not found", totals.missing], ["Not recognised", extras.length],
      ["Systems with no BIOS files", untouched], ["Core data folders", skipped.size]]) {
      summary.append(element("dt", "", label), element("dd", "", String(value)));
    }
    summary.hidden = false;

    for (const entry of report) {
      const states = entry.rows.map(row => row.state);
      const complete = states.every(state => state === "good");
      const started = states.some(state => state !== "missing");
      const trouble = states.some(state => state === "bad" || state === "warn");
      if (!showEmpty && !started) continue;

      const panel = element("section", "panel bios-system");
      const head = element("div", "section-head");
      head.append(element("h2", "", entry.system.name),
        element("span", `status ${complete || (started && !trouble) ? "good" : started ? "bad" : ""}`.trim(),
          complete ? "Ready" : trouble ? "Needs attention" : started ? "Some found" : "No files"));
      panel.append(head);
      const list = element("ul", "bios-files");
      for (const row of entry.rows) {
        const item = element("li", `bios-${row.state}`);
        item.append(element("code", "", row.expected.file), element("span", "", ` ${row.note}`));
        list.append(item);
      }
      panel.append(list);
      holder.append(panel);
    }

    if (extras.length) {
      const panel = element("section", "panel bios-system");
      panel.append(element("h2", "", "Not recognised"));
      panel.append(element("p", "help", "These files are not in the manifests. They may belong to a core with its own BIOS list, or they can be removed."));
      const list = element("ul", "bios-files");
      for (const entry of extras) list.append(element("li", "", entry.path));
      panel.append(list);
      holder.append(panel);
    }

    if (skipped.size) {
      const panel = element("section", "panel bios-system");
      panel.append(element("h2", "", "Core data folders"));
      panel.append(element("p", "help", "No BIOS list names these folders, so they hold data that cores install or use, such as fonts and assets. They were not checked and can be left as they are."));
      const list = element("ul", "bios-files");
      for (const [folder, count] of [...skipped].sort((a, b) => naturalOrder(a[0], b[0])))
        list.append(element("li", "", `${folder}/ (${count.toLocaleString()} ${count === 1 ? "file" : "files"})`));
      panel.append(list);
      holder.append(panel);
    }

    $("#bios-empty").hidden = true;
  }

  async function load(fileList, folders = new Map()) {
    await loadSystems;
    const known = knownFolders();
    skipped = new Map(folders);
    const files = [...fileList].filter(file => {
      if (file.name.startsWith(".")) return false;
      const folder = dataFolder(relativePath(file), known);
      if (folder) skipped.set(folder, (skipped.get(folder) || 0) + 1);
      return !folder;
    });
    if (!files.length && !skipped.size) return;
    const found = [];
    for (let index = 0; index < files.length; index++) {
      setProgress(`Checking ${index + 1} of ${files.length}: ${files[index].name}`);
      found.push({path: relativePath(files[index]), hash: await md5(files[index])});
    }
    check(found);
    $("#bios-empty").textContent = emptyText;
    $("#bios-empty").classList.remove("busy");
    const passed = [...skipped.values()].reduce((total, count) => total + count, 0);
    setStatus(`Checked ${files.length} ${files.length === 1 ? "file" : "files"}.${passed
      ? ` Left ${passed.toLocaleString()} ${passed === 1 ? "file" : "files"} in core data folders unchecked.` : ""}`, "good");
  }

  async function filesFromDrop(items) {
    const files = [];
    async function walk(entry, prefix) {
      if (entry.isFile) {
        const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
        file.relativePath = prefix + file.name;
        files.push(file);
      } else if (entry.isDirectory) {
        const reader = entry.createReader();
        let batch;
        do {
          batch = await new Promise((resolve, reject) => reader.readEntries(resolve, reject));
          for (const child of batch) await walk(child, `${prefix}${entry.name}/`);
        } while (batch.length);
      }
    }
    for (const item of items) {
      const entry = item.webkitGetAsEntry && item.webkitGetAsEntry();
      if (entry) await walk(entry, "");
    }
    return files;
  }

  const device = window.MUTool;
  const systemData = device
    ? device.core().then(result => JSON.parse(result.text))
    : fetch("/assets/data/core-assign.json").then(response => response.json());

  const loadSystems = systemData
    .then(data => {
      systems = Object.values(data)
        .filter(system => Array.isArray(system.bios) && system.bios.length)
        .sort((a, b) => a.name.localeCompare(b.name));
    })
    .catch(() => setStatus("The BIOS list could not be loaded. Refresh the page to try again.", "bad"));

  $("#bios-folder").addEventListener("change", event => load(event.target.files));
  $("#bios-files").addEventListener("change", event => load(event.target.files));
  $("#bios-problems").addEventListener("change", () => { if (report.length) render(); });

  const tool = $("#bios-tool");
  tool.addEventListener("dragover", event => { event.preventDefault(); tool.classList.add("dropping"); });
  tool.addEventListener("dragleave", () => tool.classList.remove("dropping"));
  tool.addEventListener("drop", async event => {
    event.preventDefault();
    tool.classList.remove("dropping");
    let files = event.dataTransfer.items ? await filesFromDrop([...event.dataTransfer.items]) : [];
    if (!files.length) files = [...event.dataTransfer.files];
    load(files);
  });

  if (device) {
    device.bar($("#bios-tool .toolbar"), [
      ["Check This Device", async () => {
        try {
          setProgress("Reading MUOS/bios on the device");
          const listed = await device.list("bios");
          if (!listed.length) {
            setProgress("");
            setStatus("MUOS/bios on the device is empty.", "bad");
            return;
          }
          await loadSystems;
          const known = knownFolders();
          const folders = new Map();
          const wanted = listed.filter(entry => {
            const folder = dataFolder(entry.path, known);
            if (folder) folders.set(folder, (folders.get(folder) || 0) + 1);
            return !folder;
          });
          const files = [];
          for (let index = 0; index < wanted.length; index++) {
            setProgress(`Reading ${index + 1} of ${wanted.length}: ${wanted[index].path}`);
            const file = await device.file("bios", wanted[index].path);
            file.relativePath = `bios/${wanted[index].path}`;
            files.push(file);
          }
          await load(files, folders);
        } catch (error) {
          setProgress("");
          setStatus(`Could not read MUOS/bios on the device: ${error.message}`, "bad");
        }
      }, true]
    ]);
  }
})();
