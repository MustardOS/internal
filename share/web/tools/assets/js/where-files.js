(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const normalise = value => value.toLowerCase().replace(/[\s\-_+]/g, "");
  let systems = [];

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function score(system, query) {
    const plain = normalise(query);
    if (!plain) return 0;
    if (system.friendly.includes(plain)) return 100;
    if (normalise(system.name) === plain) return 90;
    if (system.friendly.some(name => name.startsWith(plain))) return 60;
    if (normalise(system.name).includes(plain)) return 50;
    if (system.friendly.some(name => name.includes(plain))) return 30;
    if (system.cores.some(entry => normalise(entry.core.name).includes(plain))) return 10;
    return 0;
  }

  function card(system) {
    const article = element("article", "panel files-card");
    const head = element("div", "section-head");
    head.append(element("h2", "", system.name), element("span", "help", system.namespace));
    article.append(head);

    article.append(element("h3", "", "Automatically assigned folder names"));
    const chips = element("div", "files-chips");
    for (const name of system.friendly) chips.append(element("code", "", name));
    article.append(chips);

    article.append(element("h3", "", "Cores"));
    const list = element("ul", "files-cores");
    const defaultGroup = system.runtime === "external" ? "external" : "libretro";
    for (const { group, key, core } of system.cores) {
      const item = element("li");
      item.append(element("strong", "", core.name));
      if (key === system.default && group === defaultGroup) item.append(element("span", "files-badge", "Default"));
      if (core.bios_required) item.append(element("span", "files-badge warn", "Needs BIOS"));
      if (group === "external") item.append(element("span", "help", ` External launcher ${core.launcher || ""}`));
      list.append(item);
    }
    article.append(list);

    if (system.bios.length) {
      article.append(element("h3", "", "BIOS files for MUOS/bios"));
      const bios = element("ul", "files-bios");
      for (const file of system.bios) {
        const item = element("li");
        item.append(element("code", "", file.file));
        if (file.hash) item.append(element("span", "help", ` MD5 ${file.hash.toLowerCase()}`));
        bios.append(item);
      }
      article.append(bios);
    }
    return article;
  }

  function render() {
    const query = $("#files-query").value.trim();
    const holder = $("#files-results");
    holder.replaceChildren();
    if (!query) {
      $("#files-status").textContent = `${systems.length} systems known. Start typing to find yours.`;
      return;
    }
    const matches = systems.map(system => [score(system, query), system])
      .filter(([value]) => value > 0)
      .sort((a, b) => b[0] - a[0] || a[1].name.localeCompare(b[1].name))
      .slice(0, 12);
    $("#files-status").textContent = matches.length
      ? `${matches.length} ${matches.length === 1 ? "match" : "matches"} for "${query}".`
      : `Nothing matches "${query}". Try the console's short name, such as snes or psx.`;
    for (const [, system] of matches) holder.append(card(system));
  }

  (window.MUTool
    ? window.MUTool.core().then(result => JSON.parse(result.text))
    : fetch("/assets/data/core-assign.json").then(response => response.json()))
    .then(data => {
      systems = Object.values(data).map(system => ({
        ...system,
        friendly: (system.friendly || []).map(normalise),
        bios: system.bios || [],
        cores: ["libretro", "external"].flatMap(group => Object.entries(system[group] || {}).map(([key, core]) => ({ group, key, core })))
      }));
      render();
    })
    .catch(() => { $("#files-status").textContent = "The system list could not be loaded. Refresh the page to try again."; });

  $("#files-query").addEventListener("input", render);
})();
