(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast, clock} = MU;
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
    const shuffle = el("player-shuffle");
    const repeat = el("player-repeat");
    const repeatOne = el("player-repeat-one");
    const listBox = el("player-list-box");
    const listSummary = el("player-list-summary");
    const list = el("player-list");
    const controls = [toggle, back, forward, previous, next, stop, seek, volume, shuffle, repeat];

    let listCount = -1;
    let listLoading = false;

    let state = null;
    let receivedAt = 0;
    let dragging = false;
    let adjusting = false;
    let pollTimer = 0;
    let sending = false;

    const visible = () => !document.hidden && (!el("view-dash").hidden || !el("view-playing").hidden);

    const REPEAT_LABELS = ["Repeat off", "Repeat this item", "Repeat all"];

    async function loadList() {
        if (listLoading) return;
        listLoading = true;
        try {
            const payload = await MU.api("api/player/list");
            const items = (payload && payload.items) || [];
            list.replaceChildren();
            for (const item of items) {
                const row = document.createElement("li");
                const button = document.createElement("button");
                button.type = "button";
                button.className = "player-list-item";
                button.dataset.index = String(item.index);
                button.textContent = item.title || t("Unknown");
                button.addEventListener("click", () => send("jump", item.index));
                row.append(button);
                list.append(row);
            }
            listCount = items.length;
        } catch (_) {
            listCount = -1;
        } finally {
            listLoading = false;
            paintList();
        }
    }

    function paintList() {
        if (!state || state.count < 2) {
            listBox.hidden = true;
            return;
        }
        listBox.hidden = false;
        listSummary.textContent = state.channels ? t("Channels (%s)", state.count) : t("Playlist (%s)", state.count);
        if (listCount !== state.count) loadList();
        const canControl = MU.canControlPlayer();
        list.querySelectorAll(".player-list-item").forEach((button) => {
            const current = Number(button.dataset.index) === state.index;
            button.classList.toggle("current", current);
            if (current) button.setAttribute("aria-current", "true");
            else button.removeAttribute("aria-current");
            button.disabled = !canControl || sending;
        });
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
        if (MU.paintPlaying) MU.paintPlaying();
    }

    function paint() {
        if (!state) {
            box.hidden = true;
            listCount = -1;
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

        const modes = !state.live && state.count > 0;
        shuffle.hidden = !modes || state.count < 2;
        repeat.hidden = !modes;
        shuffle.setAttribute("aria-pressed", String(Boolean(state.shuffle)));
        shuffle.classList.toggle("on", Boolean(state.shuffle));
        const repeatMode = Number(state.repeat) || 0;
        repeat.setAttribute("aria-label", t(REPEAT_LABELS[repeatMode] || REPEAT_LABELS[0]));
        repeat.title = t(REPEAT_LABELS[repeatMode] || REPEAT_LABELS[0]);
        repeat.classList.toggle("on", repeatMode > 0);
        repeatOne.hidden = repeatMode !== 1;

        paintList();
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
        if (state && target !== Number(state.volume)) {
            state = {...state, volume: target};
            await send("setvolume", target);
        }
        adjusting = false;
        paint();
    });
    shuffle.addEventListener("click", () => send("shuffle", state && state.shuffle ? 0 : 1));
    repeat.addEventListener("click", () => send("repeat", ((Number(state && state.repeat) || 0) + 1) % 3));
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
    document.querySelectorAll('[data-view="dash"], [data-view="playing"]').forEach((tab) => {
        tab.addEventListener("click", refresh);
    });

    refresh().then(schedule);
}());
