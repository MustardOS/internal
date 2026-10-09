(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
  const plain = value => value !== null && typeof value === "object" && !Array.isArray(value);
  const safeKey = key => key !== "__proto__" && key !== "prototype" && key !== "constructor";
  let data = Object.create(null);
  let filter = "";

  const help = {
    folder: "Keys are actual folder names in lower case. Values are the names shown when Friendly Folder Names is enabled. This file downloads as folder.json.",
    global: "Keys are content filenames without their final extension, in lower case. Values are the names shown throughout content lists. This file downloads as global.json.",
    specific: "Works like global.json for one ROM folder. Name the file after that folder, for example Nintendo Game Boy Advance.json. A folder-specific file replaces global lookup for that folder."
  };

  function setStatus(text, kind = "") { $("#status").textContent = text; $("#status").className = `status ${kind}`.trim(); }
  function sortedEntries() { return Object.entries(data).sort((a, b) => a[0].localeCompare(b[0], "en-AU", { sensitivity: "base" })); }
  function uniqueKey(base) { let key = base; let i = 2; while (own(data, key) || !safeKey(key)) key = `${base} ${i++}`; return key; }
  function replaceKey(oldKey, newKey) {
    const next = Object.create(null);
    for (const [key, value] of Object.entries(data)) next[key === oldKey ? newKey : key] = value;
    data = next;
  }
  function inferredKind(name) { return name.toLowerCase() === "folder.json" ? "folder" : name.toLowerCase() === "global.json" ? "global" : "specific"; }
  function stem(name) { const at = name.lastIndexOf("."); return (at > 0 ? name.slice(0, at) : name).toLocaleLowerCase("en-AU"); }

  function renderKind() {
    const kind = $("#kind").value;
    $("#kind-help").textContent = help[kind];
    $("#content-files").disabled = kind === "folder";
    $("#choose-files").disabled = kind === "folder";
    if (kind === "folder") $("#filename").value = "folder.json";
    if (kind === "global") $("#filename").value = "global.json";
    if (kind === "specific" && ["folder.json", "global.json"].includes($("#filename").value.toLowerCase())) $("#filename").value = "Content Folder.json";
    validate();
  }

  function render() {
    const query = filter.toLocaleLowerCase("en-AU");
    const entries = sortedEntries().filter(([key, value]) => `${key} ${value}`.toLocaleLowerCase("en-AU").includes(query));
    const holder = $("#entries");
    holder.replaceChildren();
    $("#count").textContent = `(${Object.keys(data).length})`;
    $("#empty").hidden = entries.length !== 0;
    for (const [key, value] of entries) {
      const row = document.createElement("div"); row.className = "entry";
      const keyLabel = document.createElement("label");
      const keyCaption = document.createElement("span"); keyCaption.textContent = "Lookup key";
      const keyInput = document.createElement("input"); keyInput.value = key;
      keyInput.addEventListener("change", () => {
        const next = keyInput.value.trim().toLocaleLowerCase("en-AU");
        if (!next || !safeKey(next) || (next !== key && own(data, next))) { setStatus("Lookup keys must be unique, non-empty and not reserved.", "bad"); keyInput.value = key; return; }
        replaceKey(key, next); render(); validate();
      });
      keyLabel.append(keyCaption, keyInput);
      const valueLabel = document.createElement("label");
      const valueCaption = document.createElement("span"); valueCaption.textContent = "Display name";
      const valueInput = document.createElement("input"); valueInput.value = value;
      valueInput.addEventListener("input", () => { data[key] = valueInput.value; refreshRaw(); validate(); });
      valueLabel.append(valueCaption, valueInput);
      const remove = document.createElement("button"); remove.type = "button"; remove.className = "danger"; remove.textContent = "Remove";
      remove.addEventListener("click", () => { delete data[key]; render(); validate(); });
      row.append(keyLabel, valueLabel, remove); holder.append(row);
    }
    refreshRaw();
  }

  function refreshRaw() { $("#raw").value = JSON.stringify(data, null, 2); }
  function validate() {
    const issues = [];
    const filename = $("#filename").value.trim();
    const kind = $("#kind").value;
    if (!filename || !filename.toLowerCase().endsWith(".json") || filename.includes("/") || filename.includes("\\")) issues.push(["error", "Filename must end in .json and must not contain a path."]);
    if (kind === "folder" && filename.toLowerCase() !== "folder.json") issues.push(["warning", "Friendly folder lookup normally uses folder.json."]);
    if (kind === "global" && filename.toLowerCase() !== "global.json") issues.push(["warning", "Global content lookup normally uses global.json."]);
    if (kind === "specific" && ["folder.json", "global.json"].includes(filename.toLowerCase())) issues.push(["error", "Use the exact content-folder name for a folder-specific lookup."]);
    for (const [key, value] of Object.entries(data)) {
      if (!key.trim() || !safeKey(key)) issues.push(["error", `Invalid key: ${key || "(empty)"}`]);
      if (key !== key.toLocaleLowerCase("en-AU")) issues.push(["warning", `${key}: lookup keys should be lower case.`]);
      if (typeof value !== "string" || !value.trim()) issues.push(["error", `${key}: display name must be a non-empty string.`]);
    }
    const list = $("#issues"); list.replaceChildren();
    if (!issues.length) {
      const item = document.createElement("li"); item.textContent = "No structural problems found."; item.className = "good"; list.append(item);
      setStatus(`${Object.keys(data).length} valid entr${Object.keys(data).length === 1 ? "y" : "ies"}.`, "good");
    } else {
      for (const [level, message] of issues) { const item = document.createElement("li"); item.className = level; item.textContent = message; list.append(item); }
      const errors = issues.filter(([level]) => level === "error").length;
      setStatus(errors ? `${errors} error${errors === 1 ? "" : "s"}.` : "Warnings found.", errors ? "bad" : "");
    }
    return issues;
  }

  $("#kind").addEventListener("change", renderKind);
  $("#filename").addEventListener("input", validate);
  $("#filter").addEventListener("input", event => { filter = event.target.value; render(); });
  $("#new").addEventListener("click", () => { if (Object.keys(data).length && !confirm("Clear the current lookup and start a new file?")) return; data = Object.create(null); render(); setStatus("New lookup ready.", "good"); });
  $("#add").addEventListener("click", () => { const key = uniqueKey("new entry"); data[key] = "New Name"; render(); validate(); });
  $("#sort").addEventListener("click", () => { const sorted = Object.create(null); for (const [key, value] of sortedEntries()) sorted[key] = value; data = sorted; render(); setStatus("Entries sorted.", "good"); });
  $("#choose-files").addEventListener("click", () => $("#content-files").click());
  $("#content-files").addEventListener("change", event => {
    let added = 0;
    for (const file of event.target.files) {
      const key = stem(file.name);
      if (!key || own(data, key) || !safeKey(key)) continue;
      const at = file.name.lastIndexOf(".");
      data[key] = at > 0 ? file.name.slice(0, at) : file.name;
      added++;
    }
    event.target.value = ""; render(); validate(); setStatus(`${added} content entr${added === 1 ? "y" : "ies"} added.`, "good");
  });
  function openText(name, text) {
    const parsed = JSON.parse(text);
    if (!plain(parsed) || Object.values(parsed).some(value => typeof value !== "string")) throw new Error("The file must be one JSON object containing string values.");
    data = Object.assign(Object.create(null), parsed);
    $("#kind").value = inferredKind(name); $("#filename").value = name;
    filter = ""; $("#filter").value = ""; renderKind(); render(); setStatus(`${name} opened.`, "good");
  }
  function serialised() {
    const sorted = Object.create(null); for (const [key, value] of sortedEntries()) sorted[key] = value;
    return `${JSON.stringify(sorted, null, 2)}\n`;
  }
  $("#open").addEventListener("change", async event => {
    const file = event.target.files[0]; if (!file) return;
    try { openText(file.name, await file.text()); } catch (error) { setStatus(error.message, "bad"); }
    event.target.value = "";
  });
  $("#apply").addEventListener("click", () => {
    try {
      const parsed = JSON.parse($("#raw").value);
      if (!plain(parsed) || Object.values(parsed).some(value => typeof value !== "string")) throw new Error("The file must be one JSON object containing string values.");
      data = Object.assign(Object.create(null), parsed); render(); validate(); setStatus("JSON applied.", "good");
    } catch (error) { setStatus(error.message, "bad"); }
  });
  $("#download").addEventListener("click", () => {
    const errors = validate().filter(([level]) => level === "error");
    if (errors.length) { setStatus("Fix validation errors before downloading.", "bad"); return; }
    const blob = new Blob([serialised()], { type: "application/json" });
    const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = $("#filename").value.trim(); link.click(); URL.revokeObjectURL(link.href);
    setStatus(`${link.download} downloaded.`, "good");
  });

  renderKind(); render();

  const device = window.MUTool;
  if (device) {
    device.bar($(".toolbar"), [
      ["Open from Device", async () => {
        try {
          const files = (await device.list("name")).map(file => file.path).filter(path => !path.includes("/"));
          const items = files.sort((a, b) => a.localeCompare(b, "en-AU")).map(path => ({ label: path, value: path, hint: path === "folder.json" ? "Friendly folders" : path === "global.json" ? "Global game names" : "One content folder" }));
          const picked = await device.choose("Open a name lookup from MUOS/info/name", items);
          if (!picked) return;
          openText(picked, await device.text("name", picked));
        } catch (error) { setStatus(error.message, "bad"); }
      }],
      ["Save to Device", async () => {
        const errors = validate().filter(([level]) => level === "error");
        if (errors.length) { setStatus("Fix validation errors before saving.", "bad"); return; }
        const name = $("#filename").value.trim();
        if (!/\.json$/i.test(name) || name.includes("/")) { setStatus("The filename must end in .json and cannot include a folder.", "bad"); return; }
        try {
          await device.save("name", name, serialised());
          setStatus(`Saved ${name} to MUOS/info/name. Any previous copy is kept as ${name}.bak.`, "good");
        } catch (error) { setStatus(error.message, "bad"); }
      }, true]
    ]);
  }
})();
