(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, stamp, showToast, busy, crumbs, loading, problem, api, apiPath, ask, register, sortableHead, t} = MU;

    const LOCKED_HINT = "Unlock to manage with the Web Dashboard Code shown on the device.";

    function hint(busy, message) {
        if (busy) return t(message);
        return MU.canManageLists() ? "" : t(LOCKED_HINT);
    }

    const GLYPHS = {Collection: "plus", Rename: "edit", "Update path": "path", "Add to collection": "folder-plus", Move: "move", Remove: "trash"};

    function action(label, handler, danger, iconOnly) {
        const text = t(label);
        const button = make("button", `link${danger ? " danger" : ""}${iconOnly ? " file-action" : ""}`,
            iconOnly ? undefined : text);
        button.type = "button";
        if (GLYPHS[label]) button.dataset.glyph = GLYPHS[label];
        if (iconOnly) {
            button.dataset.tooltip = text;
            button.title = text;
            button.setAttribute("aria-label", text);
        }
        button.addEventListener("click", () => handler(button));
        return button;
    }

    const collator = new Intl.Collator(undefined, {numeric: true, sensitivity: "base"});

    function readSort(key, column, descending) {
        try {
            const state = JSON.parse(localStorage.getItem(key));
            if (["name", "date"].includes(state.column)) {
                return {key, column: state.column, descending: Boolean(state.descending)};
            }
        } catch (_) {
        }
        return {key, column, descending};
    }

    function writeSort(state, column, descending) {
        state.column = column;
        state.descending = descending;
        try {
            localStorage.setItem(state.key, JSON.stringify({column, descending}));
        } catch (_) {
        }
    }

    function sortedItems(items, state) {
        return [...items].sort((left, right) => {
            let result;
            if (state.column === "date") result = (left.modified || 0) - (right.modified || 0);
            else result = collator.compare(left.name || left.path, right.name || right.path);
            if (!result) result = collator.compare(left.name || left.path, right.name || right.path);
            return state.descending ? -result : result;
        });
    }

    function entryRow(item, actions, manage, selection) {
        const row = make("tr");
        const selectCell = make("td", "table-select");
        if (manage && selection) {
            const selector = make("input", "file-select");
            selector.type = "checkbox";
            selector.checked = selection.selected.has(item.id);
            selector.setAttribute("aria-label", t("Select %s", item.name || item.path));
            selector.addEventListener("change", () => selection.change(item, selector.checked));
            selectCell.append(selector);
        }
        const name = make("span", "entry-name file-name", item.name || item.path);
        if (item.exists === 0 || item.exists === false) name.classList.add("entry-missing");
        name.title = item.name || item.path;
        const nameCell = make("td", "content-name-cell");
        nameCell.append(name);
        const dateCell = make("td", "number table-date", stamp(item.modified));
        const tools = make("div", "entry-actions");
        if (manage) tools.append(...actions);
        const toolsCell = make("td", "table-options");
        toolsCell.append(tools);
        row.append(selectCell, nameCell, dateCell, toolsCell);
        return row;
    }

    function folderRow(folder, actions, manage, open, selection) {
        const row = make("tr", "collection-folder-row");
        const selectCell = make("td", "table-select");
        if (manage && selection && selection.folderKey) {
            row.classList.add("file-entry-selectable");
            const selector = make("input", "file-select");
            selector.type = "checkbox";
            selector.checked = selection.selected.has(selection.folderKey(folder));
            selector.setAttribute("aria-label", t("Select %s", folder.name));
            selector.addEventListener("change", () => selection.changeFolder(folder, selector.checked));
            selectCell.append(selector);
        }
        const name = make("button", "entry-name collection-folder-name", folder.name);
        name.type = "button";
        name.title = folder.name;
        name.addEventListener("click", open);
        const count = make("span", "collection-folder-count",
            t(folder.items.length === 1 ? "%s item" : "%s items", folder.items.length));
        const nameCell = make("td", "content-name-cell");
        nameCell.append(name, count);
        const dateCell = make("td", "number table-date");
        const tools = make("div", "entry-actions");
        if (manage) tools.append(...actions);
        const toolsCell = make("td", "table-options");
        toolsCell.append(tools);
        row.append(selectCell, nameCell, dateCell, toolsCell);
        return row;
    }

    function itemTable({items, folders, actionsFor, folderActions, manage, state, onSort, selection, openFolder,
        nameLabel = "Content"}) {
        const table = make("table", "data-table browser-table content-table");
        const head = make("thead");
        head.append(sortableHead([
            {label: "", className: "table-select"},
            {key: "name", label: nameLabel},
            {key: "date", label: "Date", descending: true, className: "table-date"},
            {label: "Options", className: "table-options"}
        ], state.column, state.descending, onSort));
        const tableBody = make("tbody");
        (folders || []).forEach((folder) => tableBody.append(folderRow(folder,
            folderActions ? folderActions(folder) : [], manage, () => openFolder(folder.name), selection)));
        sortedItems(items, state).forEach((item) =>
            tableBody.append(entryRow(item, actionsFor(item), manage, selection)));
        table.append(head, tableBody);
        const scroll = make("div", "table-scroll");
        scroll.append(table);
        return scroll;
    }

    function contentPath(path) {
        return (path || "").replace(/^\/mnt\/[^/]+\/(ROMS\/)?/i, "");
    }

    function matches(item, needle) {
        if (!needle) return true;
        return [item.name, contentPath(item.path), item.system]
            .some((value) => (value || "").toLocaleLowerCase().includes(needle));
    }

    function emptyNote(text) {
        return make("p", "note list-hint", t(text));
    }

    async function run(button, label, task, done) {
        try {
            await busy(button, button && button.classList.contains("file-action") ? "" : t(label), task);
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

    function selectionControls(prefix) {
        return {
            box: el(`${prefix}-selection`),
            all: el(`${prefix}-select-all`),
            count: el(`${prefix}-selection-count`),
            clear: el(`${prefix}-clear-selected`)
        };
    }

    function paintSelection(controls, selected, items, visible, manage, actionButtons) {
        const ids = new Set(items.map((item) => item.id));
        selected.forEach((id) => {
            if (!ids.has(id)) selected.delete(id);
        });
        controls.box.hidden = !manage || !items.length;
        if (controls.box.hidden) return;

        const visibleSelected = visible.filter((item) => selected.has(item.id)).length;
        controls.all.disabled = !visible.length;
        controls.all.checked = Boolean(visible.length && visibleSelected === visible.length);
        controls.all.indeterminate = visibleSelected > 0 && visibleSelected < visible.length;
        controls.count.textContent = t("%s selected", selected.size);
        controls.clear.disabled = !selected.size;
        actionButtons.forEach((button) => { button.disabled = !selected.size; });
    }

    async function runMany(setWorking, operations, reload, done) {
        setWorking(true);
        let failure = null;
        for (const operation of operations) {
            try {
                await operation();
            } catch (error) {
                if (!failure) failure = error;
            }
        }
        setWorking(false);
        await reload();
        if (failure) showToast(failure.message, "bad");
        else showToast(done, "good");
    }

    const historyView = (function () {
        const body = el("history-body");
        const search = el("history-search");
        const controls = selectionControls("history");
        const collectSelected = el("history-collect-selected");
        const removeSelected = el("history-remove-selected");
        const selected = new Set();
        let items = [];
        let folders = [];
        let busy = 0;
        let loadingData = false;
        let reloadRequested = false;
        let working = false;
        const sort = readSort("muos.history.sort", "date", true);

        function setSort(column, descending) {
            writeSort(sort, column, descending);
            render();
        }

        function render() {
            const needle = search.value.trim().toLocaleLowerCase();
            const visible = items.filter((item) => matches(item, needle));
            const manage = MU.canManageLists() && !busy && !working;

            crumbs(el("history-crumbs"), [
                {label: t("File Management"), glyph: "home", go: () => MU.show("files")},
                {label: t("History")}
            ]);
            el("history-hint").textContent = hint(busy, "History is open on the device, so changes are paused until it is closed there.");
            paintSelection(controls, selected, items, visible, manage, [collectSelected, removeSelected]);

            if (!items.length) return body.replaceChildren(emptyNote("Nothing has been played yet."));
            if (!visible.length) return body.replaceChildren(emptyNote("Nothing matches that search."));

            body.replaceChildren(itemTable({
                items: visible,
                actionsFor: (item) => item.exists === 0 || item.exists === false ? [
                    action("Update path", (button) => repoint(item, button), false, true),
                    action("Remove", (button) => remove(item, button), true, true)
                ] : [
                    action("Rename", (button) => renameItem(item, button), false, true),
                    action("Update path", (button) => repoint(item, button), false, true),
                    action("Add to collection", (button) => collect(item, button), false, true),
                    action("Remove", (button) => remove(item, button), true, true)
                ],
                manage,
                state: sort,
                onSort: setSort,
                nameLabel: "Name",
                selection: {
                    selected,
                    change: (item, checked) => {
                        if (checked) selected.add(item.id);
                        else selected.delete(item.id);
                        paintSelection(controls, selected, items, visible, manage, [collectSelected, removeSelected]);
                    }
                }
            }));

            if (chosenItems().some((item) => item.exists === 0 || item.exists === false)) {
                collectSelected.disabled = true;
                collectSelected.title = t("Unavailable content cannot be added to a collection.");
            } else {
                collectSelected.title = "";
            }
        }

        function chosenItems() {
            return items.filter((item) => selected.has(item.id));
        }

        async function collectSelectedItems() {
            const chosen = chosenItems();
            if (!chosen.length) return;
            const name = await ask({
                title: t("Add to collection"),
                message: t("Choose where the selected items should go."),
                confirm: t("Add"),
                choices: collectionChoices(folders, null)
            });
            if (name === null) return;
            await runMany((value) => { working = value; render(); }, chosen.map((item) => () =>
                api(`api/history/${apiPath(item.id, "collect")}`, {method: "POST", body: name, type: "text/plain"})),
            async () => { selected.clear(); await load(); }, "Added to collection");
        }

        async function removeSelectedItems() {
            const chosen = chosenItems();
            if (!chosen.length) return;
            const sure = await ask({
                title: t("Remove %s items", chosen.length),
                message: t("Selected entries will be removed from History. The content itself is not touched."),
                confirm: t("Remove"),
                danger: true
            });
            if (!sure) return;
            await runMany((value) => { working = value; render(); }, chosen.map((item) => () =>
                api(`api/history/${apiPath(item.id)}`, {method: "DELETE"})),
            async () => { selected.clear(); await load(); }, "Removed from history");
        }

        async function repoint(item, button) {
            const path = await askPath(item);
            if (!path || path === item.path) return;
            if (await run(button, "Saving…",
                () => api(`api/history/${apiPath(item.id, "path")}`, {method: "PUT", body: path, type: "text/plain"}),
                "Path updated"))
                await load();
        }

        async function renameItem(item, button) {
            const current = item.path.split("/").pop();
            const name = await ask({
                title: t("Rename content"),
                confirm: t("Rename"),
                input: {value: current}
            });
            if (!name || !name.trim() || name.trim() === current) return;
            if (await run(button, "Renaming...",
                () => api(`api/history/${apiPath(item.id, "rename")}`,
                    {method: "POST", body: name.trim(), type: "text/plain"}),
                "Content renamed"))
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
            if (loadingData) {
                reloadRequested = true;
                return;
            }
            loadingData = true;
            do {
                reloadRequested = false;
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
            } while (reloadRequested);
            loadingData = false;
        }

        search.addEventListener("input", render);
        controls.all.addEventListener("change", () => {
            items.filter((item) => matches(item, search.value.trim().toLocaleLowerCase())).forEach((item) => {
                if (controls.all.checked) selected.add(item.id);
                else selected.delete(item.id);
            });
            render();
        });
        controls.clear.addEventListener("click", () => { selected.clear(); render(); });
        collectSelected.addEventListener("click", collectSelectedItems);
        removeSelected.addEventListener("click", removeSelectedItems);
        return {load, render};
    }());

    const collections = (function () {
        const body = el("collections-body");
        const search = el("collections-search");
        const newButton = el("collections-new");
        const controls = selectionControls("collections");
        const moveSelected = el("collections-move-selected");
        const removeSelected = el("collections-remove-selected");
        const selected = new Set();
        let data = {items: [], collections: []};
        let opened = null;
        let crumbsFor;
        let working = false;
        let loadingData = false;
        let reloadRequested = false;
        const sort = readSort("muos.collections.sort", "name", false);

        function setSort(column, descending) {
            writeSort(sort, column, descending);
            render();
        }

        function folderItems(name) {
            const folder = data.collections.find((entry) => entry.name === name);
            return folder ? folder.items : null;
        }

        function names() {
            return data.collections.map((entry) => entry.name);
        }

        function folderKey(folder) {
            return `folder:${folder.name}`;
        }

        function selectedFolders() {
            return data.collections.filter((folder) => selected.has(folderKey(folder)));
        }

        function selectableFolders(folders) {
            return folders.map((folder) => ({id: folderKey(folder)}));
        }

        function paintCrumbs() {
            if (crumbsFor === opened) return;
            crumbsFor = opened;
            const trail = [
                {label: t("File Management"), glyph: "home", go: () => MU.show("files")},
                {label: t("Collections"), go: opened === null ? null : () => open(null)}
            ];
            if (opened !== null) trail.push({label: opened});
            crumbs(el("collections-crumbs"), trail);
        }

        function render() {
            const needle = search.value.trim().toLocaleLowerCase();
            const manage = MU.canManageLists() && !data.busy && !working;
            paintCrumbs();
            el("collections-hint").textContent = hint(data.busy,
                "Collections is open on the device, so changes are paused until it is closed there.");
            let items;
            let folders = [];

            if (opened === null) {
                items = data.items;
                folders = data.collections.filter((folder) => !needle ||
                    folder.name.toLocaleLowerCase().includes(needle) ||
                    folder.items.some((item) => matches(item, needle)));
            } else {
                items = folderItems(opened);
                if (!items) {
                    opened = null;
                    return render();
                }
            }

            const visible = items.filter((item) => matches(item, needle));
            newButton.hidden = !manage;
            newButton.textContent = t(opened === null ? "New Collection" : "Add Content");
            newButton.dataset.glyph = opened === null ? "plus" : "upload";
            const allSelectable = [...items, ...selectableFolders(opened === null ? data.collections : [])];
            const visibleSelectable = [...visible, ...selectableFolders(folders)];
            paintSelection(controls, selected, allSelectable, visibleSelectable, manage,
                [moveSelected, removeSelected]);
            const foldersChosen = selectedFolders();
            if (foldersChosen.length) moveSelected.disabled = true;
            if (foldersChosen.some((folder) => folder.items.length)) removeSelected.disabled = true;
            moveSelected.title = foldersChosen.length ? t("Collection folders cannot be moved.") : "";
            removeSelected.title = foldersChosen.some((folder) => folder.items.length)
                ? t("Empty a collection before removing it.") : "";

            if (!visible.length && !folders.length) {
                const empty = needle ? "Nothing matches that search."
                    : opened === null && !data.collections.length ? "No collections yet."
                        : opened === null ? "Everything is in a collection." : "This collection is empty.";
                return body.replaceChildren(emptyNote(empty));
            }

            body.replaceChildren(itemTable({
                items: visible,
                folders,
                actionsFor: (item) => item.exists === 0 || item.exists === false ? [
                    action("Update path", (button) => repoint(item, button), false, true),
                    action("Remove", (button) => removeItem(item, button), true, true)
                ] : [
                    action("Rename", (button) => renameItem(item, button), false, true),
                    action("Update path", (button) => repoint(item, button), false, true),
                    action("Move", (button) => move(item, button), false, true),
                    action("Remove", (button) => removeItem(item, button), true, true)
                ],
                folderActions: (folder) => [
                    action("Rename", (button) => rename(folder, button), false, true),
                    action("Remove", (button) => removeFolder(folder, button), true, true)
                ],
                manage,
                state: sort,
                onSort: setSort,
                selection: {
                    selected,
                    folderKey,
                    change: (item, checked) => {
                        if (checked) selected.add(item.id);
                        else selected.delete(item.id);
                        render();
                    },
                    changeFolder: (folder, checked) => {
                        if (checked) selected.add(folderKey(folder));
                        else selected.delete(folderKey(folder));
                        render();
                    }
                },
                openFolder: open,
                nameLabel: "Name"
            }));
        }

        function open(name) {
            selected.clear();
            opened = name;
            MU.navigate(name);
            render();
        }

        function chosenItems() {
            const items = opened === null ? data.items : folderItems(opened) || [];
            return items.filter((item) => selected.has(item.id));
        }

        async function moveSelectedItems() {
            if (selectedFolders().length) return;
            const chosen = chosenItems();
            if (!chosen.length) return;
            const current = opened || "";
            const choices = collectionChoices(names(), current);
            if (!choices.length) {
                showToast("Create another collection to move this into");
                return;
            }
            const name = await ask({
                title: t("Move to collection"),
                message: t("Choose where the selected items should go."),
                confirm: t("Move"),
                choices
            });
            if (name === null) return;
            await runMany((value) => { working = value; render(); }, chosen.map((item) => () =>
                api(`api/collection/${apiPath(...item.id.split("/"), "move")}`,
                    {method: "POST", body: name, type: "text/plain"})),
            async () => { selected.clear(); await load(); }, "Moved");
        }

        async function removeSelectedItems() {
            const chosen = chosenItems();
            const folders = selectedFolders();
            if (folders.some((folder) => folder.items.length)) {
                showToast("Empty a collection before removing it");
                return;
            }
            const count = chosen.length + folders.length;
            if (!count) return;
            const sure = await ask({
                title: t("Remove %s items", count),
                message: t("Selected entries and empty collections will be removed. The content itself is not touched."),
                confirm: t("Remove"),
                danger: true
            });
            if (!sure) return;
            const operations = [
                ...chosen.map((item) => () =>
                    api(`api/collection/${apiPath(...item.id.split("/"))}`, {method: "DELETE"})),
                ...folders.map((folder) => () =>
                    api(`api/collection/${apiPath(folder.name)}`, {method: "DELETE"}))
            ];
            await runMany((value) => { working = value; render(); }, operations,
            async () => { selected.clear(); await load(); }, "Removed from collection");
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

        async function addContent(button) {
            if (opened === null) return;
            const path = await ask({
                title: t("Add content"),
                message: t("Enter the full path to content on the device."),
                confirm: t("Add"),
                input: {value: "", placeholder: "/mnt/mmc/ROMS/..."}
            });
            if (!path || !path.trim()) return;
            if (await run(button, "Adding...",
                () => api(`api/collection/${apiPath(opened, "add")}`,
                    {method: "POST", body: path.trim(), type: "text/plain"}),
                "Added to collection"))
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

        async function renameItem(item, button) {
            const current = item.path.split("/").pop();
            const name = await ask({
                title: t("Rename content"),
                confirm: t("Rename"),
                input: {value: current}
            });
            if (!name || !name.trim() || name.trim() === current) return;
            if (await run(button, "Renaming...",
                () => api(`api/collection/${apiPath(...item.id.split("/"), "rename")}`,
                    {method: "POST", body: name.trim(), type: "text/plain"}),
                "Content renamed"))
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
            if (loadingData) {
                reloadRequested = true;
                return;
            }
            loadingData = true;
            do {
                reloadRequested = false;
                if (!body.childElementCount) body.replaceChildren(loading("Reading the collections…"));
                try {
                    const fresh = await api("api/collection");
                    data = {items: fresh.items || [], collections: fresh.collections || [], busy: fresh.busy || 0};
                    render();
                } catch (error) {
                    body.replaceChildren(problem(error.message, load));
                }
            } while (reloadRequested);
            loadingData = false;
        }

        function restore(where) {
            selected.clear();
            opened = typeof where === "string" ? where : null;
            load();
        }

        search.addEventListener("input", render);
        newButton.addEventListener("click", () => opened === null ? create(newButton) : addContent(newButton));
        controls.all.addEventListener("change", () => {
            const items = opened === null ? data.items : folderItems(opened) || [];
            const needle = search.value.trim().toLocaleLowerCase();
            const keys = items.filter((item) => matches(item, needle)).map((item) => item.id);
            if (opened === null) data.collections.filter((folder) => !needle ||
                folder.name.toLocaleLowerCase().includes(needle) ||
                folder.items.some((item) => matches(item, needle))).forEach((folder) => keys.push(folderKey(folder)));
            keys.forEach((key) => {
                if (controls.all.checked) selected.add(key);
                else selected.delete(key);
            });
            render();
        });
        controls.clear.addEventListener("click", () => { selected.clear(); render(); });
        moveSelected.addEventListener("click", moveSelectedItems);
        removeSelected.addEventListener("click", removeSelectedItems);
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
