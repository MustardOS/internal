(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, count, fillKv, register, t} = MU;
    const A = window.MUOS_ACTIVITY;
    const REFRESH = 60000;
    const RECENT = 20;
    const GROUP_KEY = "muos-tracker-group";

    let all = [];
    let grouped = new Map();
    let items = [];
    let group = "";
    let sortKey = "total";
    let descending = true;
    let query = "";
    let ticking = 0;
    let shown = null;

    function savedGroup() {
        try {
            return localStorage.getItem(GROUP_KEY) || "";
        } catch (_) {
            return "";
        }
    }

    function saveGroup(key) {
        try {
            localStorage.setItem(GROUP_KEY, key);
        } catch (_) {
        }
    }

    function groupTime(key) {
        return grouped.get(key).reduce((sum, item) => sum + item.total, 0);
    }

    function pickGroup() {
        if (A.groups.some((entry) => entry.key === group)) return group;

        const saved = savedGroup();
        if (A.groups.some((entry) => entry.key === saved)) return saved;

        return A.groups.reduce((best, entry) => (groupTime(entry.key) > groupTime(best.key) ? entry : best)).key;
    }

    function renderGroups() {
        el("tracker-groups").replaceChildren(...A.groups.map((entry) => {
            const titles = grouped.get(entry.key).length;
            const button = make("button", "box stat tracker-group");
            button.type = "button";
            button.setAttribute("aria-pressed", String(entry.key === group));
            button.append(
                make("h2", null, t(entry.label)),
                make("p", "stat-value", A.duration(groupTime(entry.key))),
                make("p", "stat-note", t(titles === 1 ? "%s title" : "%s titles", count(titles)))
            );
            button.addEventListener("click", () => selectGroup(entry.key));
            return button;
        }));
    }

    function renderTiles(stats) {
        el("tracker-total").textContent = A.duration(stats.total);
        el("tracker-total-note").textContent = t("%s average", A.duration(stats.average));
        el("tracker-launches").textContent = count(stats.launches);
        el("tracker-titles").textContent = count(stats.titles);
        el("tracker-style").textContent = t(stats.style);
    }

    function renderColumns() {
        const row = el("tracker-columns");
        row.replaceChildren();

        A.columnsFor(group).forEach((column) => {
            const cell = make("th");
            cell.scope = "col";
            if (column.key === sortKey) cell.setAttribute("aria-sort", descending ? "descending" : "ascending");

            const button = make("button", "sort-head", t(column.label) + (column.key === sortKey ? (descending ? " ▾" : " ▴") : ""));
            button.type = "button";
            button.addEventListener("click", () => {
                descending = column.key === sortKey ? !descending : Boolean(column.number);
                sortKey = column.key;
                renderTable();
            });

            cell.append(button);
            row.append(cell);
        });
    }

    function renderRows() {
        const needle = query.toLocaleLowerCase();
        const columns = A.columnsFor(group);
        const visible = A.sortItems(items, sortKey, descending)
            .filter((item) => item.name.toLocaleLowerCase().includes(needle));
        const body = el("tracker-rows");
        body.replaceChildren();

        visible.forEach((item) => {
            const row = make("tr");
            columns.forEach((column) => row.append(make("td", column.number ? "number" : null, column.show(item))));
            body.append(row);
        });

        el("tracker-count").textContent = needle ? t("%s of %s", visible.length, items.length) : String(items.length);
        el("tracker-no-match").hidden = visible.length > 0;
    }

    function renderTable() {
        renderColumns();
        renderRows();
    }

    function renderSessions() {
        const columns = A.sessionColumnsFor(group);
        const sessions = A.recentSessions(all, Infinity)
            .filter((session) => group === "all" || session.runtime === group)
            .slice(0, RECENT);
        const head = el("tracker-session-columns");
        const body = el("tracker-sessions");

        head.replaceChildren(...columns.map((column) => {
            const cell = make("th", "table-head", t(column.label));
            cell.scope = "col";
            return cell;
        }));

        body.replaceChildren(...sessions.map((session) => {
            const row = make("tr");
            columns.forEach((column) => row.append(make("td", column.number ? "number" : null, column.show(session))));
            return row;
        }));

        el("tracker-sessions-box").hidden = sessions.length === 0;
    }

    function renderGroup() {
        items = grouped.get(group);
        renderGroups();

        const label = A.groups.find((entry) => entry.key === group).label;
        el("tracker-group-empty").textContent = t("Nothing played with %s yet.", t(label));
        el("tracker-group-empty").hidden = items.length > 0;
        el("tracker-group-report").hidden = items.length === 0;
        if (!items.length) return;

        if (!A.columnsFor(group).some((column) => column.key === sortKey)) {
            sortKey = "total";
            descending = true;
        }

        renderTable();
        renderSessions();
    }

    function selectGroup(key) {
        group = key;
        saveGroup(key);
        renderGroup();
    }

    function show(hasItems) {
        el("tracker-report").hidden = !hasItems;
        el("tracker-empty").hidden = hasItems;
        if (!hasItems) el("tracker-save").hidden = true;
    }

    async function refresh() {
        const response = await fetch(`state/tracker.json?_=${Date.now()}`, {cache: "no-store"});
        if (response.status === 404) {
            all = [];
            return show(false);
        }
        if (!response.ok) throw new Error(`tracker returned ${response.status}`);

        all = A.parse(await response.json());
        if (!all.length) return show(false);

        shown = A.summarise(all);
        renderTiles(shown);
        fillKv(el("tracker-summary"), A.summaryRows(shown));
        el("tracker-save").hidden = false;

        grouped = A.groupItems(all);
        group = pickGroup();
        renderGroup();
        show(true);
    }

    async function tick() {
        if (ticking || document.hidden || el("view-activity").hidden) return;
        ticking = 1;
        try {
            await refresh();
        } catch (_) {
            show(false);
        } finally {
            ticking = 0;
        }
    }

    el("tracker-save").addEventListener("click", () => {
        if (!shown) return;
        MU.saveImage({
            title: t("Activity Tracker"),
            file: "activity",
            tiles: [
                [t("Play time"), A.duration(shown.total), t("%s average", A.duration(shown.average))],
                [t("Launches"), count(shown.launches)],
                [t("Titles"), count(shown.titles)],
                [t("Play style"), t(shown.style), "", true]
            ],
            sections: [{
                title: t("Summary"),
                rows: A.summaryRows(shown).filter(([, value]) => value).map(([name, value]) => [t(name), value])
            }]
        });
    });

    el("tracker-search").addEventListener("input", (event) => {
        query = event.target.value;
        renderRows();
    });

    setInterval(tick, REFRESH);
    document.addEventListener("visibilitychange", tick);

    register("activity", {load: tick, restore: tick});
}());
