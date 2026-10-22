(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast, clock} = MU;
    const POLL = 2000;
    const IDLE_POLL = 8000;

    const box = el("game-box");
    const title = el("game-title");
    const detail = el("game-detail");
    const stateText = el("game-state");
    const toggle = el("game-toggle");
    const pauseIcon = el("game-pause-icon");
    const playIcon = el("game-play-icon");
    const slow = el("game-slow");
    const fast = el("game-fast");
    const fps = el("game-fps");
    const save = el("game-save");
    const load = el("game-load");
    const quit = el("game-quit");
    const unlock = el("game-unlock");
    const controls = [toggle, slow, fast, fps, save, load, quit];

    let state = null;
    let pollTimer = 0;
    let sending = false;

    const visible = () => !document.hidden && (!el("view-dash").hidden || !el("view-playing").hidden);

    function paintPlaying() {
        const wasabi = Boolean(MU.playerState);
        const pickles = Boolean(state);
        el("playing-empty").hidden = wasabi || pickles;

        const link = el("playing-link");
        link.hidden = !wasabi && !pickles;
        const name = pickles ? state.name : wasabi ? MU.playerState.title : "";
        el("playing-link-text").textContent = pickles ? t("%s is running in Pickles.", name || t("A game"))
            : t("%s is playing in Wasabi.", name || t("Something"));
    }

    MU.paintPlaying = paintPlaying;

    function paint() {
        if (!state) {
            box.hidden = true;
            paintPlaying();
            return;
        }

        box.hidden = false;
        const canControl = MU.canControlPlayer();
        unlock.hidden = canControl;

        title.textContent = state.name || t("Unknown");
        const parts = [];
        if (state.folder) parts.push(state.folder);
        if (state.library || state.core) parts.push(state.library || state.core);
        parts.push(t("Played for %s", clock(state.played)));
        detail.textContent = parts.join(" · ");

        const notes = [];
        if (state.menu) notes.push(t("The Pickles menu is open on the device, so only Quit works until it closes."));
        else if (state.paused) notes.push(t("Paused."));
        else if (state.speed === "fast_forward") notes.push(t("Fast forward is on."));
        else if (state.speed === "slow_motion") notes.push(t("Slow motion is on."));
        if (state.fps > 0 && !state.paused && !state.menu) notes.push(t("%s frames a second.", Number(state.fps).toFixed(1)));
        if (state.netplay) notes.push(t("Netplay is active, so pausing and speed changes are not available."));
        stateText.textContent = notes.join(" ");
        stateText.hidden = !notes.length;

        const blocked = !canControl || sending;
        const menuOpen = Boolean(state.menu);
        toggle.disabled = blocked || menuOpen || Boolean(state.netplay);
        slow.disabled = blocked || menuOpen || Boolean(state.netplay) || Boolean(state.paused);
        fast.disabled = blocked || menuOpen || Boolean(state.netplay) || Boolean(state.paused);
        fps.disabled = blocked || menuOpen;
        save.disabled = blocked || menuOpen || !state.saves;
        load.disabled = blocked || menuOpen || !state.saves || !state.quicksave;
        quit.disabled = blocked;

        pauseIcon.toggleAttribute("hidden", Boolean(state.paused));
        playIcon.toggleAttribute("hidden", !state.paused);
        toggle.setAttribute("aria-label", state.paused ? t("Resume") : t("Pause"));
        slow.setAttribute("aria-pressed", String(state.speed === "slow_motion"));
        fast.setAttribute("aria-pressed", String(state.speed === "fast_forward"));
        slow.classList.toggle("on", state.speed === "slow_motion");
        fast.classList.toggle("on", state.speed === "fast_forward");

        paintPlaying();
    }

    async function refresh() {
        try {
            const payload = await MU.api("api/game");
            state = payload && payload.active !== false ? payload : null;
        } catch (_) {
            state = null;
        }
        MU.gameState = state;
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

    async function send(command, value, done) {
        if (sending) return;
        sending = true;
        paint();
        try {
            await MU.api(`api/game/${command}`, {
                method: "POST",
                type: "text/plain",
                body: value === undefined ? "" : String(value)
            });
            if (done) showToast(done, "good");
            await new Promise((resolve) => setTimeout(resolve, 300));
            await refresh();
        } catch (error) {
            showToast(error.message, "bad");
        } finally {
            sending = false;
            paint();
        }
    }

    toggle.addEventListener("click", () => send(state && state.paused ? "resume" : "pause"));
    slow.addEventListener("click", () => send("slow_motion", state && state.speed === "slow_motion" ? 0 : 1));
    fast.addEventListener("click", () => send("fast_forward", state && state.speed === "fast_forward" ? 0 : 1));
    fps.addEventListener("click", () => send("fps"));
    save.addEventListener("click", () => send("quicksave", undefined, t("Quick Save sent")));

    load.addEventListener("click", async () => {
        const sure = await MU.ask({
            title: t("Quick Load"),
            message: t("Load the quick save in %s? Anything since that save is lost.", (state && state.name) || t("this game")),
            confirm: t("Quick Load"),
            danger: true
        });
        if (sure) send("quickload", undefined, t("Quick Load sent"));
    });

    quit.addEventListener("click", async () => {
        const sure = await MU.ask({
            title: t("Quit"),
            message: t("Quit %s and return to the menu? Pickles saves automatically first when Auto Save is on.",
                (state && state.name) || t("this game")),
            confirm: t("Quit"),
            danger: true
        });
        if (sure) send("quit", undefined, t("Quit sent"));
    });

    unlock.addEventListener("click", () => MU.unlock());

    document.addEventListener("visibilitychange", () => {
        if (visible()) refresh();
        schedule();
    });
    MU.onAuthChange(paint);
    document.querySelectorAll('[data-view="dash"], [data-view="playing"]').forEach((tab) => {
        tab.addEventListener("click", refresh);
    });

    MU.register("playing", {load: refresh, restore: refresh});

    refresh().then(schedule);
}());
