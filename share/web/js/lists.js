(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, stamp, showToast, busy, crumbs, loading, problem, api, apiPath, ask, register, t} = MU;

    const LOCKED_HINT = "Unlock to manage with the Web Dashboard Code shown on the device.";

    function hint(busy, message) {
        if (busy) return t(message);
        return MU.canManageLists() ? "" : t(LOCKED_HINT);
    }

    function action(label, handler, danger) {
        const button = make("button", danger ? "link danger" : "link", t(label));
        button.type = "button";
        button.addEventListener("click", () => handler(button));
        return button;
    }

    function entryRow(item, actions, manage) {
        const row = make("div", "entry");
        const main = make("div", "entry-main");
        const meta = [item.system, stamp(item.modified)].filter(Boolean).join(" · ");

        main.append(make("span", "entry-name", item.name || item.path));
        if (meta) main.append(make("span", "entry-meta", meta));

        const path = make("span", item.exists ? "entry-path" : "entry-path entry-missing",
            item.exists ? item.path : t("%s (missing)", item.path));
        main.append(path);

        const tools = make("div", "entry-actions");
        if (manage) tools.append(...actions);

        row.append(main, tools);
        return row;
    }

    function matches(item, needle) {
        if (!needle) return true;
        return [item.name, item.path, item.system].some((value) => (value || "").toLocaleLowerCase().includes(needle));
    }

    function emptyNote(text) {
        return make("p", "note list-hint", t(text));
    }

    async function run(button, label, task, done) {
        try {
            await busy(button, t(label), task);
            showToast(done, "good");
            return true;
        } catch (error) {
            showToast(error.message, "bad");
            return false;
        }
    }

    async function askPath(item) {
        return ask({
            title: t("Update path"),
            message: t("Where %s lives now. The file must already exist on the device.", item.name || t("this content")),
            confirm: t("Save"),
            input: {value: item.path, placeholder: "/mnt/sdcard/ROMS/…"}
        });
    }

    function collectionChoices(names, current) {
        return [{value: "", label: t("Top level")}, ...names.map((name) => ({value: name, label: name}))]
            .filter((choice) => choice.value !== current);
    }

    const historyView = (function () {
        const body = el("history-body");
        const search = el("history-search");
        let items = [];
        let folders = [];
        let busy = 0;

        function render() {
            const needle = search.value.trim().toLocaleLowerCase();
            const visible = items.filter((item) => matches(item, needle));
            const manage = MU.canManageLists() && !busy;

            el("history-count").textContent = needle ? t("%s of %s", visible.length, items.length) : String(items.length);
            el("history-hint").textContent = hint(busy, "History is open on the device, so changes are paused until it is closed there.");

            if (!items.length) return body.replaceChildren(emptyNote("Nothing has been played yet."));
            if (!visible.length) return body.replaceChildren(emptyNote("Nothing matches that search."));

            const list = make("div", "entries");
            list.append(...visible.map((item) => entryRow(item, [
                action("Update path", (button) => repoint(item, button)),
                action("Add to collection", (button) => collect(item, button)),
                action("Remove", (button) => remove(item, button), true)
            ], manage)));
            body.replaceChildren(list);
        }

        async function repoint(item, button) {
            const path = await askPath(item);
            if (!path || path === item.path) return;
            if (await run(button, "Saving…",
                () => api(`api/history/${apiPath(item.id, "path")}`, {method: "PUT", body: path, type: "text/plain"}),
                "Path updated"))
                await load();
        }

        async function collect(item, button) {
            const name = await ask({
                title: t("Add to collection"),
                message: t("Choose where %s should go.", item.name || t("this content")),
                confirm: t("Add"),
                choices: collectionChoices(folders, null)
            });
            if (name === null) return;
            await run(button, "Adding…",
                () => api(`api/history/${apiPath(item.id, "collect")}`, {method: "POST", body: name, type: "text/plain"}),
                "Added to collection");
        }

        async function remove(item, button) {
            const sure = await ask({
                title: t("Remove from history"),
                message: t("%s will be removed from History. The content itself is not touched.", item.name || item.path),
                confirm: t("Remove"),
                danger: true
            });
            if (!sure) return;
            if (await run(button, "Removing…", () => api(`api/history/${apiPath(item.id)}`, {method: "DELETE"}),
                "Removed from history"))
                await load();
        }

        async function load() {
            if (!body.childElementCount) body.replaceChildren(loading("Reading the history…"));
            try {
                const fresh = await api("api/history");
                items = fresh.items || [];
                busy = fresh.busy || 0;
                if (MU.canManageLists()) {
                    try {
                        folders = ((await api("api/collection")).collections || []).map((entry) => entry.name);
                    } catch (_) {
                        folders = [];
                    }
                }
                render();
            } catch (error) {
                body.replaceChildren(problem(error.message, load));
            }
        }

        search.addEventListener("input", render);
        return {load, render};
    }());

    const collections = (function () {
        const body = el("collections-body");
        const search = el("collections-search");
        let data = {items: [], collections: []};
        let opened = null;
        let crumbsFor;

        function folderItems(name) {
            const folder = data.collections.find((entry) => entry.name === name);
            return folder ? folder.items : null;
        }

        function names() {
            return data.collections.map((entry) => entry.name);
        }

        function paintCrumbs() {
            if (crumbsFor === opened) return;
            crumbsFor = opened;
            const trail = [{label: t("Collections"), go: opened === null ? null : () => open(null)}];
            if (opened !== null) trail.push({label: opened});
            crumbs(el("collections-crumbs"), trail);
        }

        function itemRows(items, needle, manage) {
            return items.filter((item) => matches(item, needle)).map((item) => entryRow(item, [
                action("Update path", (button) => repoint(item, button)),
                action("Move", (button) => move(item, button)),
                action("Remove", (button) => removeItem(item, button), true)
            ], manage));
        }

        function folderCard(folder, manage, shown) {
            const card = make("div", "folder-card");
            const name = make("button", "folder-name", folder.name);
            name.type = "button";
            name.addEventListener("click", () => open(folder.name));

            const total = folder.items.length;
            const meta = make("span", "folder-count", shown === undefined
                ? t(total === 1 ? "%s item" : "%s items", total)
                : t("%s of %s", shown, total));
            card.append(name, meta);

            if (manage) {
                const tools = make("div", "folder-actions");
                tools.append(
                    action("Rename", (button) => rename(folder, button)),
                    action("Remove", (button) => removeFolder(folder, button), true)
                );
                card.append(tools);
            }

            return card;
        }

        function render() {
            const needle = search.value.trim().toLocaleLowerCase();
            const manage = MU.canManageLists() && !data.busy;
            paintCrumbs();
            el("collections-hint").textContent = hint(data.busy,
                "Collections is open on the device, so changes are paused until it is closed there.");

            const folderHolder = el("collections-folders");
            const title = el("collections-items-title");
            let items;

            if (opened === null) {
                const tools = make("div", "list-tools");
                if (manage) tools.append(action("New collection", create));

                if (needle) {
                    const groups = data.collections.map((folder) => {
                        const named = folder.name.toLocaleLowerCase().includes(needle);
                        const hits = named ? folder.items : folder.items.filter((item) => matches(item, needle));
                        return {folder, named, hits};
                    }).filter((group) => group.named || group.hits.length);

                    const results = make("div", "folder-results");
                    results.append(...groups.map(({folder, hits}) => {
                        const group = make("div", "folder-group");
                        group.append(folderCard(folder, manage, hits.length));
                        if (hits.length) {
                            const list = make("div", "entries");
                            list.append(...itemRows(hits, "", manage));
                            group.append(list);
                        }
                        return group;
                    }));
                    folderHolder.replaceChildren(tools,
                        groups.length ? results : emptyNote("No collections match that search."));
                } else {
                    const grid = make("div", "folder-grid");
                    grid.append(...data.collections.map((folder) => folderCard(folder, manage)));
                    folderHolder.replaceChildren(tools,
                        data.collections.length ? grid : emptyNote("No collections yet."));
                }
                folderHolder.hidden = false;

                title.textContent = t("Not in a collection");
                items = data.items;
            } else {
                items = folderItems(opened);
                if (!items) {
                    opened = null;
                    return render();
                }
                folderHolder.replaceChildren();
                folderHolder.hidden = true;
                title.textContent = opened;
            }

            const rows = itemRows(items, needle, manage);
            if (!rows.length) {
                const empty = needle ? "Nothing matches that search."
                    : opened === null ? "Everything is in a collection." : "This collection is empty.";
                return body.replaceChildren(emptyNote(empty));
            }

            const list = make("div", "entries");
            list.append(...rows);
            body.replaceChildren(list);
        }

        function open(name) {
            opened = name;
            MU.navigate(name);
            render();
        }

        async function create(button) {
            const name = await ask({
                title: t("New collection"),
                confirm: t("Create"),
                input: {value: "", placeholder: t("Collection name")}
            });
            if (!name || !name.trim()) return;
            if (await run(button, "Creating…", () => api(`api/collection/${apiPath(name.trim())}`, {method: "PUT"}),
                "Collection created"))
                await load();
        }

        async function rename(folder, button) {
            const name = await ask({
                title: t("Rename collection"),
                confirm: t("Rename"),
                input: {value: folder.name}
            });
            if (!name || !name.trim() || name.trim() === folder.name) return;
            if (await run(button, "Renaming…",
                () => api(`api/collection/${apiPath(folder.name, "rename")}`,
                    {method: "POST", body: name.trim(), type: "text/plain"}),
                "Collection renamed"))
                await load();
        }

        async function removeFolder(folder, button) {
            if (folder.items.length) {
                showToast("Move or remove everything in this collection first");
                return;
            }
            const sure = await ask({
                title: t("Remove collection"),
                message: t("%s will be removed.", folder.name),
                confirm: t("Remove"),
                danger: true
            });
            if (!sure) return;
            if (await run(button, "Removing…", () => api(`api/collection/${apiPath(folder.name)}`, {method: "DELETE"}),
                "Collection removed"))
                await load();
        }

        async function repoint(item, button) {
            const path = await askPath(item);
            if (!path || path === item.path) return;
            if (await run(button, "Saving…",
                () => api(`api/collection/${apiPath(...item.id.split("/"), "path")}`,
                    {method: "PUT", body: path, type: "text/plain"}),
                "Path updated"))
                await load();
        }

        async function move(item, button) {
            const current = item.id.includes("/") ? item.id.split("/")[0] : "";
            const choices = collectionChoices(names(), current);
            if (!choices.length) {
                showToast("Create another collection to move this into");
                return;
            }
            const name = await ask({
                title: t("Move to collection"),
                message: t("Choose where %s should go.", item.name || t("this content")),
                confirm: t("Move"),
                choices
            });
            if (name === null) return;
            if (await run(button, "Moving…",
                () => api(`api/collection/${apiPath(...item.id.split("/"), "move")}`,
                    {method: "POST", body: name, type: "text/plain"}),
                "Moved"))
                await load();
        }

        async function removeItem(item, button) {
            const sure = await ask({
                title: t("Remove from collection"),
                message: t("%s will be removed from the collection. The content itself is not touched.", item.name || item.path),
                confirm: t("Remove"),
                danger: true
            });
            if (!sure) return;
            if (await run(button, "Removing…",
                () => api(`api/collection/${apiPath(...item.id.split("/"))}`, {method: "DELETE"}),
                "Removed from collection"))
                await load();
        }

        async function load() {
            if (!body.childElementCount) body.replaceChildren(loading("Reading the collections…"));
            try {
                const fresh = await api("api/collection");
                data = {items: fresh.items || [], collections: fresh.collections || [], busy: fresh.busy || 0};
                render();
            } catch (error) {
                body.replaceChildren(problem(error.message, load));
            }
        }

        function restore(where) {
            opened = typeof where === "string" ? where : null;
            load();
        }

        search.addEventListener("input", render);
        return {load, render, restore};
    }());

    setInterval(() => {
        if (document.hidden) return;
        if (!el("view-history").hidden) historyView.load();
        if (!el("view-collections").hidden) collections.load();
    }, 15000);

    MU.onAuthChange(() => {
        if (!el("view-history").hidden) historyView.load();
        if (!el("view-collections").hidden) collections.load();
    });

    register("history", {load: historyView.load, restore: historyView.load});
    register("collections", {load: () => collections.restore(null), restore: collections.restore});
}());
