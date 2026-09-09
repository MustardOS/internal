(function () {
    "use strict";

    const {el, make, bytes, showToast, api, register, mediaUrl, apiPath, canManage, onAuthChange,
           sortItems, sortControl, navigate, crumbs, ask, busy, problem, loading, showSpace,
           layoutClass, layoutControl, onLayoutChange} = window.MU;

    const KINDS = [
        {key: "box", name: "Box Art"},
        {key: "grid", name: "Grid Image"},
        {key: "manual", name: "Pickles Manuals"},
        {
            name: "Overlays",
            parts: [
                {key: "overlay/base", name: "Base"},
                {key: "overlay/battery", name: "Battery"},
                {key: "overlay/bright", name: "Brightness"},
                {key: "overlay/volume", name: "Volume"}
            ]
        },
        {key: "preview", name: "Content Preview Image"},
        {key: "splash", name: "Content Launch Splash Image"},
        {key: "text", name: "Content Description Text"},
        {key: "video", name: "Content Preview Video"}
    ];

    const VIEWABLE = ["svg", "png", "jpg", "jpeg", "webp", "gif", "bmp"];
    const PAGE = 60;
    const trail = el("catalogue-crumbs");
    const body = el("catalogue-body");
    const search = el("catalogue-search");
    let folder = null;
    let group = null;
    let type = null;
    let entries = [];
    let shown = PAGE;
    let missingOnly = false;
    let order = "name";
    const label = (entry) => (entry.friendly ? `${entry.friendly} (${entry.stem})` : entry.stem);
    const extension = (name) => (name.split(".").pop() || "").toLowerCase();
    const plural = (n, one, many) => `${n.toLocaleString()} ${n === 1 ? one : many}`;
    const held = (key) => entries.filter((entry) => entry.files[key]).length;

    function chrome(searchable) {
        const steps = [{label: "Catalogue", go: () => go(null, null, null)}];

        if (folder) {
            const parts = folder.path.split("/");
            parts.forEach((part, index) => {
                const upto = parts.slice(0, index + 1).join("/");
                steps.push({label: part, go: () => go(upto, null, null)});
            });
        }

        if (group) steps.push({label: group.name, go: () => go(folder.path, group, null)});
        if (type) steps.push({label: type.name});

        crumbs(trail, steps);
        search.hidden = !searchable;
    }

    function go(nextFolder, nextGroup, nextType, push = true) {
        if (push) navigate({folder: nextFolder, group: nextGroup && nextGroup.name, type: nextType && nextType.key});
        return render(nextFolder, nextGroup, nextType);
    }

    async function render(nextFolder, nextGroup, nextType) {
        if (!nextFolder) return showFolders();

        if (!folder || nextFolder !== folder.path || !entries.length) {
            const loaded = await loadFolder(nextFolder);
            if (!loaded) return;
        }

        if (nextType) return showType(nextType, nextGroup);
        if (nextGroup) return showGroup(nextGroup);
        return showKinds();
    }

    function restore(where) {
        const at = where || {};
        const kind = KINDS.find((k) => k.parts && k.name === at.group) || null;
        const leaf = at.type
            ? KINDS.find((k) => k.key === at.type)
              || KINDS.flatMap((k) => k.parts || []).find((part) => part.key === at.type)
            : null;
        return render(at.folder || null, kind, leaf || null);
    }

    const NOUNS = {text: ["file", "files"], video: ["video", "videos"], manual: ["manual", "manuals"]};
    const nounFor = (key) => NOUNS[key] || ["image", "images"];

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
        folder = group = type = null;
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

    function kindBar() {
        const bar = make("div", "filters");
        bar.append(layoutControl("catalogue"));
        return bar;
    }

    function showKinds() {
        group = type = null;
        chrome(false);
        body.replaceChildren();
        body.append(kindBar());

        const grid = make("div", layoutClass("catalogue", "counts"));
        KINDS.forEach((kind) => {
            if (kind.parts) {
                const done = kind.parts.reduce((sum, part) => sum + held(part.key), 0);
                grid.append(countCard(kind.name, done, ["image", "images"], () => go(folder.path, kind, null)));
                return;
            }
            grid.append(countCard(kind.name, held(kind.key), nounFor(kind.key),
                () => go(folder.path, null, kind)));
        });

        body.append(grid);
    }

    function showGroup(kind) {
        group = kind;
        type = null;
        chrome(false);
        body.replaceChildren();
        body.append(kindBar());

        const grid = make("div", layoutClass("catalogue", "counts"));
        kind.parts.forEach((part) => {
            grid.append(countCard(part.name, held(part.key), ["image", "images"],
                () => go(folder.path, kind, part)));
        });
        body.append(grid);
    }

    const pathUrl = (path) => apiPath(...path.split("/"));

    async function loadFolder(path) {
        folder = {path, name: path.split("/").pop(), catalogue: null};
        group = type = null;
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
            return true;
        } catch (error) {
            body.replaceChildren(problem(error.message, () => go(path, null, null, false)));
            return false;
        }
    }

    function card(entry) {
        const file = entry.files[type.key];
        const box = make("div", "card");

        const editable = canManage() && placeable(entry);

        const art = make(editable ? "button" : "div", "card-art");
        if (editable) {
            art.type = "button";
            art.classList.add("opens");
        }

        if (file && VIEWABLE.includes(extension(file))) {
            const image = make("img");
            image.loading = "lazy";
            image.alt = "";
            image.src = mediaUrl("catalogue", artPath(entry, file));

            image.addEventListener("error", () => {
                image.remove();
                art.append(make("span", "card-mark", extension(file)));
            });
            art.append(image);
        } else {
            art.append(make("span", "card-mark", file ? extension(file) : editable ? "+" : ""));
            if (!file) art.classList.add("empty");
        }

        if (entry.path) {
            const into = make("button", "card-name", entry.stem);
            into.type = "button";
            into.title = `Open ${entry.stem}`;
            into.addEventListener("click", () => go(entry.path, group, type));
            into.textContent = label(entry);
            box.append(art, into);
        } else {
            box.append(art, make("span", "card-name",
                entry.self ? `${label(entry)} (this folder)` : label(entry)));
        }

        if (!placeable(entry)) {
            const mark = make("span", "card-meta orphan", "no catalogue");
            mark.title = `${folder.name} has no system, so there is nowhere to file this`;
            box.append(mark);
        } else if (entry.folder) {
            box.append(make("span", "card-meta", entry.path ? "folder" : "folder art"));
        }

        if (entry.orphan) {
            const mark = make("span", "card-meta orphan", "not on the card");
            mark.title = `Nothing on the card is named ${entry.stem}`;
            box.append(mark);
        }

        if (editable) {
            const picker = make("input");
            picker.type = "file";
            picker.hidden = true;
            picker.addEventListener("change", () => {
                if (picker.files.length) upload(entry, picker.files[0], art);
                picker.value = "";
            });

            const what = `${file ? "Replace" : "Add"} the ${type.name.toLowerCase()} for ${label(entry)}`;
            art.title = what;
            art.setAttribute("aria-label", what);
            art.addEventListener("click", () => picker.click());
            box.append(picker);
        }

        const actions = make("span", "card-actions");
        if (file) {
            const download = make("a", "link", "Get");
            download.href = mediaUrl("catalogue", artPath(entry, file));
            download.download = file.split("/").pop();
            actions.append(download);

            if (editable) {
                if (VIEWABLE.includes(extension(file)) && extension(file) !== "svg") {
                    const tweak = make("button", "link", "Adjust");
                    tweak.type = "button";
                    tweak.title = `Crop and resize the ${type.name.toLowerCase()} for ${label(entry)}`;
                    tweak.addEventListener("click", () => adjust(entry, file, tweak));
                    actions.append(tweak);
                }

                const remove = make("button", "link danger", "Remove");
                remove.type = "button";
                remove.addEventListener("click", () => discard(entry, file, remove));
                actions.append(remove);
            }
        }
        if (actions.childElementCount) box.append(actions);

        return box;
    }

    function addCard() {
        const box = make("div", "card");

        const art = make("button", "card-art opens empty");
        art.type = "button";

        const what = `Add ${type.name.toLowerCase()} for content in ${folder.name} not listed here`;
        art.title = what;
        art.setAttribute("aria-label", what);
        art.append(make("span", "card-mark", "+"));

        const picker = make("input");
        picker.type = "file";
        picker.multiple = true;
        picker.hidden = true;
        picker.addEventListener("change", () => {
            const chosen = [...picker.files];
            picker.value = "";
            if (chosen.length) addFiles(chosen, art);
        });

        art.addEventListener("click", () => picker.click());

        box.append(art, make("span", "card-name", "Add artwork"), picker);
        return box;
    }

    async function addFiles(files, art) {
        let done = 0;
        const failed = [];

        const ready = [];
        for (const file of files) {
            const prepared = await prepare(file);
            if (prepared) ready.push(prepared);
        }
        if (!ready.length) return;

        await busy(art, "…", async () => {
            for (const file of ready) {
                try {
                    await api(`api/catalogue/${apiPath(folder.catalogue, ...type.key.split("/"), file.name)}`, {
                        method: "POST",
                        body: file,
                        type: file.type || "application/octet-stream"
                    });
                    done += 1;
                } catch (error) {
                    failed.push({name: file.name, why: error.message});
                }
            }
        });

        if (done) showToast(failed.length ? `Added ${done}, ${failed.length} refused` : `Added ${done}`);
        else if (failed.length === 1) showToast(`${failed[0].name}: ${failed[0].why}`);
        else showToast(`None of the ${failed.length} were accepted: ${failed[0].why}`);

        await refresh();
    }

    function renderCards() {
        const needle = search.value.trim().toLowerCase();
        let found = entries;
        if (needle) {
            found = found.filter((entry) =>
                entry.stem.toLowerCase().includes(needle) ||
                (entry.friendly || "").toLowerCase().includes(needle));
        }
        if (missingOnly) found = found.filter((entry) => !entry.files[type.key]);

        const sorted = sortItems(found, order, (entry) => entry.friendly || entry.stem);
        const here = sorted.filter((entry) => entry.self);
        const content = sorted.filter((entry) => !entry.self && !entry.path);
        const directories = sorted.filter((entry) => !entry.self && entry.path);

        const page = [...here, ...content.slice(0, shown)];
        body.replaceChildren();

        const filter = make("div", "filters");
        const toggle = make("button", `chip-toggle${missingOnly ? " on" : ""}`, "Missing only");
        toggle.type = "button";
        toggle.addEventListener("click", () => {
            missingOnly = !missingOnly;
            shown = PAGE;
            renderCards();
        });
        filter.append(sortControl(order, (value) => {
            order = value;
            renderCards();
        }), layoutControl("catalogue"), toggle, make("span", "note", `${content.length} shown`));
        body.append(filter);

        if (canManage() && !folder.catalogue) {
            body.append(make("p", "note", `${folder.name} has no system, so only its folder art can be set.`));
        }

        const grid = make("div", layoutClass("catalogue"));
        if (canManage() && folder.catalogue) grid.append(addCard());
        page.forEach((entry) => grid.append(card(entry)));
        body.append(grid);

        if (!content.length && !directories.length) {
            body.append(make("p", "note", missingOnly ? "Every game has one." : "No games match that."));
            return;
        }

        if (content.length > shown) {
            const more = make("button", "link more", `Show more (${content.length - shown} left)`);
            more.type = "button";
            more.addEventListener("click", () => {
                shown += PAGE;
                renderCards();
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
            directories.forEach((entry) => inside.append(card(entry)));
            group.append(inside);
            body.append(group);
        }
    }

    function showType(kind, within) {
        type = kind;
        group = within || null;
        shown = PAGE;
        missingOnly = false;
        search.value = "";
        chrome(true);
        renderCards();
    }

    function destination(entry, name) {
        const has = entry.files[type.key] || "";
        const within = has.includes("/") ? `${has.slice(0, has.lastIndexOf("/"))}/` : "";
        return `api/catalogue/${apiPath(entry.catalogue, ...type.key.split("/"), ...`${within}${name}`.split("/"))}`;
    }

    function artPath(entry, file) {
        return `${entry.catalogue}/${type.key}/${file}`;
    }

    const placeable = (entry) => Boolean(entry.catalogue);
    const UPLOAD_LIMIT = 32 * 1024 * 1024;

    async function prepare(file) {
        if (file.size > UPLOAD_LIMIT) {
            showToast(`${file.name} is ${bytes(file.size)}, over the ${bytes(UPLOAD_LIMIT)} limit`);
            return null;
        }
        if (!VIEWABLE.includes(extension(file.name)) || extension(file.name) === "svg") return file;
        return window.MU.cropImage(file);
    }

    async function upload(entry, chosen, button) {
        const file = await prepare(chosen);
        if (!file) return;

        const has = entry.files[type.key];
        const name = `${entry.stem}.${extension(file.name)}`;

        try {
            await busy(button, "Saving…", () => api(destination(entry, name), {
                method: "POST",
                body: file,
                type: file.type || "application/octet-stream"
            }));

            if (has && has.split("/").pop() !== name) {
                await api(`api/catalogue/${apiPath(entry.catalogue, ...type.key.split("/"), ...has.split("/"))}`, {
                    method: "DELETE"
                });
            }

            showToast(`${type.name} saved`);
            await refresh();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function adjust(entry, file, button) {
        const path = artPath(entry, file);
        const name = file.split("/").pop();
        let edited;

        try {
            const response = await fetch(mediaUrl("catalogue", path), {cache: "no-store"});
            if (!response.ok) throw new Error(`Could not read that ${type.name.toLowerCase()}`);

            const blob = await response.blob();
            edited = await window.MU.cropImage(new File([blob], name, {type: blob.type}));
        } catch (error) {
            showToast(error.message);
            return;
        }

        if (!edited) return;

        try {
            await busy(button, "Saving…", () => api(destination(entry, name), {
                method: "POST",
                body: edited,
                type: edited.type || "application/octet-stream"
            }));
            showToast(`${type.name} adjusted`);
            await refresh();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function discard(entry, file, button) {
        const sure = await ask({
            title: "Remove artwork",
            message: `The ${type.name.toLowerCase()} for ${entry.stem} will be deleted.`,
            confirm: "Remove",
            danger: true
        });
        if (!sure) return;

        try {
            await busy(button, "Removing…",
                () => api(`api/catalogue/${apiPath(entry.catalogue, ...type.key.split("/"), ...file.split("/"))}`,
                    {method: "DELETE"}));
            showToast(`${type.name} removed`);
            await refresh();
        } catch (error) {
            showToast(error.message);
        }
    }

    async function refresh() {
        const data = await api(`api/content/${pathUrl(folder.path)}`);
        showSpace("catalogue", data);
        entries = data.entries || [];
        renderCards();
    }

    search.addEventListener("input", () => {
        shown = PAGE;
        renderCards();
    });

    onLayoutChange((view) => {
        if (view !== "catalogue") return;
        if (type) renderCards();
        else if (group) showGroup(group);
        else if (folder) showKinds();
        else showFolders();
    });

    onAuthChange(() => {
        if (type) renderCards();
    });

    register("catalogue", {
        restore,
        load: () => render(folder && folder.path, group, type)
    });
}());
