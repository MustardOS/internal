(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast} = MU;
    const POLL = 2000;
    const IDLE_POLL = 8000;

    const box = el("player-box");
    const heading = el("player-heading");
    const title = el("player-title");
    const detail = el("player-detail");
    const seekRow = el("player-seek-row");
    const seek = el("player-seek");
    const positionText = el("player-position");
    const durationText = el("player-duration");
    const toggle = el("player-toggle");
    const pauseIcon = el("player-pause-icon");
    const playIcon = el("player-play-icon");
    const back = el("player-back");
    const forward = el("player-forward");
    const previous = el("player-previous");
    const next = el("player-next");
    const volume = el("player-volume-slider");
    const volumeText = el("player-volume");
    const stop = el("player-stop");
    const unlock = el("player-unlock");
    const controls = [toggle, back, forward, previous, next, stop, seek, volume];

    let state = null;
    let receivedAt = 0;
    let dragging = false;
    let adjusting = false;
    let pollTimer = 0;
    let sending = false;

    const visible = () => !document.hidden && !el("view-dash").hidden;

    function clock(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        const rest = String(total % 60).padStart(2, "0");
        return hours ? `${hours}:${String(minutes).padStart(2, "0")}:${rest}` : `${minutes}:${rest}`;
    }

    function livePosition() {
        if (!state) return 0;
        const moving = !state.paused && !state.live;
        const position = state.position + (moving ? (Date.now() - receivedAt) / 1000 : 0);
        return state.duration > 0 ? Math.min(position, state.duration) : position;
    }

    function paintPosition() {
        if (!state || dragging || !state.seek) return;
        const position = livePosition();
        positionText.textContent = clock(position);
        seek.value = String(state.duration > 0 ? Math.round((position / state.duration) * 1000) : 0);
    }

    function publish() {
        MU.playerState = state;
        window.dispatchEvent(new CustomEvent("muos-player-state", {detail: state}));
    }

    function paint() {
        if (!state) {
            box.hidden = true;
            if (MU.playerState) publish();
            return;
        }

        box.hidden = false;
        const canControl = MU.canControlPlayer();
        unlock.hidden = canControl;
        controls.forEach((control) => {
            control.disabled = !canControl || sending;
        });

        heading.textContent = state.live ? t("Watching live TV in Wasabi")
            : state.audio ? t("Listening in Wasabi") : t("Watching in Wasabi");
        title.textContent = state.title || t("Unknown");

        const parts = [];
        if (state.artist) parts.push(state.artist);
        if (state.album) parts.push(state.album);
        if (state.count > 1) {
            parts.push(state.channels ? t("Channel %s of %s", state.index + 1, state.count)
                : t("Item %s of %s", state.index + 1, state.count));
        }
        detail.textContent = parts.join(" · ");
        detail.hidden = !parts.length;

        seekRow.hidden = !state.seek;
        back.hidden = !state.seek;
        forward.hidden = !state.seek;
        durationText.textContent = clock(state.duration);
        paintPosition();

        const stepping = state.count > 1;
        previous.hidden = !stepping;
        next.hidden = !stepping;
        previous.setAttribute("aria-label", state.channels ? t("Previous channel") : t("Previous"));
        next.setAttribute("aria-label", state.channels ? t("Next channel") : t("Next"));

        toggle.hidden = Boolean(state.live);
        pauseIcon.toggleAttribute("hidden", Boolean(state.paused));
        playIcon.toggleAttribute("hidden", !state.paused);
        toggle.setAttribute("aria-label", state.paused ? t("Play") : t("Pause"));
        if (!adjusting) {
            volume.value = String(state.volume);
            volumeText.textContent = `${state.volume}%`;
        }
        publish();
    }

    async function refresh() {
        try {
            const payload = await MU.api("api/player");
            state = payload && payload.active !== false ? payload : null;
            receivedAt = Date.now();
        } catch (_) {
            state = null;
        }
        paint();
    }

    function schedule() {
        clearTimeout(pollTimer);
        if (document.hidden) return;
        pollTimer = setTimeout(async () => {
            if (visible()) await refresh();
            schedule();
        }, visible() && state ? POLL : IDLE_POLL);
    }

    async function send(command, value) {
        if (sending) return;
        sending = true;
        if (command === "toggle" && state) {
            state = {...state, paused: !Boolean(state.paused)};
            receivedAt = Date.now();
        }
        paint();
        try {
            await MU.api(`api/player/${command}`, {
                method: "POST",
                type: "text/plain",
                body: value === undefined ? "" : String(value)
            });
            await new Promise((resolve) => setTimeout(resolve, 200));
            await refresh();
            setTimeout(refresh, 500);
        } catch (error) {
            showToast(error.message, "bad");
        } finally {
            sending = false;
            paint();
        }
    }

    toggle.addEventListener("click", () => send("toggle"));
    back.addEventListener("click", () => send("skip", -10));
    forward.addEventListener("click", () => send("skip", 10));
    previous.addEventListener("click", () => send("previous"));
    next.addEventListener("click", () => send("next"));
    volume.addEventListener("input", () => {
        adjusting = true;
        volumeText.textContent = `${volume.value}%`;
    });
    volume.addEventListener("change", async () => {
        const target = Number(volume.value);
        const change = state ? target - Number(state.volume) : 0;
        if (change) {
            state = {...state, volume: target};
            await send("volume", change);
        }
        adjusting = false;
        paint();
    });
    stop.addEventListener("click", () => send("stop"));
    unlock.addEventListener("click", () => MU.unlock());

    seek.addEventListener("input", () => {
        dragging = true;
        if (state && state.duration > 0) positionText.textContent = clock((seek.value / 1000) * state.duration);
    });
    seek.addEventListener("change", async () => {
        dragging = false;
        if (state && state.duration > 0) await send("seek", ((seek.value / 1000) * state.duration).toFixed(2));
    });

    setInterval(() => {
        if (visible()) paintPosition();
    }, 500);

    document.addEventListener("visibilitychange", () => {
        if (visible()) refresh();
        schedule();
    });
    MU.onAuthChange(paint);
    document.querySelectorAll('[data-view="dash"]').forEach((tab) => tab.addEventListener("click", refresh));

    refresh().then(schedule);
}());
