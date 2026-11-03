(function () {
    "use strict";

    const MU = window.MU;
    const {api, apiPath, ask, bytes, crumbs, el, fetchAuthed, holdFocus, loading, make, problem, register, setBar, showToast, sortableHead, stamp, t, uploadAuthed} = MU;
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
    const downloadSelected = el("files-download-selected");
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
    const richTextPreviewPane = el("text-editor-rich-preview-pane");
    const richTextPreview = el("text-editor-rich-preview");
    const imagePreview = el("file-image-preview-box");
    const imagePreviewTitle = el("file-image-preview-title");
    const imagePreviewImage = el("file-image-preview-image");
    const imagePreviewClose = el("file-image-preview-close");
    const modeBox = el("file-mode-box");
    const modeForm = el("file-mode-form");
    const modeTitle = el("file-mode-title");
    const modePath = el("file-mode-path");
    const modeValue = el("file-mode-value");
    const modeSave = el("file-mode-save");
    const modeCancel = el("file-mode-cancel");
    const modeChecks = [...modeForm.querySelectorAll("[data-mode-bit]")];
    const actionMenu = make("div", "file-action-menu");
    actionMenu.hidden = true;
    actionMenu.setAttribute("role", "menu");
    document.body.append(actionMenu);
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
    const imageExtensions = new Set(["png", "apng", "jpg", "jpeg", "jpe", "jfif", "pjpeg", "pjp", "webp", "gif", "bmp", "avif"]);
    const editableImageExtensions = new Set(["png", "jpg", "jpeg", "jpe", "jfif", "pjpeg", "pjp", "webp"]);
    const textLimit = 4 * 1024 * 1024;
    const imageLimit = 32 * 1024 * 1024;
    let roots = [];
    let current = null;
    let path = "";
    let items = [];
    let sortColumn = "name";
    let sortDescending = false;
    let crumbsFor = null;
    let textTarget = null;
    let imagePreviewUrl = "";
    let modeTarget = null;
    let actionMenuOwner = null;
    let uploadQueue = Promise.resolve();
    const selected = new Set();
    const uploadRelativePaths = new WeakMap();
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

    function endpointFor(root, action, value = "") {
        const suffix = encoded(value);
        return `api/files/${encodeURIComponent(root)}/${action}${suffix ? `/${suffix}` : ""}`;
    }

    function endpoint(action, value = path) {
        return endpointFor(current.id, action, value);
    }

    function join(parent, name) {
        return parent ? `${parent}/${name}` : name;
    }

    function parentOf(value) {
        const at = value.lastIndexOf("/");
        return at < 0 ? "" : value.slice(0, at);
    }

    function transferTarget() {
        return current ? {
            root: current.id,
            label: current.label,
            protected: Boolean(current.protected),
            path,
            items: [...items]
        } : null;
    }

    function protectedHeaders(target = current) {
        return target && target.protected ? {"X-muOS-System-Write": "confirm"} : {};
    }

    async function confirmProtected(target = current) {
        if (!target || !target.protected) return true;
        try {
            if (localStorage.getItem(systemWarningKey) === "off") return true;
        } catch (_) {
        }
        const answer = await ask({
            title: t("Modify system files"),
            message: t("Changes here can stop MustardOS from starting or working correctly."),
            confirm: t("Continue"),
            alternate: t("Do Not Remind Me")
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

    const actionGlyphs = {
        "Edit Text": "text", "Edit Image": "sliders", "Preview Text": "text", "Preview Image": "text",
        "More Options": "more", Permissions: "lock", Rename: "edit", Move: "move", Copy: "copy", Remove: "trash"
    };

    function action(label, handler, danger) {
        const text = t(label);
        const button = make("button", `link file-action${danger ? " danger" : ""}`);
        button.type = "button";
        button.dataset.glyph = actionGlyphs[label];
        button.dataset.tooltip = text;
        button.title = text;
        button.setAttribute("aria-label", text);
        button.addEventListener("click", () => handler(button));
        return button;
    }

    function closeActionMenu(restoreFocus = false) {
        if (!actionMenuOwner) return;
        const owner = actionMenuOwner;
        actionMenuOwner = null;
        actionMenu.hidden = true;
        actionMenu.replaceChildren();
        owner.setAttribute("aria-expanded", "false");
        if (restoreFocus && owner.isConnected) owner.focus();
    }

    function openActionMenu(owner, entries) {
        if (actionMenuOwner === owner) {
            closeActionMenu(true);
            return;
        }
        closeActionMenu();
        actionMenuOwner = owner;
        owner.setAttribute("aria-expanded", "true");
        owner.setAttribute("aria-haspopup", "menu");

        actionMenu.replaceChildren(...entries.map((entry) => {
            const button = make("button", `link file-menu-item${entry.danger ? " danger" : ""}`, t(entry.label));
            button.type = "button";
            button.dataset.glyph = actionGlyphs[entry.label];
            button.setAttribute("role", "menuitem");
            button.addEventListener("click", (event) => {
                event.stopPropagation();
                closeActionMenu();
                entry.handler();
            });
            return button;
        }));

        actionMenu.hidden = false;
        const anchor = owner.getBoundingClientRect();
        const menu = actionMenu.getBoundingClientRect();
        const left = Math.max(8, Math.min(window.innerWidth - menu.width - 8, anchor.right - menu.width));
        let top = anchor.bottom + 4;
        if (top + menu.height > window.innerHeight - 8) top = Math.max(8, anchor.top - menu.height - 4);
        actionMenu.style.left = `${Math.round(left)}px`;
        actionMenu.style.top = `${Math.round(top)}px`;
        const first = actionMenu.querySelector("button");
        if (first) first.focus();
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
        if (imageExtensions.has(kind) && item.bytes <= imageLimit)
            return editableImageExtensions.has(kind) ? "image" : "image-preview";
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
        downloadSelected.hidden = chosen.length < 2;
        downloadSelected.disabled = chosen.length < 2 || chosen.some((item) => item.link);
        copySelected.disabled = !chosen.length || chosen.some((item) => item.link);
        moveSelected.disabled = !chosen.length;
        removeSelected.disabled = !chosen.length;
        clearSelected.disabled = !chosen.length;
    }

    function render() {
        closeActionMenu();
        browser.classList.toggle("box", Boolean(current));
        toolbar.hidden = !current;
        paintCrumbs();
        paintRoots();
        const manageable = current && MU.canManage();
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

            const tools = make("div", "entry-actions file-entry-actions");
            const toolSlots = new Array(3).fill(null);
            const editable = editableType(item);
            if (editable === "text") {
                toolSlots[0] = action(manageable ? "Edit Text" : "Preview Text",
                    () => openText(item, relative, manageable));
            } else if (editable === "image" || editable === "image-preview") {
                const canEditImage = manageable && editable === "image";
                toolSlots[0] = action(canEditImage ? "Edit Image" : "Preview Image",
                    () => openImage(item, relative, canEditImage));
            }
            if (!item.link) {
                const text = t("Download");
                const download = make("a", "link file-action");
                download.dataset.glyph = "download";
                download.dataset.tooltip = text;
                download.title = text;
                download.setAttribute("aria-label", text);
                download.href = endpoint("download", relative);
                download.download = item.directory ? `${item.name}.zip` : item.name;
                toolSlots[1] = download;
            }
            if (manageable) {
                const menuEntries = [];
                if (current.permissions && item.permissions)
                    menuEntries.push({label: "Permissions", handler: () => openPermissions(item, relative)});
                menuEntries.push({label: "Rename", handler: () => renameItem(item, relative)});
                menuEntries.push({label: "Move", handler: () => moveItem(item, relative)});
                if (!item.link) menuEntries.push({label: "Copy", handler: () => copyItem(item, relative)});
                menuEntries.push({label: "Remove", handler: () => removeItem(item, relative), danger: true});
                toolSlots[2] = action("More Options", (button) => openActionMenu(button, menuEntries));
            }
            toolSlots.forEach((tool) => tools.append(tool || make("span", "file-action-placeholder")));
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

    function updateRichPreview() {
        richTextPreview.replaceChildren();
        const palette = ["#000", "#0000aa", "#00aa00", "#00aaaa", "#aa0000", "#aa00aa", "#ffaa00", "#aaa",
            "#555", "#5555ff", "#55ff55", "#55ffff", "#ff5555", "#ff55ff", "#ffff55", "#fff"];
        const state = {bold: false, italic: false, underline: false, strike: false, colour: ""};
        const content = textEditorContent.value;
        let text = "";
        const flush = () => {
            if (!text) return;
            const span = document.createElement("span");
            span.textContent = text;
            span.style.fontWeight = state.bold ? "700" : "";
            span.style.fontStyle = state.italic ? "italic" : "";
            span.style.textDecoration = [state.underline && "underline", state.strike && "line-through"].filter(Boolean).join(" ");
            span.style.color = state.colour;
            richTextPreview.append(span);
            text = "";
        };
        for (let at = 0; at < content.length;) {
            if (content[at] !== "§" || at + 1 >= content.length) {
                text += content[at++];
                continue;
            }
            if (content[at + 1] === "§") {
                text += "§";
                at += 2;
                continue;
            }
            const code = content[at + 1].toLowerCase();
            if (!/[0-9a-flonmr]/.test(code)) {
                text += content[at++];
                continue;
            }
            flush();
            if (/[0-9a-f]/.test(code)) state.colour = palette[parseInt(code, 16)];
            else if (code === "l") state.bold = true;
            else if (code === "o") state.italic = true;
            else if (code === "n") state.underline = true;
            else if (code === "m") state.strike = true;
            else if (code === "r") Object.assign(state, {bold: false, italic: false, underline: false, strike: false, colour: ""});
            at += 2;
        }
        flush();
        if (!richTextPreview.childNodes.length) richTextPreview.textContent = t("Formatted preview");
    }

    function closeTextEditor() {
        if (textEditor.hidden) return;
        textEditor.hidden = true;
        textTarget = null;
        textEditorContent.value = "";
        textEditorContent.readOnly = false;
        textEditorSave.hidden = false;
        textEditorCancel.textContent = t("Cancel");
        richTextTools.hidden = true;
        richTextPreviewPane.hidden = true;
        richTextPreview.replaceChildren();
    }

    function openTextEditor({title, content, save, richText = false, readOnly = false}) {
        textTarget = readOnly ? null : {save};
        textEditorTitle.textContent = title;
        textEditorContent.value = content;
        textEditorContent.readOnly = readOnly;
        textEditorSave.hidden = readOnly;
        textEditorCancel.textContent = t(readOnly ? "Close" : "Cancel");
        richTextTools.hidden = readOnly || !richText;
        richTextPreviewPane.hidden = !richText;
        richTextColour.value = "";
        updateTextSize();
        if (richText) updateRichPreview();
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
        updateRichPreview();
    }

    async function openText(item, relative, editable) {
        try {
            const response = await fetchAuthed(endpoint("download", relative), {cache: "no-store"});
            if (!response.ok) throw await responseError(response);
            const content = await response.text();
            const options = {
                title: t(editable ? "Edit %s" : "Preview %s", item.name),
                content,
                readOnly: !editable
            };
            if (editable) {
                options.save = async (updated) => {
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
                };
            }
            openTextEditor(options);
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

    function closeImagePreview() {
        if (imagePreview.hidden) return;
        imagePreview.hidden = true;
        imagePreviewImage.removeAttribute("src");
        if (imagePreviewUrl) URL.revokeObjectURL(imagePreviewUrl);
        imagePreviewUrl = "";
    }

    function selectedMode() {
        return modeChecks.reduce((value, input) => value | (input.checked ? Number(input.dataset.modeBit) : 0), 0);
    }

    function paintMode() {
        modeValue.textContent = selectedMode().toString(8).padStart(3, "0");
    }

    function closePermissions() {
        if (!modeTarget) return;
        const restore = modeTarget.restore;
        modeTarget = null;
        modeBox.hidden = true;
        restore();
    }

    async function openPermissions(item, relative) {
        if (!await confirmProtected()) return;
        const mode = Number(item.mode) & 0o777;
        modeChecks.forEach((input) => { input.checked = Boolean(mode & Number(input.dataset.modeBit)); });
        modeTitle.textContent = t("Permissions for %s", item.name);
        modePath.textContent = relative;
        modeTarget = {relative, restore: holdFocus()};
        paintMode();
        modeBox.hidden = false;
        modeChecks[0].focus();
    }

    async function savePermissions(event) {
        event.preventDefault();
        if (!modeTarget) return;
        const relative = modeTarget.relative;
        const mode = selectedMode().toString(8).padStart(3, "0");
        modeSave.disabled = true;
        try {
            await api(endpoint("chmod", relative), {
                method: "POST", body: mode, type: "text/plain", headers: protectedHeaders()
            });
            closePermissions();
            showToast("Permissions changed", "good");
            await openFolder(path);
        } catch (error) {
            showToast(error.message, "bad");
        } finally {
            modeSave.disabled = false;
        }
    }

    async function openImage(item, relative, editable) {
        try {
            const response = await fetchAuthed(endpoint("download", relative), {cache: "no-store"});
            if (!response.ok) throw await responseError(response);
            const blob = await response.blob();
            if (!editable) {
                closeImagePreview();
                imagePreviewTitle.textContent = t("Preview %s", item.name);
                imagePreviewUrl = URL.createObjectURL(blob);
                imagePreviewImage.src = imagePreviewUrl;
                imagePreviewImage.alt = item.name;
                imagePreview.hidden = false;
                imagePreviewClose.focus();
                return;
            }
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
            current.permissions = Boolean(payload.permissions);
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
        const target = transferTarget();
        if (!target || !await confirmProtected(target)) return;
        const destination = await ask({
            title: t(title),
            message: actionName === "move" || actionName === "copy" ? t("Enter a path relative to %s.", target.label) : "",
            confirm: t(title),
            input: {value: initial}
        });
        if (!destination || destination === relative) return;
        const row = transferRow(item, item.name, title);
        const note = row.querySelector(".meter-foot");
        const fill = row.querySelector(".bar span");
        note.textContent = t("%s to %s", title, destination);
        fill.classList.add("file-transfer-active");
        try {
            await api(endpointFor(target.root, actionName, relative), {
                method: "POST", body: destination, type: "text/plain", headers: protectedHeaders(target)
            });
            completeTransfer(row, done);
            showToast(done, "good");
            await refreshVisibleRoot(target.root);
        } catch (error) {
            failTransfer(row, error);
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
        const target = transferTarget();
        if (!target || !chosen.length || !await confirmProtected(target)) return;
        if (actionName === "copy" && chosen.some((item) => item.link)) return;

        const destination = await ask({
            title: t(actionName === "copy" ? "Copy" : "Move"),
            message: t("Enter a path relative to %s.", target.label),
            confirm: t(actionName === "copy" ? "Copy" : "Move"),
            input: {value: target.path, placeholder: t("Destination folder")}
        });
        if (destination === null) return;
        const targetFolder = destination.trim().replace(/^\/+|\/+$/g, "");
        if (targetFolder === target.path) {
            showToast(t("Choose another folder."), "bad");
            return;
        }

        selected.clear();
        render();
        let failure = null;
        for (const item of chosen) {
            const row = transferRow(item, item.name, actionName === "copy" ? "Copy" : "Move");
            const note = row.querySelector(".meter-foot");
            const fill = row.querySelector(".bar span");
            note.textContent = t("%s to %s", actionName === "copy" ? "Copying" : "Moving", targetFolder);
            fill.classList.add("file-transfer-active");
            try {
                await api(endpointFor(target.root, actionName, join(target.path, item.name)), {
                    method: "POST",
                    body: join(targetFolder, item.name),
                    type: "text/plain",
                    headers: protectedHeaders(target)
                });
                completeTransfer(row, actionName === "copy" ? "Copied" : "Moved");
            } catch (error) {
                if (!failure) failure = error;
                failTransfer(row, error);
            }
        }
        await refreshVisibleRoot(target.root);
        if (failure) showToast(failure.message, "bad");
        else showToast(actionName === "copy" ? "Copied" : "Moved", "good");
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

    function trimTransferHistory() {
        const completed = [...queue.querySelectorAll(".file-transfer-complete")];
        completed.slice(5).forEach((row) => row.remove());
        if (!queue.childElementCount) queueBox.hidden = true;
    }

    function expireTransfer(row) {
        window.clearTimeout(row._muosExpiry);
        row._muosExpiry = window.setTimeout(() => {
            row.classList.add("file-transfer-expiring");
            window.setTimeout(() => {
                row.remove();
                if (!queue.childElementCount) queueBox.hidden = true;
            }, 850);
        }, 9000);
    }

    function completeTransfer(row, message = "Complete") {
        const fill = row.querySelector(".bar span");
        fill.classList.remove("file-transfer-active", "warn");
        fill.style.width = "100%";
        row.querySelector(".meter-foot").textContent = t(message);
        row.classList.add("file-transfer-complete");
        trimTransferHistory();
        expireTransfer(row);
    }

    function failTransfer(row, error) {
        const fill = row.querySelector(".bar span");
        fill.classList.remove("file-transfer-active");
        fill.classList.add("warn");
        row.querySelector(".meter-foot").textContent = error.message;
        row.classList.add("file-transfer-complete");
        trimTransferHistory();
        expireTransfer(row);
    }

    async function refreshVisibleRoot(root) {
        if (!current || current.id !== root) return;
        const visiblePath = path;
        await openFolder(visiblePath);
    }

    function transferRow(file, label, kind = "") {
        const row = make("div", "file-transfer");
        const heading = make("div", "meter-head");
        const size = Number(file && (file.size !== undefined ? file.size : file.bytes)) || 0;
        heading.append(make("b", null, label), make("span", null, size ? bytes(size) : t(kind)));
        const bar = make("div", "bar");
        bar.append(make("span"));
        row.append(heading, bar, make("p", "meter-foot", t("Waiting...")));
        queue.prepend(row);
        queueBox.hidden = false;
        return row;
    }

    function archiveName() {
        const leaf = path.split("/").filter(Boolean).pop() || (current && current.label) || "MustardOS";
        const clean = leaf.replace(/[\\/:*?"<>|]+/g, "-").trim() || "MustardOS";
        return `${clean}-Selection.zip`;
    }

    function wait(milliseconds) {
        return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
    }

    async function downloadSelectedItems() {
        const chosen = selectedItems();
        if (!current || chosen.length < 2 || chosen.some((item) => item.link)) return;
        const root = current.id;
        const downloadName = archiveName();
        const archiveEndpoint = endpoint("archive");
        const jobEndpoint = (action, job) => `api/files/${encodeURIComponent(root)}/${action}/${encodeURIComponent(job)}`;

        const row = transferRow({size: 0}, downloadName, "Archive");
        const count = row.querySelector(".meter-head span");
        const note = row.querySelector(".meter-foot");
        const fill = row.querySelector(".bar span");
        count.textContent = t("%s items", chosen.length);
        note.textContent = t("Preparing archive...");
        fill.classList.add("file-transfer-active");

        try {
            const started = await api(archiveEndpoint, {
                method: "POST", body: chosen.map((item) => item.name).join("\n"), type: "text/plain"
            });
            let status;
            do {
                await wait(250);
                status = await api(jobEndpoint("archive-status", started.job));
                if (status.state === "failed") throw new Error(t(status.error || "Could not prepare that archive"));
                const total = Number(status.total) || chosen.length;
                const completed = Math.min(Number(status.completed) || 0, total);
                fill.classList.remove("file-transfer-active");
                fill.style.width = `${Math.round(completed * 100 / total)}%`;
                if (status.current)
                    note.textContent = t("Adding %s (%s of %s)", status.current, Math.min(completed + 1, total), total);
                else note.textContent = t("Preparing archive...");
            } while (status.state !== "ready");

            fill.style.width = "100%";
            note.textContent = t("Archive ready. Download starting...");
            const link = document.createElement("a");
            link.href = jobEndpoint("archive-download", started.job);
            link.download = downloadName;
            document.body.append(link);
            link.click();
            link.remove();
            selected.clear();
            completeTransfer(row, "Download started");
        } catch (error) {
            failTransfer(row, error);
            showToast(error.message, "bad");
        }
    }

    function uploadPath(file) {
        return uploadRelativePaths.get(file) || file.webkitRelativePath || file.name;
    }

    async function ensureUploadFolders(files, explicitFolders, target) {
        const folders = new Set(explicitFolders || []);
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
            const response = await fetchAuthed(endpointFor(target.root, "mkdir", join(target.path, folder)), {
                method: "POST", headers: protectedHeaders(target)
            });
            if (!response.ok && response.status !== 409) throw await responseError(response);
        }
    }

    async function existingUploads(files, target) {
        const folders = new Map();
        files.forEach((file) => {
            const relative = uploadPath(file);
            const folder = parentOf(relative);
            if (!folders.has(folder)) folders.set(folder, []);
            folders.get(folder).push(relative);
        });

        const existing = new Set();
        for (const [folder, relatives] of folders) {
            let listed = target.items;
            if (folder) {
                try {
                    listed = (await api(endpointFor(target.root, "browse", join(target.path, folder)))).items || [];
                } catch (_) {
                    continue;
                }
            }
            const names = new Set(listed.filter((item) => !item.directory).map((item) => item.name));
            relatives.forEach((relative) => {
                if (names.has(relative.slice(relative.lastIndexOf("/") + 1))) existing.add(relative);
            });
        }
        return existing;
    }

    async function chooseReplacements(files, target) {
        const existing = await existingUploads(files, target);
        if (!existing.size) return files;

        const clashes = files.filter((file) => existing.has(uploadPath(file)));
        const skipped = new Set();
        let every = null;
        for (let index = 0; index < clashes.length; index++) {
            const relative = uploadPath(clashes[index]);
            let answer = every;
            if (!answer) {
                const remaining = clashes.length - index - 1;
                answer = await ask({
                    title: t("Replace %s?", relative),
                    message: remaining > 1 ? t("A file with this name already exists. %s more files being uploaded also already exist.", remaining)
                        : remaining ? t("A file with this name already exists. One more file being uploaded also already exists.")
                            : t("A file with this name already exists."),
                    actions: [
                        {value: "skip", label: t("Skip")},
                        {value: "skip-all", label: t("Skip All")},
                        {value: "replace-all", label: t("Replace All"), danger: true},
                        {value: "replace", label: t("Replace"), danger: true}
                    ]
                });
                if (!answer) return null;
                if (answer === "skip-all" || answer === "replace-all") {
                    every = answer === "skip-all" ? "skip" : "replace";
                    answer = every;
                }
            }
            if (answer === "skip") skipped.add(relative);
        }
        return files.filter((file) => !skipped.has(uploadPath(file)));
    }

    function retryableUpload(error, response) {
        if (response) return response.status === 409 || response.status === 429 || response.status >= 500;
        return error && error.message !== t("Upload cancelled");
    }

    async function uploadWithRetry(file, target, relative, progress, retrying) {
        let lastError;
        for (let attempt = 1; attempt <= 3; attempt++) {
            try {
                const response = await uploadAuthed(
                    endpointFor(target.root, "upload", join(target.path, relative)), file,
                    protectedHeaders(target), progress
                );
                if (response.ok) return;
                lastError = await responseError(response);
                if (!retryableUpload(lastError, response)) {
                    lastError.muosPermanent = true;
                    throw lastError;
                }
            } catch (error) {
                lastError = error;
                if (error.muosPermanent || !retryableUpload(error, null)) throw error;
            }
            if (attempt < 3) {
                retrying(attempt + 1);
                await wait(attempt * 350);
            }
        }
        throw lastError || new Error(t("Could not finish that upload"));
    }

    async function verifyUploads(uploaded, target) {
        const groups = new Map();
        uploaded.forEach((entry, relative) => {
            const folder = parentOf(relative);
            if (!groups.has(folder)) groups.set(folder, []);
            groups.get(folder).push({relative, ...entry});
        });
        const failed = new Set();
        for (const [folder, entries] of groups) {
            try {
                const listed = (await api(endpointFor(target.root, "browse", join(target.path, folder)))).items || [];
                const byName = new Map(listed.filter((item) => !item.directory).map((item) => [item.name, item]));
                entries.forEach(({relative, file}) => {
                    const item = byName.get(relative.slice(relative.lastIndexOf("/") + 1));
                    if (!item || Number(item.bytes) !== Number(file.size)) failed.add(relative);
                });
            } catch (_) {
                entries.forEach(({relative}) => failed.add(relative));
            }
        }
        return failed;
    }

    async function upload(files, folders = [], target = transferTarget()) {
        if (!target || (!files.length && !folders.length) || !await confirmProtected(target)) return;
        let chosen;
        try {
            chosen = await chooseReplacements(files, target);
        } catch (error) {
            showToast(error.message, "bad");
            return;
        }
        if (!chosen) return;
        if (!chosen.length && !folders.length) {
            showToast(t("No files were uploaded"), "good");
            return;
        }
        files = chosen;
        let completed = 0;
        let failed = 0;
        const uploaded = new Map();
        try {
            await ensureUploadFolders(files, folders, target);
        } catch (error) {
            showToast(error.message, "bad");
            return;
        }
        for (const file of files) {
            const relative = uploadPath(file);
            const row = transferRow(file, relative, "Upload");
            const note = row.querySelector(".meter-foot");
            const fill = row.querySelector(".bar span");
            note.textContent = t("Uploading...");
            fill.classList.add("file-transfer-active");
            try {
                await uploadWithRetry(file, target, relative, (loaded, total) => {
                    const percent = total ? Math.round(loaded * 100 / total) : 100;
                    fill.classList.remove("file-transfer-active");
                    fill.style.width = `${percent}%`;
                    note.textContent = t("Uploading... %s%", percent);
                }, (attempt) => {
                    fill.style.width = "0%";
                    fill.classList.add("file-transfer-active");
                    note.textContent = t("Retrying upload... attempt %s of 3", attempt);
                });
                fill.classList.remove("file-transfer-active");
                fill.style.width = "100%";
                note.textContent = t("Verifying...");
                uploaded.set(relative, {file, row});
            } catch (error) {
                failTransfer(row, error);
                failed += 1;
            }
        }

        const unverified = await verifyUploads(uploaded, target);
        uploaded.forEach(({row}, relative) => {
            if (unverified.has(relative)) {
                failTransfer(row, new Error(t("Upload could not be verified")));
                failed += 1;
            } else {
                completeTransfer(row);
                completed += 1;
            }
        });

        if (failed) {
            showToast(t(failed === 1 ? "One file could not be uploaded" : "%s files could not be uploaded", failed), "bad");
        } else if (completed) {
            showToast(t(completed === 1 ? "File uploaded" : "%s files uploaded", completed), "good");
        } else if (folders.length) {
            showToast(t(folders.length === 1 ? "Folder created" : "%s folders created", folders.length), "good");
        }
        if (completed || folders.length) {
            await refreshVisibleRoot(target.root);
        }
    }

    function queueUpload(files, folders = [], target = transferTarget()) {
        const queuedFiles = [...files];
        const queuedFolders = [...folders];
        uploadQueue = uploadQueue
            .then(() => upload(queuedFiles, queuedFolders, target))
            .catch((error) => showToast(error.message, "bad"));
        return uploadQueue;
    }

    function readDirectoryBatch(reader) {
        return new Promise((resolve, reject) => reader.readEntries(resolve, reject));
    }

    async function readDirectoryEntries(entry) {
        const reader = entry.createReader();
        const entries = [];
        for (;;) {
            const batch = await readDirectoryBatch(reader);
            if (!batch.length) return entries;
            entries.push(...batch);
        }
    }

    async function droppedContent(dataTransfer) {
        const files = [];
        const folders = [];
        const items = [...(dataTransfer.items || [])].filter((item) => item.kind === "file");
        /* Request every handle before awaiting; browsers revoke drag handles once the event yields. */
        const handleRequests = items.map((item) => item.getAsFileSystemHandle
            ? item.getAsFileSystemHandle().catch(() => null) : Promise.resolve(null));
        const handles = await Promise.all(handleRequests);

        const visitHandle = async (handle, parent = "") => {
            const relative = join(parent, handle.name);
            if (handle.kind === "file") {
                const file = await handle.getFile();
                uploadRelativePaths.set(file, relative);
                files.push(file);
                return;
            }
            if (handle.kind !== "directory") return;
            folders.push(relative);
            for await (const child of handle.values()) await visitHandle(child, relative);
        };

        const visit = async (entry, parent = "") => {
            const relative = join(parent, entry.name);
            if (entry.isFile) {
                const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
                uploadRelativePaths.set(file, relative);
                files.push(file);
                return;
            }
            if (!entry.isDirectory) return;
            folders.push(relative);
            const children = await readDirectoryEntries(entry);
            for (const child of children) await visit(child, relative);
        };

        for (let index = 0; index < items.length; index++) {
            if (handles[index]) {
                await visitHandle(handles[index]);
                continue;
            }
            const item = items[index];
            const entry = item.webkitGetAsEntry ? item.webkitGetAsEntry() : null;
            if (entry) {
                await visit(entry);
                continue;
            }
            const file = item.getAsFile();
            if (file) files.push(file);
        }

        if (!items.length) files.push(...dataTransfer.files);
        return {files, folders: [...new Set(folders)]};
    }

    newButton.addEventListener("click", createFolder);
    uploadFilesButton.addEventListener("click", () => filePicker.click());
    uploadFoldersButton.addEventListener("click", () => folderPicker.click());
    filePicker.addEventListener("change", () => {
        queueUpload(filePicker.files);
        filePicker.value = "";
    });
    folderPicker.addEventListener("change", () => {
        queueUpload(folderPicker.files);
        folderPicker.value = "";
    });
    textEditorContent.addEventListener("input", () => {
        updateTextSize();
        if (!richTextPreviewPane.hidden) updateRichPreview();
    });
    textEditorContent.addEventListener("keydown", (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLocaleLowerCase() === "s") {
            event.preventDefault();
            saveText();
        }
    });
    textEditorSave.addEventListener("click", saveText);
    textEditorCancel.addEventListener("click", closeTextEditor);
    imagePreviewClose.addEventListener("click", closeImagePreview);
    modeForm.addEventListener("submit", savePermissions);
    modeCancel.addEventListener("click", closePermissions);
    modeChecks.forEach((input) => input.addEventListener("change", paintMode));
    richTextTools.querySelectorAll("[data-rich-code]").forEach((button) => {
        button.addEventListener("click", () => insertRichCode(button.dataset.richCode));
    });
    richTextColour.addEventListener("change", () => {
        if (richTextColour.value) insertRichCode(richTextColour.value);
        richTextColour.value = "";
    });
    MU.onDismiss(closeTextEditor);
    MU.onDismiss(closeImagePreview);
    MU.onDismiss(closePermissions);
    MU.onDismiss(closeActionMenu);
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
    downloadSelected.addEventListener("click", downloadSelectedItems);
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
    document.addEventListener("drop", async (event) => {
        if (!current || !MU.canManage()) return;
        const target = transferTarget();
        try {
            const dropped = await droppedContent(event.dataTransfer);
            await queueUpload(dropped.files, dropped.folders, target);
        } catch (error) {
            showToast(error.message, "bad");
        }
    });
    document.addEventListener("click", (event) => {
        if (!actionMenu.hidden && !actionMenu.contains(event.target) && event.target !== actionMenuOwner)
            closeActionMenu();
    });
    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && !actionMenu.hidden) {
            event.preventDefault();
            closeActionMenu(true);
        }
    });
    window.addEventListener("resize", () => closeActionMenu());
    window.addEventListener("scroll", () => closeActionMenu(), true);
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
