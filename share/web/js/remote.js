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
    const pauseButton = el("remote-pause");
    const popoutButton = el("remote-popout");
    const layoutButtons = Array.from(el("remote-layout").querySelectorAll("[data-layout]"));
    const LAYOUT_KEY = "muos-remote-layout";
    const SCREEN_KEY = "muos-remote-screen";
    const screenToggle = el("remote-screen-toggle");

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
    let liveBlocked = false;
    let liveEmpty = 0;
    const FIRST_FRAME_WAIT = 8000;
    let mode = null;
    let paused = false;
    let pendingShow = false;
    let popped = null;

    el("nav-remote").hidden = !runtime.remoteView;

    let layout = "desktop";
    try {
        if (localStorage.getItem(LAYOUT_KEY) === "mobile") layout = "mobile";
    } catch (_) {
    }

    let screenOff = false;
    try {
        screenOff = localStorage.getItem(SCREEN_KEY) === "off";
    } catch (_) {
    }

    function applyScreen() {
        el("view-remote").classList.toggle("screen-off", screenOff);
        screenToggle.setAttribute("aria-pressed", String(screenOff));
        screenToggle.textContent = t(screenOff ? "Show Live View" : "Hide Live View");
    }

    function applyLayout() {
        for (const button of layoutButtons) button.setAttribute("aria-pressed", String(button.dataset.layout === layout));
        document.body.classList.toggle("remote-mobile", layout === "mobile" && !el("view-remote").hidden);
    }

    applyScreen();

    screenToggle.addEventListener("click", () => {
        screenOff = !screenOff;
        try {
            localStorage.setItem(SCREEN_KEY, screenOff ? "off" : "on");
        } catch (_) {
        }
        applyScreen();
        if (screenOff) {
            stopLive();
            clearTimeout(pollTimer);
        } else {
            tick("GET");
        }
    });

    for (const button of layoutButtons) {
        button.addEventListener("click", () => {
            layout = button.dataset.layout;
            try {
                localStorage.setItem(LAYOUT_KEY, layout);
            } catch (_) {
            }
            applyLayout();
        });
    }

    const open = () => Boolean(popped) || (!document.hidden && !el("view-remote").hidden);
    const allowed = () => Boolean(runtime.remotePublic) || MU.canManage();

    function every(seconds) {
        return seconds >= 60 ? `${Math.round(seconds / 60)}m` : `${seconds}s`;
    }

    const holding = () => mode === "manual" || paused;

    function announcePause() {
        document.dispatchEvent(new CustomEvent("muos-remote-pause", {detail: paused}));
    }

    MU.remotePaused = () => paused;

    function chooseMode(status) {
        const previous = mode;
        if (status.manual) mode = "manual";
        else if (status.live && !liveUnavailable) mode = "live";
        else mode = "timed";
        if (previous && previous !== mode && paused) {
            paused = false;
            announcePause();
        }
    }

    function updateControls() {
        pauseButton.hidden = !allowed() || mode === "manual";
        pauseButton.textContent = t(paused ? "Resume" : "Pause");
        refreshButton.hidden = !allowed() || mode === "live";
        popoutButton.hidden = !allowed() || canvas.hidden;
        popoutButton.textContent = t(popped ? "Close pop out" : "Pop out");
    }

    function describe(status) {
        if (mode === "manual") {
            const parts = [t("Manual. Press Refresh now to capture the screen.")];
            if (capturedAt) parts.push(t("Captured at %s.", new Date(capturedAt).toLocaleTimeString()));
            if (status.state === "hidden") parts.push(t("A private screen is open on the device, so it was not captured."));
            if (status.state === "failed") parts.push(t("The last capture failed."));
            return parts.join(" ");
        }
        if (paused) return t("Paused. The picture stays as it is until you press Resume.");

        const parts = [t("Updates every %s while this page is open.", every(status.interval))];
        if (liveBlocked) parts.unshift(t("This browser could not show the live stream, so pictures are used instead."));
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
        if (live || paused || mode !== "timed" || !lastStatus || !capturedAt) {
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
        updateControls();
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
        updateControls();
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
        let framed = false;
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
            const response = await MU.fetchAuthed("api/screen/live?raw=1", {signal: controller.signal});
            if (!response.ok || !response.body) {
                if (response.status === 404) liveUnavailable = true;
                throw new Error(String(response.status));
            }

            const firstFrame = setTimeout(() => {
                if (framed || live !== controller) return;
                liveEmpty = 2;
                controller.abort();
            }, FIRST_FRAME_WAIT);
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

                    if (!framed) clearTimeout(firstFrame);
                    framed = true;
                    liveEmpty = 0;
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

        if (!framed && !controller.signal.aborted) liveEmpty++;
        if (!framed && liveEmpty >= 2) {
            liveBlocked = true;
            liveUnavailable = true;
        }
        if (live !== controller && !liveBlocked) return;
        if (live === controller) live = null;
        if (paused || mode !== "live") return;
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
                : await MU.api(holding() && !requestedAt ? "api/screen?peek=1" : "api/screen");
        } catch (error) {
            if (allowed()) note.textContent = t(error.message);
            else showLocked(t(error.message));
            return;
        }

        if (method === "POST") {
            requestedAt = Date.now();
            pendingShow = true;
        }
        if (requestedAt && (status.captured !== shownCapture || Date.now() - requestedAt > REQUEST_WAIT)) requestedAt = 0;

        chooseMode(status);
        unlockButton.hidden = true;
        updateControls();

        if (mode === "live") {
            progress.hidden = true;
            lastStatus = null;
            if (paused) {
                note.textContent = t("Paused. The live screen stops until you press Resume.");
                return "paused";
            }
            startLive(status.rotate || 0);
            return "live";
        }

        lastStatus = status;
        const hold = holding() && !pendingShow && shownCapture;
        if (!hold) capturedAt = status.captured && status.age >= 0 ? Date.now() - status.age * 1000 : 0;
        note.textContent = describe(status);
        paintBar();

        if (!status.captured || status.captured === shownCapture || hold) return;
        pendingShow = false;

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
        if ((mode === "manual" || paused) && !requestedAt) return;

        const left = remaining();
        const wait = !lastStatus || left <= 0 || requestedAt ? CATCH_UP : Math.min(POLL, left + 500);
        pollTimer = setTimeout(() => tick("GET"), wait);
    }

    async function tick(method) {
        if (!open() || screenOff) {
            stopLive();
            return;
        }
        if (ticking || live) return;
        ticking = 1;
        let result = "";
        try {
            result = await refresh(method);
        } catch (_) {
            note.textContent = t("Could not reach the device.");
        } finally {
            ticking = 0;
            if (result !== "live" || paused) schedule();
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

    pauseButton.addEventListener("click", () => {
        paused = !paused;
        announcePause();
        if (paused) {
            stopLive();
            clearTimeout(pollTimer);
            progress.hidden = true;
        }
        updateControls();
        if (lastStatus) note.textContent = describe(lastStatus);
        if (paused && mode === "live") note.textContent = t("Paused. The live screen stops until you press Resume.");
        if (!paused) tick("GET");
    });

    function popoutSize() {
        const width = Math.min(canvas.width || 640, 640);
        const height = Math.round(width * ((canvas.height || 480) / (canvas.width || 640)));
        return {width, height};
    }

    function fitInto(element) {
        element.style.display = "block";
        element.style.width = "100%";
        element.style.height = "100%";
        element.style.objectFit = "contain";
        element.style.maxWidth = "none";
        element.style.border = "0";
        element.style.borderRadius = "0";
    }

    function prepareWindow(target) {
        const doc = target.document;
        doc.title = t("Remote View");
        doc.documentElement.style.height = "100%";
        doc.body.style.margin = "0";
        doc.body.style.height = "100%";
        doc.body.style.background = "#000";
        return doc;
    }

    function closePopped() {
        const was = popped;
        popped = null;
        if (!was) return;
        was.close();
        updateControls();
        if (!open()) stopLive();
        else tick("GET");
    }

    async function popOut() {
        if (popped) return closePopped();
        const size = popoutSize();

        if ("documentPictureInPicture" in window) {
            try {
                const pip = await window.documentPictureInPicture.requestWindow(size);
                const doc = prepareWindow(pip);
                const marker = document.createComment("remote-screen");
                canvas.before(marker);
                fitInto(canvas);
                doc.body.append(canvas);
                popped = {
                    close: () => {
                        for (const key of ["display", "width", "height", "objectFit", "maxWidth", "border", "borderRadius"]) {
                            canvas.style[key] = "";
                        }
                        marker.replaceWith(canvas);
                        if (!pip.closed) pip.close();
                    }
                };
                pip.addEventListener("pagehide", () => {
                    if (popped) closePopped();
                });
                updateControls();
                return;
            } catch (_) {
            }
        }

        const stream = canvas.captureStream ? canvas.captureStream() : null;
        if (!stream) {
            showToast(t("This browser cannot pop out Remote View."), "bad");
            return;
        }
        const stopStream = () => stream.getTracks().forEach((track) => track.stop());

        if (document.pictureInPictureEnabled && "requestPictureInPicture" in HTMLVideoElement.prototype) {
            const video = document.createElement("video");
            video.muted = true;
            video.playsInline = true;
            video.srcObject = stream;
            video.style.position = "fixed";
            video.style.width = "1px";
            video.style.height = "1px";
            video.style.opacity = "0";
            document.body.append(video);
            try {
                await video.play();
                await video.requestPictureInPicture();
                popped = {
                    close: () => {
                        if (document.pictureInPictureElement === video) document.exitPictureInPicture().catch(() => {});
                        stopStream();
                        video.remove();
                    }
                };
                video.addEventListener("leavepictureinpicture", () => {
                    if (popped) closePopped();
                });
                updateControls();
                return;
            } catch (_) {
                video.remove();
            }
        }

        const win = window.open("", "muos-remote-view", `popup,width=${size.width},height=${size.height}`);
        if (!win) {
            stopStream();
            showToast(t("Allow pop-ups for the dashboard to pop out Remote View."), "bad");
            return;
        }
        const doc = prepareWindow(win);
        doc.body.replaceChildren();
        const video = doc.createElement("video");
        video.muted = true;
        video.autoplay = true;
        video.playsInline = true;
        video.srcObject = stream;
        fitInto(video);
        doc.body.append(video);
        video.play().catch(() => {});
        popped = {
            close: () => {
                stopStream();
                if (!win.closed) win.close();
            }
        };
        const watch = setInterval(() => {
            if (!win.closed) return;
            clearInterval(watch);
            if (popped) closePopped();
        }, 1000);
        updateControls();
    }

    popoutButton.addEventListener("click", () => popOut());

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
        applyLayout();
        if (el("view-remote").hidden && !popped) stopLive();
    }).observe(el("view-remote"), {attributes: true, attributeFilter: ["hidden"]});
    MU.onAuthChange(() => {
        if (!allowed()) stopLive();
        if (!el("view-remote").hidden) tick("GET");
    });

    register("remote", {load: start, restore: start});
}());
