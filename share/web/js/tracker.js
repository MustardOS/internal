(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, count, fillKv, register, t} = MU;
    const A = window.MUOS_ACTIVITY;
    const REFRESH = 60000;
    const RECENT = 20;
    const GROUP_KEY = "muos-tracker-group";

    const SVG = "http://www.w3.org/2000/svg";
    const WEEKS = 53;
    const CELL = 11;
    const STEP = 14;
    const LEFT = 30;
    const TOP = 16;
    const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    let all = [];
    let grouped = new Map();
    let items = [];
    let group = "";
    let sortKey = "total";
    let descending = true;
    let query = "";
    let ticking = 0;
    let shown = null;

    let daily = null;
    let measure = "time";
    let pick = "";
    let pickedDay = "";
    let cells = [];

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
        const total = groupTime("all");

        el("tracker-groups").replaceChildren(...A.groups.map((entry) => {
            const titles = grouped.get(entry.key).length;
            const time = groupTime(entry.key);
            const button = make("button", "box stat tracker-group");
            button.type = "button";
            button.setAttribute("aria-pressed", String(entry.key === group));
            button.append(
                make("h2", null, t(entry.label)),
                make("p", "stat-value", A.duration(time)),
                make("p", "stat-note", t(titles === 1 ? "%s title" : "%s titles", count(titles)))
            );

            if (entry.key !== "all") {
                const share = total ? Math.round((time / total) * 100) : 0;
                const bar = make("div", "bar");
                const fill = make("span");
                fill.style.width = `${share}%`;
                bar.append(fill);
                bar.setAttribute("aria-hidden", "true");
                button.append(bar, make("p", "stat-note", t("%s of play time", `${share}%`)));
            }

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

    function nameCell(item) {
        const button = make("button", "link content-pick", item.name);
        button.type = "button";
        button.setAttribute("aria-pressed", String(item.key === pick));
        button.addEventListener("click", () => selectContent(item.key));

        const cell = make("td");
        cell.append(button);
        return cell;
    }

    function renderRows() {
        const needle = query.toLocaleLowerCase();
        const columns = A.columnsFor(group);
        const visible = A.sortItems(items, sortKey, descending)
            .filter((item) => item.name.toLocaleLowerCase().includes(needle));
        const body = el("tracker-rows");
        body.replaceChildren();

        visible.forEach((item) => {
            const row = make("tr", item.key === pick ? "selected" : null);
            columns.forEach((column) => row.append(column.key === "name"
                ? nameCell(item)
                : make("td", column.number ? "number" : null, column.show(item))));
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

    function pickedItem() {
        return pick ? items.find((item) => item.key === pick) || null : null;
    }

    function scopeItems() {
        const item = pickedItem();
        return item ? [item] : items;
    }

    function scopeDays() {
        const item = pickedItem();
        if (item) return A.sessionDays([item]);

        const days = daily && daily.days && typeof daily.days === "object" ? daily.days : null;
        if (!days) return A.sessionDays(items);

        const out = {};
        Object.entries(days).forEach(([date, day]) => {
            const source = group === "all" ? day : day && day.runtimes && day.runtimes[group];
            if (source) out[date] = {time: Number(source.time) || 0, launches: Number(source.launches) || 0};
        });
        return out;
    }

    function valueOf(cell) {
        return measure === "time" ? cell.time : cell.launches;
    }

    function limitsOf(values) {
        const played = values.filter((value) => value > 0).sort((a, b) => a - b);
        if (!played.length) return [0, 0, 0];

        const at = (share) => played[Math.floor(share * (played.length - 1))];
        return [at(0.25), at(0.5), at(0.75)];
    }

    function levelOf(value, limits) {
        if (value <= 0) return 0;
        return 1 + limits.filter((limit) => value > limit).length;
    }

    function launchText(launches) {
        return t(launches === 1 ? "%s launch" : "%s launches", count(launches));
    }

    function dateText(date) {
        return `${t(WEEKDAYS[date.getDay()])} ${date.getDate()} ${t(MONTHS[date.getMonth()])} ${date.getFullYear()}`;
    }

    function cellValue(cell) {
        if (measure === "time") return cell.time ? A.duration(cell.time) : t("No play");
        return launchText(cell.launches);
    }

    function cellDetail(cell) {
        const other = measure === "time" ? launchText(cell.launches) : A.duration(cell.time);
        return `${other} · ${dateText(cell.date)}`;
    }

    function svg(name, attributes, text) {
        const node = document.createElementNS(SVG, name);
        Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, String(value)));
        if (text !== undefined) node.textContent = text;
        return node;
    }

    function buildCells(days) {
        const today = new Date();
        today.setHours(12, 0, 0, 0);

        const start = new Date(today);
        start.setDate(start.getDate() - 7 * (WEEKS - 1) - today.getDay());

        const list = [];
        for (const date = new Date(start); date <= today; date.setDate(date.getDate() + 1)) {
            const key = A.dateKey(date.getTime() / 1000);
            const day = days[key] || {time: 0, launches: 0};
            list.push({key, date: new Date(date), index: list.length, time: day.time, launches: day.launches});
        }
        return list;
    }

    function renderCalendar() {
        cells = buildCells(scopeDays());
        if (!cells.some((cell) => cell.key === pickedDay)) pickedDay = "";

        const limits = limitsOf(cells.map(valueOf));
        const canvas = el("tracker-calendar");
        canvas.setAttribute("viewBox", `0 0 ${LEFT + WEEKS * STEP} ${TOP + 7 * STEP}`);
        canvas.replaceChildren();

        [1, 3, 5].forEach((weekday) => canvas.append(svg("text", {x: 0, y: TOP + weekday * STEP + CELL - 2}, t(WEEKDAYS[weekday]))));

        let lastLabel = -3;
        cells.forEach((cell) => {
            const week = Math.floor(cell.index / 7);
            if (cell.date.getDate() === 1 && week - lastLabel >= 3 && week < WEEKS - 1) {
                canvas.append(svg("text", {x: LEFT + week * STEP, y: TOP - 5}, t(MONTHS[cell.date.getMonth()])));
                lastLabel = week;
            }
        });

        const focusKey = pickedDay || cells[cells.length - 1].key;
        cells.forEach((cell) => {
            const rect = svg("rect", {
                x: LEFT + Math.floor(cell.index / 7) * STEP,
                y: TOP + cell.date.getDay() * STEP,
                width: CELL,
                height: CELL,
                rx: 2,
                class: `lv${levelOf(valueOf(cell), limits)}${cell.key === pickedDay ? " selected" : ""}`,
                role: "button",
                tabindex: cell.key === focusKey ? 0 : -1,
                "aria-label": `${dateText(cell.date)}: ${cellValue(cell)}`,
                "aria-pressed": String(cell.key === pickedDay),
                "data-index": cell.index
            });
            canvas.append(rect);
        });

        const total = cells.reduce((sum, cell) => sum + valueOf(cell), 0);
        el("tracker-calendar-total").textContent = measure === "time"
            ? t("%s played in the last year", A.duration(total))
            : t(total === 1 ? "%s launch in the last year" : "%s launches in the last year", count(total));

        const item = pickedItem();
        const label = A.groups.find((entry) => entry.key === group).label;
        el("tracker-scope").textContent = t("Showing %s", item ? item.name : t(label));
        el("tracker-scope-clear").hidden = !item;

        renderDay();
    }

    function cellFor(node) {
        const index = node && node.getAttribute ? node.getAttribute("data-index") : null;
        return index === null ? null : cells[Number(index)] || null;
    }

    function showTip(rect) {
        const cell = cellFor(rect);
        if (!cell) return hideTip();

        const tip = el("tracker-tip");
        const frame = tip.parentElement;
        el("tracker-tip-value").textContent = cellValue(cell);
        el("tracker-tip-detail").textContent = cellDetail(cell);
        tip.hidden = false;

        const box = rect.getBoundingClientRect();
        const area = frame.getBoundingClientRect();
        const left = box.left - area.left + frame.scrollLeft + box.width / 2 - tip.offsetWidth / 2;
        const maximum = frame.scrollLeft + frame.clientWidth - tip.offsetWidth;
        tip.style.left = `${Math.max(frame.scrollLeft, Math.min(left, maximum))}px`;
        tip.style.top = `${Math.max(0, box.top - area.top - tip.offsetHeight - 6)}px`;
    }

    function hideTip() {
        el("tracker-tip").hidden = true;
    }

    function dayItems(key) {
        const totals = new Map();
        scopeItems().forEach((item) => item.sessions.forEach((session) => {
            if (!session.start || A.dateKey(session.start) !== key) return;
            const entry = totals.get(item.key) || {name: item.name, time: 0, launches: 0};
            entry.time += session.length;
            entry.launches += 1;
            totals.set(item.key, entry);
        }));
        return [...totals.values()].sort((a, b) => b.time - a.time || a.name.localeCompare(b.name));
    }

    function renderDay() {
        const cell = cells.find((entry) => entry.key === pickedDay);
        el("tracker-day").hidden = !cell;
        el("tracker-calendar-hint").hidden = Boolean(cell);
        if (!cell) return;

        el("tracker-day-title").textContent = `${dateText(cell.date)} · ${A.duration(cell.time)} · ${launchText(cell.launches)}`;

        const played = dayItems(cell.key);
        el("tracker-day-list").replaceChildren(...played.map((entry) => {
            const row = make("li");
            row.append(make("span", "rank-name", entry.name), make("span", "rank-time", A.duration(entry.time)));
            return row;
        }));

        const empty = el("tracker-day-empty");
        empty.hidden = played.length > 0;
        empty.textContent = cell.time || cell.launches
            ? t("Session details are not available for this day.")
            : t("Nothing was played on this day.");
    }

    function selectDay(key) {
        pickedDay = pickedDay === key ? "" : key;
        el("tracker-calendar").querySelectorAll("rect").forEach((rect) => {
            const selected = cellFor(rect).key === pickedDay;
            rect.classList.toggle("selected", selected);
            rect.setAttribute("aria-pressed", String(selected));
        });
        renderDay();
    }

    function focusCell(index) {
        const target = el("tracker-calendar").querySelector(`rect[data-index="${Math.max(0, Math.min(index, cells.length - 1))}"]`);
        if (!target) return;

        el("tracker-calendar").querySelectorAll("rect[tabindex=\"0\"]").forEach((rect) => rect.setAttribute("tabindex", "-1"));
        target.setAttribute("tabindex", "0");
        target.focus();
    }

    function selectMeasure(key) {
        measure = key;
        [["time", "tracker-measure-time"], ["launches", "tracker-measure-launches"]].forEach(([name, id]) => {
            el(id).classList.toggle("on", name === key);
            el(id).setAttribute("aria-pressed", String(name === key));
        });
        renderCalendar();
    }

    function selectContent(key) {
        pick = pick === key ? "" : key;
        renderRows();
        renderCalendar();
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

        if (!pickedItem()) pick = "";

        renderTable();
        renderSessions();
        renderCalendar();
    }

    function selectGroup(key) {
        group = key;
        pick = "";
        saveGroup(key);
        renderGroup();
    }

    function show(hasItems) {
        el("tracker-report").hidden = !hasItems;
        el("tracker-empty").hidden = hasItems;
        if (!hasItems) el("tracker-save").hidden = true;
    }

    async function loadDaily() {
        try {
            const response = await fetch(`state/daily.json?_=${Date.now()}`, {cache: "no-store"});
            daily = response.ok ? await response.json() : null;
        } catch (_) {
            daily = null;
        }
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

        await loadDaily();

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

    el("tracker-measure-time").addEventListener("click", () => selectMeasure("time"));
    el("tracker-measure-launches").addEventListener("click", () => selectMeasure("launches"));
    el("tracker-scope-clear").addEventListener("click", () => selectContent(pick));

    const calendar = el("tracker-calendar");
    calendar.addEventListener("pointerover", (event) => showTip(event.target));
    calendar.addEventListener("pointerleave", hideTip);
    calendar.addEventListener("focusin", (event) => showTip(event.target));
    calendar.addEventListener("focusout", hideTip);
    calendar.addEventListener("click", (event) => {
        const cell = cellFor(event.target);
        if (cell) selectDay(cell.key);
    });
    calendar.addEventListener("keydown", (event) => {
        const cell = cellFor(event.target);
        if (!cell) return;

        const moves = {ArrowLeft: -7, ArrowRight: 7, ArrowUp: -1, ArrowDown: 1};
        if (event.key in moves) {
            focusCell(cell.index + moves[event.key]);
        } else if (event.key === "Home") {
            focusCell(0);
        } else if (event.key === "End") {
            focusCell(cells.length - 1);
        } else if (event.key === "Enter" || event.key === " ") {
            selectDay(cell.key);
        } else {
            return;
        }
        event.preventDefault();
    });

    setInterval(tick, REFRESH);
    document.addEventListener("visibilitychange", tick);

    register("activity", {load: tick, restore: tick});
}());
