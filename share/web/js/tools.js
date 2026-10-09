(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {register} = MU;
    const list = document.getElementById("tools-list");
    const empty = document.getElementById("tools-empty");
    let loaded = false;

    function row(tool) {
        const link = document.createElement("a");
        link.className = "tool-row";
        link.href = `tools/${encodeURIComponent(tool.slug)}`;

        if (tool.icon) {
            const icon = document.createElement("img");
            icon.src = `tools/${tool.icon}`;
            icon.alt = "";
            icon.width = 40;
            icon.height = 40;
            link.append(icon);
        }

        const text = document.createElement("span");
        text.className = "tool-row-text";
        const title = document.createElement("span");
        title.className = "tool-row-title";
        title.textContent = tool.title;
        const description = document.createElement("span");
        description.className = "tool-row-desc";
        description.textContent = tool.description;
        text.append(title, description);
        link.append(text);
        return link;
    }

    async function load() {
        if (loaded) return;
        try {
            const response = await fetch("tools/tools.json", {cache: "no-store"});
            if (!response.ok) throw new Error(String(response.status));
            const tools = await response.json();
            list.replaceChildren(...tools.map(row));
            empty.hidden = tools.length > 0;
            loaded = true;
        } catch (_) {
            list.replaceChildren();
            empty.hidden = false;
        }
    }

    async function fillNav() {
        const holder = document.getElementById("nav-tools");
        if (!holder) return;
        try {
            const response = await fetch("tools/tools.json", {cache: "no-store"});
            if (!response.ok) return;
            for (const tool of await response.json()) {
                const item = document.createElement("li");
                item.className = "nav-list-item";
                const link = document.createElement("a");
                link.className = "nav-list-link";
                link.href = `tools/${encodeURIComponent(tool.slug)}`;
                link.textContent = tool.title;
                item.append(link);
                holder.append(item);
            }
        } catch (_) {
        }
    }

    register("tools", {load});
    fillNav();
}());
