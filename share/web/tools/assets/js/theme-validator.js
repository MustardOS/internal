(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const data = JSON.parse($("#theme-data").textContent);
  const glyphs = new Set(data.glyphs.filter(Boolean));
  const modules = new Set(data.modules);
  const resolutions = new Set(data.resolutions);
  const sounds = new Set(data.sounds);
  const ROOT_FOLDERS = new Set(["scheme", "font", "glyph", "image", "alternate", "sound", "rgb", "overlay"]);
  const RES_FOLDERS = new Set(["scheme", "font", "glyph", "image"]);
  const META = ["name.txt", "version.txt", "credits.txt"];
  const IMAGE_LIMIT = 4 * 1024 * 1024;
  let findings = [];
  let level = "all";

  function setStatus(text, kind = "") {
    $("#theme-status").textContent = text;
    $("#theme-status").className = `status ${kind}`.trim();
  }

  function add(kind, path, message) {
    findings.push({kind, path, message});
  }

  function distance(a, b) {
    const row = Array.from({length: b.length + 1}, (_, index) => index);
    for (let i = 1; i <= a.length; i++) {
      let previous = row[0];
      row[0] = i;
      for (let j = 1; j <= b.length; j++) {
        const current = row[j];
        row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1));
        previous = current;
      }
    }
    return row[b.length];
  }

  function nearest(word, options) {
    let best = "";
    let score = Infinity;
    for (const option of options) {
      const value = distance(word, option);
      if (value < score) {
        score = value;
        best = option;
      }
    }
    return score <= Math.max(2, Math.floor(word.length / 4)) ? best : "";
  }

  function readText(file) {
    return file.text();
  }

  function checkValue(path, line, section, key, kind, value) {
    const text = value.trim();
    if (kind === "hex" && !/^#?[0-9a-fA-F]{6}$/.test(text))
      add("error", path, `Line ${line}: [${section}] ${key} should be a six digit colour such as FFFFFF, found "${text}"`);
    else if ((kind === "int" || kind === "uint") && !/^-?\d+$/.test(text))
      add("error", path, `Line ${line}: [${section}] ${key} should be a whole number, found "${text}"`);
    else if (kind === "uint" && Number(text) < 0)
      add("error", path, `Line ${line}: [${section}] ${key} cannot be negative`);
    else if (kind === "float" && Number.isNaN(Number(text)))
      add("error", path, `Line ${line}: [${section}] ${key} should be a number, found "${text}"`);
    else if (key.endsWith("_ALPHA") && /^\d+$/.test(text) && Number(text) > 255)
      add("warning", path, `Line ${line}: [${section}] ${key} is ${text}, but alpha values go up to 255`);
  }

  async function checkScheme(path, file) {
    const text = await readText(file);
    let section = "";
    const seen = new Set();
    const sections = Object.keys(data.scheme);
    text.split(/\r?\n/).forEach((raw, index) => {
      const line = raw.trim();
      if (!line || line.startsWith("#") || line.startsWith(";")) return;
      const header = line.match(/^\[(.+)\]$/);
      if (header) {
        section = header[1].trim();
        if (!data.scheme[section]) {
          const guess = nearest(section, sections);
          add("warning", path, `Line ${index + 1}: section [${section}] is not read by MustardOS${guess ? `. Did you mean [${guess}]?` : ""}`);
        }
        return;
      }
      const equals = line.indexOf("=");
      if (equals < 0) {
        add("warning", path, `Line ${index + 1}: "${line}" is not a KEY = value line`);
        return;
      }
      const key = line.slice(0, equals).trim();
      const value = line.slice(equals + 1);
      if (!section) {
        add("warning", path, `Line ${index + 1}: ${key} is outside any [section]`);
        return;
      }
      const known = data.scheme[section];
      if (!known) return;
      if (!known[key]) {
        const guess = nearest(key, Object.keys(known));
        add("warning", path, `Line ${index + 1}: [${section}] ${key} is not read by MustardOS${guess ? `. Did you mean ${guess}?` : ""}`);
        return;
      }
      const id = `${section}.${key}`;
      if (seen.has(id)) add("warning", path, `Line ${index + 1}: [${section}] ${key} is set more than once; the last value wins`);
      seen.add(id);
      checkValue(path, index + 1, section, key, known[key], value);
    });
  }

  async function imageSize(file) {
    try {
      const bitmap = await createImageBitmap(file);
      const size = {width: bitmap.width, height: bitmap.height};
      bitmap.close();
      return size;
    } catch (_) {
      return null;
    }
  }

  async function checkFile(path, file, resolution, label = path) {
    const parts = path.split("/");
    const area = parts[0];
    const name = parts[parts.length - 1];
    const extension = name.includes(".") ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : "";

    if (area === "scheme") {
      if (extension !== "ini") return add("warning", label, "Only .ini files are read from scheme");
      const stem = name.slice(0, -4);
      if (stem !== "global" && stem !== "default" && !modules.has(stem))
        add("warning", label, `${stem} is not a MustardOS module, so this file is never read`);
      if (stem === "global" && resolution) add("warning", label, "global.ini is only read from the theme root");
      return checkScheme(label, file);
    }

    if (area === "glyph") {
      if (parts.length < 3) return add("warning", label, "Glyphs belong in glyph/<module>/<name>.svg");
      if (extension !== "svg" && extension !== "png") return add("warning", label, "Glyphs should be .svg or .png files");
      const key = `${parts[1]}/${name.slice(0, name.lastIndexOf("."))}`;
      if (!glyphs.has(key)) add("note", label, "This glyph name is not used by the bundled theme, so it may never be shown");
      return;
    }

    if (area === "font") {
      if (extension !== "ttf" && extension !== "otf") add("warning", label, "Fonts should be TrueType (.ttf) or OpenType (.otf)");
      return;
    }

    if (area === "sound") {
      if (extension !== "wav") return add("warning", label, "Interface sounds should be .wav files");
      if (!sounds.has(name.slice(0, -4))) add("note", label, "This sound name is not one the frontend plays");
      return;
    }

    if (area === "image") {
      if (file.size > IMAGE_LIMIT) add("warning", label, `This file is ${(file.size / 1048576).toFixed(1)} MB and will slow loading`);
      if ((extension === "png" || extension === "jpg" || extension === "jpeg") && parts[1] === "wall" && resolution) {
        const size = await imageSize(file);
        if (size && `${size.width}x${size.height}` !== resolution)
          add("warning", label, `Wallpaper is ${size.width}x${size.height} but sits in the ${resolution} folder`);
      }
    }
  }

  async function validate(files) {
    findings = [];
    const entries = files.map(file => {
      const full = file.webkitRelativePath || file.relativePath || file.name;
      const parts = full.split("/");
      return {file, path: parts.length > 1 ? parts.slice(1).join("/") : parts[0], theme: parts.length > 1 ? parts[0] : ""};
    }).filter(entry => !entry.path.split("/").some(part => part.startsWith(".")));

    const name = entries.find(entry => entry.path === "name.txt");
    $("#theme-name").textContent = name ? (await name.file.text()).trim() || entries[0].theme : entries[0].theme || "Theme";

    const paths = new Set(entries.map(entry => entry.path));
    for (const meta of META) if (!paths.has(meta)) add("warning", meta, "Missing. Theme pickers and the theme site show this information");

    const topLevel = new Set(entries.map(entry => entry.path.split("/")[0]));
    let resolutionCount = 0;
    for (const top of topLevel) {
      if (!top.includes(".") || top === "assets.muxzip") {
        if (/^\d+x\d+$/.test(top)) {
          if (!resolutions.has(top)) add("error", top, `${top} is not a supported resolution, so this folder is never read`);
          else resolutionCount += 1;
        } else if (!ROOT_FOLDERS.has(top) && top !== "assets.muxzip" && !paths.has(top)) {
          add("warning", top, "This folder is not part of the theme structure and is ignored");
        }
      }
    }

    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      setStatus(`Checking ${index + 1} of ${entries.length}: ${entry.path}`);
      const parts = entry.path.split("/");
      if (parts.length === 1) {
        if (!META.includes(parts[0]) && !["active.txt", "assets.muxzip"].includes(parts[0]) && !/^preview(\.\d+)?\.png$/.test(parts[0]))
          add("note", entry.path, "Loose file in the theme root");
        continue;
      }
      if (/^\d+x\d+$/.test(parts[0])) {
        if (!resolutions.has(parts[0])) continue;
        const inner = parts.slice(1);
        if (inner.length === 1) continue;
        if (!RES_FOLDERS.has(inner[0])) {
          add("warning", entry.path, `${inner[0]} is not read from a resolution folder`);
          continue;
        }
        await checkFile(inner.join("/"), entry.file, parts[0], entry.path);
        continue;
      }
      if (parts[0] === "alternate") {
        const name = parts[parts.length - 1].toLowerCase();
        if (parts.length === 2 && name.endsWith(".ini")) await checkScheme(entry.path, entry.file);
        else if (parts.length === 2 && !name.endsWith(".muxalt")) add("warning", entry.path, "Alternatives should be .ini schemes or .muxalt packages");
        continue;
      }
      if (ROOT_FOLDERS.has(parts[0])) await checkFile(entry.path, entry.file, "");
    }

    if (!resolutionCount && !topLevel.has("scheme")) add("error", "scheme", "No scheme folder in the root or any resolution folder");
    render(entries.length);
  }

  function render(total) {
    const counts = {error: 0, warning: 0, note: 0};
    for (const finding of findings) counts[finding.kind] += 1;
    const summary = $("#theme-summary");
    summary.replaceChildren();
    for (const [label, value] of [["Files checked", total], ["Errors", counts.error], ["Warnings", counts.warning], ["Notes", counts.note]]) {
      const term = document.createElement("dt");
      term.textContent = label;
      const detail = document.createElement("dd");
      detail.textContent = String(value);
      summary.append(term, detail);
    }
    const verdict = $("#theme-verdict");
    verdict.textContent = counts.error ? "Has errors" : counts.warning ? "Works, with warnings" : "Ready to share";
    verdict.className = `status ${counts.error ? "bad" : counts.warning ? "" : "good"}`.trim();
    renderList();
    $("#theme-empty").hidden = true;
    $("#theme-report").hidden = false;
    setStatus(`Checked ${total} files.`, counts.error ? "bad" : "good");
  }

  function renderList() {
    const list = $("#theme-findings");
    list.replaceChildren();
    const shown = findings.filter(finding => level === "all" || finding.kind === level)
      .sort((a, b) => a.path.localeCompare(b.path));
    if (!shown.length) {
      const item = document.createElement("li");
      item.className = "good";
      item.textContent = level === "all" ? "No problems found." : "Nothing in this group.";
      list.append(item);
      return;
    }
    for (const finding of shown) {
      const item = document.createElement("li");
      item.className = finding.kind;
      const path = document.createElement("code");
      path.textContent = finding.path;
      item.append(path, document.createTextNode(` ${finding.message}`));
      list.append(item);
    }
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

  function start(files) {
    const list = [...files];
    if (!list.length) return;
    validate(list).catch(error => setStatus(`The theme could not be checked: ${error.message}`, "bad"));
  }

  $("#theme-folder").addEventListener("change", event => start(event.target.files));
  document.querySelectorAll("#theme-report .tabs button").forEach(button => {
    button.addEventListener("click", () => {
      level = button.dataset.level;
      document.querySelectorAll("#theme-report .tabs button").forEach(other => other.classList.toggle("active", other === button));
      renderList();
    });
  });
  const tool = $("#theme-tool");
  tool.addEventListener("dragover", event => { event.preventDefault(); tool.classList.add("dropping"); });
  tool.addEventListener("dragleave", () => tool.classList.remove("dropping"));
  tool.addEventListener("drop", async event => {
    event.preventDefault();
    tool.classList.remove("dropping");
    let files = event.dataTransfer.items ? await filesFromDrop([...event.dataTransfer.items]) : [];
    if (!files.length) files = [...event.dataTransfer.files];
    start(files);
  });

  const device = window.MUTool;
  if (device) {
    device.bar($("#theme-tool .toolbar"), [
      ["Check an Installed Theme", async () => {
        try {
          const folders = (await device.folders("theme")).filter(name => name.toLowerCase() !== "override");
          const picked = await device.choose("Check a theme installed on the device", folders.sort((a, b) => a.localeCompare(b, "en-AU")).map(name => ({label: name, value: name})));
          if (!picked) return;
          const listed = await device.listIn("theme", picked);
          const files = [];
          for (let index = 0; index < listed.length; index++) {
            setStatus(`Reading ${index + 1} of ${listed.length} from ${picked}`);
            const file = await device.file("theme", listed[index].path);
            file.relativePath = listed[index].path;
            files.push(file);
          }
          start(files);
        } catch (error) {
          setStatus(`Could not read that theme from the device: ${error.message}`, "bad");
        }
      }, true]
    ]);
  }
})();
