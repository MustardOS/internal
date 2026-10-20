(function () {
    "use strict";

    const MU = window.MU;
    const {api, apiPath, ask, bytes, crumbs, el, fetchAuthed, loading, make, problem, register, setBar, showToast, sortableHead, stamp, t} = MU;
    const browser = el("files-browser");
    const body = el("files-body");
    const rootsBox = el("files-roots");
    const toolbar = el("files-toolbar");
    const search = el("files-search");
    const filePicker = el("files-file-picker");
    const folderPicker = el("files-folder-picker");
    const newButton = el("files-new");
    const uploadFilesButton = el("files-upload-files");
    const uploadFoldersButton = el("files-upload-folders");
    const drop = el("files-drop");
    const queueBox = el("files-queue-box");
    const queue = el("files-queue");
    const selectionBox = el("files-selection");
    const selectAll = el("files-select-all");
    const selectionCount = el("files-selection-count");
    const copySelected = el("files-copy-selected");
    const moveSelected = el("files-move-selected");
    const removeSelected = el("files-remove-selected");
    const clearSelected = el("files-clear-selected");
    const textEditor = el("text-editor-box");
    const textEditorTitle = el("text-editor-title");
    const textEditorSize = el("text-editor-size");
    const textEditorContent = el("text-editor-content");
    const textEditorSave = el("text-editor-save");
    const textEditorCancel = el("text-editor-cancel");
    const richTextTools = el("text-editor-rich-tools");
    const richTextColour = el("text-editor-rich-colour");
    const sortStorageKey = "muos.files.sort";
    const systemWarningKey = "muos.files.system-warning";
    const textExtensions = new Set([
        "txt", "text", "md", "markdown", "rst", "adoc", "nfo", "info", "log", "out",
        "conf", "config", "cfg", "ini", "toml", "env", "properties", "profile", "rc", "desktop",
        "service", "socket", "target", "timer", "mount", "automount", "path", "rules", "network", "netdev", "link",
        "json", "jsonc", "json5", "xml", "xhtml", "xsl", "xslt", "svg", "yaml", "yml", "csv", "tsv", "sql",
        "html", "htm", "css", "scss", "sass", "less", "js", "mjs", "cjs", "jsx", "ts", "tsx", "webmanifest",
        "sh", "bash", "zsh", "fish", "lua", "py", "rb", "php", "pl", "pm", "tcl", "awk", "sed",
        "c", "h", "cc", "hh", "cpp", "hpp", "cxx", "hxx", "inc", "asm", "s", "ld", "dts", "dtsi", "def",
        "java", "kt", "kts", "groovy", "gradle", "go", "rs", "mk", "mak", "cmake", "meson", "ninja", "kconfig",
        "diff", "patch", "spec", "manifest", "list", "map", "url", "gitignore", "gitattributes", "editorconfig",
        "sha256", "sha1", "md5", "asc", "m3u", "m3u8", "pls", "xspf", "wpl", "asx", "cue", "gdi", "toc",
        "srt", "ass", "ssa", "vtt", "ttml", "lrc", "smi", "rss", "atom", "lpl", "cht"
    ]);
    const textNames = new Set([
        "makefile", "dockerfile", "containerfile", "cmakelists.txt", "meson.build", "kconfig", "config.in",
        "readme", "license", "copying", "authors", "changelog", "fstab", "hosts", "hostname", "interfaces", "issue"
    ]);
    const imageExtensions = new Set(["png", "jpg", "jpeg", "jpe", "jfif", "pjpeg", "pjp", "webp"]);
    const textLimit = 4 * 1024 * 1024;
    const imageLimit = 32 * 1024 * 1024;
    let roots = [];
    let current = null;
    let path = "";
    let items = [];
    let uploading = false;
    let sortColumn = "name";
    let sortDescending = false;
    let crumbsFor = null;
    let textTarget = null;
    const selected = new Set();
    const collator = new Intl.Collator(undefined, {numeric: true, sensitivity: "base"});

    try {
        const saved = localStorage.getItem(sortStorageKey);
        if (saved && saved[0] === "{") {
            const state = JSON.parse(saved);
            if (["name", "size", "date"].includes(state.column)) sortColumn = state.column;
            sortDescending = Boolean(state.descending);
        } else if (saved === "recent") {
            sortColumn = "date";
            sortDescending = true;
        } else if (saved === "size") {
            sortColumn = "size";
            sortDescending = true;
        }
    } catch (_) {
    }

    function setSort(column, descending) {
        sortColumn = column;
        sortDescending = descending;
        try {
            localStorage.setItem(sortStorageKey, JSON.stringify({column, descending}));
        } catch (_) {
        }
        render();
    }

    function encoded(value) {
        return String(value || "").split("/").filter(Boolean).map(encodeURIComponent).join("/");
    }

    function endpoint(action, value = path) {
        const suffix = encoded(value);
        return `api/files/${encodeURIComponent(current.id)}/${action}${suffix ? `/${suffix}` : ""}`;
    }

    function join(parent, name) {
        return parent ? `${parent}/${name}` : name;
    }

    function parentOf(value) {
        const at = value.lastIndexOf("/");
        return at < 0 ? "" : value.slice(0, at);
    }

    function protectedHeaders() {
        return current && current.protected ? {"X-muOS-System-Write": "confirm"} : {};
    }

    async function confirmProtected() {
        if (!current || !current.protected) return true;
        try {
            if (localStorage.getItem(systemWarningKey) === "off") return true;
        } catch (_) {
        }
        const answer = await ask({
            title: t("Modify system files"),
            message: t("Changes here can stop MustardOS from starting or working correctly."),
            confirm: t("Continue"),
            alternate: t("Don't Remind Me")
        });
        if (answer === "alternate") {
            try {
                localStorage.setItem(systemWarningKey, "off");
            } catch (_) {
            }
            return true;
        }
        return Boolean(answer);
    }

    async function responseError(response) {
        let message = t("Request failed (%s)", response.status);
        try {
            const payload = await response.json();
            if (payload && payload.error) message = t(payload.error);
        } catch (_) {
        }
        return new Error(message);
    }

    function paintCrumbs() {
        const state = current ? `${current.id}/${path}` : "";
        if (state === crumbsFor) return;
        crumbsFor = state;
        if (!current) {
            el("files-crumbs").replaceChildren();
            return;
        }
        const trail = [{label: t("File Management"), glyph: "home", go: () => openRoot(null)}];
        if (current) {
            trail.push({label: t(current.label), go: path ? () => openFolder("") : null});
            const parts = path.split("/").filter(Boolean);
            parts.forEach((part, index) => {
                const value = parts.slice(0, index + 1).join("/");
                trail.push({label: part, go: index < parts.length - 1 ? () => openFolder(value) : null});
            });
        }
        crumbs(el("files-crumbs"), trail);
    }

    function paintRoots() {
        if (current) {
            rootsBox.replaceChildren();
            rootsBox.hidden = true;
            return;
        }
        rootsBox.hidden = false;
        const rootGrid = (entries, compact) => {
            const grid = make("div", compact ? "file-root-grid file-root-grid-system" : "file-root-grid");
            entries.forEach((root) => {
                const button = make("button", "file-root", t(root.label));
                button.type = "button";
                button.append(make("span", "file-root-path", root.path));
                button.addEventListener("click", () => openRoot(root));
                grid.append(button);
            });
            return grid;
        };
        const storage = roots.filter((root) => !root.protected);
        const system = roots.filter((root) => root.protected);
        const sections = make("div", "file-root-sections");
        const library = make("section", "file-root-group file-root-library box");
        const libraryGrid = make("div", "file-root-grid file-root-grid-library");
        [["History", "history"], ["Collections", "collections"], ["Pickles Saves", "pickles"],
            ["Catalogue", "catalogue"]].forEach(([label, view]) => {
            const button = make("button", "file-root", t(label));
            button.type = "button";
            button.addEventListener("click", () => MU.show(view));
            libraryGrid.append(button);
        });
        library.append(make("h3", "file-root-title", t("Library")), libraryGrid);
        sections.append(library);
        if (storage.length) {
            const group = make("section", "file-root-group box");
            group.append(make("h3", "file-root-title", t("User Storage")), rootGrid(storage, false));
            sections.append(group);
        }
        if (system.length) {
            const group = make("section", "file-root-group file-root-system box");
            group.append(make("h3", "file-root-title", t("System Storage")), rootGrid(system, true));
            sections.append(group);
        }
        if (!roots.length) sections.append(make("p", "note", t("No storage is mounted.")));
        rootsBox.replaceChildren(sections);
    }

    function paintSpace(payload) {
        const box = el("files-space");
        const space = payload && payload.space;
        const total = Number(space && space.total) || 0;
        box.hidden = !current || !total;
        if (!total) return;
        const free = Math.max(0, Number(space.free) || 0);
        const percent = Math.round(((total - free) / total) * 100);
        el("files-space-free").textContent = t("%s free", bytes(free));
        setBar(el("files-space-fill"), percent, percent >= 90);
    }

    function action(label, handler, danger) {
        const glyphs = {"Edit Text": "text", "Edit Image": "sliders", Rename: "edit", Move: "move", Copy: "copy", Remove: "trash"};
        const text = t(label);
        const button = make("button", `link file-action${danger ? " danger" : ""}`);
        button.type = "button";
        button.dataset.glyph = glyphs[label];
        button.dataset.tooltip = text;
        button.title = text;
        button.setAttribute("aria-label", text);
        button.addEventListener("click", () => handler(button));
        return button;
    }

    function extension(name) {
        const dot = String(name || "").lastIndexOf(".");
        return dot < 0 ? "" : name.slice(dot + 1).toLocaleLowerCase();
    }

    function editableType(item) {
        if (item.directory || item.link) return null;
        const kind = extension(item.name);
        const name = String(item.name || "").toLocaleLowerCase();
        if ((textExtensions.has(kind) || textNames.has(name)) && item.bytes <= textLimit) return "text";
        if (imageExtensions.has(kind) && item.bytes <= imageLimit) return "image";
        return null;
    }

    function shownItems() {
        const needle = search.value.trim().toLocaleLowerCase();
        const matches = items.filter((item) => item.name.toLocaleLowerCase().includes(needle));
        const compare = (left, right) => {
            let result;
            if (sortColumn === "size") result = (left.bytes || 0) - (right.bytes || 0);
            else if (sortColumn === "date") result = (left.modified || 0) - (right.modified || 0);
            else result = collator.compare(left.name, right.name);
            if (!result) result = collator.compare(left.name, right.name);
            return sortDescending ? -result : result;
        };
        return [...matches.filter((item) => item.directory).sort(compare),
            ...matches.filter((item) => !item.directory).sort(compare)];
    }

    function selectedItems() {
        return items.filter((item) => selected.has(item.name));
    }

    function paintSelection(shown, manageable) {
        const names = new Set(items.map((item) => item.name));
        selected.forEach((name) => {
            if (!names.has(name)) selected.delete(name);
        });

        selectionBox.hidden = !manageable || !items.length;
        if (selectionBox.hidden) return;

        const visibleSelected = shown.filter((item) => selected.has(item.name)).length;
        selectAll.disabled = !shown.length;
        selectAll.checked = Boolean(shown.length && visibleSelected === shown.length);
        selectAll.indeterminate = visibleSelected > 0 && visibleSelected < shown.length;
        selectionCount.textContent = t("%s selected", selected.size);

        const chosen = selectedItems();
        copySelected.disabled = !chosen.length || chosen.some((item) => item.link);
        moveSelected.disabled = !chosen.length;
        removeSelected.disabled = !chosen.length;
        clearSelected.disabled = !chosen.length;
    }

    function render() {
        browser.classList.toggle("box", Boolean(current));
        toolbar.hidden = !current;
        paintCrumbs();
        paintRoots();
        const manageable = current && MU.canManage() && !uploading;
        newButton.hidden = !manageable;
        uploadFilesButton.hidden = !manageable;
        uploadFoldersButton.hidden = !manageable;
        search.hidden = !current;
        drop.hidden = true;
        if (!current) {
            selectionBox.hidden = true;
            body.replaceChildren();
            paintSpace(null);
            return;
        }

        const needle = search.value.trim().toLocaleLowerCase();
        const shown = shownItems();
        paintSelection(shown, manageable);
        if (!shown.length) {
            body.replaceChildren(make("p", "note file-empty", t(needle ? "Nothing matches that search." : "This folder is empty.")));
            return;
        }

        const table = make("table", "data-table browser-table file-table");
        const head = make("thead");
        head.append(sortableHead([
            {label: "", className: "table-select"},
            {key: "name", label: "Name"},
            {key: "size", label: "Size", descending: true, className: "table-size"},
            {key: "date", label: "Date", descending: true, className: "table-date"},
            {label: "Options", className: "table-options"}
        ], sortColumn, sortDescending, setSort));
        const tableBody = make("tbody");
        shown.forEach((item) => {
            const relative = join(path, item.name);
            const row = make("tr", "file-entry");
            let selector = null;
            if (manageable) {
                row.classList.add("file-entry-selectable");
                selector = make("input", "file-select");
                selector.type = "checkbox";
                selector.checked = selected.has(item.name);
                selector.setAttribute("aria-label", t("Select %s", item.name));
                selector.addEventListener("change", () => {
                    if (selector.checked) selected.add(item.name);
                    else selected.delete(item.name);
                    paintSelection(shown, true);
                });
            }
            const name = item.directory ? make("button", "entry-name file-name", item.name) : make("span", "entry-name file-name", item.name);
            name.title = item.name;
            if (item.directory) {
                name.type = "button";
                name.addEventListener("click", () => openFolder(relative));
            }

            const tools = make("div", "entry-actions");
            const editable = manageable && editableType(item);
            if (editable === "text") tools.append(action("Edit Text", () => editText(item, relative)));
            else if (editable === "image") tools.append(action("Edit Image", () => editImage(item, relative)));
            if (!item.directory && !item.link) {
                const text = t("Download");
                const download = make("a", "link file-action");
                download.dataset.glyph = "download";
                download.dataset.tooltip = text;
                download.title = text;
                download.setAttribute("aria-label", text);
                download.href = endpoint("download", relative);
                download.download = item.name;
                tools.append(download);
            }
            if (manageable) {
                tools.append(
                    action("Rename", () => renameItem(item, relative)),
                    action("Move", () => moveItem(item, relative)),
                    ...(!item.link ? [action("Copy", () => copyItem(item, relative))] : []),
                    action("Remove", () => removeItem(item, relative), true)
                );
            }
            const selectCell = make("td", "table-select");
            if (selector) selectCell.append(selector);
            const nameCell = make("td", "file-name-cell");
            nameCell.append(name);
            const size = item.directory ? t("Folder") : item.link ? t("Link") : bytes(item.bytes);
            const sizeCell = make("td", "number table-size", size);
            const dateCell = make("td", "number table-date", stamp(item.modified));
            const toolsCell = make("td", "table-options");
            toolsCell.append(tools);
            row.append(selectCell, nameCell, sizeCell, dateCell, toolsCell);
            tableBody.append(row);
        });
        table.append(head, tableBody);
        const scroll = make("div", "table-scroll");
        scroll.append(table);
        body.replaceChildren(scroll);
    }

    function updateTextSize() {
        textEditorSize.textContent = bytes(new TextEncoder().encode(textEditorContent.value).length);
    }

    function closeTextEditor() {
        if (textEditor.hidden) return;
        textEditor.hidden = true;
        textTarget = null;
        textEditorContent.value = "";
        richTextTools.hidden = true;
    }

    function openTextEditor({title, content, save, richText = false}) {
        textTarget = {save};
        textEditorTitle.textContent = title;
        textEditorContent.value = content;
        richTextTools.hidden = !richText;
        richTextColour.value = "";
        updateTextSize();
        textEditor.hidden = false;
        textEditorContent.focus();
    }

    function insertRichCode(code) {
        const begin = textEditorContent.selectionStart;
        const finish = textEditorContent.selectionEnd;
        const value = textEditorContent.value;
        const prefix = `§${code}`;
        const suffix = finish > begin && code !== "r" ? "§r" : "";
        textEditorContent.setRangeText(`${prefix}${value.slice(begin, finish)}${suffix}`, begin, finish, "end");
        textEditorContent.focus();
        updateTextSize();
    }

    async function editText(item, relative) {
        try {
            const response = await fetchAuthed(endpoint("download", relative), {cache: "no-store"});
            if (!response.ok) throw await responseError(response);
            const content = await response.text();
            openTextEditor({
                title: t("Edit %s", item.name),
                content,
                save: async (updated) => {
                    if (!await confirmProtected()) return false;
                    const saved = await fetchAuthed(endpoint("upload", relative), {
                        method: "PUT",
                        body: new Blob([updated], {type: "text/plain;charset=utf-8"}),
                        headers: protectedHeaders()
                    });
                    if (!saved.ok) throw await responseError(saved);
                    showToast("File saved", "good");
                    await openFolder(path);
                    return true;
                }
            });
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function saveText() {
        if (!textTarget) return;
        const target = textTarget;
        const content = textEditorContent.value;
        const size = new TextEncoder().encode(content).length;
        if (size > textLimit) {
            showToast(t("Text files must be %s or smaller.", bytes(textLimit)), "bad");
            return;
        }

        textEditorSave.disabled = true;
        try {
            if (await target.save(content) !== false) closeTextEditor();
        } catch (error) {
            showToast(error.message, "bad");
        } finally {
            textEditorSave.disabled = false;
        }
    }

    async function editImage(item, relative) {
        try {
            const response = await fetchAuthed(endpoint("download", relative), {cache: "no-store"});
            if (!response.ok) throw await responseError(response);
            const blob = await response.blob();
            const edited = await MU.cropImage(new File([blob], item.name, {type: blob.type}));
            if (!edited || !await confirmProtected()) return;
            const saved = await fetchAuthed(endpoint("upload", relative), {
                method: "PUT", body: edited, headers: protectedHeaders()
            });
            if (!saved.ok) throw await responseError(saved);
            showToast("Image saved", "good");
            await openFolder(path);
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function loadRoots() {
        body.replaceChildren(loading("Reading storage..."));
        try {
            roots = (await api("api/files")).roots || [];
            if (current) {
                const fresh = roots.find((root) => root.id === current.id);
                if (!fresh) current = null;
                else current = fresh;
            }
            render();
        } catch (error) {
            body.replaceChildren(problem(error.message, loadRoots));
        }
    }

    async function openRoot(root) {
        current = root;
        path = "";
        items = [];
        selected.clear();
        search.value = "";
        MU.navigate(root ? root.id : null);
        if (root) await openFolder("");
        else render();
    }

    async function openFolder(value) {
        if (!current) return;
        if (value !== path) selected.clear();
        path = value;
        body.replaceChildren(loading("Reading folder..."));
        paintCrumbs();
        try {
            const payload = await api(endpoint("browse"));
            items = payload.items || [];
            paintSpace(payload);
            render();
        } catch (error) {
            body.replaceChildren(problem(error.message, () => openFolder(value)));
        }
    }

    async function createFolder() {
        if (!await confirmProtected()) return;
        const name = await ask({
            title: t("New folder"),
            confirm: t("Create"),
            input: {value: "", placeholder: t("Folder name")}
        });
        if (!name || !name.trim() || name.includes("/")) return;
        try {
            await api(endpoint("mkdir", join(path, name.trim())), {method: "POST", headers: protectedHeaders()});
            showToast("Folder created", "good");
            await openFolder(path);
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function changePath(actionName, item, relative, initial, title, done) {
        if (!await confirmProtected()) return;
        const destination = await ask({
            title: t(title),
            message: actionName === "move" || actionName === "copy" ? t("Enter a path relative to %s.", current.label) : "",
            confirm: t(title),
            input: {value: initial}
        });
        if (!destination || destination === relative) return;
        try {
            await api(endpoint(actionName, relative), {
                method: "POST", body: destination, type: "text/plain", headers: protectedHeaders()
            });
            showToast(done, "good");
            await openFolder(path);
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    function renameItem(item, relative) {
        const base = parentOf(relative);
        return changePath("move", item, relative, join(base, item.name), "Rename", "Renamed");
    }

    function moveItem(item, relative) {
        return changePath("move", item, relative, relative, "Move", "Moved");
    }

    function copyItem(item, relative) {
        return changePath("copy", item, relative, `${relative} copy`, "Copy", "Copied");
    }

    async function removeItem(item, relative) {
        if (!await confirmProtected()) return;
        const sure = await ask({
            title: t("Remove %s", item.name),
            message: item.directory ? t("This folder and everything inside it will be permanently removed.") : t("This file will be permanently removed."),
            confirm: t("Remove"),
            danger: true
        });
        if (!sure) return;
        try {
            await api(endpoint("remove", relative), {method: "DELETE", headers: protectedHeaders()});
            showToast("Removed", "good");
            await openFolder(path);
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    async function finishBulk(work, done) {
        let failure = null;
        for (const operation of work) {
            try {
                await operation();
            } catch (error) {
                if (!failure) failure = error;
            }
        }
        const currentPath = path;
        selected.clear();
        await openFolder(currentPath);
        if (failure) showToast(failure.message, "bad");
        else showToast(done, "good");
    }

    async function transferSelected(actionName) {
        const chosen = selectedItems();
        if (!chosen.length || !await confirmProtected()) return;
        if (actionName === "copy" && chosen.some((item) => item.link)) return;

        const destination = await ask({
            title: t(actionName === "copy" ? "Copy" : "Move"),
            message: t("Enter a path relative to %s.", current.label),
            confirm: t(actionName === "copy" ? "Copy" : "Move"),
            input: {value: path, placeholder: t("Destination folder")}
        });
        if (destination === null) return;
        const targetFolder = destination.trim().replace(/^\/+|\/+$/g, "");
        if (targetFolder === path) {
            showToast(t("Choose another folder."), "bad");
            return;
        }

        const sourceFolder = path;
        await finishBulk(chosen.map((item) => () => api(endpoint(actionName, join(sourceFolder, item.name)), {
            method: "POST",
            body: join(targetFolder, item.name),
            type: "text/plain",
            headers: protectedHeaders()
        })), actionName === "copy" ? "Copied" : "Moved");
    }

    async function removeSelectedItems() {
        const chosen = selectedItems();
        if (!chosen.length || !await confirmProtected()) return;
        const sure = await ask({
            title: t("Remove %s items", chosen.length),
            message: t("Selected items will be permanently removed."),
            confirm: t("Remove"),
            danger: true
        });
        if (!sure) return;

        const sourceFolder = path;
        await finishBulk(chosen.map((item) => () => api(endpoint("remove", join(sourceFolder, item.name)), {
            method: "DELETE", headers: protectedHeaders()
        })), "Removed");
    }

    function transferRow(file, label) {
        const row = make("div", "file-transfer");
        const heading = make("div", "meter-head");
        heading.append(make("b", null, label), make("span", null, bytes(file.size)));
        const bar = make("div", "bar");
        bar.append(make("span"));
        row.append(heading, bar, make("p", "meter-foot", t("Waiting...")));
        queue.append(row);
        queueBox.hidden = false;
        return row;
    }

    function uploadPath(file) {
        return file.webkitRelativePath || file.name;
    }

    async function ensureUploadFolders(files) {
        const folders = new Set();
        files.forEach((file) => {
            const parts = uploadPath(file).split("/");
            parts.pop();
            while (parts.length) {
                folders.add(parts.join("/"));
                parts.pop();
            }
        });

        const ordered = [...folders].sort((left, right) => {
            const depth = left.split("/").length - right.split("/").length;
            return depth || left.localeCompare(right);
        });
        for (const folder of ordered) {
            const response = await fetchAuthed(endpoint("mkdir", join(path, folder)), {
                method: "POST", headers: protectedHeaders()
            });
            if (!response.ok && response.status !== 409) throw await responseError(response);
        }
    }

    async function upload(files) {
        if (!current || uploading || !files.length || !await confirmProtected()) return;
        uploading = true;
        render();
        queue.replaceChildren();
        let completed = 0;
        try {
            await ensureUploadFolders(files);
        } catch (error) {
            uploading = false;
            render();
            showToast(error.message, "bad");
            return;
        }
        for (const file of files) {
            const relative = uploadPath(file);
            const row = transferRow(file, relative);
            const note = row.querySelector(".meter-foot");
            const fill = row.querySelector(".bar span");
            note.textContent = t("Uploading...");
            fill.classList.add("file-transfer-active");
            try {
                const response = await fetchAuthed(endpoint("upload", join(path, relative)), {
                    method: "PUT", body: file, headers: protectedHeaders()
                });
                if (!response.ok) throw await responseError(response);
                fill.classList.remove("file-transfer-active");
                fill.style.width = "100%";
                note.textContent = t("Complete");
                completed += 1;
            } catch (error) {
                fill.classList.remove("file-transfer-active");
                fill.classList.add("warn");
                note.textContent = error.message;
            }
        }
        uploading = false;
        render();
        if (completed) {
            showToast(t(completed === 1 ? "File uploaded" : "%s files uploaded", completed), "good");
            await openFolder(path);
        }
    }

    newButton.addEventListener("click", createFolder);
    uploadFilesButton.addEventListener("click", () => filePicker.click());
    uploadFoldersButton.addEventListener("click", () => folderPicker.click());
    filePicker.addEventListener("change", () => {
        upload([...filePicker.files]);
        filePicker.value = "";
    });
    folderPicker.addEventListener("change", () => {
        upload([...folderPicker.files]);
        folderPicker.value = "";
    });
    textEditorContent.addEventListener("input", updateTextSize);
    textEditorContent.addEventListener("keydown", (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLocaleLowerCase() === "s") {
            event.preventDefault();
            saveText();
        }
    });
    textEditorSave.addEventListener("click", saveText);
    textEditorCancel.addEventListener("click", closeTextEditor);
    richTextTools.querySelectorAll("[data-rich-code]").forEach((button) => {
        button.addEventListener("click", () => insertRichCode(button.dataset.richCode));
    });
    richTextColour.addEventListener("change", () => {
        if (richTextColour.value) insertRichCode(richTextColour.value);
        richTextColour.value = "";
    });
    MU.onDismiss(closeTextEditor);
    MU.editTextDocument = openTextEditor;
    search.addEventListener("input", render);
    selectAll.addEventListener("change", () => {
        shownItems().forEach((item) => {
            if (selectAll.checked) selected.add(item.name);
            else selected.delete(item.name);
        });
        render();
    });
    copySelected.addEventListener("click", () => transferSelected("copy"));
    moveSelected.addEventListener("click", () => transferSelected("move"));
    removeSelected.addEventListener("click", removeSelectedItems);
    clearSelected.addEventListener("click", () => {
        selected.clear();
        render();
    });
    ["dragenter", "dragover"].forEach((name) => document.addEventListener(name, (event) => {
        if (!current || !MU.canManage()) return;
        event.preventDefault();
        drop.hidden = false;
    }));
    ["dragleave", "drop"].forEach((name) => document.addEventListener(name, (event) => {
        if (!current) return;
        event.preventDefault();
        drop.hidden = true;
    }));
    document.addEventListener("drop", (event) => upload([...event.dataTransfer.files]));
    MU.onAuthChange(() => {
        if (!MU.canManage()) selected.clear();
        render();
    });

    register("files", {
        load: loadRoots,
        restore: async (where) => {
            await loadRoots();
            if (where) {
                const root = roots.find((entry) => entry.id === where);
                if (root) await openRoot(root);
            }
        }
    });
}());
