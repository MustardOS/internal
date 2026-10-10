(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast} = MU;
    const runtime = window.MUOS_RUNTIME || {};
    const RENEW = 500;
    const LEVEL_REPEAT = 200;

    const pad = el("remote-pad");
    const note = el("remote-pad-note");
    const buttons = Array.from(pad.querySelectorAll("[data-button]"));
    const levels = Array.from(pad.querySelectorAll("[data-level]"));

    const KEYS = [
        ["KeyW", "up", "W"], ["KeyA", "left", "A"], ["KeyS", "down", "S"], ["KeyD", "right", "D"],
        ["KeyI", "x", "I"], ["KeyJ", "y", "J"], ["KeyK", "b", "K"], ["KeyL", "a", "L"],
        ["KeyG", "menu", "G"], ["KeyF", "select", "F"], ["KeyH", "start", "H"],
        ["KeyQ", "l1", "Q"], ["KeyE", "l2", "E"], ["KeyR", "l3", "R"],
        ["KeyY", "r3", "Y"], ["KeyU", "r2", "U"], ["KeyO", "r1", "O"],
        ["KeyC", "brightness/down", "C"], ["KeyV", "volume/down", "V"],
        ["KeyB", "brightness/up", "B"], ["KeyN", "volume/up", "N"]
    ];
    const NAMES = {
        up: "Up", down: "Down", left: "Left", right: "Right", a: "A", b: "B", x: "X", y: "Y",
        l1: "L1", r1: "R1", l2: "L2", r2: "R2", l3: "L3", r3: "R3", select: "Select", start: "Start", menu: "Menu",
        "volume/down": "Volume down", "volume/up": "Volume up",
        "brightness/down": "Brightness down", "brightness/up": "Brightness up"
    };
    const byCode = new Map(KEYS.map(([code, action]) => [code, action]));

    let available = new Set();
    let ready = false;
    let queue = Promise.resolve();
    let failed = false;
    const held = new Map();
    const repeating = new Map();

    const shown = () => !pad.hidden && !el("view-remote").hidden;
    const paused = () => Boolean(MU.remotePaused && MU.remotePaused());
    const allowed = () => Boolean(runtime.remoteControlPublic) || MU.canManage();

    function send(path, body) {
        queue = queue.then(async () => {
            try {
                await Promise.race([
                    MU.api(`api/input/${path}`, {method: "POST", type: "text/plain", body}),
                    new Promise((_, reject) => setTimeout(() => reject(new Error(t("The device did not answer."))), 3000))
                ]);
                failed = false;
            } catch (error) {
                if (!failed) showToast(error.message, "bad");
                failed = true;
                if (!allowed()) releaseAll(false);
            }
        });
        return queue;
    }

    function mark(action, down) {
        for (const button of pad.querySelectorAll(`[data-button="${action}"], [data-level="${action}"]`)) {
            button.classList.toggle("down", down);
        }
    }

    function press(name) {
        if (!available.has(name) || held.has(name)) return;
        mark(name, true);
        send(name, "1");
        held.set(name, setInterval(() => send(name, "1"), RENEW));
    }

    function release(name) {
        if (!held.has(name)) return;
        clearInterval(held.get(name));
        held.delete(name);
        mark(name, false);
        send(name, "0");
    }

    function levelStart(action) {
        if (repeating.has(action)) return;
        mark(action, true);
        send(action, "");
        repeating.set(action, setInterval(() => send(action, ""), LEVEL_REPEAT));
    }

    function levelStop(action) {
        if (!repeating.has(action)) return;
        clearInterval(repeating.get(action));
        repeating.delete(action);
        mark(action, false);
    }

    function releaseAll(tell) {
        const any = held.size > 0;
        for (const name of Array.from(held.keys())) release(name);
        for (const action of Array.from(repeating.keys())) levelStop(action);
        if (tell && any) send("clear", "");
    }

    function startAction(action) {
        if (paused()) return;
        if (action.includes("/")) levelStart(action);
        else press(action);
    }

    function stopAction(action) {
        if (action.includes("/")) levelStop(action);
        else release(action);
    }

    function bindPointer(element, action) {
        element.addEventListener("pointerdown", (event) => {
            if (event.button !== 0) return;
            event.preventDefault();
            element.setPointerCapture(event.pointerId);
            startAction(action);
        });
        const stop = () => stopAction(action);
        element.addEventListener("pointerup", stop);
        element.addEventListener("pointercancel", stop);
        element.addEventListener("lostpointercapture", stop);
        element.addEventListener("contextmenu", (event) => event.preventDefault());
        element.addEventListener("keydown", (event) => {
            if ((event.key === "Enter" || event.key === " ") && !event.repeat) {
                event.preventDefault();
                event.stopPropagation();
                startAction(action);
            }
        });
        element.addEventListener("keyup", (event) => {
            if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                event.stopPropagation();
                stopAction(action);
            }
        });
    }

    for (const button of buttons) bindPointer(button, button.dataset.button);
    for (const button of levels) bindPointer(button, button.dataset.level);

    function typing(target) {
        if (!(target instanceof Element)) return false;
        return Boolean(target.closest("input, textarea, select, [contenteditable=''], [contenteditable='true']"));
    }

    document.addEventListener("keydown", (event) => {
        if (!shown() || event.ctrlKey || event.altKey || event.metaKey || typing(event.target)) return;
        const action = byCode.get(event.code);
        if (!action) return;
        event.preventDefault();
        if (event.repeat) return;
        startAction(action);
    });

    document.addEventListener("keyup", (event) => {
        const action = byCode.get(event.code);
        if (!action) return;
        stopAction(action);
    });

    window.addEventListener("blur", () => releaseAll(true));
    document.addEventListener("visibilitychange", () => {
        if (document.hidden) releaseAll(true);
    });

    function addHints() {
        for (const [, action, label] of KEYS) {
            for (const button of pad.querySelectorAll(`[data-button="${action}"], [data-level="${action}"]`)) {
                if (button.querySelector(".pad-hint")) continue;
                const hint = document.createElement("kbd");
                hint.className = "pad-hint";
                hint.textContent = label;
                hint.setAttribute("aria-hidden", "true");
                button.append(hint);
                button.title = t("%s (key %s)", t(NAMES[action]), label);
            }
        }
    }

    addHints();

    function applyPause() {
        const off = paused();
        if (off) releaseAll(true);
        pad.classList.toggle("paused", off);
        for (const button of buttons) button.disabled = off || !available.has(button.dataset.button);
        for (const button of levels) button.disabled = off;
        if (pad.hidden) return;
        note.textContent = off ? t("The controls are off while Remote View is paused.") : "";
        note.hidden = !off;
    }

    document.addEventListener("muos-remote-pause", applyPause);

    function hide(message) {
        releaseAll(false);
        document.body.classList.remove("remote-has-pad");
        pad.hidden = true;
        note.textContent = message || "";
        note.hidden = !message;
    }

    async function load() {
        if (runtime.remoteControlNeedsAuth) {
            return hide(t("Remote Controls need Authentication, or Live with Remote View Privacy disabled. Change this in Web Services on the device to use them."));
        }
        if (!runtime.remoteControl) return hide("");
        if (!allowed()) return hide(t("Unlock with the Web Dashboard Code to use the controls."));

        let state;
        try {
            state = await MU.api("api/input");
        } catch (error) {
            return hide(error.message);
        }

        available = new Set(state.buttons || []);
        ready = Boolean(state.ready);
        for (const button of buttons) button.disabled = !available.has(button.dataset.button);

        if (!ready) return hide(t("The device input service is not running."));
        note.hidden = true;
        pad.hidden = false;
        document.body.classList.add("remote-has-pad");
        applyPause();
    }

    new MutationObserver(() => {
        if (el("view-remote").hidden) releaseAll(true);
        else load();
    }).observe(el("view-remote"), {attributes: true, attributeFilter: ["hidden"]});

    MU.onAuthChange(() => {
        if (!el("view-remote").hidden) load();
    });
}());
