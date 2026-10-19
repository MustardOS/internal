(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, bytes, duration, stamp, showToast, api, register, fillKv, mediaUrl, apiPath, canManage,
           onAuthChange, navigate, crumbs, ask, busy, problem, loading, sortableHead, attachMediaPreview,
           hideMediaPreview, t} = MU;

    const PAGE = 80;
    const trail = el("pickles-crumbs");
    const body = el("pickles-body");
    const search = el("pickles-search");
    const collator = new Intl.Collator(undefined, {numeric: true, sensitivity: "base"});
    const SECTIONS = {
        state: {name: "Save States", singular: "game", plural: "games"},
        sram: {name: "Save Games", singular: "save", plural: "saves"}
    };

    let states = [];
    let saves = [];
    let stateGroups = [];
    let saveGroups = [];
    let activity = {};
    let section = null;
    let opened = null;
    let shown = PAGE;
    let sortColumn = "name";
    let sortDescending = false;

    try {
        const saved = JSON.parse(localStorage.getItem("muos.pickles.sort"));
        if (["name", "count"].includes(saved.column)) sortColumn = saved.column;
        sortDescending = Boolean(saved.descending);
    } catch (_) {
    }

    const mediaPath = (path) => mediaUrl("pickles", path);
    const extension = (name) => ((name || "").split(".").pop() || "").toLowerCase();
    const label = (item) => (item.name || "").replace(/\.[^.]+$/, "");
    const title = (item) => {
        const own = label(item);
        return item.friendly && item.friendly !== own ? `${item.friendly} (${own})` : own;
    };

    function parentName(item) {
        const parts = String(item.path || "").split("/");
        return parts.length > 1 ? parts[parts.length - 2] : "";
    }

    function groupContent(items, kind) {
        const grouped = new Map();
        items.forEach((item) => {
            const name = title(item);
            const key = name.toLocaleLowerCase();
            let group = grouped.get(key);
            if (!group) {
                group = {key, name, items: [], count: 0, search: ""};
                grouped.set(key, group);
            }
            group.items.push(item);
            group.count += kind === "state" ? item.slots || 0 : 1;
            group.search += ` ${item.name || ""} ${item.friendly || ""} ${parentName(item)}`;
        });
        return [...grouped.values()];
    }

    function groupsFor(kind) {
        return kind === "state" ? stateGroups : saveGroups;
    }

    function setSort(column, descending) {
        sortColumn = column;
        sortDescending = descending;
        try {
            localStorage.setItem("muos.pickles.sort", JSON.stringify({column, descending}));
        } catch (_) {
        }
        if (section && !opened) renderSection();
        else if (!section) showSections();
    }

    function sorted(items, naming) {
        return [...items].sort((left, right) => {
            let result;
            if (sortColumn === "count") result = (left.count || 0) - (right.count || 0);
            else result = collator.compare(naming(left), naming(right));
            if (!result) result = collator.compare(naming(left), naming(right));
            return sortDescending ? -result : result;
        });
    }

    function chrome(here, searchable) {
        const steps = [
            {label: t("File Management"), glyph: "home", go: () => MU.show("files")},
            {label: t("Pickles Saves"), go: () => go(null, null)}
        ];
        if (section) steps.push({label: t(SECTIONS[section].name), go: () => go(section, null)});
        if (here) steps.push({label: here});
        crumbs(trail, steps);
        search.hidden = !searchable;
    }

    function go(nextSection, nextOpened, push = true) {
        if (push) navigate({section: nextSection, opened: nextOpened});
        return render(nextSection, nextOpened);
    }

    function render(nextSection, nextOpened) {
        if (!nextSection || !SECTIONS[nextSection]) return showSections();
        if (!nextOpened) return showSection(nextSection);
        return nextSection === "state" ? showGame(nextOpened) : showSave(nextOpened);
    }

    function restore(where) {
        const at = where || {};
        return render(at.section || null, at.opened || null);
    }

    const GLYPHS = {Open: "external", Download: "download", Remove: "trash", Replace: "upload", Restore: "restore"};

    function action(name, handler, danger) {
        const text = t(name);
        const button = make("button", `link file-action${danger ? " danger" : ""}`);
        button.type = "button";
        button.dataset.glyph = GLYPHS[name];
        button.dataset.tooltip = text;
        button.title = text;
        button.setAttribute("aria-label", text);
        button.addEventListener("click", () => handler(button));
        return button;
    }

    function download(path, name) {
        const text = t("Download");
        const link = make("a", "link file-action");
        link.dataset.glyph = "download";
        link.dataset.tooltip = text;
        link.title = text;
        link.setAttribute("aria-label", text);
        link.href = mediaPath(path);
        link.download = name;
        return link;
    }

    function toolsCell(actions) {
        const tools = make("div", "entry-actions");
        actions.filter(Boolean).forEach((item) => tools.append(item));
        const cell = make("td", "table-options");
        cell.append(tools);
        return cell;
    }

    function table(columns, rows, sortable = true) {
        const node = make("table", "data-table browser-table save-table");
        const head = make("thead");
        if (sortable) head.append(sortableHead(columns, sortColumn, sortDescending, setSort));
        else head.append(sortableHead(columns, "", false, () => {}));
        const tableBody = make("tbody");
        rows.forEach((row) => tableBody.append(row));
        node.append(head, tableBody);
        const scroll = make("div", "table-scroll");
        scroll.append(node);
        return scroll;
    }

    function previewImage(source) {
        if (!source) {
            const placeholder = make("span", "table-preview table-preview-placeholder", "?");
            placeholder.setAttribute("aria-label", t("No save state image"));
            return placeholder;
        }
        const image = make("img", "table-preview");
        image.loading = "lazy";
        image.alt = "";
        image.src = source;
        image.tabIndex = 0;
        image.setAttribute("aria-label", t("Preview save state"));
        attachMediaPreview(image, source);
        image.addEventListener("error", () => {
            hideMediaPreview();
            image.replaceWith(previewImage(null));
        });
        return image;
    }

    function openName(text, onOpen, preview, reservePreview = false) {
        const holder = make("div", preview || reservePreview ? "table-name-with-preview" : null);
        if (preview || reservePreview) holder.append(previewImage(preview));
        const button = make("button", "entry-name", text);
        button.type = "button";
        button.title = text;
        button.addEventListener("click", onOpen);
        holder.append(button);
        return holder;
    }

    function showSections() {
        section = null;
        opened = null;
        chrome(null, false);

        const holdings = {state: stateGroups, sram: saveGroups};
        const sections = ["sram", "state"].map((key) => ({
            key,
            name: SECTIONS[key].name,
            count: holdings[key].length
        }));
        const grid = make("div", "pickles-section-grid");
        sections.forEach((item) => {
            const card = make("button", "pickles-section-card");
            card.type = "button";
            card.append(
                make("span", "pickles-section-name", t(item.name)),
                make("span", "pickles-section-count", t("%s content", item.count.toLocaleString()))
            );
            card.addEventListener("click", () => go(item.key, null));
            grid.append(card);
        });
        body.replaceChildren(grid);
    }

    function renderSection() {
        const source = groupsFor(section);
        const needle = search.value.trim().toLocaleLowerCase();
        const matches = source.filter((group) => !needle
            || `${group.name} ${group.search}`.toLocaleLowerCase().includes(needle));
        const page = sorted(matches, (group) => group.name).slice(0, shown);

        body.replaceChildren();
        const bar = make("div", "filters");
        bar.append(make("span", "note", t("%s shown", matches.length)));
        body.append(bar);

        if (!matches.length) {
            body.append(make("p", "note", t(needle ? "Nothing matches that." : "Nothing here yet.")));
            return;
        }

        const rows = page.map((group) => {
            const row = make("tr");
            const nameCell = make("td", "content-name-cell");
            const featured = section === "state" ? group.items.find((item) => item.preview) : null;
            const preview = featured ? mediaPath(`state/${featured.path}/${featured.preview}`) : null;
            nameCell.append(openName(group.name, () => go(section, group.key), preview, section === "state"));
            row.append(nameCell,
                make("td", "number table-count", group.count.toLocaleString()),
                toolsCell([action("Open", () => go(section, group.key))]));
            return row;
        });

        body.append(table([
            {key: "name", label: "Name"},
            {key: "count", label: section === "state" ? "States" : "Saves", descending: true, className: "table-count"},
            {label: "Options", className: "table-options"}
        ], rows));

        if (matches.length > page.length) {
            const more = make("button", "link more", t("Show more (%s left)", matches.length - page.length));
            more.type = "button";
            more.addEventListener("click", () => {
                shown += PAGE;
                renderSection();
            });
            body.append(more);
        }
    }

    function showSection(key) {
        const arriving = section !== key;
        section = key;
        opened = null;
        if (arriving) {
            shown = PAGE;
            search.value = "";
        }
        const total = groupsFor(key).length;
        chrome(null, total > 8);
        renderSection();
    }

    function activityPanel(items) {
        const names = new Set();
        items.forEach((item) => {
            [item.name, label(item), item.friendly].filter(Boolean).forEach((name) => names.add(name.toLocaleLowerCase()));
        });
        const match = Object.entries(activity).find(([key, value]) => names.has(key.toLocaleLowerCase())
            || names.has(String(value.name || "").toLocaleLowerCase()));
        const played = match && match[1];
        if (!played) return null;
        const facts = make("dl", "kv");
        fillKv(facts, [
            ["Play time", played.time ? duration(played.time, true) : ""],
            ["Launches", played.launches ? played.launches.toLocaleString() : ""],
            ["Typical session", played.average ? duration(played.average) : ""],
            ["Last session", played.session ? duration(played.session) : ""],
            ["Last played with", played.core],
            ["On", played.device]
        ]);
        if (!facts.childElementCount) return null;
        const panel = make("div", "panel");
        panel.append(make("h3", null, t("Activity")), facts);
        return panel;
    }

    async function showGame(key) {
        const group = stateGroups.find((candidate) => candidate.key === key);
        if (!group) return showSection("state");
        opened = key;
        section = "state";
        chrome(group.name, false);
        body.replaceChildren(loading("Reading the save..."));

        try {
            const results = await Promise.all(group.items.map(async (game) => ({
                game,
                data: await api(`api/pickles/state/${apiPath(...game.path.split("/"))}`)
            })));
            body.replaceChildren();
            const panel = activityPanel(group.items);
            if (panel) body.append(panel);
            const slots = results.flatMap(({game, data}) => (data.slots || []).map((slot) => ({game, slot})));
            if (!slots.length) {
                body.append(make("p", "note", t("No saves for this game.")));
                return;
            }

            const multiple = group.items.length > 1;
            const rows = slots.map(({game, slot}) => {
                const row = make("tr");
                const nameCell = make("td", "content-name-cell");
                const preview = slot.preview ? mediaPath(`state/${game.path}/${slot.preview}`) : null;
                const holder = make("div", "table-name-with-preview");
                holder.append(previewImage(preview));
                const ownName = slot.name || slot.id;
                const shownName = multiple ? `${ownName} — ${parentName(game)}` : ownName;
                const name = make("span", "entry-name", shownName);
                name.title = shownName;
                holder.append(name);
                nameCell.append(holder);
                const core = slot.core && slot.core_version ? `${slot.core} ${slot.core_version}` : slot.core || "";
                row.append(nameCell,
                    make("td", "table-core", core),
                    make("td", "number table-size", bytes(slot.bytes)),
                    make("td", "number table-date", stamp(slot.created || slot.modified)),
                    toolsCell([
                        download(`state/${game.path}/${slot.state}`, `${slot.id}.state`),
                        canManage() && action("Remove", (button) => discardSlot(game, slot, button), true)
                    ]));
                return row;
            });
            body.append(table([
                {label: "Name"},
                {label: "Core", className: "table-core"},
                {label: "Size", className: "table-size"},
                {label: "Date", className: "table-date"},
                {label: "Options", className: "table-options"}
            ], rows, false));
        } catch (error) {
            body.replaceChildren(problem(error.message, () => showGame(key)));
        }
    }

    function picker(onPick) {
        const input = make("input");
        input.type = "file";
        input.hidden = true;
        input.addEventListener("change", () => {
            if (input.files.length) onPick(input.files[0]);
            input.value = "";
        });
        return input;
    }

    function showSave(key) {
        const group = saveGroups.find((candidate) => candidate.key === key);
        if (!group) return showSection("sram");
        opened = key;
        section = "sram";
        chrome(group.name, false);
        body.replaceChildren();
        const panel = activityPanel(group.items);
        if (panel) body.append(panel);

        const choices = [];
        const rows = [];
        group.items.forEach((item) => {
            let replaceButton = null;
            const choose = canManage() ? picker((file) => replace(item, file, replaceButton)) : null;
            if (choose) choices.push(choose);
            const copies = [{current: true, name: t("Current save"), file: item.name, bytes: item.bytes, modified: item.modified},
                ...(item.backups || []).map((backup) => ({
                    ...backup,
                    file: `${item.name}.bk${backup.index}`,
                    name: backup.index === 0 ? t("Most recent copy") : t("%s rotations back", backup.index + 1)
                }))];

            copies.forEach((copy) => {
                const row = make("tr");
                const nameCell = make("td", "content-name-cell");
                const ownName = copy.name;
                const name = make("span", "entry-name", ownName);
                name.title = ownName;
                nameCell.append(name);
                const fileCell = make("td", "content-name-cell");
                const fileName = make("span", "entry-name", copy.file);
                fileName.title = copy.file;
                fileCell.append(fileName);
                const actions = copy.current ? [
                    download(`sram/${item.path}`, item.name),
                    choose && (replaceButton = action("Replace", () => choose.click()))
                ] : [
                    download(`sram/${item.path}.bk${copy.index}`, copy.file),
                    canManage() && action("Restore", (button) => restoreBackup(item, copy, button))
                ];
                row.append(nameCell, make("td", "table-core", parentName(item)), fileCell,
                    make("td", "number table-size", bytes(copy.bytes)),
                    make("td", "number table-date", stamp(copy.modified)),
                    toolsCell(actions));
                rows.push(row);
            });
        });

        body.append(table([
            {label: "Name"},
            {label: "Core", className: "table-core"},
            {label: "File"},
            {label: "Size", className: "table-size"},
            {label: "Date", className: "table-date"},
            {label: "Options", className: "table-options"}
        ], rows, false));
        choices.forEach((choice) => body.append(choice));
    }

    async function discardSlot(game, slot, button) {
        const sure = await ask({
            title: t("Remove save state"),
            message: t("%s will be deleted.", slot.name || slot.id),
            confirm: t("Remove"),
            danger: true
        });
        if (!sure) return;
        try {
            await busy(button, "", () => api(`api/pickles/state/${apiPath(...game.path.split("/"), slot.id)}`, {method: "DELETE"}));
            showToast("Save state removed", "good");
            await load();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function replace(item, file, button) {
        const sure = await ask({
            title: t("Replace save game"),
            message: t("%s will be overwritten. Earlier copies are kept.", label(item)),
            confirm: t("Replace"),
            danger: true
        });
        if (!sure) return;
        try {
            await busy(button, "", () => api(`api/pickles/sram/${apiPath(...item.path.split("/"))}`, {
                method: "POST", body: file, type: "application/octet-stream"
            }));
            showToast("Save game replaced", "good");
            await load();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function restoreBackup(item, backup, button) {
        const sure = await ask({
            title: t("Restore earlier copy"),
            message: t("The copy from %s will replace the current save.", stamp(backup.modified)),
            confirm: t("Restore"),
            danger: true
        });
        if (!sure) return;
        try {
            await busy(button, "", () => api(`api/pickles/backup/${backup.index}/${apiPath(...item.path.split("/"))}`, {method: "POST"}));
            showToast("Save game restored", "good");
            await load();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function load() {
        const heldSection = section;
        const heldItem = opened;
        if (!body.childElementCount) body.replaceChildren(loading("Reading the saves..."));
        try {
            const data = await api("api/pickles");
            states = data.content || [];
            saves = data.sram || [];
            stateGroups = groupContent(states, "state");
            saveGroups = groupContent(saves, "sram");
            try {
                activity = await (await fetch("state/activity.json", {cache: "no-store"})).json();
            } catch (_) {
                activity = {};
            }
            if (heldItem && heldSection === "state" && stateGroups.some((group) => group.key === heldItem)) return showGame(heldItem);
            if (heldItem && heldSection === "sram" && saveGroups.some((group) => group.key === heldItem)) return showSave(heldItem);
            if (heldSection && SECTIONS[heldSection]) return showSection(heldSection);
            showSections();
        } catch (error) {
            body.replaceChildren(problem(error.message, load));
        }
    }

    search.addEventListener("input", () => {
        shown = PAGE;
        renderSection();
    });
    onAuthChange(() => {
        if (opened && section === "state") showGame(opened);
        else if (opened && section === "sram") showSave(opened);
        else if (section) renderSection();
    });

    register("pickles", {load, restore});
}());
