(function () {
    "use strict";

    const runtime = window.MUOS_RUNTIME || {};
    const el = (id) => document.getElementById(id);
    let strings = {};

    function t(text, ...values) {
        const own = typeof text === "string" && Object.prototype.hasOwnProperty.call(strings, text);
        let index = 0;
        return String(own ? strings[text] : text).replace(/%s/g, () => (index < values.length ? String(values[index++]) : "%s"));
    }

    const TRANSLATED_ATTRIBUTES = ["placeholder", "aria-label", "title", "alt"];

    function translatePage(root) {
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        for (let node = walker.nextNode(); node; node = walker.nextNode()) {
            const text = node.nodeValue.trim();
            if (!text || node.parentElement.closest("script, style")) continue;
            const translated = t(text);
            if (translated !== text) node.nodeValue = node.nodeValue.replace(text, translated);
        }

        root.querySelectorAll("[placeholder], [aria-label], [title], [alt]").forEach((element) => {
            TRANSLATED_ATTRIBUTES.forEach((name) => {
                const value = element.getAttribute(name);
                if (value) element.setAttribute(name, t(value));
            });
        });
    }

    const RTL_SCRIPT = /[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/;

    function flatten(data) {
        const sections = Object.keys(data).filter((key) => key !== "generic" && key !== "muweb");
        const merged = {};
        [...sections, "generic", "muweb"].forEach((key) => {
            const section = data[key];
            if (!section || typeof section !== "object") return;
            Object.entries(section).forEach(([english, value]) => {
                if (typeof value === "string" && value && value !== english) merged[english] = value;
            });
        });
        return merged;
    }

    async function loadLanguage() {
        try {
            const response = await fetch(`state/lang.json?_=${Date.now()}`, {cache: "no-store"});
            strings = response.ok ? flatten(await response.json()) : {};
        } catch (_) {
            strings = {};
        }

        const sample = Object.values(strings).slice(0, 40).join("");
        if (sample) document.documentElement.removeAttribute("lang");
        if (RTL_SCRIPT.test(sample)) document.documentElement.dir = "rtl";
        if (Object.keys(strings).length) translatePage(document.body);
    }

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

    function clock(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        const rest = String(total % 60).padStart(2, "0");
        return hours ? `${hours}:${String(minutes).padStart(2, "0")}:${rest}` : `${minutes}:${rest}`;
    }

    const count = (value) => (Number(value) || 0).toLocaleString();

    function stamp(seconds) {
        const value = Number(seconds);
        if (!Number.isFinite(value) || value <= 0) return "";
        return new Date(value * 1000).toLocaleString([], {
            day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit"
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
        select.setAttribute("aria-label", t("Sort by"));

        SORTS.forEach(([value, text]) => {
            const option = make("option", null, t(text));
            option.value = value;
            if (value === current) option.selected = true;
            select.append(option);
        });

        select.addEventListener("change", () => onChange(select.value));
        return select;
    }

    function sortableHead(columns, current, descending, onChange) {
        const row = make("tr");
        columns.forEach((column) => {
            const cell = make("th", column.className || null);
            cell.scope = "col";
            if (!column.key) {
                cell.classList.add("table-head");
                cell.textContent = t(column.label || "");
                row.append(cell);
                return;
            }

            const active = column.key === current;
            if (active) cell.setAttribute("aria-sort", descending ? "descending" : "ascending");
            const button = make("button", "sort-head", t(column.label));
            button.type = "button";
            if (active) button.append(document.createTextNode(descending ? " ▾" : " ▴"));
            button.addEventListener("click", () => onChange(column.key,
                active ? !descending : Boolean(column.descending)));
            cell.append(button);
            row.append(cell);
        });
        return row;
    }

    const toast = el("toast");
    let toastTimer;

    function showToast(text, kind = "info") {
        toast.textContent = t(text);
        toast.dataset.kind = kind;
        toast.setAttribute("role", kind === "bad" ? "alert" : "status");
        toast.classList.add("visible");
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove("visible"), kind === "bad" ? 4500 : 2600);
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

    const mediaPreview = make("div", "media-preview-tooltip");
    mediaPreview.hidden = true;
    document.body.append(mediaPreview);

    function hideMediaPreview() {
        mediaPreview.hidden = true;
        mediaPreview.replaceChildren();
        delete mediaPreview.dataset.kind;
    }

    function placeMediaPreview(owner) {
        if (mediaPreview.hidden || !owner.isConnected) return;
        const anchor = owner.getBoundingClientRect();
        const popup = mediaPreview.getBoundingClientRect();
        let left = anchor.right + 10;
        if (left + popup.width > window.innerWidth - 8) left = anchor.left - popup.width - 10;
        let top = anchor.top + (anchor.height - popup.height) / 2;
        left = Math.max(8, Math.min(left, window.innerWidth - popup.width - 8));
        top = Math.max(8, Math.min(top, window.innerHeight - popup.height - 8));
        mediaPreview.style.left = `${Math.round(left)}px`;
        mediaPreview.style.top = `${Math.round(top)}px`;
    }

    function showMediaPreview(owner, source, kind) {
        const media = make(kind === "video" ? "video" : "img");
        if (kind === "video") {
            media.autoplay = true;
            media.loop = true;
            media.muted = true;
            media.playsInline = true;
            media.preload = "metadata";
        }
        media.addEventListener("error", hideMediaPreview);
        const fit = () => {
            const width = kind === "video" ? media.videoWidth : media.naturalWidth;
            const height = kind === "video" ? media.videoHeight : media.naturalHeight;
            if (!width || !height) return;
            const maximumWidth = Math.min(kind === "video" ? 360 : 260, window.innerWidth - 16);
            const maximumHeight = Math.min(kind === "video" ? 240 : 220, window.innerHeight - 16);
            const factor = Math.min(maximumWidth / width, maximumHeight / height);
            mediaPreview.style.width = `${Math.max(80, Math.round(width * factor))}px`;
            mediaPreview.style.height = `${Math.max(60, Math.round(height * factor))}px`;
            placeMediaPreview(owner);
        };
        media.addEventListener(kind === "video" ? "loadedmetadata" : "load", fit, {once: true});
        media.src = source;
        mediaPreview.dataset.kind = kind;
        mediaPreview.style.width = "";
        mediaPreview.style.height = "";
        mediaPreview.replaceChildren(media);
        mediaPreview.hidden = false;
        requestAnimationFrame(() => placeMediaPreview(owner));
    }

    function attachMediaPreview(owner, source, kind = "image") {
        owner.addEventListener("mouseenter", () => showMediaPreview(owner, source, kind));
        owner.addEventListener("mouseleave", hideMediaPreview);
        owner.addEventListener("focus", () => showMediaPreview(owner, source, kind));
        owner.addEventListener("blur", hideMediaPreview);
    }

    window.addEventListener("resize", hideMediaPreview);
    document.addEventListener("scroll", hideMediaPreview, true);

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

            const link = make("button", `crumb${step.glyph ? " crumb-glyph" : ""}`,
                step.glyph ? undefined : step.label);
            link.type = "button";
            if (step.glyph) {
                link.dataset.glyph = step.glyph;
                link.title = step.label;
                link.setAttribute("aria-label", step.label);
            }
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

        box.append(make("p", "loading-note", t(message || "Reading the card…")), bar);
        return box;
    }

    function problem(message, retry) {
        const block = make("div", "problem");
        block.append(make("p", "note danger", t(message)));

        if (retry) {
            const again = make("button", "link", t("Try again"));
            again.type = "button";
            again.dataset.glyph = "refresh";
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
        t,
        loadLanguage,
        make,
        bytes,
        duration,
        clock,
        count,
        stamp,
        showToast,
        sortItems,
        sortControl,
        sortableHead,
        onDismiss,
        holdFocus,
        attachMediaPreview,
        hideMediaPreview,
        busy,
        setBar,
        showSpace,
        crumbs,
        loading,
        problem,
        runtime
    });
}());
