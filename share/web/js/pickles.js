(function () {
    "use strict";

    const {el, make, bytes, duration, stamp, showToast, api, register, fillKv, mediaUrl, apiPath, canManage,
           onAuthChange, sortItems, sortControl, navigate, crumbs, ask, busy, problem, loading, showSpace,
           layoutClass, layoutControl, onLayoutChange} = window.MU;

    const PAGE = 40;
    const trail = el("pickles-crumbs");
    const body = el("pickles-body");
    const search = el("pickles-search");

    const SECTIONS = {
        state: {name: "Save States"},
        sram: {name: "Save Games"},
        other: {name: "System Files"}
    };

    let states = [];
    let saves = [];
    let working = [];
    let activity = {};
    let section = null;
    let opened = null;
    let shown = PAGE;
    let order = "name";
    const plural = (n, one, many) => `${n.toLocaleString()} ${n === 1 ? one : many}`;
    const mediaPath = (path) => mediaUrl("pickles", path);
    const extension = (name) => ((name || "").split(".").pop() || "").toLowerCase();
    const label = (item) => (item.name || "").replace(/\.[^.]+$/, "");

    const title = (item) => {
        const own = label(item);
        return item.friendly && item.friendly !== own ? `${item.friendly} (${own})` : own;
    };

    function chrome(here, searchable) {
        const steps = [{label: "Saves", go: () => go(null, null)}];
        if (section) steps.push({label: SECTIONS[section].name, go: () => go(section, null)});
        if (here) steps.push({label: here});

        crumbs(trail, steps);
        search.hidden = !searchable;
    }

    function go(nextSection, nextOpened, push = true) {
        if (push) navigate({section: nextSection, opened: nextOpened});
        return render(nextSection, nextOpened);
    }

    function render(nextSection, nextOpened) {
        if (!nextSection) return showSections();

        if (!nextOpened) return showSection(nextSection);
        if (nextSection === "state") return showGame(nextOpened);
        if (nextSection === "sram") return showSave(nextOpened);
        return showSystem(nextOpened);
    }

    function restore(where) {
        const at = where || {};
        return render(at.section || null, at.opened || null);
    }

    function download(text, path, name) {
        const link = make("a", "link", text);
        link.href = mediaPath(path);
        link.download = name;
        return link;
    }

    function card({count, mark, image, title, meta, open, actions}) {
        const box = make("div", "card");

        const art = make("div", "card-art");
        if (open) {
            art.classList.add("opens");
            art.title = title;
            art.addEventListener("click", open);
        }

        if (count !== undefined) {
            box.classList.add("wide");
            art.append(make("span", "card-count", count.toLocaleString()));
            if (!count) art.classList.add("empty");
        } else if (image) {
            const shot = make("img");
            shot.loading = "lazy";
            shot.alt = "";
            shot.src = image;
            shot.addEventListener("error", () => {
                shot.remove();
                art.append(make("span", "card-mark", "no shot"));
            });
            art.append(shot);
        } else {
            art.append(make("span", "card-mark", mark || "-"));
            if (!mark) art.classList.add("empty");
        }
        const name = make(open ? "button" : "span", "card-name", title);
        if (open) {
            name.type = "button";
            name.addEventListener("click", open);
        }

        box.append(art, name);
        if (meta) box.append(make("span", "card-meta", meta));

        if (actions && actions.length) {
            const row = make("span", "card-actions");
            actions.forEach((a) => a && row.append(a));
            box.append(row);
        }

        return box;
    }

    function grid(cards, counts) {
        const holder = make("div", layoutClass("pickles", counts ? "counts" : null));
        cards.forEach((c) => holder.append(c));
        return holder;
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

    function action(label, className, onClick) {
        const button = make("button", className, label);
        button.type = "button";
        button.addEventListener("click", () => onClick(button));
        return button;
    }

    function showSections() {
        section = null;
        opened = null;
        chrome(null, false);

        const counts = {state: states.length, sram: saves.length, other: working.length};
        const words = {state: ["game", "games"], sram: ["save", "saves"], other: ["system", "systems"]};

        const bar = make("div", "filters");
        bar.append(sortControl(order, (value) => {
            order = value;
            showSections();
        }), layoutControl("pickles"));

        const holdings = {state: states, sram: saves, other: working};
        const sections = sortItems(
            Object.keys(SECTIONS).map((key) => ({
                key,
                name: SECTIONS[key].name,
                count: counts[key],
                bytes: holdings[key].reduce((sum, item) => sum + (item.bytes || 0), 0),
                modified: holdings[key].reduce((latest, item) => Math.max(latest, item.modified || 0), 0)
            })),
            order, (item) => item.name
        );

        body.replaceChildren(bar, grid(sections.map((item) => card({
            count: item.count,
            title: item.name,
            meta: item.count === 1 ? words[item.key][0] : words[item.key][1],
            open: () => go(item.key, null)
        })), true));
    }

    function stateCard(game) {
        return card({
            image: game.preview ? mediaPath(`state/${game.path}/${game.preview}`) : null,
            mark: game.preview ? null : "no shot",
            title: title(game),
            meta: `${plural(game.slots, "save", "saves")}\n${bytes(game.bytes)}`,
            open: () => go("state", game.path)
        });
    }

    function saveCard(item) {
        const copies = (item.backups || []).length;
        return card({
            mark: extension(item.name),
            title: title(item),
            meta: `${bytes(item.bytes)}\n${stamp(item.modified)}${copies ? `\n${plural(copies, "backup", "backups")}` : ""}`,
            open: () => go("sram", item.path)
        });
    }

    function systemCard(group) {
        return card({
            mark: group.group,
            title: group.group,
            meta: `${plural(group.files, "file", "files")}\n${bytes(group.bytes)}`,
            open: () => go("other", group.group)
        });
    }

    function renderSection() {
        const source = section === "state" ? states : section === "sram" ? saves : working;

        const naming = section === "other" ? (item) => item.group : (item) => item.friendly || label(item);
        const haystack = section === "other"
            ? (item) => item.group
            : (item) => `${label(item)} ${item.friendly || ""}`;

        const needle = search.value.trim().toLowerCase();
        const found = needle ? source.filter((item) => haystack(item).toLowerCase().includes(needle)) : source;
        const matches = sortItems(found, order, naming);
        const page = matches.slice(0, shown);

        body.replaceChildren();

        const bar = make("div", "filters");
        bar.append(sortControl(order, (value) => {
            order = value;
            renderSection();
        }), layoutControl("pickles"), make("span", "note", `${matches.length} shown`));
        body.append(bar);

        if (!matches.length) {
            body.append(make("p", "note", needle ? "Nothing matches that." : "Nothing here yet."));
            return;
        }

        const build = section === "state" ? stateCard : section === "sram" ? saveCard : systemCard;
        body.append(grid(page.map(build)));

        if (matches.length > page.length) {
            const more = make("button", "link more", `Show more (${matches.length - page.length} left)`);
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

        const total = key === "state" ? states.length : key === "sram" ? saves.length : working.length;
        chrome(null, total > 8);
        renderSection();
    }

    function slotCard(game, slot) {
        const core = slot.core && slot.core_version ? `${slot.core} ${slot.core_version}` : slot.core;
        const meta = [stamp(slot.created || slot.modified), bytes(slot.bytes), core, slot.crc && `crc ${slot.crc}`]
            .filter(Boolean).join("\n");

        return card({
            image: slot.preview ? mediaPath(`state/${game.path}/${slot.preview}`) : null,
            mark: slot.preview ? null : "no shot",
            title: slot.name || slot.id,
            meta,
            actions: [
                download("Download", `state/${game.path}/${slot.state}`, `${slot.id}.state`),
                canManage() && action("Remove", "link danger", (b) => discardSlot(game, slot, b))
            ]
        });
    }

    function activityPanel(name) {
        const played = activity[name];
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
        panel.append(make("h3", null, "Activity"), facts);
        return panel;
    }

    function detailBar(count, noun) {
        const bar = make("div", "filters");
        bar.append(layoutControl("pickles"),
            make("span", "note", `${count.toLocaleString()} ${count === 1 ? noun[0] : noun[1]}`));
        return bar;
    }

    async function showGame(path) {
        const game = states.find((candidate) => candidate.path === path);
        if (!game) return showSection("state");

        opened = path;
        section = "state";
        chrome(title(game), false);
        body.replaceChildren(loading("Reading the save…"));

        try {
            const data = await api(`api/pickles/state/${apiPath(...game.path.split("/"))}`);
            body.replaceChildren();

            const panel = activityPanel(game.name);
            if (panel) body.append(panel);

            const slots = data.slots || [];
            if (slots.length) {
                body.append(detailBar(slots.length, ["save", "saves"]),
                    grid(slots.map((slot) => slotCard(game, slot))));
            } else {
                body.append(make("p", "note", "No saves for this game."));
            }
        } catch (error) {
            body.replaceChildren(problem(error.message, () => showGame(path)));
        }
    }

    function showSave(path) {
        const item = saves.find((candidate) => candidate.path === path);
        if (!item) return showSection("sram");

        opened = path;
        section = "sram";
        chrome(title(item), false);
        body.replaceChildren();

        const panel = activityPanel(label(item));
        if (panel) body.append(panel);

        let replaceButton = null;
        const choose = canManage() ? picker((file) => replace(item, file, replaceButton)) : null;

        const live = card({
            mark: extension(item.name),
            title: "Current save",
            meta: `${bytes(item.bytes)}\n${stamp(item.modified)}`,
            actions: [
                download("Download", `sram/${item.path}`, item.name),
                choose && (replaceButton = action("Replace", "link", () => choose.click()))
            ]
        });
        if (choose) live.append(choose);

        const cards = [live];

        (item.backups || []).forEach((backup) => {
            cards.push(card({
                mark: `bk${backup.index}`,
                title: backup.index === 0 ? "Most recent copy" : `${backup.index + 1} rotations back`,
                meta: `${bytes(backup.bytes)}\n${stamp(backup.modified)}`,
                actions: [
                    download("Download", `sram/${item.path}.bk${backup.index}`, `${item.name}.bk${backup.index}`),
                    canManage() && action("Restore", "link", (b) => restoreBackup(item, backup, b))
                ]
            }));
        });

        body.append(detailBar(cards.length, ["copy", "copies"]), grid(cards));
    }

    function showSystem(name) {
        const group = working.find((candidate) => candidate.group === name);
        if (!group) return showSection("other");

        opened = name;
        section = "other";
        chrome(group.group, false);
        body.replaceChildren();

        const cards = (group.items || []).map((item) => card({
            mark: extension(item.name) || "file",
            title: item.name,
            meta: `${bytes(item.bytes)}\n${stamp(item.modified)}`,
            actions: [download("Download", `sram/${item.path}`, item.name)]
        }));

        body.append(detailBar(cards.length, ["file", "files"]), grid(cards));
        if (group.items && group.items.length < group.files) {
            body.append(make("p", "note",
                `${(group.files - group.items.length).toLocaleString()} more not shown`));
        }
    }

    async function discardSlot(game, slot, button) {
        const sure = await ask({
            title: "Remove save state",
            message: `${slot.name || slot.id} will be deleted.`,
            confirm: "Remove",
            danger: true
        });
        if (!sure) return;

        try {
            await busy(button, "Removing…",
                () => api(`api/pickles/state/${apiPath(...game.path.split("/"), slot.id)}`, {method: "DELETE"}));
            showToast("Save state removed");
            await load();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function replace(item, file, button) {
        const sure = await ask({
            title: "Replace save game",
            message: `${label(item)} will be overwritten. Earlier copies are kept.`,
            confirm: "Replace",
            danger: true
        });
        if (!sure) return;

        try {
            await busy(button, "Replacing…", () => api(`api/pickles/sram/${apiPath(...item.path.split("/"))}`, {
                method: "POST",
                body: file,
                type: "application/octet-stream"
            }));
            showToast("Save game replaced");
            await load();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function restoreBackup(item, backup, button) {
        const sure = await ask({
            title: "Restore earlier copy",
            message: `The copy from ${stamp(backup.modified)} will replace the current save.`,
            confirm: "Restore",
            danger: true
        });
        if (!sure) return;

        try {
            await busy(button, "Restoring…",
                () => api(`api/pickles/backup/${backup.index}/${apiPath(...item.path.split("/"))}`,
                    {method: "POST"}));
            showToast("Save game restored");
            await load();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function load() {
        const heldSection = section;
        const heldGame = opened;

        if (!body.childElementCount) body.replaceChildren(loading("Reading the saves…"));

        try {
            const data = await api("api/pickles");
            showSpace("pickles", data);
            states = data.content || [];
            saves = data.sram || [];
            working = data.other || [];

            if (!Object.keys(activity).length) {
                try {
                    activity = await (await fetch("state/activity.json", {cache: "no-store"})).json();
                } catch (_) {
                    activity = {};
                }
            }

            if (heldGame && heldSection === "state" && states.some((g) => g.path === heldGame)) return showGame(heldGame);
            if (heldGame && heldSection === "sram" && saves.some((v) => v.path === heldGame)) return showSave(heldGame);
            if (heldGame && heldSection === "other" && working.some((w) => w.group === heldGame)) return showSystem(heldGame);
            if (heldSection) return showSection(heldSection);
            showSections();
        } catch (error) {
            body.replaceChildren(problem(error.message, load));
        }
    }

    search.addEventListener("input", () => {
        shown = PAGE;
        renderSection();
    });

    onLayoutChange((view) => {
        if (view !== "pickles") return;
        if (section && !opened) renderSection();
        else if (!section) showSections();
    });

    onAuthChange(() => {
        if (opened && section === "state") showGame(opened);
        else if (opened && section === "sram") showSave(opened);
        else if (opened && section === "other") showSystem(opened);
        else if (section) renderSection();
    });

    register("pickles", {load, restore});
}());
