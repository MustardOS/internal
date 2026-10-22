(function () {
    "use strict";

    const MU = window.MU;
    const {el, t, showToast} = MU;
    const runtime = window.MUOS_RUNTIME || {};
    const RENEW = 1000;
    const LEVEL_REPEAT = 200;
    const STICK_GAP = 33;
    const STICK_KEEP = 150;
    const STICK_STEP = 0.02;
    const STICK_DEAD = 0.08;
    const PAD_DEAD = 0.12;

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
    const sticks = Array.from(pad.querySelectorAll("[data-stick]"));
    const gamepadNote = el("remote-gamepad");

    // Standard Gamepad API layout, by position: bottom face button is B and right is A on the device
    const GAMEPAD_BUTTONS = ["b", "a", "y", "x", "l1", "r1", "l2", "r2", "select", "start", "l3", "r3",
        "up", "down", "left", "right", "menu"];

    let available = new Set();
    let ready = false;
    let queue = Promise.resolve();
    let failed = false;
    let localLocked = false;
    const held = new Map();
    const repeating = new Map();

    const shown = () => !pad.hidden && !el("view-remote").hidden;
    const paused = () => Boolean(MU.remotePaused && MU.remotePaused());
    const controlsOff = () => paused() || localLocked;
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

    const stickLevels = {lx: 0, ly: 0, rx: 0, ry: 0};
    const stickSent = {lx: 0, ly: 0, rx: 0, ry: 0};
    const pointerSticks = new Map();
    let stickBusy = false;
    let stickTimer = 0;
    let stickLast = 0;

    function stickAxes(side) {
        return side === "l" ? ["lx", "ly"] : ["rx", "ry"];
    }

    function stickAvailable(side) {
        const [x, y] = stickAxes(side);
        return available.has(x) && available.has(y);
    }

    function drawStick(side) {
        const stick = pad.querySelector(`[data-stick="${side}"]`);
        if (!stick) return;
        const [x, y] = stickAxes(side);
        const knob = stick.querySelector(".pad-stick-knob");
        const reach = (stick.clientWidth - knob.offsetWidth) / 2;
        knob.style.transform = `translate(${stickLevels[x] * reach}px, ${stickLevels[y] * reach}px)`;
        stick.classList.toggle("down", stickLevels[x] !== 0 || stickLevels[y] !== 0);
    }

    function stickChanged() {
        return Object.keys(stickLevels).some((axis) => Math.abs(stickLevels[axis] - stickSent[axis]) >= STICK_STEP ||
            (stickLevels[axis] === 0) !== (stickSent[axis] === 0));
    }

    function stickActive() {
        return Object.values(stickLevels).some((level) => level !== 0);
    }

    function flushSticks() {
        clearTimeout(stickTimer);
        stickTimer = 0;
        if (stickBusy) return;

        const now = Date.now();
        const due = stickChanged() || (stickActive() && now - stickLast >= STICK_KEEP);
        if (!due) {
            if (stickActive()) stickTimer = setTimeout(flushSticks, STICK_KEEP);
            return;
        }
        if (now - stickLast < STICK_GAP) {
            stickTimer = setTimeout(flushSticks, STICK_GAP - (now - stickLast));
            return;
        }

        const parts = [];
        for (const axis of Object.keys(stickLevels)) {
            if (!available.has(axis)) continue;
            parts.push(`${axis} ${stickLevels[axis].toFixed(3)}`);
            stickSent[axis] = stickLevels[axis];
        }
        if (!parts.length) return;

        stickBusy = true;
        stickLast = now;
        Promise.race([
            MU.api("api/input/stick", {method: "POST", type: "text/plain", body: parts.join(" ")}),
            new Promise((_, reject) => setTimeout(() => reject(new Error(t("The device did not answer."))), 3000))
        ]).then(() => {
            failed = false;
        }).catch((error) => {
            if (!failed) showToast(error.message, "bad");
            failed = true;
        }).finally(() => {
            stickBusy = false;
            flushSticks();
        });
    }

    function setStick(side, x, y) {
        const length = Math.hypot(x, y);
        if (length > 1) {
            x /= length;
            y /= length;
        }
        if (length < STICK_DEAD) x = y = 0;
        const [ax, ay] = stickAxes(side);
        stickLevels[ax] = Math.round(x * 1000) / 1000;
        stickLevels[ay] = Math.round(y * 1000) / 1000;
        drawStick(side);
        flushSticks();
    }

    function centreSticks() {
        pointerSticks.clear();
        for (const side of ["l", "r"]) setStick(side, 0, 0);
    }

    function releaseAll(tell) {
        const any = held.size > 0 || stickActive();
        for (const name of Array.from(held.keys())) release(name);
        for (const action of Array.from(repeating.keys())) levelStop(action);
        centreSticks();
        if (tell && any) send("clear", "");
    }

    function startAction(action) {
        if (controlsOff()) return;
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

    function stickFromPointer(stick, event) {
        const box = stick.getBoundingClientRect();
        const knob = stick.querySelector(".pad-stick-knob");
        const reach = Math.max(1, (box.width - knob.offsetWidth) / 2);
        setStick(stick.dataset.stick, (event.clientX - (box.left + box.width / 2)) / reach,
            (event.clientY - (box.top + box.height / 2)) / reach);
    }

    for (const stick of sticks) {
        stick.addEventListener("pointerdown", (event) => {
            if (event.button !== 0 || controlsOff() || stick.classList.contains("disabled")) return;
            event.preventDefault();
            stick.setPointerCapture(event.pointerId);
            pointerSticks.set(event.pointerId, stick);
            stickFromPointer(stick, event);
        });
        stick.addEventListener("pointermove", (event) => {
            if (pointerSticks.get(event.pointerId) === stick) stickFromPointer(stick, event);
        });
        const stop = (event) => {
            if (pointerSticks.get(event.pointerId) !== stick) return;
            pointerSticks.delete(event.pointerId);
            setStick(stick.dataset.stick, 0, 0);
        };
        stick.addEventListener("pointerup", stop);
        stick.addEventListener("pointercancel", stop);
        stick.addEventListener("lostpointercapture", stop);
        stick.addEventListener("contextmenu", (event) => event.preventDefault());
    }

    const gamepadHeld = new Set();
    let gamepadFrame = 0;
    let gamepadName = "";

    function gamepads() {
        try {
            return navigator.getGamepads ? Array.from(navigator.getGamepads()).filter(Boolean) : [];
        } catch (_) {
            return [];
        }
    }

    function axis(value) {
        return Math.abs(value) < PAD_DEAD ? 0 : value;
    }

    function showGamepad(name) {
        if (name === gamepadName) return;
        gamepadName = name;
        gamepadNote.textContent = name ? t("Using %s.", name) : "";
        gamepadNote.hidden = !name;
    }

    function pollGamepad() {
        gamepadFrame = 0;
        const usable = shown() && !controlsOff() && allowed();
        const gamepad = usable ? gamepads().find((candidate) => candidate.connected) : null;

        if (!gamepad) {
            for (const name of Array.from(gamepadHeld)) {
                gamepadHeld.delete(name);
                release(name);
            }
            showGamepad("");
            return;
        }

        showGamepad(gamepad.id.replace(/\s*\(.*\)\s*$/, "") || t("a game controller"));

        GAMEPAD_BUTTONS.forEach((name, index) => {
            const button = gamepad.buttons[index];
            const down = Boolean(button && (button.pressed || button.value > 0.5));
            if (down && !gamepadHeld.has(name) && available.has(name)) {
                gamepadHeld.add(name);
                press(name);
            } else if (!down && gamepadHeld.has(name)) {
                gamepadHeld.delete(name);
                release(name);
            }
        });

        if (!pointerSticks.size) {
            const [lx, ly, rx, ry] = [0, 1, 2, 3].map((index) => axis(gamepad.axes[index] || 0));
            if (stickAvailable("l")) setStick("l", lx, ly);
            if (stickAvailable("r")) setStick("r", rx, ry);
        }

        gamepadFrame = requestAnimationFrame(pollGamepad);
    }

    function watchGamepad() {
        if (!gamepadFrame && gamepads().length) gamepadFrame = requestAnimationFrame(pollGamepad);
    }

    window.addEventListener("gamepadconnected", watchGamepad);
    window.addEventListener("gamepaddisconnected", () => {
        if (!gamepads().length) showGamepad("");
    });

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
        const off = controlsOff();
        if (off) releaseAll(true);
        pad.classList.toggle("paused", off);
        for (const button of buttons) button.disabled = off || !available.has(button.dataset.button);
        for (const button of levels) button.disabled = off;
        for (const stick of sticks) stick.classList.toggle("disabled", off);
        if (pad.hidden) return;
        note.textContent = localLocked
            ? t("Controls are paused while the device is being used.")
            : off ? t("The controls are off while Remote View is paused.") : "";
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
        localLocked = Boolean(state.local_active);
        for (const button of buttons) button.disabled = !available.has(button.dataset.button);
        for (const stick of sticks) stick.hidden = !stickAvailable(stick.dataset.stick);

        if (!ready) return hide(t("The device input service is not running."));
        note.hidden = true;
        pad.hidden = false;
        document.body.classList.add("remote-has-pad");
        applyPause();
        for (const stick of sticks) drawStick(stick.dataset.stick);
        watchGamepad();
    }

    async function checkLocalInput() {
        if (!shown() || pad.hidden || !ready) return;
        try {
            const state = await MU.api("api/input");
            const next = Boolean(state.local_active);
            if (next === localLocked) return;
            localLocked = next;
            applyPause();
            if (!localLocked) watchGamepad();
        } catch (_) {
        }
    }

    setInterval(checkLocalInput, 250);

    new MutationObserver(() => {
        if (el("view-remote").hidden) releaseAll(true);
        else load();
    }).observe(el("view-remote"), {attributes: true, attributeFilter: ["hidden"]});

    MU.onAuthChange(() => {
        if (!el("view-remote").hidden) load();
    });
}());
