(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast, setBar, register} = MU;
    const runtime = window.MUOS_RUNTIME || {};
    const POLL = 10000;
    const CATCH_UP = 2000;
    const REQUEST_WAIT = 30000;

    const canvas = el("remote-screen");
    const note = el("remote-note");
    const progress = el("remote-progress");
    const bar = el("remote-bar");
    const next = el("remote-next");
    const refreshButton = el("remote-refresh");
    const saveButton = el("remote-save");
    const unlockButton = el("remote-unlock");

    let shownCapture = 0;
    let shownBlob = null;
    let lastStatus = null;
    let capturedAt = 0;
    let ticking = 0;
    let pollTimer = 0;
    let barTimer = 0;
    let requestedAt = 0;
    let live = null;
    let liveRetry = 0;
    let liveUnavailable = false;

    el("nav-remote").hidden = !runtime.remoteView;

    const open = () => !document.hidden && !el("view-remote").hidden;
    const allowed = () => Boolean(runtime.remotePublic) || MU.canManage();

    function every(seconds) {
        return seconds >= 60 ? `${Math.round(seconds / 60)}m` : `${seconds}s`;
    }

    function describe(status) {
        const parts = [t("Updates every %s while this page is open.", every(status.interval))];
        if (capturedAt) parts.push(t("Captured at %s.", new Date(capturedAt).toLocaleTimeString()));
        if (status.state === "hidden") parts.push(t("A private screen is open on the device, so it was not captured."));
        if (status.state === "failed") parts.push(t("The last capture failed."));
        if (!status.captured) parts.push(t("Waiting for the first capture…"));
        return parts.join(" ");
    }

    function remaining() {
        if (!lastStatus || !capturedAt) return 0;
        return capturedAt + lastStatus.interval * 1000 - Date.now();
    }

    function paintBar() {
        if (live || !lastStatus || !capturedAt) {
            progress.hidden = true;
            return;
        }

        const span = lastStatus.interval * 1000;
        const left = remaining();
        setBar(bar, Math.max(0, Math.min(100, ((span - left) / span) * 100)), false);
        next.textContent = left > 0 && !requestedAt
            ? t("Next refresh in about %s", every(Math.ceil(left / 1000))) : t("Refreshing…");
        progress.hidden = false;
    }

    async function draw(blob, rotate) {
        const bitmap = await createImageBitmap(blob);
        const sideways = rotate === 90 || rotate === 270;
        canvas.width = sideways ? bitmap.height : bitmap.width;
        canvas.height = sideways ? bitmap.width : bitmap.height;

        const context = canvas.getContext("2d");
        context.save();
        context.translate(canvas.width / 2, canvas.height / 2);
        context.rotate((rotate * Math.PI) / 180);
        context.drawImage(bitmap, -bitmap.width / 2, -bitmap.height / 2);
        context.restore();
        bitmap.close();
        canvas.hidden = false;
    }

    function showLocked(message) {
        note.textContent = message;
        unlockButton.hidden = false;
        refreshButton.hidden = true;
        saveButton.hidden = true;
        canvas.hidden = true;
        progress.hidden = true;
        shownCapture = 0;
        shownBlob = null;
        lastStatus = null;
        capturedAt = 0;
    }

    function stopLive() {
        clearTimeout(liveRetry);
        if (live) live.abort();
        live = null;
    }

    function joined(a, b) {
        const out = new Uint8Array(a.length + b.length);
        out.set(a);
        out.set(b, a.length);
        return out;
    }

    function headerEnd(bytes) {
        for (let i = 0; i + 3 < bytes.length; i++) {
            if (bytes[i] === 13 && bytes[i + 1] === 10 && bytes[i + 2] === 13 && bytes[i + 3] === 10) return i;
        }
        return -1;
    }

    async function startLive(rotate) {
        if (live) return;
        const controller = new AbortController();
        live = controller;
        note.textContent = t("Connecting to the live screen…");

        let latest = null;
        let drawing = false;
        const show = async () => {
            if (drawing) return;
            drawing = true;
            while (latest) {
                const blob = latest;
                latest = null;
                try {
                    await draw(blob, rotate);
                    shownBlob = blob;
                    capturedAt = Date.now();
                    saveButton.hidden = false;
                } catch (_) {
                }
            }
            drawing = false;
        };

        try {
            const response = await MU.fetchAuthed("api/screen/live", {signal: controller.signal});
            if (!response.ok || !response.body) {
                if (response.status === 404) liveUnavailable = true;
                throw new Error(String(response.status));
            }

            note.textContent = t("Live. The screen streams while this page is open.");
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let pending = new Uint8Array(0);

            for (;;) {
                const {value, done} = await reader.read();
                if (done) break;
                pending = joined(pending, value);

                for (;;) {
                    const end = headerEnd(pending);
                    if (end < 0) break;
                    const head = decoder.decode(pending.subarray(0, end));
                    const size = /Content-Length:\s*(\d+)/i.exec(head);
                    const type = /Content-Type:\s*([^\r\n;]+)/i.exec(head);
                    const start = end + 4;
                    if (!size) {
                        pending = pending.slice(start);
                        continue;
                    }
                    const length = Number(size[1]);
                    if (pending.length < start + length + 2) break;

                    const body = pending.slice(start, start + length);
                    pending = pending.slice(start + length + 2);

                    if (type && type[1].trim() === "image/jpeg") {
                        note.textContent = t("Live. The screen streams while this page is open.");
                        latest = new Blob([body], {type: "image/jpeg"});
                        show();
                    } else {
                        canvas.hidden = true;
                        note.textContent = t("A private screen is open on the device, so it is not shown.");
                    }
                }
            }
        } catch (_) {
        }

        if (live !== controller) return;
        live = null;
        if (open() && allowed() && !liveUnavailable) liveRetry = setTimeout(() => tick("GET"), 2000);
        else if (liveUnavailable) tick("GET");
    }

    async function refresh(method) {
        if (!allowed()) {
            stopLive();
            return showLocked(t("Unlock with the Web Dashboard Code to see the screen."));
        }

        let status;
        try {
            status = method === "POST"
                ? await MU.api("api/screen", {method: "POST"})
                : await MU.api("api/screen");
        } catch (error) {
            if (allowed()) note.textContent = t(error.message);
            else showLocked(t(error.message));
            return;
        }

        if (method === "POST") requestedAt = Date.now();
        if (requestedAt && (status.captured !== shownCapture || Date.now() - requestedAt > REQUEST_WAIT)) requestedAt = 0;

        if (status.live && !liveUnavailable) {
            unlockButton.hidden = true;
            refreshButton.hidden = true;
            progress.hidden = true;
            lastStatus = null;
            startLive(status.rotate || 0);
            return "live";
        }

        lastStatus = status;
        capturedAt = status.captured && status.age >= 0 ? Date.now() - status.age * 1000 : 0;
        unlockButton.hidden = true;
        refreshButton.hidden = false;
        note.textContent = describe(status);
        paintBar();

        if (!status.captured || status.captured === shownCapture) return;

        const response = await MU.fetchAuthed(`api/screen/image?_=${status.captured}`);
        if (!response.ok) return;

        shownBlob = await response.blob();
        shownCapture = status.captured;
        await draw(shownBlob, status.rotate || 0);
        saveButton.hidden = false;
    }

    function schedule() {
        clearTimeout(pollTimer);
        if (!open()) return;

        const left = remaining();
        const wait = !lastStatus || left <= 0 || requestedAt ? CATCH_UP : Math.min(POLL, left + 500);
        pollTimer = setTimeout(() => tick("GET"), wait);
    }

    async function tick(method) {
        if (!open()) {
            stopLive();
            return;
        }
        if (ticking || live) return;
        ticking = 1;
        let mode = "";
        try {
            mode = await refresh(method);
        } catch (_) {
            note.textContent = t("Could not reach the device.");
        } finally {
            ticking = 0;
            if (mode !== "live") schedule();
        }
    }

    function start() {
        clearInterval(barTimer);
        barTimer = setInterval(() => {
            if (open()) paintBar();
        }, 1000);
        tick("GET");
    }

    refreshButton.addEventListener("click", () => tick("POST"));

    saveButton.addEventListener("click", () => {
        if (!shownBlob) return;
        canvas.toBlob((blob) => {
            if (!blob) return;
            const link = document.createElement("a");
            link.href = URL.createObjectURL(blob);
            const when = new Date(capturedAt || Date.now());
            const pad = (value) => String(value).padStart(2, "0");
            link.download = `remote-view-${when.getFullYear()}${pad(when.getMonth() + 1)}${pad(when.getDate())}-`
                + `${pad(when.getHours())}${pad(when.getMinutes())}${pad(when.getSeconds())}.png`;
            document.body.append(link);
            link.click();
            link.remove();
            setTimeout(() => URL.revokeObjectURL(link.href), 10000);
            showToast(t("Image saved"), "good");
        }, "image/png");
    });

    unlockButton.addEventListener("click", () => MU.unlock());

    document.addEventListener("visibilitychange", () => tick("GET"));
    new MutationObserver(() => {
        if (el("view-remote").hidden) stopLive();
    }).observe(el("view-remote"), {attributes: true, attributeFilter: ["hidden"]});
    MU.onAuthChange(() => {
        if (!allowed()) stopLive();
        if (!el("view-remote").hidden) tick("GET");
    });

    register("remote", {load: start, restore: start});
}());
