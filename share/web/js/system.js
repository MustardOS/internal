(function () {
    "use strict";

    const MU = window.MU;
    const {el, make, bytes, fillKv, register, t} = MU;
    const REFRESH = 5000;
    const TIME_FLOOR = 1735689600;
    const TIME_CEILING = 4102444799;
    const UNKNOWN = "Unknown";
    const NOT_CONNECTED = "Not Connected";

    const CHANNELS = {
        2412: 1, 2417: 2, 2422: 3, 2427: 4, 2432: 5, 2437: 6, 2442: 7, 2447: 8, 2452: 9, 2457: 10, 2462: 11,
        2467: 12, 2472: 13, 2484: 14, 5180: 36, 5200: 40, 5220: 44, 5240: 48, 5260: 52, 5280: 56, 5300: 60,
        5320: 64, 5500: 100, 5520: 104, 5540: 108, 5560: 112, 5580: 116, 5600: 120, 5620: 124, 5640: 128,
        5660: 132, 5680: 136, 5700: 140, 5745: 149, 5765: 153, 5785: 157, 5805: 161, 5825: 165
    };

    const INTEGRITY = [
        ["signature", "Release Signature"],
        ["provenance", "Release Metadata"],
        ["scripts", "System Scripts"],
        ["frontend", "Frontend"],
        ["device", "Device Package"],
        ["kernel", "Kernel"],
        ["modules", "Kernel Modules"],
        ["dtb", "Device Tree"],
        ["ramdisk", "Initial Ramdisk"],
        ["bootloader", "Bootloader"],
        ["boot_resources", "Boot Resources"]
    ];

    let previous = null;
    let latest = null;
    let ticking = 0;

    const known = (value) => value !== null && value !== undefined && value !== "" && Number.isFinite(Number(value));
    const or = (value, fallback = UNKNOWN) => (value ? String(value) : t(fallback));
    const pad = (value) => String(value).padStart(2, "0");

    function date(epoch) {
        const when = new Date(epoch * 1000);
        return `${when.getFullYear()}-${pad(when.getMonth() + 1)}-${pad(when.getDate())} `
            + `${pad(when.getHours())}:${pad(when.getMinutes())}`;
    }

    function uptime(seconds) {
        const minutes = Math.floor(seconds / 60);
        const days = Math.floor(minutes / 1440);
        const hours = Math.floor((minutes % 1440) / 60);
        const parts = [];
        if (days) parts.push(`${days} ${t("Day(s)")}`);
        if (days || hours) parts.push(`${hours} ${t("Hour(s)")}`);
        parts.push(`${days || hours ? minutes % 60 : minutes} ${t("Minute(s)")}`);
        return parts.join(" ");
    }

    function span(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (days) return `${days}d ${hours}h`;
        if (hours) return `${hours}h ${minutes}m`;
        if (minutes) return `${minutes}m`;
        return "< 1m";
    }

    function megabytes(used, total) {
        return `${(used / 1024).toFixed(2)} MB / ${(total / 1024).toFixed(2)} MB`;
    }

    function range(low, high, divisor) {
        if (!known(low) || !known(high) || !low || !high) return t(UNKNOWN);
        return `${Math.floor(low / divisor)} - ${Math.floor(high / divisor)} MHz`;
    }

    function percent(value) {
        return known(value) && value >= 0 && value <= 100 ? `${value}%` : "-";
    }

    function signal(dbm) {
        if (!known(dbm)) return t(UNKNOWN);
        const strength = dbm <= -100 ? 0 : dbm >= -10 ? 100 : Math.floor(((dbm + 100) * 100) / 90);
        return `${strength}% (${dbm} dBm)`;
    }

    function channel(frequency) {
        if (!known(frequency) || frequency <= 0) return t(UNKNOWN);
        return `${frequency} MHz - ${t("Channel %s", CHANNELS[frequency] || t(UNKNOWN))}`;
    }

    function traffic(detail) {
        const now = detail.traffic || {};
        let rx = 0;
        let tx = 0;
        if (previous && detail.epoch > previous.epoch && known(now.rx) && known(previous.rx)) {
            const seconds = detail.epoch - previous.epoch;
            rx = Math.max(0, now.rx - previous.rx) / seconds;
            tx = Math.max(0, now.tx - previous.tx) / seconds;
        }
        previous = {epoch: detail.epoch, rx: now.rx, tx: now.tx};
        return {
            active: `RX: ${(rx / 1024).toFixed(1)} KB/s TX: ${(tx / 1024).toFixed(1)} KB/s`,
            total: `RX: ${((now.rx || 0) / 1048576).toFixed(1)} MB TX: ${((now.tx || 0) / 1048576).toFixed(1)} MB`
        };
    }

    function softwareRows(detail) {
        const system = detail.system || {};
        const frontend = detail.frontend || {};
        return [
            ["Version", or(system.version)],
            ["Build", or(system.build)],
            ["Kernel", or(system.kernel)],
            ["Architecture", or(system.arch)],
            ["Theme", or(frontend.theme)],
            ["Language", or(frontend.language)]
        ];
    }

    function deviceRows(detail) {
        const system = detail.system || {};
        const network = detail.network || {};
        return [
            ["Device", system.device ? system.device.toUpperCase() : t(UNKNOWN)],
            ["Serial Number", or(system.serial)],
            ["Display", or(system.display)],
            ["Hostname", detail.network ? or(network.hostname) : ""],
            ["MAC Address", detail.network ? or(network.mac) : ""]
        ];
    }

    function runtimeRows(detail) {
        const runtime = detail.runtime || {};
        const load = (runtime.load || []).map((value) => Number(value).toFixed(2));
        return [
            ["Uptime", known(runtime.uptime) ? uptime(runtime.uptime) : t(UNKNOWN)],
            ["Boot Time", known(runtime.uptime) ? date(detail.epoch - runtime.uptime) : t(UNKNOWN)],
            ["Time Zone", or((detail.frontend || {}).zone)],
            ["Load Average", load.length === 3 ? load.join(" / ") : t(UNKNOWN)],
            ["Tasks", known(runtime.tasks) ? String(runtime.tasks) : t(UNKNOWN)],
            ["Temperature", runtime.temperature ? `${(runtime.temperature / 1000).toFixed(2)}°C` : t(UNKNOWN)]
        ];
    }

    function memoryRows(detail) {
        const runtime = detail.runtime || {};
        const memory = runtime.memory || {};
        const swap = runtime.swap || {};
        const storage = (detail.storage || []).map((entry) => {
            const total = Number(entry.total) || 0;
            const used = Math.min(Number(entry.used) || 0, total);
            const share = total ? Math.round((used / total) * 100) : 0;
            return [entry.label, t("%s free of %s (%s used)", bytes(total - used), bytes(total), `${share}%`)];
        });
        return [
            ["Memory", memory.total ? megabytes(memory.total - (memory.available || 0), memory.total) : t(UNKNOWN)],
            ["Swap", swap.total ? megabytes(swap.total - (swap.free || 0), swap.total) : "0.00 MB / 0.00 MB"],
            ...storage
        ];
    }

    function processorRows(detail) {
        const cpu = detail.processor || {};
        const model = cpu.cpu ? (cpu.cores ? `${cpu.cpu} (${t("%s Cores", cpu.cores)})` : cpu.cpu) : t(UNKNOWN);
        return [
            ["Processor", model],
            ["Speed", cpu.speed ? `${(cpu.speed / 1000).toFixed(2)} MHz` : t(UNKNOWN)],
            ["Speed Range", range(cpu.cpu_min, cpu.cpu_max, 1000)],
            ["Governor", or(cpu.governor)]
        ];
    }

    function graphicsRows(detail) {
        const cpu = detail.processor || {};
        return [
            ["Graphics", or(cpu.gpu)],
            ["Graphics Speed", cpu.gpu_speed ? `${Math.floor(cpu.gpu_speed / 1000000)} MHz` : t(UNKNOWN)],
            ["Graphics Speed Range", range(cpu.gpu_min, cpu.gpu_max, 1000000)],
            ["Graphics Governor", or(cpu.gpu_governor)]
        ];
    }

    function batteryRows(detail) {
        const battery = detail.battery || {};
        return [
            ["Capacity", known(battery.capacity) ? `${battery.capacity}%` : t(UNKNOWN)],
            ["Voltage", known(battery.voltage) ? `${(battery.voltage / 1000).toFixed(2)} V` : "0.00 V"],
            ["Status", battery.status ? t(battery.status) : t(UNKNOWN)],
            ["Health", battery.health ? t(battery.health) : t(UNKNOWN)],
            ["Design Capacity", battery.design ? `${battery.design} mAh` : t(UNKNOWN)],
            ["Charger", battery.charging === 1 ? t("Online") : t("Offline")]
        ];
    }

    function chargingRows(detail) {
        const power = detail.power || {};
        const capacity = (detail.battery || {}).capacity;
        const charged = known(power.last_charged) && power.last_charged >= TIME_FLOOR
            && power.last_charged <= TIME_CEILING;
        const rows = [
            ["Last Charged", charged ? date(power.last_charged) : "-"],
            ["Time on Battery", power.time_on_battery > 0 ? span(power.time_on_battery) : "-"]
        ];

        if (known(power.unplug)) {
            const valid = power.unplug > 0 && power.unplug <= 100 && known(capacity);
            rows.push(["Battery Used", valid ? `${Math.max(0, power.unplug - capacity)}%` : "-"]);
        }

        return rows;
    }

    function poweredOffRows(detail) {
        const power = detail.power || {};
        const history = known(power.shutdown) && known(power.boot) && known(power.off_duration) && known(power.off_delta)
            && power.shutdown >= 0 && power.shutdown <= 100 && power.boot >= 0 && power.boot <= 100
            && power.off_duration >= 0 && power.off_delta >= -100 && power.off_delta <= 100;
        if (!history) return [];

        const change = -power.off_delta;
        return [
            ["Battery at Shutdown", percent(power.shutdown)],
            ["Battery at Boot", percent(power.boot)],
            ["Time Powered Off", span(power.off_duration)],
            ["Battery Change While Off", change === 0 ? "0%" : `${change > 0 ? "+" : ""}${change}%`]
        ];
    }

    function networkRows(network) {
        const online = network.connected;
        const when = (value) => (online ? or(value) : t(NOT_CONNECTED));
        return [
            ["IP Address", when(network.ip)],
            ["Network Name", when(network.ssid)],
            ["Signal", online ? signal(network.signal) : t(NOT_CONNECTED)],
            ["Gateway", when(network.gateway)],
            ["DNS", when(network.dns)]
        ];
    }

    function trafficRows(network, rates) {
        const online = network.connected;
        return [
            ["Channel", online ? channel(network.frequency) : t(NOT_CONNECTED)],
            ["Active Traffic", online ? rates.active : t(NOT_CONNECTED)],
            ["Total Traffic", online ? rates.total : t(NOT_CONNECTED)]
        ];
    }

    function integrityRows(detail, keys) {
        const integrity = detail.integrity;
        return INTEGRITY.filter(([key]) => keys.includes(key)).map(([key, label]) => [
            label,
            t(integrity ? (integrity[key] ? "Clean" : "Modified") : "Checking...")
        ]);
    }

    function sections(detail) {
        const rates = traffic(detail);
        const list = [
            ["Software", softwareRows(detail)],
            ["Device", deviceRows(detail)],
            ["Runtime", runtimeRows(detail)],
            ["Memory and Storage", memoryRows(detail)],
            ["Processor", processorRows(detail)],
            ["Graphics", graphicsRows(detail)],
            ["Battery", batteryRows(detail)],
            ["Charging", chargingRows(detail)],
            ["Powered Off", poweredOffRows(detail)]
        ];

        if (detail.network) {
            list.push(["Network", networkRows(detail.network)], ["Traffic", trafficRows(detail.network, rates)]);
        }

        list.push(
            ["System Modifications", integrityRows(detail, ["signature", "provenance", "scripts", "frontend", "device"])],
            ["Boot Modifications", integrityRows(detail, ["kernel", "modules", "dtb", "ramdisk", "bootloader", "boot_resources"])]
        );

        return list.filter(([, rows]) => rows.some(([, value]) => value));
    }

    function snapshot() {
        if (!latest) return;
        MU.saveImage({
            title: t("System Information"),
            file: "system-information",
            columns: 2,
            sections: latest.map(([title, rows]) => ({
                title: t(title),
                rows: rows.filter(([, value]) => value).map(([name, value]) => [t(name), value])
            }))
        });
    }

    function render(detail) {
        const holder = el("system-sections");
        const boxes = holder.children;
        const list = sections(detail);
        latest = list;
        el("system-save").hidden = false;

        list.forEach(([title, rows], index) => {
            let box = boxes[index];
            if (!box || box.dataset.section !== title) {
                box = make("section", "box");
                box.dataset.section = title;
                box.append(make("h2", null, t(title)), make("dl", "kv"));
                if (boxes[index]) boxes[index].replaceWith(box);
                else holder.append(box);
            }
            box.hidden = !fillKv(box.querySelector("dl"), rows);
        });

        while (boxes.length > list.length) holder.lastChild.remove();
    }

    function setLive(live) {
        el("system-sections").hidden = !live;
        el("system-offline").hidden = live;
    }

    async function refresh() {
        const response = await fetch(`state/detail.json?_=${Date.now()}`, {cache: "no-store"});
        if (response.status === 404) return setLive(false);
        if (!response.ok) throw new Error(`detail returned ${response.status}`);

        render(await response.json());
        setLive(true);
    }

    async function tick() {
        if (ticking || document.hidden || el("view-system").hidden) return;
        ticking = 1;
        try {
            await refresh();
        } catch (_) {
            setLive(false);
        } finally {
            ticking = 0;
        }
    }

    el("system-save").addEventListener("click", snapshot);

    setInterval(tick, REFRESH);
    document.addEventListener("visibilitychange", tick);

    register("system", {load: tick, restore: tick});
}());
