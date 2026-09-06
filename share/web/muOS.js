(function () {
    "use strict";

    const runtime = window.MUOS_RUNTIME || {};
    const services = runtime.services || {};
    const browserHost = window.location.hostname || runtime.localName || "muos.local";
    const hostName = runtime.localName || browserHost;
    const urlHost = browserHost.includes(":") && !browserHost.startsWith("[") ? `[${browserHost}]` : browserHost;

    const el = (id) => document.getElementById(id);

    function make(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined) node.textContent = text;
        return node;
    }

    /* Formatting */

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

    /* Services */

    const toast = el("toast");
    let toastTimer;

    function showToast(text) {
        toast.textContent = text;
        toast.classList.add("visible");
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove("visible"), 1800);
    }

    let enabled = 0;
    document.querySelectorAll("[data-service]").forEach((row) => {
        const service = services[row.dataset.service];
        row.hidden = !(service && service.enabled);
        if (row.hidden) return;

        enabled += 1;
        const meta = row.querySelector("i");

        if (row.dataset.service === "sshd") {
            const command = `ssh -p ${service.port} root@${hostName}`;
            meta.textContent = command;
            row.title = command;
            row.addEventListener("click", async () => {
                try {
                    await navigator.clipboard.writeText(command);
                    showToast("Copied");
                } catch (_) {
                    showToast(command);
                }
            });
        } else {
            const port = Number(service.port);
            row.href = `http://${urlHost}${port === 80 ? "" : `:${port}`}/`;
            meta.textContent = `:${port}`;
        }
    });
    el("no-services").hidden = enabled > 0;

    /* Dashboard */

    const PROGRAMS = {
        muxfrontend: "MustardOS frontend",
        muxretro: "Pickles",
        retroarch: "RetroArch",
        drastic: "DraStic",
        flycast: "Flycast",
        mupen64plus: "Mupen64Plus",
        ppsspp: "PPSSPP",
        scummvm: "ScummVM",
        amiberry: "Amiberry",
        muterm: "Terminal",
        external: "External application"
    };

    function core(value) {
        const trimmed = String(value).replace(/\.so$/i, "").replace(/_libretro$/i, "").replace(/_/g, " ").trim();
        return trimmed || value;
    }

    function fillKv(target, rows) {
        target.replaceChildren();
        rows.forEach(([label, value]) => {
            if (value) target.append(make("dt", null, label), make("dd", null, value));
        });
        return target.childElementCount > 0;
    }

    function setBar(bar, percent, warn) {
        bar.style.width = `${Math.max(0, Math.min(100, percent))}%`;
        bar.classList.toggle("warn", Boolean(warn));
    }

    function renderTiles(status) {
        const battery = status.battery || {};
        const capacity = Number.isFinite(battery.capacity) ? battery.capacity : null;
        const volts = Number.isFinite(battery.voltage) ? `${(battery.voltage / 1000).toFixed(2)}V` : "";
        const state = battery.charging === 1 ? "Charging" : battery.charging === 0 ? "On battery" : "";

        el("battery-value").textContent = capacity === null ? "—" : `${capacity}%`;
        el("battery-note").textContent = [state, volts].filter(Boolean).join(" · ");
        setBar(el("battery-bar"), capacity || 0, capacity !== null && capacity <= 15 && battery.charging !== 1);

        el("clock-value").textContent = status.clock || "—";
        el("clock-note").textContent = [status.day, status.zone].filter(Boolean).join(" ");

        el("uptime-value").textContent = duration(status.uptime, true);
        el("uptime-note").textContent = status.boot ? `Booted ${status.boot}` : "";

        const activity = status.activity;
        el("playtime-value").textContent = activity ? duration(activity.total_time) : "—";
        el("playtime-note").textContent = activity
            ? `${count(activity.launches)} launches · ${count(activity.titles)} titles`
            : "";
    }

    function renderStorage(entries) {
        const list = el("storage-list");
        list.replaceChildren();

        (entries || []).forEach((entry) => {
            const total = Number(entry.total) || 0;
            const used = Math.min(Number(entry.used) || 0, total);
            const percent = total ? Math.round((used / total) * 100) : 0;

            const head = make("div", "meter-head");
            head.append(make("b", null, entry.label), make("span", null, `${percent}%`));

            const bar = make("div", "bar");
            const fill = make("span");
            setBar(fill, percent, percent >= 90);
            bar.append(fill);

            const row = make("div");
            row.append(head, bar, make("p", "meter-foot", `${bytes(total - used)} free of ${bytes(total)}`));
            list.append(row);
        });

        el("storage-empty").hidden = list.childElementCount > 0;
    }

    function renderActivity(activity, playing) {
        const list = el("activity-list");
        list.replaceChildren();

        ((activity && activity.top) || []).forEach((item) => {
            const label = make("span", "rank-name", item.name);
            if (playing && item.name === playing) label.append(make("em", null, "playing"));
            const row = make("li");
            row.append(label, make("span", "rank-time", duration(item.time)));
            list.append(row);
        });

        el("activity-empty").hidden = list.childElementCount > 0;
    }

    function renderNow(running) {
        const program = (running && running.process) || "";
        const content = (running && running.content) || {};
        el("now-box").hidden = !fillKv(el("now-facts"), [
            ["Program", PROGRAMS[program.toLowerCase()] || program],
            ["Content", content.name],
            ["System", content.system],
            ["Core", content.core ? core(content.core) : ""],
            ["For", Number.isFinite(running && running.elapsed) ? duration(running.elapsed) : ""]
        ]);
    }

    function renderDevice(status) {
        const device = status.device || {};
        el("device-box").hidden = !fillKv(el("device-spec"), [
            ["Model", device.name],
            ["Version", device.version],
            ["Build", device.build],
            ["Screen", device.screen],
            ["Kernel", device.kernel],
            ["Address", status.address || hostName]
        ]);
    }

    function setLive(live) {
        el("tiles").hidden = !live;
        el("dash").hidden = !live;
        el("offline").hidden = live;
    }

    /* Polling */

    async function refresh() {
        const response = await fetch(`state/status.json?_=${Date.now()}`, {cache: "no-store"});
        if (response.status === 404) return setLive(false);
        if (!response.ok) throw new Error(`status returned ${response.status}`);

        const status = await response.json();
        renderTiles(status);
        renderNow(status.running);
        renderDevice(status);
        renderStorage(status.storage);
        renderActivity(status.activity, status.running && status.running.content && status.running.content.name);
        setLive(true);
    }

    async function tick() {
        // Skip while the tab is hidden, so an idle page costs the device nothing.
        if (document.hidden) return;
        try {
            await refresh();
        } catch (_) {
            setLive(false);
        }
    }

    tick();
    setInterval(tick, 5000);
    document.addEventListener("visibilitychange", tick);
}());
