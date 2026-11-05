(function () {
    "use strict";

    const MU = window.MU;
    const {api, ask, bytes, el, loading, make, problem, register, showToast, stamp, t} = MU;
    const view = el("view-file-log");
    const body = el("file-log-body");
    const search = el("file-log-search");
    const actionFilter = el("file-log-action");
    const resultFilter = el("file-log-result");
    const actions = {
        mkdir: "New Folder", upload: "Upload", replace: "Replace", rename: "Rename", move: "Move", copy: "Copy",
        chmod: "Permissions", remove: "Remove"
    };
    let entries = [];

    const parentOf = (value) => value.slice(0, Math.max(0, value.lastIndexOf("/")));

    function options(select, choices) {
        select.replaceChildren(...choices.map(([value, label]) => {
            const option = make("option", "", t(label));
            option.value = value;
            return option;
        }));
    }

    options(actionFilter, [["", "All actions"], ...Object.entries(actions)]);
    options(resultFilter, [["", "All results"], ["done", "Done"], ["failed", "Failed"]]);

    function actionOf(entry) {
        return entry.action === "move" && parentOf(entry.path) === parentOf(entry.target || "") ? "rename" : entry.action;
    }

    function item(entry) {
        const where = `${entry.label}: ${entry.path || "/"}`;
        if (entry.target) return t("%s to %s", where, entry.target);
        if (entry.mode) return `${where} (${entry.mode})`;
        return entry.size === undefined ? where : `${where} (${bytes(entry.size)})`;
    }

    function render() {
        if (!entries.length) {
            body.replaceChildren(make("p", "note file-empty", t("No files have been changed yet.")));
            return;
        }

        const needle = search.value.trim().toLocaleLowerCase();
        const shown = entries.filter((entry) => {
            if (actionFilter.value && actionOf(entry) !== actionFilter.value) return false;
            if (resultFilter.value && (resultFilter.value === "done") !== entry.ok) return false;
            return !needle || [item(entry), entry.error, entry.client].some((text) =>
                String(text || "").toLocaleLowerCase().includes(needle));
        });
        if (!shown.length) {
            body.replaceChildren(make("p", "note file-empty", t("No entries match that filter.")));
            return;
        }

        const head = make("tr");
        ["Time", "Action", "Item", "Result", "From"].forEach((label) => head.append(make("th", "table-head", t(label))));
        const rows = make("tbody");
        shown.forEach((entry) => {
            const action = actionOf(entry);
            const pill = make("span", "file-log-pill", t(actions[action] || action));
            pill.dataset.action = action;
            const actionCell = make("td");
            actionCell.append(pill);
            const row = make("tr");
            row.append(
                make("td", "table-date", stamp(entry.time)),
                actionCell,
                make("td", "file-log-item", item(entry)),
                make("td", entry.ok ? "file-log-done" : "file-log-failed", entry.ok ? t("Done") : entry.error),
                make("td", "", entry.client)
            );
            rows.append(row);
        });
        const columns = make("thead");
        columns.append(head);
        const table = make("table", "data-table file-log-table");
        table.append(columns, rows);
        const scroll = make("div", "table-scroll");
        scroll.append(table);
        body.replaceChildren(scroll);
    }

    async function load() {
        body.replaceChildren(loading("Reading the file log..."));
        try {
            entries = (await api("api/files/log")).entries || [];
            render();
        } catch (error) {
            body.replaceChildren(problem(error.message, load));
        }
    }

    async function clear() {
        const confirmed = await ask({
            title: t("Clear the file log"),
            message: t("Every entry in the file log will be removed."),
            confirm: t("Clear"),
            danger: true
        });
        if (!confirmed) return;
        try {
            await api("api/files/log", {method: "DELETE"});
            await load();
        } catch (error) {
            showToast(error.message, "bad");
        }
    }

    el("file-log-refresh").addEventListener("click", load);
    search.addEventListener("input", render);
    actionFilter.addEventListener("change", render);
    resultFilter.addEventListener("change", render);
    el("file-log-clear").addEventListener("click", clear);
    MU.onAuthChange(() => {
        if (!view.hidden) load();
    });

    register("file-log", {load, restore: load});
}());
