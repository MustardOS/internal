(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast} = MU;
    const runtime = window.MUOS_RUNTIME || {};
    const settings = typeof runtime.remoteSound === "object" && runtime.remoteSound ? runtime.remoteSound : null;
    const FRAME_BYTES = 4;
    const LEAD = Math.max(40, Math.min(1000, Number(settings && settings.buffer) || 150)) / 1000;
    const MAX_LAG = LEAD + 0.35;
    const SOUND_KEY = "muos-remote-sound";

    let rate = Math.max(8000, Math.min(48000, Number(settings && settings.rate) || 24000));

    const toggle = el("remote-sound");

    let wanted = false;
    try {
        wanted = localStorage.getItem(SOUND_KEY) === "on";
    } catch (_) {
    }

    let context = null;
    let stream = null;
    let nextTime = 0;

    const allowed = () => Boolean(runtime.remotePublic) || MU.canManage();
    const visible = () => !document.hidden && !el("view-remote").hidden;
    const paused = () => Boolean(MU.remotePaused && MU.remotePaused());

    function label(on) {
        toggle.setAttribute("aria-pressed", String(on));
        toggle.querySelectorAll("[data-when]").forEach((glyph) => {
            glyph.toggleAttribute("hidden", (glyph.dataset.when === "on") !== on);
        });
        toggle.title = on ? t("Stop the sound from the device") : t("Play the sound from the device");
    }

    function remember(on) {
        wanted = on;
        try {
            localStorage.setItem(SOUND_KEY, on ? "on" : "off");
        } catch (_) {
        }
    }

    function play(samples, frames) {
        const buffer = context.createBuffer(2, frames, rate);
        const left = buffer.getChannelData(0);
        const right = buffer.getChannelData(1);
        for (let i = 0; i < frames; i++) {
            left[i] = samples[i * 2] / 32768;
            right[i] = samples[i * 2 + 1] / 32768;
        }

        const now = context.currentTime;
        if (nextTime < now || nextTime - now > MAX_LAG) nextTime = now + LEAD;

        const source = context.createBufferSource();
        source.buffer = buffer;
        source.connect(context.destination);
        source.start(nextTime);
        nextTime += buffer.duration;
    }

    function stop() {
        if (stream) stream.abort();
        stream = null;
        if (context) context.close().catch(() => {});
        context = null;
        label(false);
    }

    async function start() {
        if (stream || !settings || !allowed() || !visible() || paused()) return;

        const controller = new AbortController();
        stream = controller;
        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) {
            stream = null;
            showToast(t("This browser cannot play the sound from the device."), "bad");
            return;
        }

        context = new AudioContextClass();
        nextTime = 0;
        label(true);
        if (context.state === "suspended") {
            try {
                await context.resume();
            } catch (_) {
            }
        }
        if (context && context.state === "suspended") {
            stop();
            return;
        }

        try {
            const response = await MU.fetchAuthed("api/screen/audio", {signal: controller.signal});
            if (!response.ok || !response.body) {
                const problem = await response.json().catch(() => ({}));
                throw new Error(problem.error || t("The device did not send any sound."));
            }

            const format = /rate=(\d+)/.exec(response.headers.get("X-Audio-Format") || "");
            if (format) rate = Math.max(8000, Math.min(48000, Number(format[1])));
            const blockFrames = Math.round(rate / 20);

            const reader = response.body.getReader();
            let pending = new Uint8Array(0);
            for (;;) {
                const {value, done} = await reader.read();
                if (done || stream !== controller) break;

                const joined = new Uint8Array(pending.length + value.length);
                joined.set(pending);
                joined.set(value, pending.length);

                const blockBytes = blockFrames * FRAME_BYTES;
                let offset = 0;
                while (joined.length - offset >= blockBytes) {
                    const block = joined.slice(offset, offset + blockBytes);
                    play(new Int16Array(block.buffer), blockFrames);
                    offset += blockBytes;
                }
                pending = joined.slice(offset);
            }
        } catch (error) {
            if (stream === controller && error.name !== "AbortError") showToast(error.message, "bad");
        }

        if (stream === controller) stop();
    }

    toggle.addEventListener("click", () => {
        if (stream) {
            remember(false);
            stop();
        } else {
            remember(true);
            start();
        }
    });

    function refresh() {
        toggle.hidden = !settings || !allowed();
        if (toggle.hidden || !visible() || paused()) {
            stop();
            return;
        }
        if (wanted) start();
    }

    label(false);
    new MutationObserver(refresh).observe(el("view-remote"), {attributes: true, attributeFilter: ["hidden"]});
    document.addEventListener("visibilitychange", refresh);
    document.addEventListener("muos-remote-pause", refresh);
    MU.onAuthChange(refresh);
    refresh();
}());
