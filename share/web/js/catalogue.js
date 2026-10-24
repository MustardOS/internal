(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, bytes, showToast, api, register, mediaUrl, apiPath, canManage, onAuthChange,
           navigate, crumbs, ask, busy, problem, loading, sortableHead, attachMediaPreview,
           hideMediaPreview, t} = MU;

    const TYPES = [
        {key: "box", name: "Box Art", short: "Box"},
        {key: "grid", name: "Grid Image", short: "Grid"},
        {key: "preview", name: "Preview Media", short: "Preview"},
        {key: "splash", name: "Launch Splash", short: "Splash"},
        {key: "text", name: "Description Text", short: "Text"},
        {key: "manual", name: "Manual", short: "Manual"},
        {key: "overlay/base", name: "Overlay", short: "Overlay"}
    ];
    const VIEWABLE = ["svg", "png", "apng", "jpg", "jpeg", "webp", "gif", "bmp"];
    const ACCEPTS = {
        box: "image/*,.apng,.mp4,video/mp4",
        preview: "image/*,.apng,.mp4,video/mp4",
        splash: "image/*,.apng,.mp4,video/mp4",
        text: ".txt,text/plain",
        manual: ".txt,text/plain"
    };
    const UPLOAD_LIMIT = 32 * 1024 * 1024;
    const PAGE = 100;
    const collator = new Intl.Collator(undefined, {numeric: true, sensitivity: "base"});
    const trail = el("catalogue-crumbs");
    const body = el("catalogue-body");
    const search = el("catalogue-search");
    const refreshButton = el("catalogue-refresh");

    let folder = null;
    let opened = null;
    let mediaVersion = Date.now();
    let entries = [];
    let shown = PAGE;
    let bareOnly = false;
    let sortColumn = "name";
    let sortDescending = false;

    try {
        const saved = JSON.parse(localStorage.getItem("muos.catalogue.sort"));
        if (["name", "count", "missing"].includes(saved.column)) sortColumn = saved.column;
        sortDescending = Boolean(saved.descending);
    } catch (_) {
    }

    const label = (entry) => (entry.friendly ? `${entry.friendly} (${entry.stem || entry.name})` : entry.stem || entry.name);
    const extension = (name) => ((name || "").split(".").pop() || "").toLowerCase();
    const placeable = (entry) => Boolean(entry.catalogue);
    const pathUrl = (path) => apiPath(...path.split("/"));
    const held = (entry) => TYPES.filter((kind) => entry.files && entry.files[kind.key]).length;

    function setSort(column, descending) {
        sortColumn = column;
        sortDescending = descending;
        try {
            localStorage.setItem("muos.catalogue.sort", JSON.stringify({column, descending}));
        } catch (_) {
        }
        if (folder) renderContents();
        else showFolders();
    }

    function sorted(items, naming) {
        return [...items].sort((left, right) => {
            let result;
            if (sortColumn === "count") {
                const leftCount = Object.prototype.hasOwnProperty.call(left, "count") ? left.count : held(left);
                const rightCount = Object.prototype.hasOwnProperty.call(right, "count") ? right.count : held(right);
                result = leftCount - rightCount;
            }
            else if (sortColumn === "missing") {
                const leftMissing = Object.prototype.hasOwnProperty.call(left, "missing")
                    ? left.missing : TYPES.length - held(left);
                const rightMissing = Object.prototype.hasOwnProperty.call(right, "missing")
                    ? right.missing : TYPES.length - held(right);
                result = leftMissing - rightMissing;
            }
            else result = collator.compare(naming(left), naming(right));
            if (!result) result = collator.compare(naming(left), naming(right));
            return sortDescending ? -result : result;
        });
    }

    function chrome(searchable) {
        const trailSteps = [
            {label: t("File Management"), glyph: "home", go: () => MU.show("files")},
            {label: t("Catalogue"), go: () => go(null, null)}
        ];
        if (folder) {
            const parts = folder.path.split("/");
            parts.forEach((part, index) => {
                const upto = parts.slice(0, index + 1).join("/");
                trailSteps.push({label: part, go: () => go(upto, null)});
            });
        }
        if (opened) {
            const entry = entries.find((item) => item.stem === opened);
            trailSteps.push({label: entry ? label(entry) : opened});
        }
        crumbs(trail, trailSteps);
        search.hidden = !searchable;
    }

    function go(nextFolder, nextOpened, push = true) {
        if (push) navigate({folder: nextFolder, opened: nextOpened});
        return render(nextFolder, nextOpened);
    }

    async function render(nextFolder, nextOpened) {
        if (!nextFolder) return showFolders();
        if (!folder || nextFolder !== folder.path || !entries.length) {
            const loaded = await loadFolder(nextFolder);
            if (!loaded) return;
        }
        if (nextOpened) return showItem(nextOpened);
        return showContents();
    }

    function restore(where) {
        const at = where || {};
        return render(at.folder || null, at.opened || null);
    }

    const GLYPHS = {Add: "upload", Replace: "upload", Edit: "edit", Adjust: "sliders", Remove: "trash"};

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

    function download(url, name) {
        const text = t("Download");
        const link = make("a", "link file-action");
        link.dataset.glyph = "download";
        link.dataset.tooltip = text;
        link.title = text;
        link.setAttribute("aria-label", text);
        link.href = url;
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
        const node = make("table", "data-table browser-table catalogue-table");
        const head = make("thead");
        head.append(sortableHead(columns, sortable ? sortColumn : "", sortable ? sortDescending : false,
            sortable ? setSort : () => {}));
        const tableBody = make("tbody");
        rows.forEach((row) => tableBody.append(row));
        node.append(head, tableBody);
        const scroll = make("div", "table-scroll");
        scroll.append(node);
        return scroll;
    }

    function notice(title, message) {
        const node = make("aside", "catalogue-notice");
        node.append(make("strong", null, t(title)), make("p", null, message));
        return node;
    }

    function openName(text, onOpen, folderName) {
        const button = make("button", `entry-name ${folderName ? "collection-folder-name" : ""}`, text);
        button.type = "button";
        button.title = text;
        button.addEventListener("click", onOpen);
        return button;
    }

    async function showFolders() {
        folder = null;
        opened = null;
        chrome(false);
        body.replaceChildren(loading("Reading the card..."));
        try {
            const data = await api("api/content");
            const folders = sorted((data.folders || []).map((entry) => ({
                ...entry,
                count: entry.content,
                missing: Number(entry.missing) || 0
            })),
                (entry) => entry.friendly || entry.name);
            if (!folders.length) {
                body.replaceChildren(make("p", "note", t("No content on the card.")));
                return;
            }

            const rows = folders.map((entry) => {
                const row = make("tr");
                const nameCell = make("td", "content-name-cell");
                const name = entry.friendly ? `${entry.friendly} (${entry.name})` : entry.name;
                nameCell.append(openName(name, () => go(entry.name, null), true));
                row.append(nameCell,
                    make("td", "number table-count", entry.content.toLocaleString()),
                    make("td", "number table-missing", entry.missing.toLocaleString()));
                return row;
            });
            body.replaceChildren(table([
                {key: "name", label: "Name"},
                {key: "count", label: "Content", descending: true, className: "table-count"},
                {key: "missing", label: "Missing", descending: true, className: "table-missing"}
            ], rows));
        } catch (error) {
            body.replaceChildren(problem(error.message, showFolders));
        }
    }

    async function loadFolder(path) {
        folder = {path, name: path.split("/").pop(), catalogue: null};
        opened = null;
        shown = PAGE;
        bareOnly = false;
        search.value = "";
        chrome(false);
        body.replaceChildren(loading(t("Reading %s...", path.split("/").pop())));
        try {
            const data = await api(`api/content/${pathUrl(path)}`);
            folder = {path: data.path || path, name: data.name || path.split("/").pop(), catalogue: data.catalogue || null};
            entries = data.entries || [];
            return true;
        } catch (error) {
            body.replaceChildren(problem(error.message, () => go(path, null, false)));
            return false;
        }
    }

    function showContents() {
        opened = null;
        shown = PAGE;
        chrome(true);
        renderContents();
    }

    function renderContents() {
        const needle = search.value.trim().toLocaleLowerCase();
        let found = entries.filter((entry) => !needle || `${entry.stem} ${entry.friendly || ""}`.toLocaleLowerCase().includes(needle));
        if (bareOnly) found = found.filter((entry) => !held(entry));
        const here = sorted(found.filter((entry) => entry.self), label);
        const directories = sorted(found.filter((entry) => !entry.self && entry.path), label);
        const content = sorted(found.filter((entry) => !entry.self && !entry.path), label);
        const page = [...here, ...directories, ...content.slice(0, shown)];

        body.replaceChildren();
        const filter = make("div", "filters");
        const toggle = make("button", `chip-toggle${bareOnly ? " on" : ""}`, t("No artwork"));
        toggle.type = "button";
        toggle.addEventListener("click", () => {
            bareOnly = !bareOnly;
            shown = PAGE;
            renderContents();
        });
        filter.append(toggle, make("span", "note", t("%s shown", content.length)));
        body.append(filter);
        if (canManage() && !folder.catalogue) {
            body.append(notice("Folder artwork only",
                t("Content artwork requires an assigned system. You can still set artwork for the %s folder.", folder.name)));
        }

        const rows = [];
        page.forEach((entry) => {
            const open = () => entry.path ? go(entry.path, null) : go(folder.path, entry.stem);
            const row = make("tr");
            const nameCell = make("td", "content-name-cell");
            let name = entry.self ? t("This Folder") : label(entry);
            if (entry.orphan) name = `${name} (${t("not on the card")})`;
            nameCell.append(openName(name, open, Boolean(entry.path || entry.self)));
            const missing = TYPES.length - held(entry);
            row.append(nameCell,
                make("td", "number table-missing", missing.toLocaleString()));
            rows.push(row);
        });

        if (!rows.length) {
            body.append(make("p", "note", t(bareOnly ? "Everything here has artwork." : "Nothing matches that.")));
            return;
        }
        body.append(table([
            {key: "name", label: "Name"},
            {key: "missing", label: "Missing", descending: true, className: "table-missing"}
        ], rows));

        if (content.length > shown) {
            const more = make("button", "link more", t("Show more (%s left)", content.length - shown));
            more.type = "button";
            more.addEventListener("click", () => {
                shown += PAGE;
                renderContents();
            });
            body.append(more);
        }
    }

    function showItem(stem) {
        opened = stem;
        chrome(false);
        renderItem();
    }

    function renderItem() {
        const entry = entries.find((item) => item.stem === opened);
        body.replaceChildren();
        if (!entry) {
            body.append(problem(t("%s is no longer here", opened), () => go(folder.path, null, false)));
            return;
        }
        if (!placeable(entry)) {
            body.append(notice("Artwork unavailable",
                t("%s is not assigned to a system, so artwork for %s cannot be stored.", folder.name, label(entry))));
        }
        else if (entry.orphan) body.append(make("p", "note danger", t("Nothing on the card is named %s, so none of this is drawn.", entry.stem)));
        body.append(table([
            {label: "Name"}, {label: "File"}, {label: "Status", className: "table-artwork"},
            {label: "Options", className: "table-options"}
        ], TYPES.map((kind) => typeRow(entry, kind, kind.name)), false));
    }

    function previewName(entry, kind, file) {
        const holder = make("div", "table-name-with-preview");
        const source = freshUrl(entry, kind, file);
        if (extension(file) === "mp4") {
            const video = make("video", "table-preview catalogue-video-preview");
            video.playsInline = true;
            video.preload = "metadata";
            video.src = source;
            video.tabIndex = 0;
            video.setAttribute("aria-label", t("Preview video"));
            attachMediaPreview(video, source, "video");
            video.addEventListener("loadedmetadata", () => {
                if (Number.isFinite(video.duration) && video.duration > 0) video.currentTime = Math.min(.5, video.duration / 10);
            }, {once: true});
            video.addEventListener("error", () => {
                hideMediaPreview();
                video.remove();
            });
            holder.append(video);
        } else if (VIEWABLE.includes(extension(file))) {
            const image = make("img", "table-preview");
            image.loading = "lazy";
            image.alt = "";
            image.src = source;
            image.tabIndex = 0;
            image.setAttribute("aria-label", t("Preview image"));
            attachMediaPreview(image, source);
            image.addEventListener("error", () => {
                hideMediaPreview();
                image.remove();
            });
            holder.append(image);
        }
        const name = make("span", "entry-name", file);
        name.title = file;
        holder.append(name);
        return holder;
    }

    function typeRow(entry, kind, naming) {
        const file = entry.files[kind.key];
        const editable = canManage() && placeable(entry);
        const row = make("tr");
        const nameCell = make("td", "content-name-cell", t(naming || kind.name));
        const fileCell = make("td", "content-name-cell");
        if (file) fileCell.append(previewName(entry, kind, file));
        else fileCell.textContent = "-";
        const picker = editable ? make("input") : null;
        let uploadButton = null;
        if (picker) {
            picker.type = "file";
            picker.hidden = true;
            picker.accept = ACCEPTS[kind.key] || "image/*";
            picker.addEventListener("change", () => {
                if (picker.files.length) upload(entry, kind, picker.files[0], uploadButton);
                picker.value = "";
            });
            uploadButton = action(file ? "Replace" : "Add", () => picker.click());
        }
        const actions = [
            file && download(mediaUrl("catalogue", artPath(entry, kind, file)), file.split("/").pop()),
            editable && (kind.key === "text" || kind.key === "manual")
                && action("Edit", () => editTextArtwork(entry, kind, file)),
            uploadButton,
            file && editable && extension(file) === "mp4"
                && action("Adjust", () => editVideoArtwork(entry, kind, file)),
            file && editable && VIEWABLE.includes(extension(file))
                && !["svg", "gif", "apng"].includes(extension(file))
                && action("Adjust", (button) => adjust(entry, kind, file, button)),
            file && editable && action("Remove", (button) => discard(entry, kind, file, button), true)
        ];
        const options = toolsCell(actions);
        if (picker) options.append(picker);
        row.append(nameCell, fileCell, make("td", "table-artwork", t(file ? "Added" : "Missing")), options);
        return row;
    }

    async function editTextArtwork(entry, kind, file) {
        try {
            let content = "";
            if (file) {
                const response = await fetch(mediaUrl("catalogue", artPath(entry, kind, file)), {cache: "no-store"});
                if (!response.ok) throw new Error(t("Could not read that %s", kind.name.toLowerCase()));
                content = await response.text();
            }

            MU.editTextDocument({
                title: t("Edit %s", kind.name),
                content,
                richText: kind.key === "manual",
                save: async (updated) => {
                    const name = file ? file.split("/").pop() : `${entry.stem}.txt`;
                    await api(destination(entry, kind, name), {
                        method: "POST",
                        body: new Blob([updated], {type: "text/plain;charset=utf-8"}),
                        type: "text/plain;charset=utf-8"
                    });
                    showToast(t("%s saved", kind.name), "good");
                    await refresh();
                    return true;
                }
            });
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    function artPath(entry, kind, file) {
        return `${entry.catalogue}/${kind.key}/${file}`;
    }

    function freshUrl(entry, kind, file) {
        return `${mediaUrl("catalogue", artPath(entry, kind, file))}?v=${mediaVersion}`;
    }

    function destination(entry, kind, name) {
        const has = entry.files[kind.key] || "";
        const within = has.includes("/") ? `${has.slice(0, has.lastIndexOf("/"))}/` : "";
        return `api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...`${within}${name}`.split("/"))}`;
    }

    function sidecar(file) {
        const slash = file.lastIndexOf("/");
        const within = slash >= 0 ? `${file.slice(0, slash + 1)}` : "";
        const name = file.slice(slash + 1).replace(/\.[^.]+$/, "");
        return `${within}_edit/${name}.conf`;
    }

    function catalogueEndpoint(entry, kind, leaf) {
        return `api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...leaf.split("/"))}`;
    }

    function parseSettings(text) {
        const settings = {};
        text.split(/\r?\n/).forEach((line) => {
            const match = line.match(/^([a-z_]+)=(\d+)$/);
            if (match) settings[match[1]] = Number(match[2]);
        });
        return settings;
    }

    async function editVideoArtwork(entry, kind, file) {
        const edit = sidecar(file);
        let settings = {};
        try {
            const response = await fetch(mediaUrl("catalogue", artPath(entry, kind, edit)), {cache: "no-store"});
            if (response.ok) settings = parseSettings(await response.text());
        } catch (_) {
        }
        await MU.editVideo({
            name: file.split("/").pop(),
            source: freshUrl(entry, kind, file),
            settings,
            save: async (updated) => {
                const content = Object.entries(updated).map(([key, value]) => `${key}=${value}`).join("\n") + "\n";
                await api(catalogueEndpoint(entry, kind, edit), {
                    method: "POST",
                    body: new Blob([content], {type: "text/plain;charset=utf-8"}),
                    type: "text/plain;charset=utf-8"
                });
                showToast(t("%s saved", kind.name), "good");
                return true;
            }
        });
    }

    async function animatedPng(file) {
        if (extension(file.name) !== "png") return false;
        const bytes = new Uint8Array(await file.arrayBuffer());
        for (let at = 8; at + 12 <= bytes.length;) {
            const length = (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3];
            const type = String.fromCharCode(bytes[at + 4], bytes[at + 5], bytes[at + 6], bytes[at + 7]);
            if (type === "acTL") return true;
            if (type === "IDAT" || length < 0) return false;
            at += length + 12;
        }
        return false;
    }

    async function prepare(file) {
        if (file.size > UPLOAD_LIMIT) {
            showToast(t("%s is %s, over the %s limit", file.name, bytes(file.size), bytes(UPLOAD_LIMIT)), "bad");
            return null;
        }
        const ext = extension(file.name);
        if (![...VIEWABLE, "mp4"].includes(ext) || ["svg", "gif", "apng", "mp4"].includes(ext)) return file;
        if (await animatedPng(file)) return file;
        return MU.cropImage(file);
    }

    async function upload(entry, kind, chosen, button) {
        const file = await prepare(chosen);
        if (!file) return;
        const has = entry.files[kind.key];
        const name = `${entry.stem}.${extension(file.name)}`;
        try {
            await busy(button, "", () => api(destination(entry, kind, name), {
                method: "POST", body: file, type: file.type || "application/octet-stream"
            }));
            if (has && has.split("/").pop() !== name) {
                await api(`api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...has.split("/"))}`, {method: "DELETE"});
            }
            if (kind.key === "box" || kind.key === "preview" || kind.key === "splash") {
                try {
                    await api(catalogueEndpoint(entry, kind, sidecar(has || name)), {method: "DELETE"});
                } catch (_) {
                }
            }
            showToast(t("%s saved", kind.name), "good");
            await refresh();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function adjust(entry, kind, file, button) {
        const name = file.split("/").pop();
        try {
            const response = await fetch(mediaUrl("catalogue", artPath(entry, kind, file)), {cache: "no-store"});
            if (!response.ok) throw new Error(t("Could not read that %s", kind.name.toLowerCase()));
            const blob = await response.blob();
            const edited = await MU.cropImage(new File([blob], name, {type: blob.type}));
            if (!edited) return;
            await busy(button, "", () => api(destination(entry, kind, name), {
                method: "POST", body: edited, type: edited.type || "application/octet-stream"
            }));
            showToast(t("%s adjusted", kind.name), "good");
            await refresh();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function discard(entry, kind, file, button) {
        const sure = await ask({
            title: t("Remove artwork"),
            message: t("The %s for %s will be deleted.", kind.name.toLowerCase(), entry.stem),
            confirm: t("Remove"), danger: true
        });
        if (!sure) return;
        try {
            await busy(button, "", () => api(`api/catalogue/${apiPath(entry.catalogue, ...kind.key.split("/"), ...file.split("/"))}`, {method: "DELETE"}));
            if (extension(file) === "mp4") {
                try {
                    await api(catalogueEndpoint(entry, kind, sidecar(file)), {method: "DELETE"});
                } catch (_) {
                }
            }
            showToast(t("%s removed", kind.name), "good");
            await refresh();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function refresh() {
        mediaVersion = Date.now();
        const data = await api(`api/content/${pathUrl(folder.path)}`);
        entries = data.entries || [];
        if (opened) renderItem();
        else renderContents();
    }

    async function refreshAll() {
        try {
            await busy(refreshButton, t("Refreshing..."), () => api("api/catalogue/refresh", {method: "POST"}));
            mediaVersion = Date.now();
            entries = [];
            await render(folder && folder.path, opened);
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    search.addEventListener("input", () => {
        shown = PAGE;
        renderContents();
    });
    refreshButton.addEventListener("click", refreshAll);
    onAuthChange(() => {
        if (opened) renderItem();
        else if (folder) renderContents();
    });
    register("catalogue", {
        restore,
        load: () => {
            entries = [];
            return render(folder && folder.path, opened);
        }
    });
}());
