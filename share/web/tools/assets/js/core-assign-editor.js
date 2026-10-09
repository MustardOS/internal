(() => {
  "use strict";

  const $ = selector => document.querySelector(selector);
  const $$ = selector => [...document.querySelectorAll(selector)];
  const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
  const plainObject = value => value !== null && typeof value === "object" && !Array.isArray(value);
  const lines = value => String(value || "").split(/\r?\n/).map(item => item.trim()).filter(Boolean);
  const clone = value => JSON.parse(JSON.stringify(value));
  const safeKey = key => key !== "__proto__" && key !== "prototype" && key !== "constructor";

  const FILENAME = "core.json";

  const FALLBACK_OPTIONS = {
    governor: ["conservative", "interactive", "ondemand", "performance", "powersave", "schedutil", "userspace"],
    control: [{ id: "system", name: "System" }, { id: "modern", name: "Modern" }, { id: "retro", name: "Retro" }],
    arch: [{ id: "aarch64", name: "ARM 64-bit" }, { id: "arm32", name: "ARM 32-bit" }, { id: "x64", name: "x86 64-bit" }, { id: "x86", name: "x86 32-bit" }],
    device: [],
    runtime: [{ id: "pickles", name: "Pickles" }, { id: "retroarch", name: "RetroArch" }, { id: "external", name: "External" }]
  };

  const RUNTIME_LABELS = { pickles: "Pickles", retroarch: "RetroArch", external: "External" };
  const GROUPS = ["libretro", "external"];
  const GROUP_LABELS = { libretro: "Libretro Cores", external: "External Emulators" };

  function tag(text, kind, title = "") {
    const node = document.createElement("span");
    node.className = `tag tag-${kind}`;
    node.textContent = text;
    if (title) node.title = title;
    return node;
  }

  function fillListButton(button, name, key, tags, detail = "") {
    const label = document.createElement("span");
    label.className = "name";
    label.textContent = name || key;
    button.replaceChildren(label);
    if (tags.length) {
      const row = document.createElement("span");
      row.className = "tags";
      row.append(...tags);
      button.append(row);
    }
    button.title = [name && name !== key ? `${name} (${key})` : key, detail].filter(Boolean).join(", ");
  }

  function limits(core) {
    if (!plainObject(core) || !plainObject(core.require)) return [];
    const parts = [];
    for (const [fact, label] of [["device", "Devices"], ["arch", "Architectures"]]) {
      const values = core.require[fact];
      if (Array.isArray(values) && values.length) parts.push(`${label}: ${values.join(", ")}`);
    }
    return parts;
  }

  function optionEntries(list) {
    if (!Array.isArray(list)) return [];
    return list.map(item => {
      if (!plainObject(item)) return { value: String(item), label: String(item) };
      const value = String(item.id ?? item.value ?? "");
      const name = item.name ?? item.label ?? "";
      return { value, label: name && name !== value ? `${name} (${value})` : value };
    }).filter(entry => entry.value);
  }

  const options = (() => {
    const node = document.getElementById("manifest-options");
    let parsed = {};
    try {
      if (node) parsed = JSON.parse(node.textContent);
    } catch (error) {
      parsed = {};
    }
    const result = {};
    for (const name of Object.keys(FALLBACK_OPTIONS)) {
      const entries = optionEntries(plainObject(parsed) ? parsed[name] : null);
      result[name] = entries.length ? entries : optionEntries(FALLBACK_OPTIONS[name]);
    }
    return result;
  })();

  // An empty list means the page shipped without that option data, so nothing can be judged unknown.
  function known(name, value) { return !options[name].length || options[name].some(entry => entry.value === value); }

  function option(value, label) {
    const node = document.createElement("option");
    node.value = value;
    node.textContent = label;
    return node;
  }

  function fillSelect(select) {
    const entries = options[select.dataset.options] || [];
    const blank = select.multiple ? [] : [option("", select.dataset.blank || "Not set")];
    select.replaceChildren(...blank, ...entries.map(entry => option(entry.value, entry.label)));
  }

  // A file may name a governor, board or build that this page does not list,
  // so keep the value selectable rather than dropping it on the next render.
  function keepUnlisted(select, values) {
    for (const node of [...select.options]) if (node.dataset.unlisted) node.remove();
    for (const value of values) {
      if (!value || [...select.options].some(node => node.value === value)) continue;
      const node = option(value, `${value} (not listed)`);
      node.dataset.unlisted = "1";
      select.append(node);
    }
  }

  const state = {
    doc: null,
    systemKey: "",
    group: "libretro",
    coreKey: "",
    systemFilter: "",
    coreFilter: ""
  };

  function defaultGroup(system) { return system && system.runtime === "external" ? "external" : "libretro"; }
  function groupOf(system, group) { return plainObject(system) && plainObject(system[group]) ? system[group] : {}; }
  function coreTotal(system) { return GROUPS.reduce((total, group) => total + Object.keys(groupOf(system, group)).length, 0); }

  function activeSystem() {
    const doc = state.doc;
    return doc && own(doc.data, state.systemKey) ? doc.data[state.systemKey] : null;
  }
  function activeCores() {
    const system = activeSystem();
    if (!system) return null;
    if (!plainObject(system[state.group])) system[state.group] = {};
    return system[state.group];
  }
  function activeCore() {
    const system = activeSystem();
    const cores = groupOf(system, state.group);
    return own(cores, state.coreKey) ? cores[state.coreKey] : null;
  }
  function pruneEmptyGroups(system) {
    for (const group of GROUPS) if (plainObject(system[group]) && !Object.keys(system[group]).length) delete system[group];
  }
  function uniqueKey(base, object) {
    let candidate = base;
    let number = 2;
    while (own(object, candidate) || !safeKey(candidate)) candidate = `${base} ${number++}`;
    return candidate;
  }
  function replaceKey(object, oldKey, newKey) {
    const replacement = Object.create(null);
    for (const [key, value] of Object.entries(object)) replacement[key === oldKey ? newKey : key] = value;
    return replacement;
  }
  function setStatus(message, kind = "") {
    const node = $("#status");
    node.textContent = message;
    node.className = `status ${kind}`.trim();
  }
  function markChanged() {
    if (state.doc) state.doc.changed = true;
    refreshTitle();
    refreshRawJson();
  }

  function oldFormat(data) {
    return Object.values(data).some(system => plainObject(system) && own(system, "cores"));
  }

  function selectSystem(key) {
    state.systemKey = key;
    state.group = defaultGroup(activeSystem());
    state.coreKey = "";
    state.coreFilter = "";
  }

  function openDocument(source, data) {
    if (!plainObject(data)) throw new Error("The file must contain a JSON object.");
    if (oldFormat(data)) throw new Error("This is a libretro.json or external.json file from an older release. Open a core.json file instead.");
    if (state.doc && state.doc.changed && !confirm("Replace the open file? Its changes have not been downloaded.")) return false;
    state.doc = { source, data, changed: false };
    state.systemFilter = "";
    selectSystem(Object.keys(data)[0] || "");
    render();
    return true;
  }

  async function openFile(file) {
    try {
      if (!openDocument(file.name, JSON.parse(await file.text()))) return;
      setStatus(`${file.name} opened.`, "good");
    } catch (error) {
      setStatus(`${file.name}: ${error.message}`, "bad");
    }
  }

  function refreshTitle() {
    const node = $("#file-name");
    if (!state.doc) { node.textContent = ""; return; }
    const source = state.doc.source && state.doc.source !== FILENAME ? `, opened from ${state.doc.source}` : "";
    node.textContent = `${FILENAME}${source}${state.doc.changed ? " (changed)" : ""}`;
  }

  function render() {
    const doc = state.doc;
    $("#workspace").hidden = !doc;
    $("#download").disabled = !doc;
    refreshTitle();
    if (!doc) return;
    $("#system-filter").value = state.systemFilter;
    renderSystemList();
    renderSystem();
    refreshRawJson();
    validate();
  }

  function renderSystemList() {
    const data = state.doc.data;
    const keys = Object.keys(data);
    $("#system-count").textContent = `(${keys.length})`;
    const filter = state.systemFilter.toLocaleLowerCase("en-AU");
    const visible = keys.filter(key => {
      const name = plainObject(data[key]) ? String(data[key].name || "") : "";
      return `${key} ${name}`.toLocaleLowerCase("en-AU").includes(filter);
    });
    const list = $("#system-list");
    list.replaceChildren();
    for (const key of visible) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = key === state.systemKey ? "active" : "";
      const system = plainObject(data[key]) ? data[key] : {};
      const tags = [];
      if (own(RUNTIME_LABELS, system.runtime)) tags.push(tag(RUNTIME_LABELS[system.runtime], "runtime"));
      if (system.extra === 1) tags.push(tag("Extra", "extra", "Only shown when Additional Cores is enabled"));
      const limited = GROUPS.flatMap(group => Object.entries(groupOf(system, group)).filter(([, core]) => limits(core).length).map(([coreKey, core]) => (plainObject(core) && core.name) || coreKey));
      if (limited.length) tags.push(tag("Limited", "limited", `Limited cores: ${limited.join(", ")}`));
      fillListButton(button, system.name, key, tags, own(RUNTIME_LABELS, system.runtime) ? `defaults to ${RUNTIME_LABELS[system.runtime]}` : "");
      button.addEventListener("click", () => {
        selectSystem(key);
        renderSystemList();
        renderSystem();
        validate();
      });
      list.append(button);
    }
    const selected = !!activeSystem();
    $("#duplicate-system").disabled = !selected;
    $("#remove-system").disabled = !selected;
  }

  function setInput(selector, value) {
    const node = $(selector);
    if (!node) return;
    const text = value ?? "";
    if (node.tagName === "SELECT" && !node.multiple) keepUnlisted(node, [text]);
    node.value = text;
  }

  function setMultiSelect(selector, values) {
    const node = $(selector);
    if (!node) return;
    const wanted = Array.isArray(values) ? values.map(String) : [];
    keepUnlisted(node, wanted);
    for (const entry of node.options) entry.selected = wanted.includes(entry.value);
  }

  function selectedValues(selector) { return [...$(selector).selectedOptions].map(entry => entry.value); }

  function renderNamespaceChoices() {
    const names = [...new Set(Object.values(state.doc.data).map(system => plainObject(system) ? String(system.namespace || "").trim() : "").filter(Boolean))]
      .sort((a, b) => a.localeCompare(b, "en-AU"));
    $("#namespace-keys").replaceChildren(...names.map(name => option(name, name)));
  }

  function renderDefaultChoices() {
    const system = activeSystem();
    const datalist = $("#default-keys");
    datalist.replaceChildren(...Object.keys(groupOf(system, defaultGroup(system))).map(key => option(key, key)));
    const automatic = !own(RUNTIME_LABELS, system.runtime) ? "Automatic tries Pickles first, then RetroArch, then External. " : "";
    $("#default-help").textContent = `${automatic}The default core is taken from ${GROUP_LABELS[defaultGroup(system)]}. Another runtime is used when that core is not available on a device.`;
  }

  function renderSystem() {
    const system = activeSystem();
    $("#editor-empty").hidden = !!system;
    $("#editor").hidden = !system;
    if (!system) return;

    $("#system-heading").textContent = system.name || state.systemKey;
    setInput("#system-key", state.systemKey);
    $$("[data-system-field]").forEach(input => setInput(`[data-system-field="${input.dataset.systemField}"]`, system[input.dataset.systemField]));
    $$("[data-system-number]").forEach(input => setInput(`[data-system-number="${input.dataset.systemNumber}"]`, Number(system[input.dataset.systemNumber]) || 0));
    $$("[data-system-optional]").forEach(input => setInput(`[data-system-optional="${input.dataset.systemOptional}"]`, system[input.dataset.systemOptional]));
    $$("[data-system-flag]").forEach(input => setInput(`[data-system-flag="${input.dataset.systemFlag}"]`, system[input.dataset.systemFlag] === 1 ? "1" : "0"));
    setInput("#friendly", Array.isArray(system.friendly) ? system.friendly.join("\n") : "");
    renderNamespaceChoices();
    renderDefaultChoices();
    renderBios();
    renderGroups();
    renderCoreList();
    renderCore();
    $("#system-json").value = JSON.stringify(system, null, 2);
  }

  function renderBios() {
    const system = activeSystem();
    const biosList = Array.isArray(system.bios) ? system.bios : [];
    const list = $("#bios-list");
    list.replaceChildren();
    biosList.forEach((bios, index) => {
      const row = document.createElement("div");
      row.className = "repeat-row";
      for (const field of ["file", "hash"]) {
        const label = document.createElement("label");
        const caption = document.createElement("span");
        caption.textContent = field === "file" ? "File" : "MD5 hash";
        const input = document.createElement("input");
        input.value = plainObject(bios) ? bios[field] || "" : "";
        input.addEventListener("input", () => {
          if (!plainObject(system.bios[index])) system.bios[index] = {};
          system.bios[index][field] = input.value;
          markChanged();
          validate();
        });
        label.append(caption, input);
        row.append(label);
      }
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "danger";
      remove.textContent = "Remove";
      remove.addEventListener("click", () => { system.bios.splice(index, 1); markChanged(); renderBios(); validate(); });
      row.append(remove);
      list.append(row);
    });
    if (!biosList.length) {
      const empty = document.createElement("div");
      empty.className = "help";
      empty.textContent = "No BIOS files listed.";
      list.append(empty);
    }
  }

  function renderGroups() {
    const system = activeSystem();
    const holder = $("#core-groups");
    holder.replaceChildren();
    for (const group of GROUPS) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = group === state.group ? "active" : "";
      button.textContent = `${GROUP_LABELS[group]} (${Object.keys(groupOf(system, group)).length})`;
      button.addEventListener("click", () => {
        state.group = group;
        state.coreKey = "";
        state.coreFilter = "";
        renderGroups();
        renderCoreList();
        renderCore();
      });
      holder.append(button);
    }
    $("#core-count").textContent = `(${coreTotal(system)})`;
    $("#launcher-label").textContent = state.group === "external" ? "Launcher" : "Launcher (optional)";
  }

  function renderCoreList() {
    const system = activeSystem();
    const cores = groupOf(system, state.group);
    const keys = Object.keys(cores);
    if (!own(cores, state.coreKey)) state.coreKey = keys[0] || "";
    $("#core-filter").value = state.coreFilter;
    const filter = state.coreFilter.toLocaleLowerCase("en-AU");
    const list = $("#core-list");
    list.replaceChildren();
    for (const key of keys) {
      const core = cores[key];
      const name = plainObject(core) ? String(core.name || "") : "";
      if (!`${key} ${name}`.toLocaleLowerCase("en-AU").includes(filter)) continue;
      const button = document.createElement("button");
      button.type = "button";
      button.className = key === state.coreKey ? "active" : "";
      const tags = [];
      if (key === system.default && state.group === defaultGroup(system)) tags.push(tag("Default", "default"));
      if (plainObject(core) && core.extra === 1) tags.push(tag("Extra", "extra", "Only shown when Additional Cores is enabled"));
      const limited = limits(core);
      if (limited.length) tags.push(tag("Limited", "limited", `Only offered on ${limited.join("; ")}`));
      fillListButton(button, name, key, tags);
      button.addEventListener("click", () => { state.coreKey = key; renderCoreList(); renderCore(); });
      list.append(button);
    }
    if (!keys.length) {
      const empty = document.createElement("div");
      empty.className = "help";
      empty.textContent = `No ${GROUP_LABELS[state.group]} for this system.`;
      list.append(empty);
    }
    $("#duplicate-core").disabled = !activeCore();
    $("#remove-core").disabled = !activeCore();
  }

  function renderCore() {
    const core = activeCore();
    $("#core-empty").hidden = !!core;
    $("#core-editor").hidden = !core;
    if (!core) return;
    setInput("#core-key", state.coreKey);
    $$("[data-core-field]").forEach(input => setInput(`[data-core-field="${input.dataset.coreField}"]`, core[input.dataset.coreField]));
    $$("[data-core-number]").forEach(input => setInput(`[data-core-number="${input.dataset.coreNumber}"]`, Number(core[input.dataset.coreNumber]) || 0));
    $$("[data-core-optional]").forEach(input => setInput(`[data-core-optional="${input.dataset.coreOptional}"]`, core[input.dataset.coreOptional]));
    $$("[data-core-flag]").forEach(input => setInput(`[data-core-flag="${input.dataset.coreFlag}"]`, core[input.dataset.coreFlag] === 1 ? "1" : "0"));
    const require = plainObject(core.require) ? core.require : {};
    setMultiSelect("#require-device", require.device);
    setMultiSelect("#require-arch", require.arch);
    $("#core-json").value = JSON.stringify(core, null, 2);
  }

  function refreshRawJson() {
    if (!state.doc) return;
    $("#manifest-json").value = JSON.stringify(state.doc.data, null, 2);
    const system = activeSystem();
    if (system) $("#system-json").value = JSON.stringify(system, null, 2);
    const core = activeCore();
    if (core) $("#core-json").value = JSON.stringify(core, null, 2);
  }

  function issue(issues, level, path, message) { issues.push({ level, path, message }); }
  function checkChoice(issues, entry, field, path) {
    if (!own(entry, field)) return;
    if (typeof entry[field] !== "string" || !entry[field].trim()) issue(issues, "error", `${path}.${field}`, "Use a non-empty string or remove the field.");
    else if (!known(field, entry[field])) issue(issues, "warning", `${path}.${field}`, `"${entry[field]}" is not a ${field} this tool lists.`);
  }
  function validateCore(issues, group, coreKey, core, path) {
    const corePath = `${path}.${group}.${coreKey || "(empty core key)"}`;
    if (!coreKey.trim() || !safeKey(coreKey)) issue(issues, "error", corePath, "Core key is empty or reserved.");
    if (!plainObject(core)) { issue(issues, "error", corePath, "Core must be an object."); return; }
    for (const field of ["name", "core"]) if (typeof core[field] !== "string" || !core[field].trim()) issue(issues, "error", `${corePath}.${field}`, "A non-empty string is required.");
    if (group === "external" && (typeof core.launcher !== "string" || !core.launcher.trim())) issue(issues, "error", `${corePath}.launcher`, "External emulators need a launcher.");
    if (own(core, "extra") && core.extra !== 0 && core.extra !== 1) issue(issues, "error", `${corePath}.extra`, "Use 0 or 1.");
    if (own(core, "bios_required") && core.bios_required !== 0 && core.bios_required !== 1) issue(issues, "error", `${corePath}.bios_required`, "Use 0 or 1.");
    checkChoice(issues, core, "governor", corePath);
    checkChoice(issues, core, "control", corePath);
    if (!own(core, "require")) return;
    if (!plainObject(core.require)) { issue(issues, "error", `${corePath}.require`, "Use an object of string arrays."); return; }
    for (const [fact, values] of Object.entries(core.require)) {
      if (!Array.isArray(values) || values.some(value => typeof value !== "string")) { issue(issues, "error", `${corePath}.require.${fact}`, "Use an array of strings."); continue; }
      if (!own(options, fact)) { issue(issues, "warning", `${corePath}.require.${fact}`, "Only device and arch requirements are checked on the device."); continue; }
      for (const value of values) if (!known(fact, value)) issue(issues, "warning", `${corePath}.require.${fact}`, `"${value}" is not a ${fact} this tool lists.`);
    }
  }
  function validateData(data) {
    const issues = [];
    if (!plainObject(data)) {
      issue(issues, "error", FILENAME, "Root value must be an object.");
      return issues;
    }
    for (const [systemKey, system] of Object.entries(data)) {
      const path = systemKey || "(empty system key)";
      if (!systemKey.trim() || !safeKey(systemKey)) issue(issues, "error", path, "System key is empty or reserved.");
      if (!plainObject(system)) { issue(issues, "error", path, "System must be an object."); continue; }
      for (const field of ["name", "namespace", "catalogue", "default"]) {
        if (typeof system[field] !== "string" || !system[field].trim()) issue(issues, "error", `${path}.${field}`, "A non-empty string is required.");
      }
      if (system.lookup !== 0 && system.lookup !== 1) issue(issues, "error", `${path}.lookup`, "Use 0 or 1.");
      if (!Array.isArray(system.friendly) || system.friendly.some(value => typeof value !== "string")) issue(issues, "error", `${path}.friendly`, "Use an array of strings.");
      checkChoice(issues, system, "governor", path);
      checkChoice(issues, system, "control", path);
      if (own(system, "extra") && system.extra !== 0 && system.extra !== 1) issue(issues, "error", `${path}.extra`, "Use 0 or 1.");
      if (own(system, "runtime") && !own(RUNTIME_LABELS, system.runtime)) issue(issues, "error", `${path}.runtime`, "Use pickles, retroarch or external.");
      if (own(system, "cores")) issue(issues, "error", `${path}.cores`, "Move these cores into libretro or external.");
      if (!Array.isArray(system.bios)) issue(issues, "error", `${path}.bios`, "Use an array.");
      else system.bios.forEach((bios, index) => {
        if (!plainObject(bios) || typeof bios.file !== "string" || typeof bios.hash !== "string") issue(issues, "error", `${path}.bios[${index}]`, "Each BIOS entry needs string file and hash values.");
        else if (bios.hash && !/^[a-f0-9]{32}$/i.test(bios.hash)) issue(issues, "warning", `${path}.bios[${index}].hash`, "The current files use 32-character MD5 hashes.");
      });
      for (const group of GROUPS) {
        if (own(system, group) && !plainObject(system[group])) { issue(issues, "error", `${path}.${group}`, "Use an object of cores."); continue; }
        for (const [coreKey, core] of Object.entries(groupOf(system, group))) validateCore(issues, group, coreKey, core, path);
      }
      if (!coreTotal(system)) { issue(issues, "error", path, "Add at least one Libretro core or External emulator."); continue; }
      const group = defaultGroup(system);
      const defaultCore = groupOf(system, group)[system.default];
      if (own(groupOf(system, group), system.default) && plainObject(defaultCore) && defaultCore.extra === 1)
        issue(issues, "error", `${path}.${group}.${system.default}.extra`, "The default core cannot be an extra core. Choose another default or clear Extra core.");
      if (!own(groupOf(system, group), system.default)) {
        const other = GROUPS.find(entry => entry !== group && own(groupOf(system, entry), system.default));
        issue(issues, "error", `${path}.default`, other
          ? `"${system.default}" is in ${GROUP_LABELS[other]}, but the default runtime reads ${GROUP_LABELS[group]}. Change the default runtime or the default core.`
          : `"${system.default}" is not in ${GROUP_LABELS[group]}.`);
      }
    }
    return issues;
  }

  function validate() {
    if (!state.doc) return [];
    const issues = validateData(state.doc.data);
    const list = $("#validation-list");
    list.replaceChildren();
    if (!issues.length) {
      const item = document.createElement("li");
      item.textContent = "No structural problems found.";
      item.className = "good";
      list.append(item);
    } else {
      for (const entry of issues) {
        const item = document.createElement("li");
        item.className = entry.level;
        item.textContent = `${entry.path}: ${entry.message}`;
        list.append(item);
      }
    }
    const errors = issues.filter(entry => entry.level === "error").length;
    const warnings = issues.length - errors;
    $("#validation-summary").textContent = `${errors} error${errors === 1 ? "" : "s"}, ${warnings} warning${warnings === 1 ? "" : "s"}`;
    return issues;
  }

  function applyJson(textarea, target) {
    try {
      const parsed = JSON.parse(textarea.value);
      if (!plainObject(parsed)) throw new Error("Value must be a JSON object.");
      target(parsed);
      markChanged();
      render();
      setStatus("JSON applied.", "good");
    } catch (error) {
      setStatus(error.message, "bad");
    }
  }

  function newCore(group) {
    return group === "external" ? { name: "New Emulator", core: "ext-new", launcher: "general.sh" } : { name: "New Core", core: "new_libretro.so" };
  }

  $("#file-input").addEventListener("change", event => { if (event.target.files[0]) openFile(event.target.files[0]); event.target.value = ""; });
  $("#new-file").addEventListener("click", () => { if (openDocument(FILENAME, {})) setStatus("Started a new core.json.", "good"); });
  $("#validate").addEventListener("click", () => {
    const issues = validate();
    const errors = issues.filter(entry => entry.level === "error").length;
    setStatus(errors ? `Validation found ${errors} error${errors === 1 ? "" : "s"}.` : "Validation complete.", errors ? "bad" : "good");
  });
  $("#download").addEventListener("click", () => {
    const doc = state.doc;
    if (!doc) return;
    const errors = validate().filter(entry => entry.level === "error");
    if (errors.length && !confirm(`This file has ${errors.length} validation error${errors.length === 1 ? "" : "s"}. Download it anyway?`)) return;
    const blob = new Blob([`${JSON.stringify(doc.data, null, 2)}\n`], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = FILENAME;
    link.click();
    URL.revokeObjectURL(link.href);
    doc.changed = false;
    refreshTitle();
    setStatus(`Downloaded ${FILENAME}.`, "good");
  });

  $("#system-filter").addEventListener("input", event => { state.systemFilter = event.target.value; renderSystemList(); });
  $("#core-filter").addEventListener("input", event => { state.coreFilter = event.target.value; renderCoreList(); });
  $("#add-system").addEventListener("click", () => {
    const data = state.doc.data;
    const key = uniqueKey("New System", data);
    data[key] = { name: key, namespace: "", catalogue: key, lookup: 0, default: "new core", friendly: [], bios: [], libretro: { "new core": newCore("libretro") } };
    selectSystem(key);
    state.coreKey = "new core";
    markChanged();
    render();
  });
  $("#duplicate-system").addEventListener("click", () => {
    const data = state.doc.data;
    const key = uniqueKey(`${state.systemKey} Copy`, data);
    data[key] = clone(activeSystem());
    data[key].name = key;
    selectSystem(key);
    markChanged();
    render();
  });
  $("#remove-system").addEventListener("click", () => {
    const data = state.doc.data;
    if (!activeSystem() || !confirm(`Remove ${state.systemKey}?`)) return;
    delete data[state.systemKey];
    selectSystem(Object.keys(data)[0] || "");
    markChanged();
    render();
  });
  $("#system-key").addEventListener("change", event => {
    const doc = state.doc;
    const key = event.target.value.trim();
    if (!key || !safeKey(key) || (key !== state.systemKey && own(doc.data, key))) { setStatus("System key must be unique, non-empty, and not reserved.", "bad"); event.target.value = state.systemKey; return; }
    doc.data = replaceKey(doc.data, state.systemKey, key);
    state.systemKey = key;
    markChanged();
    render();
  });
  $$("[data-system-field]").forEach(input => input.addEventListener("input", event => {
    activeSystem()[event.target.dataset.systemField] = event.target.value;
    markChanged();
    if (event.target.dataset.systemField === "default") renderCoreList();
    validate();
  }));
  $$("[data-system-number]").forEach(input => input.addEventListener("change", event => { activeSystem()[event.target.dataset.systemNumber] = Number(event.target.value); markChanged(); validate(); }));
  $$("[data-system-optional]").forEach(input => input.addEventListener("input", event => {
    const system = activeSystem(); const key = event.target.dataset.systemOptional; const value = event.target.value.trim();
    if (value) system[key] = event.target.value; else delete system[key];
    markChanged();
    if (key === "runtime") {
      renderSystemList();
      renderDefaultChoices();
      renderCoreList();
    }
    validate();
  }));
  $$("[data-system-flag]").forEach(input => input.addEventListener("change", event => {
    const system = activeSystem(); const key = event.target.dataset.systemFlag;
    if (event.target.value === "1") system[key] = 1; else delete system[key];
    markChanged(); renderSystemList(); validate();
  }));
  $("#friendly").addEventListener("input", event => { activeSystem().friendly = lines(event.target.value); markChanged(); validate(); });
  $("#add-bios").addEventListener("click", () => {
    const system = activeSystem();
    if (!Array.isArray(system.bios)) system.bios = [];
    system.bios.push({ file: "", hash: "" }); markChanged(); renderBios(); validate();
  });

  function refreshCores() {
    pruneEmptyGroups(activeSystem());
    markChanged(); renderSystemList(); renderGroups(); renderDefaultChoices(); renderCoreList(); renderCore(); validate();
  }

  $("#add-core").addEventListener("click", () => {
    const cores = activeCores();
    const key = uniqueKey("new core", cores);
    cores[key] = newCore(state.group);
    state.coreKey = key;
    refreshCores();
  });
  $("#duplicate-core").addEventListener("click", () => {
    const cores = activeCores(); const key = uniqueKey(`${state.coreKey} copy`, cores);
    cores[key] = clone(activeCore()); cores[key].name = `${cores[key].name || state.coreKey} Copy`;
    state.coreKey = key;
    refreshCores();
  });
  $("#remove-core").addEventListener("click", () => {
    const cores = activeCores(); if (!activeCore() || !confirm(`Remove ${state.coreKey}?`)) return;
    delete cores[state.coreKey]; state.coreKey = Object.keys(cores)[0] || "";
    refreshCores();
  });
  $("#core-key").addEventListener("change", event => {
    const system = activeSystem(); const cores = activeCores(); const key = event.target.value.trim();
    if (!key || !safeKey(key) || (key !== state.coreKey && own(cores, key))) { setStatus("Core key must be unique in this group, non-empty, and not reserved.", "bad"); event.target.value = state.coreKey; return; }
    const oldKey = state.coreKey;
    system[state.group] = replaceKey(cores, oldKey, key);
    if (system.default === oldKey && state.group === defaultGroup(system)) system.default = key;
    state.coreKey = key; markChanged(); render();
  });
  $$("[data-core-field]").forEach(input => input.addEventListener("input", event => { activeCore()[event.target.dataset.coreField] = event.target.value; markChanged(); validate(); }));
  $$("[data-core-number]").forEach(input => input.addEventListener("change", event => { activeCore()[event.target.dataset.coreNumber] = Number(event.target.value); markChanged(); validate(); }));
  $$("[data-core-optional]").forEach(input => input.addEventListener("input", event => {
    const core = activeCore(); const key = event.target.dataset.coreOptional; const value = event.target.value.trim();
    if (value) core[key] = event.target.value; else delete core[key];
    markChanged(); validate();
  }));
  $$("[data-core-flag]").forEach(input => input.addEventListener("change", event => {
    const core = activeCore(); const key = event.target.dataset.coreFlag;
    if (event.target.value === "1") core[key] = 1; else delete core[key];
    markChanged(); renderSystemList(); renderCoreList(); validate();
  }));
  function updateRequirement() {
    const core = activeCore();
    const device = selectedValues("#require-device"); const arch = selectedValues("#require-arch");
    const existing = plainObject(core.require) ? core.require : {};
    if (device.length) existing.device = device; else delete existing.device;
    if (arch.length) existing.arch = arch; else delete existing.arch;
    if (Object.keys(existing).length) core.require = existing; else delete core.require;
    markChanged(); renderSystemList(); renderCoreList(); validate();
  }
  $("#require-device").addEventListener("change", updateRequirement);
  $("#require-arch").addEventListener("change", updateRequirement);

  $$("select[data-options]").forEach(fillSelect);

  $("#apply-core-json").addEventListener("click", () => applyJson($("#core-json"), value => { activeCores()[state.coreKey] = value; }));
  $("#apply-system-json").addEventListener("click", () => applyJson($("#system-json"), value => { state.doc.data[state.systemKey] = value; }));
  $("#apply-manifest-json").addEventListener("click", () => applyJson($("#manifest-json"), value => {
    if (oldFormat(value)) throw new Error("This is the older libretro.json or external.json layout. Use the core.json layout.");
    state.doc.data = value;
    selectSystem(Object.keys(value)[0] || "");
  }));

  const device = window.MUTool;
  if (device) {
    const loadFromDevice = async () => {
      try {
        const { source, text } = await device.core();
        if (!openDocument(source === "user" ? "core.json on the device" : "bundled core.json", JSON.parse(text))) return;
        state.doc.changed = false;
        refreshTitle();
        setStatus(source === "user" ? "Opened your core.json from the device." : "Opened the bundled core.json. Saving creates your own copy.", "good");
      } catch (error) {
        setStatus(`Could not open core.json from the device: ${error.message}`, "bad");
      }
    };
    device.bar($(".toolbar"), [
      ["Reload", loadFromDevice],
      ["Reset to Bundled", async () => {
        if (!confirm("Remove your core.json and go back to the bundled one? A backup is kept as core.json.bak.")) return;
        try {
          await device.resetCore();
          await loadFromDevice();
          setStatus("Your core.json was removed. The bundled file is in use again.", "good");
        } catch (error) {
          setStatus(error.message, "bad");
        }
      }],
      ["Save to Device", async () => {
        if (!state.doc) return;
        const errors = validate().filter(entry => entry.level === "error");
        if (errors.length && !confirm(`This file has ${errors.length} validation error${errors.length === 1 ? "" : "s"}. Save it anyway?`)) return;
        try {
          await device.saveCore(`${JSON.stringify(state.doc.data, null, 2)}\n`);
          state.doc.changed = false;
          state.doc.source = "core.json on the device";
          refreshTitle();
          setStatus("Saved to the device. The previous file is kept as core.json.bak.", "good");
        } catch (error) {
          setStatus(error.message, "bad");
        }
      }, true]
    ]);
    loadFromDevice();
  }
})();
