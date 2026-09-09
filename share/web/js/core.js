(function () {
    "use strict";

    const runtime = window.MUOS_RUNTIME || {};
    const el = (id) => document.getElementById(id);

    function make(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined) node.textContent = text;
        return node;
    }

    const UNITS = ["B", "KB", "MB", "GB", "TB"];

    function bytes(value) {
        let size = Number(value) || 0;
        let unit = 0;
        while (size >= 1000 && unit < UNITS.length - 1) {
            size /= 1000;
            unit += 1;
        }
        return `${unit === 0 || size >= 100 ? Math.round(size) : Number(size.toFixed(1))} ${UNITS[unit]}`;
    }

    function duration(seconds, withDays) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const days = withDays ? Math.floor(total / 86400) : 0;
        const hours = Math.floor((total - days * 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days) return `${days}d ${hours}h`;
        return hours ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    const count = (value) => (Number(value) || 0).toLocaleString();

    function stamp(seconds) {
        const value = Number(seconds);
        if (!Number.isFinite(value) || value <= 0) return "";
        return new Date(value * 1000).toLocaleString([], {
            day: "numeric", month: "short", hour: "2-digit", minute: "2-digit"
        });
    }

    const collator = new Intl.Collator(undefined, {numeric: true, sensitivity: "base"});

    const SORTS = [
        ["name", "Name"],
        ["recent", "Newest"],
        ["size", "Largest"]
    ];

    function sortItems(list, mode, label) {
        const byName = (a, b) => collator.compare(label(a), label(b));
        return [...list].sort((a, b) => {
            if (mode === "recent") return (b.modified || 0) - (a.modified || 0) || byName(a, b);
            if (mode === "size") return (b.bytes || 0) - (a.bytes || 0) || byName(a, b);
            return byName(a, b);
        });
    }

    function sortControl(current, onChange) {
        const select = make("select", "sort");
        select.setAttribute("aria-label", "Sort by");

        SORTS.forEach(([value, text]) => {
            const option = make("option", null, text);
            option.value = value;
            if (value === current) option.selected = true;
            select.append(option);
        });

        select.addEventListener("change", () => onChange(select.value));
        return select;
    }

    const LAYOUTS = [
        ["compact", "Compact list"],
        ["comfortable", "Comfortable list"],
        ["grid", "Grid"]
    ];

    const layouts = {catalogue: "comfortable", pickles: "comfortable"};
    const layoutWatchers = [];

    Object.keys(layouts).forEach((view) => {
        try {
            const saved = localStorage.getItem(`muos.layout.${view}`);
            if (saved && LAYOUTS.some(([value]) => value === saved)) layouts[view] = saved;
        } catch (_) {
        }
    });

    function layoutClass(view, extra) {
        return `cards${extra ? ` ${extra}` : ""} as-${layouts[view]}`;
    }

    function onLayoutChange(fn) {
        layoutWatchers.push(fn);
    }

    function layoutControl(view) {
        const select = make("select", "sort");
        select.setAttribute("aria-label", "Layout");

        LAYOUTS.forEach(([value, text]) => {
            const option = make("option", null, text);
            option.value = value;
            if (value === layouts[view]) option.selected = true;
            select.append(option);
        });

        select.addEventListener("change", () => {
            layouts[view] = select.value;
            try {
                localStorage.setItem(`muos.layout.${view}`, select.value);
            } catch (_) {
            }
            layoutWatchers.forEach((fn) => fn(view, select.value));
        });

        return select;
    }

    const toast = el("toast");
    let toastTimer;

    function showToast(text) {
        toast.textContent = text;
        toast.classList.add("visible");
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove("visible"), 1800);
    }

    const dismissers = [];

    function onDismiss(fn) {
        dismissers.push(fn);
    }

    function holdFocus() {
        const was = document.activeElement;
        return () => {
            if (was && was.isConnected !== false && was.focus) was.focus();
        };
    }

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") dismissers.slice().forEach((fn) => fn());
    });

    let working = 0;

    async function busy(button, label, task) {
        if (working) return;

        const was = button ? button.textContent : "";
        working += 1;
        if (button) {
            button.disabled = true;
            button.textContent = label;
        }

        try {
            return await task();
        } finally {
            working -= 1;
            if (button) {
                button.disabled = false;
                button.textContent = was;
            }
        }
    }

    function setBar(bar, percent, warn) {
        bar.style.width = `${Math.max(0, Math.min(100, percent))}%`;
        bar.classList.toggle("warn", Boolean(warn));
    }

    const painted = new Set();

    function showSpace(view, payload) {
        const box = el(`${view}-space`);
        const space = payload && payload.space;
        const total = Number(space && space.total) || 0;

        if (!box) return;
        box.hidden = !total;
        if (!total) return;

        const used = Math.max(0, Math.min(Number(space.used) || 0, total));
        const free = Math.max(0, Number(space.free) || 0);
        const percent = Math.round((used / total) * 100);

        el(`${view}-space-free`).textContent = `${bytes(free)} free`;
        el(`${view}-space-total`).textContent = `${bytes(used)} of ${bytes(total)} used`;
        setBar(el(`${view}-space-fill`), percent, percent >= 90);
    }

    function crumbs(into, trail) {
        into.replaceChildren();
        let here = null;

        trail.forEach((step, index) => {
            const last = index === trail.length - 1;

            if (index) into.append(make("span", "crumb-sep", "/"));

            if (last || !step.go) {
                here = make("span", "crumb-here", step.label);
                into.append(here);
                return;
            }

            const link = make("button", "crumb", step.label);
            link.type = "button";
            link.addEventListener("click", step.go);
            into.append(link);
        });

        if (here && painted.has(into)) {
            here.setAttribute("tabindex", "-1");
            here.focus();
        }
        painted.add(into);
    }

    function loading(message) {
        const box = make("div", "loading");
        box.setAttribute("role", "status");

        const bar = make("div", "loading-bar");
        bar.append(make("span"));

        box.append(make("p", "loading-note", message || "Reading the card…"), bar);
        return box;
    }

    function problem(message, retry) {
        const block = make("div", "problem");
        block.append(make("p", "note danger", message));

        if (retry) {
            const again = make("button", "link", "Try again");
            again.type = "button";
            again.addEventListener("click", retry);
            block.append(again);
        }
        return block;
    }

    const MU = window.MU = window.MU || {};

    MU.mediaUrl = (root, path) => `media/${root}/${path.split("/").map(encodeURIComponent).join("/")}`;
    MU.apiPath = (...parts) => parts.map(encodeURIComponent).join("/");

    Object.assign(MU, {
        el,
        make,
        bytes,
        duration,
        count,
        stamp,
        showToast,
        sortItems,
        sortControl,
        layoutClass,
        layoutControl,
        onLayoutChange,
        onDismiss,
        holdFocus,
        busy,
        setBar,
        showSpace,
        crumbs,
        loading,
        problem,
        runtime
    });
}());
