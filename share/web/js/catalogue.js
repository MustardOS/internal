(function () {
    "use strict";

    const {el, make, bytes, showToast, api, register, mediaUrl, apiPath, canManage, onAuthChange,
           sortItems, sortControl, navigate, crumbs, ask, busy, problem, loading, showSpace,
           layoutClass, layoutControl, onLayoutChange} = window.MU;

    const TYPES = [
        {key: "box", name: "Box Art", short: "Box"},
        {key: "grid", name: "Grid Image", short: "Grid"},
        {key: "preview", name: "Preview Image", short: "Preview"},
        {key: "splash", name: "Launch Splash", short: "Splash"},
        {key: "text", name: "Description Text", short: "Text"},
        {key: "video", name: "Preview Video", short: "Video"},
        {key: "manual", name: "Manual", short: "Manual"},
        {key: "overlay/base", name: "Overlay", short: "Overlay"}
    ];

    const STEPS = [
        {key: "overlay/battery", leaf: "battery", name: "Battery"},
        {key: "overlay/bright", leaf: "bright", name: "Brightness"},
        {key: "overlay/volume", leaf: "volume", name: "Volume"}
    ];

    const STEP_COUNT = 10;

    const FACE = ["box", "grid", "preview", "splash"];
    const VIEWABLE = ["svg", "png", "jpg", "jpeg", "webp", "gif", "bmp"];
    const PLAYABLE = ["mp4"];
    const READABLE = ["txt"];

    const ACCEPTS = {
        text: ".txt,text/plain",
        manual: ".txt,text/plain",
        video: ".mp4,video/mp4"
    };
    const UPLOAD_LIMIT = 32 * 1024 * 1024;
    const PAGE = 60;

    const trail = el("catalogue-crumbs");
    const body = el("catalogue-body");
    const search = el("catalogue-search");

    let folder = null;
    let opened = null;
    let overlays = null;
    let steps = {};
    let entries = [];
    let shown = PAGE;
    let bareOnly = false;
    let order = "name";

    const label = (entry) => (entry.friendly ? `${entry.friendly} (${entry.stem})` : entry.stem);
    const extension = (name) => (name.split(".").pop() || "").toLowerCase();
    const placeable = (entry) => Boolean(entry.catalogue);
    const pathUrl = (path) => apiPath(...path.split("/"));
    const held = (entry) => TYPES.filter((kind) => entry.files[kind.key]).length;
    const facePick = (entry) => FACE.map((key) => entry.files[key] && {key, file: entry.files[key]}).find(Boolean);

    function chrome(searchable) {
        const trailSteps = [{label: "Catalogue", go: () => go(null, null, null)}];

        if (folder) {
            const parts = folder.path.split("/");
            parts.forEach((part, index) => {
                const upto = parts.slice(0, index + 1).join("/");
                trailSteps.push({label: part, go: () => go(upto, null, null)});
            });
        }

        if (overlays) trailSteps.push({label: "System overlays"});
        else if (opened) {
            const entry = entries.find((item) => item.stem === opened);
            trailSteps.push({label: entry ? label(entry) : opened});
        }

        crumbs(trail, trailSteps);
        search.hidden = !searchable;
    }

    function go(nextFolder, nextOpened, nextOverlays, push = true) {
        if (push) navigate({folder: nextFolder, opened: nextOpened, overlays: Boolean(nextOverlays)});
        return render(nextFolder, nextOpened, nextOverlays);
    }

    async function render(nextFolder, nextOpened, nextOverlays) {
        if (!nextFolder) return showFolders();

        if (!folder || nextFolder !== folder.path || !entries.length) {
            const loaded = await loadFolder(nextFolder);
            if (!loaded) return;
        }

        if (nextOverlays) return showOverlays();
        if (nextOpened) return showItem(nextOpened);
        return showContents();
    }

    function restore(where) {
        const at = where || {};
        return render(at.folder || null, at.opened || null, at.overlays || null);
    }

    function countCard(name, count, noun, onOpen) {
        const face = make("div", "card-art opens");
        face.addEventListener("click", onOpen);
        if (!count) face.classList.add("empty");
        face.append(make("span", "card-count", count.toLocaleString()));

        const title = make("button", "card-name", name);
        title.type = "button";
        title.addEventListener("click", onOpen);

        const card = make("div", "card wide");
        card.append(face, title, make("span", "card-meta", count === 1 ? noun[0] : noun[1]));
        return card;
    }

    async function showFolders() {
        folder = null;
        opened = null;
        overlays = null;
        chrome(false);
        body.replaceChildren(loading("Reading the card…"));

        try {
            const data = await api("api/content");
            showSpace("catalogue", data);

            const folders = sortItems(data.folders || [], "name",
                (entry) => entry.friendly || entry.name);

            body.replaceChildren();
            if (!folders.length) {
                body.append(make("p", "note", "No content on the card."));
                return;
            }

            const bar = make("div", "filters");
            bar.append(sortControl(order, (value) => {
                order = value;
                showFolders();
            }), layoutControl("catalogue"), make("span", "note", `${folders.length} on the card`));
            body.append(bar);

            const grid = make("div", layoutClass("catalogue", "counts"));
            folders.forEach((entry) => {
                grid.append(countCard(
                    entry.friendly ? `${entry.friendly} (${entry.name})` : entry.name,
                    entry.content, ["file", "files"],
                    () => go(entry.name, null, null)));
            });
            body.append(grid);
        } catch (error) {
            body.replaceChildren(problem(error.message, showFolders));
        }
    }

    async function loadFolder(path) {
        folder = {path, name: path.split("/").pop(), catalogue: null};
        opened = null;
        overlays = null;
        shown = PAGE;
        bareOnly = false;
        search.value = "";
        chrome(false);
        body.replaceChildren(loading(`Reading ${path.split("/").pop()}…`));

        try {
            const data = await api(`api/content/${pathUrl(path)}`);
            showSpace("catalogue", data);
            folder = {
                path: data.path || path,
                name: data.name || path.split("/").pop(),
                catalogue: data.catalogue || null
            };
            entries = data.entries || [];
            steps = data.overlays || {};
            return true;
        } catch (error) {
            body.replaceChildren(problem(error.message, () => go(path, null, null, false)));
            return false;
        }
    }

    function chips(entry) {
        const row = make("span", "chips");

        TYPES.forEach((kind) => {
            const has = Boolean(entry.files[kind.key]);
            const chip = make("span", `chip${has ? " on" : ""}`, kind.short);
            chip.title = `${kind.name}: ${has ? "added" : "missing"}`;
            row.append(chip);
        });

        return row;
    }

    function contentCard(entry) {
        const box = make("div", "card");
        const open = () => go(folder.path, entry.stem, null);

        const art = make("div", "card-art opens");
        art.title = `Open ${label(entry)}`;
        art.addEventListener("click", open);

        const shot = facePick(entry);
        if (shot && VIEWABLE.includes(extension(shot.file))) {
            const image = make("img");
            image.loading = "lazy";
            image.alt = "";
            image.src = mediaUrl("catalogue", `${entry.catalogue}/${shot.key}/${shot.file}`);
            image.addEventListener("error", () => {
                image.remove();
                art.append(make("span", "card-mark", String(held(entry))));
            });
            art.append(image);
        } else {
            art.append(make("span", "card-mark", held(entry) ? String(held(entry)) : ""));
            if (!held(entry)) art.classList.add("empty");
        }

        const title = make("button", "card-name", entry.self ? `${label(entry)} (this folder)` : label(entry));
        title.type = "button";
        title.addEventListener("click", open);

        box.append(art, title);

        if (!placeable(entry)) {
            const mark = make("span", "card-meta orphan", "no catalogue");
            mark.title = `${folder.name} has no system, so there is nowhere to file this`;
            box.append(mark);
        } else {
            box.append(chips(entry));
        }

        if (entry.orphan) {
            const mark = make("span", "card-meta orphan", "not on the card");
            mark.title = `Nothing on the card is named ${entry.stem}`;
            box.append(mark);
        }

        return box;
    }

    function folderCard(entry) {
        const box = make("div", "card");
        const open = () => go(entry.path, null, null);

        const art = make("div", "card-art opens empty");
        art.title = `Open ${label(entry)}`;
        art.addEventListener("click", open);
        art.append(make("span", "card-mark", "/"));

        const title = make("button", "card-name", label(entry));
        title.type = "button";
        title.addEventListener("click", open);

        box.append(art, title, make("span", "card-meta", "folder"));
        return box;
    }

    function showContents() {
        opened = null;
        overlays = null;
        shown = PAGE;
        chrome(true);
        renderContents();
    }

    function renderContents() {
        const needle = search.value.trim().toLowerCase();
        let found = entries;

        if (needle) {
            found = found.filter((entry) =>
                entry.stem.toLowerCase().includes(needle) ||
                (entry.friendly || "").toLowerCase().includes(needle));
        }
        if (bareOnly) found = found.filter((entry) => !held(entry));

        const sorted = sortItems(found, order, (entry) => entry.friendly || entry.stem);
        const here = sorted.filter((entry) => entry.self);
        const content = sorted.filter((entry) => !entry.self && !entry.path);
        const directories = sorted.filter((entry) => !entry.self && entry.path);

        body.replaceChildren();

        const filter = make("div", "filters");
        const toggle = make("button", `chip-toggle${bareOnly ? " on" : ""}`, "No artwork");
        toggle.type = "button";
        toggle.addEventListener("click", () => {
            bareOnly = !bareOnly;
            shown = PAGE;
            renderContents();
        });
        filter.append(sortControl(order, (value) => {
            order = value;
            renderContents();
        }), layoutControl("catalogue"), toggle, make("span", "note", `${content.length} shown`));
        body.append(filter);

        if (canManage() && !folder.catalogue) {
            body.append(make("p", "note", `${folder.name} has no system, so only its folder art can be set.`));
        }

        const grid = make("div", layoutClass("catalogue"));
        here.forEach((entry) => grid.append(contentCard(entry)));
        content.slice(0, shown).forEach((entry) => grid.append(contentCard(entry)));
        body.append(grid);

        if (folder.catalogue) {
            const group = make("div", "group");
            const head = make("div", "group-head");

            head.append(make("h3", null, "System"));
            group.append(head);

            const inside = make("div", layoutClass("catalogue", "counts"));
            inside.append(overlayCard());
            group.append(inside);
            body.append(group);
        }

        if (!content.length && !directories.length) {
            body.append(make("p", "note", bareOnly ? "Everything here has artwork." : "Nothing matches that."));
            return;
        }

        if (content.length > shown) {
            const more = make("button", "link more", `Show more (${content.length - shown} left)`);
            more.type = "button";
            more.addEventListener("click", () => {
                shown += PAGE;
                renderContents();
            });
            body.append(more);
        }

        if (directories.length) {
            const group = make("div", "group");
            const head = make("div", "group-head");

            head.append(make("h3", null, directories.length === 1 ? "Folder" : "Folders"),
                make("span", "note", `${directories.length}`));
            group.append(head);

            const inside = make("div", layoutClass("catalogue"));
            directories.forEach((entry) => inside.append(folderCard(entry)));
            group.append(inside);
            body.append(group);
        }
    }

    function stepsDone() {
        return STEPS.reduce((sum, kind) => sum + Object.keys(steps[kind.leaf] || {}).length, 0);
    }

    function overlayCard() {
        const box = make("div", "card wide");
        const done = stepsDone();
        const total = STEPS.length * STEP_COUNT;
        const open = () => go(folder.path, null, true);

        const face = make("div", "card-art opens");
        face.title = "Open the system overlays";
        face.addEventListener("click", open);
        if (!done) face.classList.add("empty");
        face.append(make("span", "card-count", `${done}`));

        const title = make("button", "card-name", "System overlays");
        title.type = "button";
        title.addEventListener("click", open);

        box.append(face, title, make("span", "card-meta", `of ${total} steps\n${folder.catalogue}`));
        return box;
    }

    function showOverlays() {
        opened = null;
        overlays = true;
        chrome(false);
        renderOverlays();
    }

    function stepEntry(kind, step) {
        const stem = `${kind.leaf}_${step}`;
        const file = (steps[kind.leaf] || {})[String(step)];
        return {stem, catalogue: folder.catalogue, files: file ? {[kind.key]: file} : {}};
    }

    function renderOverlays() {
        body.replaceChildren();

        const bar = make("div", "filters");
        bar.append(layoutControl("catalogue"),
            make("span", "note", `${stepsDone()} of ${STEPS.length * STEP_COUNT} added`));
        body.append(bar);

        body.append(make("p", "note",
            `These belong to ${folder.catalogue}, not to any one game. Each gauge is drawn from ten images, one per step.`));

        STEPS.forEach((kind) => {
            const done = Object.keys(steps[kind.leaf] || {}).length;
            const group = make("div", "group");
            const head = make("div", "group-head");

            head.append(make("h3", null, kind.name), make("span", "note", `${done} of ${STEP_COUNT}`));
            group.append(head);

            const grid = make("div", layoutClass("catalogue"));
            for (let step = 0; step < STEP_COUNT; step += 1) {
                grid.append(typeCard(stepEntry(kind, step), kind, `Step ${step}`));
            }

            group.append(grid);
            body.append(group);
        });
    }

    function showItem(stem) {
        opened = stem;
        overlays = null;
        chrome(false);
        renderItem();
    }

    function renderItem() {
        const entry = entries.find((item) => item.stem === opened);
        body.replaceChildren();

        if (!entry) {
            body.append(problem(`${opened} is no longer here`, () => go(folder.path, null, null, false)));
            return;
        }

        const bar = make("div", "filters");
        bar.append(layoutControl("catalogue"),
            make("span", "note", `${held(entry)} of ${TYPES.length} added`));
        body.append(bar);

        if (!placeable(entry)) {
            body.append(make("p", "note",
                `${folder.name} has no system, so there is nowhere to file artwork for ${label(entry)}.`));
        } else if (entry.orphan) {
            body.append(make("p", "note danger",
                `Nothing on the card is named ${entry.stem}, so none of this is drawn.`));
        }

        const grid = make("div", layoutClass("catalogue"));
        TYPES.forEach((kind) => grid.append(typeCard(entry, kind)));
        body.append(grid);

        if (folder.catalogue && !entry.folder) body.append(gauges());
    }

    function gauges() {
        const group = make("div", "group");
        const head = make("div", "group-head");

        head.append(make("h3", null, "Gauges"),
            make("span", "note", `${stepsDone()} of ${STEPS.length * STEP_COUNT}`));
        group.append(head);

        group.append(make("p", "note",
            `Battery, brightness and volume are drawn from ${folder.catalogue}, ten images to a gauge, and are shared by everything in it.`));

        const grid = make("div", layoutClass("catalogue", "counts"));
        STEPS.forEach((kind) => {
            const done = Object.keys(steps[kind.leaf] || {}).length;
            const open = () => go(folder.path, null, true);

            const card = make("div", "card wide");
            const face = make("div", "card-art opens");
            face.title = `Open the ${kind.name.toLowerCase()} gauge`;
            face.addEventListener("click", open);
            if (!done) face.classList.add("empty");
            face.append(make("span", "card-count", `${done}`));

            const title = make("button", "card-name", kind.name);
            title.type = "button";
            title.addEventListener("click", open);

            card.append(face, title, make("span", "card-meta", `of ${STEP_COUNT} steps`));
            grid.append(card);
        });

        group.append(grid);
        return group;
    }

    function preview(art, url, file) {
        const kind = extension(file);
        const fallback = () => {
            art.replaceChildren(make("span", "card-mark", kind));
        };

        if (VIEWABLE.includes(kind)) {
            const image = make("img");
            image.loading = "lazy";
            image.alt = "";
            image.src = url;
            image.addEventListener("error", fallback);
            art.append(image);
            return;
        }

        if (PLAYABLE.includes(kind)) {
            const clip = make("video");
            clip.preload = "metadata";
            clip.muted = true;
            clip.playsInline = true;
            clip.src = `${url}#t=0.1`;
            clip.addEventListener("error", fallback);
            art.append(clip);
            return;
        }

        if (READABLE.includes(kind)) {
            art.append(make("span", "card-mark", kind));
            fetch(url, {cache: "no-store"})
                .then((answer) => (answer.ok ? answer.text() : ""))
                .then((words) => {
                    const trimmed = words.trim();
                    if (trimmed) art.replaceChildren(make("span", "card-text", trimmed.slice(0, 600)));
                })
                .catch(() => {});
            return;
        }

        fallback();
    }

    function typeCard(entry, kind, naming) {
        const file = entry.files[kind.key];
        const box = make("div", "card");
        const editable = canManage() && placeable(entry);

        const art = make(editable ? "button" : "div", "card-art");
        if (editable) {
            art.type = "button";
            art.classList.add("opens");
        }

        if (file) preview(art, mediaUrl("catalogue", artPath(entry, kind, file)), file);
        else {
            art.append(make("span", "card-mark", editable ? "+" : ""));
            art.classList.add("empty");
        }

        box.append(art, make("span", "card-name", naming || kind.name));

        if (editable) {
            const picker = make("input");
            picker.type = "file";
            picker.hidden = true;
            picker.accept = ACCEPTS[kind.key] || "image/*";
            picker.addEventListener("change", () => {
                if (picker.files.length) upload(entry, kind, picker.files[0], art);
                picker.value = "";
            });

            const what = `${file ? "Replace" : "Add"} the ${kind.name.toLowerCase()} for ${label(entry)}`;
            art.title = what;
            art.setAttribute("aria-label", what);
            art.addEventListener("click", () => picker.click());
            box.append(picker);
        }

        const actions = make("span", "card-actions");
        if (file) {
            const download = make("a", "link", "Get");
            download.href = mediaUrl("catalogue", artPath(entry, kind, file));
            download.download = file.split("/").pop();
            actions.append(download);

            if (editable) {
                if (VIEWABLE.includes(extension(file)) && extension(file) !== "svg") {
                    const tweak = make("button", "link", "Adjust");
                    tweak.type = "button";
                    tweak.title = `Crop and resize the ${kind.name.toLowerCase()} for ${label(entry)}`;
                    tweak.addEventListener("click", () => adjust(entry, kind, file, tweak));
                    actions.append(tweak);
                }

                const remove = make("button", "link danger", "Remove");
                remove.type = "button";
                remove.addEventListener("click", () => discard(entry, kind, file, remove));
                actions.append(remove);
            }
        }
        if (actions.childElementCount) box.append(actions);

        return box;
    }

    function artPath(entry, kind, file) {
        return `${entry.catalogue}/${kind.key}/${file}`;
    }

    function destination(entry, kind, name) {
        const has = entry.files[kind.key] || "";
        const within = has.includes("/") ? `${has.slice(0, has.lastIndexOf("/"))}/` : "";
        return `api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...`${within}${name}`.split("/"))}`;
    }

    async function prepare(file) {
        if (file.size > UPLOAD_LIMIT) {
            showToast(`${file.name} is ${bytes(file.size)}, over the ${bytes(UPLOAD_LIMIT)} limit`);
            return null;
        }
        if (!VIEWABLE.includes(extension(file.name)) || extension(file.name) === "svg") return file;
        return window.MU.cropImage(file);
    }

    async function upload(entry, kind, chosen, button) {
        const file = await prepare(chosen);
        if (!file) return;

        const has = entry.files[kind.key];
        const name = `${entry.stem}.${extension(file.name)}`;

        try {
            await busy(button, "Saving…", () => api(destination(entry, kind, name), {
                method: "POST",
                body: file,
                type: file.type || "application/octet-stream"
            }));

            if (has && has.split("/").pop() !== name) {
                await api(`api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...has.split("/"))}`, {
                    method: "DELETE"
                });
            }

            showToast(`${kind.name} saved`);
            await refresh();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function adjust(entry, kind, file, button) {
        const name = file.split("/").pop();
        let edited;

        try {
            const response = await fetch(mediaUrl("catalogue", artPath(entry, kind, file)), {cache: "no-store"});
            if (!response.ok) throw new Error(`Could not read that ${kind.name.toLowerCase()}`);

            const blob = await response.blob();
            edited = await window.MU.cropImage(new File([blob], name, {type: blob.type}));
        } catch (error) {
            showToast(error.message);
            return;
        }

        if (!edited) return;

        try {
            await busy(button, "Saving…", () => api(destination(entry, kind, name), {
                method: "POST",
                body: edited,
                type: edited.type || "application/octet-stream"
            }));
            showToast(`${kind.name} adjusted`);
            await refresh();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function discard(entry, kind, file, button) {
        const sure = await ask({
            title: "Remove artwork",
            message: `The ${kind.name.toLowerCase()} for ${entry.stem} will be deleted.`,
            confirm: "Remove",
            danger: true
        });
        if (!sure) return;

        try {
            await busy(button, "Removing…",
                () => api(`api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...file.split("/"))}`,
                    {method: "DELETE"}));
            showToast(`${kind.name} removed`);
            await refresh();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function refresh() {
        const data = await api(`api/content/${pathUrl(folder.path)}`);
        showSpace("catalogue", data);
        entries = data.entries || [];
        steps = data.overlays || {};
        if (overlays) renderOverlays();
        else if (opened) renderItem();
        else renderContents();
    }

    search.addEventListener("input", () => {
        shown = PAGE;
        renderContents();
    });

    onLayoutChange((view) => {
        if (view !== "catalogue") return;
        if (opened) renderItem();
        else if (folder) renderContents();
        else showFolders();
    });

    onAuthChange(() => {
        if (opened) renderItem();
        else if (folder) renderContents();
    });

    register("catalogue", {
        restore,
        load: () => render(folder && folder.path, opened, overlays)
    });
}());
