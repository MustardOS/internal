(() => {
  "use strict";

  // Pages copied into the Web Dashboard carry this marker, so the same tools can open and
  // save files on the device there and keep using file pickers and downloads on the website.
  if (!document.querySelector('meta[name="mustardos-device"]')) {
    window.MUTool = null;
    return;
  }

  const SESSION_KEY = "muos-session";
  const encode = path => path.split("/").map(encodeURIComponent).join("/");

  function session() {
    try { return sessionStorage.getItem(SESSION_KEY) || ""; } catch (error) { return ""; }
  }

  function remember(token) {
    try {
      if (token) sessionStorage.setItem(SESSION_KEY, token);
      else sessionStorage.removeItem(SESSION_KEY);
    } catch (error) {
      return;
    }
  }

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function dialog(title) {
    const box = element("dialog", "device-dialog");
    const form = element("form");
    form.method = "dialog";
    form.append(element("h2", "", title));
    box.append(form);
    (document.querySelector(".tool") || document.body).append(box);
    box.addEventListener("close", () => box.remove());
    return { box, form };
  }

  function actions(form, confirmLabel) {
    const row = element("div", "row-actions");
    const cancel = element("button", "", "Cancel");
    cancel.type = "button";
    cancel.addEventListener("click", () => form.parentElement.close(""));
    row.append(cancel);
    if (confirmLabel) {
      const confirm = element("button", "primary", confirmLabel);
      confirm.value = "ok";
      row.append(confirm);
    }
    form.append(row);
  }

  function ask(title, label, value = "", note = "") {
    return new Promise(resolve => {
      const { box, form } = dialog(title);
      if (note) form.append(element("p", "help", note));
      const field = element("label");
      const input = element("input");
      input.value = value;
      input.autocomplete = "off";
      field.append(element("span", "", label), input);
      form.append(field);
      actions(form, "OK");
      box.addEventListener("close", () => resolve(box.returnValue === "ok" ? input.value.trim() : ""));
      box.showModal();
      input.focus();
      input.select();
    });
  }

  function choose(title, items, note = "") {
    return new Promise(resolve => {
      const { box, form } = dialog(title);
      if (note) form.append(element("p", "help", note));
      let picked = null;
      const filter = element("input");
      filter.type = "search";
      filter.placeholder = "Filter";
      filter.autocomplete = "off";
      const list = element("div", "list device-list");
      const render = () => {
        const query = filter.value.toLocaleLowerCase("en-AU");
        list.replaceChildren();
        const shown = items.filter(item => `${item.label} ${item.hint || ""}`.toLocaleLowerCase("en-AU").includes(query));
        for (const item of shown) {
          const button = element("button", "");
          button.type = "button";
          const name = element("span", "name", item.label);
          button.append(name);
          if (item.hint) button.append(element("span", "help", item.hint));
          button.title = item.label;
          button.addEventListener("click", () => { picked = item.value; box.close("ok"); });
          list.append(button);
        }
        if (!shown.length) list.append(element("div", "help", items.length ? "Nothing matches." : "Nothing here yet."));
      };
      filter.addEventListener("input", render);
      if (items.length > 8) form.append(filter);
      form.append(list);
      actions(form, "");
      render();
      box.addEventListener("close", () => resolve(box.returnValue === "ok" ? picked : null));
      box.showModal();
    });
  }

  async function unlock(message) {
    const code = await ask("Unlock the dashboard", "Code shown on the device", "", message || "Saving to the device needs the code shown on its screen.");
    if (!code) return false;
    const response = await fetch("/api/session", { method: "POST", headers: { "X-muOS-Code": code }, cache: "no-store" });
    let payload = {};
    try { payload = await response.json(); } catch (error) { payload = {}; }
    if (!response.ok || !payload.token) throw new Error(payload.error || "That code was not accepted");
    remember(payload.token);
    return true;
  }

  async function request(path, options = {}, retried = false) {
    const headers = Object.assign({}, options.headers || {});
    const token = session();
    if (token) headers["X-muOS-Session"] = token;
    const response = await fetch(path, { method: options.method || "GET", body: options.body, headers, cache: "no-store" });
    if (response.status === 401 && !retried) {
      remember("");
      let payload = {};
      try { payload = await response.clone().json(); } catch (error) { payload = {}; }
      if (await unlock(payload.error)) return request(path, options, true);
      throw new Error("Not saved, the dashboard is still locked");
    }
    if (!response.ok) {
      let payload = {};
      try { payload = await response.json(); } catch (error) { payload = {}; }
      throw new Error(payload.error || `Request failed (${response.status})`);
    }
    return response;
  }

  const json = async path => (await request(path)).json();

  window.MUTool = {
    device: true,
    ask,
    choose,
    info: () => json("/api/tools"),
    list: async area => (await json(`/api/tools/${area}`)).files || [],
    folders: async area => (await json(`/api/tools/${area}`)).folders || [],
    listIn: async (area, dir) => (await json(`/api/tools/${area}/${encode(dir)}/`)).files || [],
    text: async (area, path) => (await request(`/api/tools/${area}/${encode(path)}`)).text(),
    file: async (area, path) => {
      const blob = await (await request(`/api/tools/${area}/${encode(path)}`)).blob();
      return new File([blob], path.split("/").pop(), { type: blob.type });
    },
    save: async (area, path, data) => {
      await request(`/api/tools/${area}/${encode(path)}`, { method: "POST", body: data });
    },
    core: async () => {
      const state = await json("/api/tools/core");
      const text = await (await request("/api/tools/core/core.json")).text();
      return { source: state.source, text };
    },
    saveCore: async text => { await request("/api/tools/core", { method: "POST", body: text }); },
    resetCore: async () => { await request("/api/tools/core", { method: "DELETE" }); },
    contentRoots: async () => (await json("/api/tools/content")).roots || [],
    folder: (root, dir) => json(`/api/tools/content/${root}/${dir ? `${encode(dir)}/` : ""}`),
    readPlaylist: async (root, path) => (await request(`/api/tools/content/${root}/${encode(path)}`)).text(),
    savePlaylist: async (root, path, text) => {
      await request(`/api/tools/content/${root}/${encode(path)}`, { method: "POST", body: text });
    },
    bar(anchor, buttons) {
      const row = element("div", "toolbar device-bar");
      row.append(element("span", "device-label", "On this device"));
      for (const [label, handler, primary] of buttons) {
        const button = element("button", primary ? "primary" : "", label);
        button.type = "button";
        button.addEventListener("click", async () => {
          button.disabled = true;
          try { await handler(); } finally { button.disabled = false; }
        });
        row.append(button);
      }
      anchor.before(row);
      return row;
    }
  };
})();
