(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {el, holdFocus, onDismiss, showToast} = MU;
    const codeBox = el("code-box");
    const codeInput = el("code-input");
    const codeNote = el("code-note");
    const codeBar = el("code-bar");
    const codeExpiry = el("code-expiry");
    let codePrompt = null;
    let codeTimer;
    const auth = {required: 0, readonly: 0, unlocked: 0, step: 30, remaining: 0, at: 0};

    function drainBar() {
        const elapsed = (Date.now() - auth.at) / 1000;
        const left = auth.remaining - elapsed;
        const span = ((left % auth.step) + auth.step) % auth.step;
        const seconds = Math.max(0, Math.ceil(span));

        codeBar.style.width = `${Math.max(0, Math.min(100, (span / auth.step) * 100))}%`;
        codeBar.classList.toggle("warn", span <= 5);

        codeExpiry.textContent = seconds <= 1 ? "A new code now" : `Changes in ${seconds}s`;
    }

    async function askCode(message) {
        if (codePrompt) return codePrompt.promise;

        codeNote.textContent = message || "";
        codeInput.value = "";
        const restore = holdFocus();
        codeBox.hidden = false;
        codeInput.focus();

        await readAuth();
        drainBar();
        clearInterval(codeTimer);
        codeTimer = setInterval(drainBar, 250);

        let settle;
        const promise = new Promise((resolve) => { settle = resolve; });
        codePrompt = {promise, settle, restore};
        return promise;
    }

    function closeCode(value) {
        if (!codePrompt) return;
        const {settle, restore} = codePrompt;
        codePrompt = null;
        clearInterval(codeTimer);
        codeBox.hidden = true;
        restore();
        settle(value);
    }

    if (codeBox) {
        el("code-form").addEventListener("submit", (event) => {
            event.preventDefault();
            closeCode(codeInput.value.trim());
        });
        el("code-cancel").addEventListener("click", () => closeCode(""));
        codeBox.addEventListener("click", (event) => {
            if (event.target === codeBox) closeCode("");
        });
        onDismiss(() => closeCode(""));
    }

    async function api(path, options) {
        const settings = options || {};
        const headers = {};

        if (session) headers["X-muOS-Session"] = session;
        if (settings.type) headers["Content-Type"] = settings.type;

        const response = await fetch(path, {
            method: settings.method || "GET",
            body: settings.body,
            headers,
            cache: "no-store"
        });

        let payload = null;
        try {
            payload = await response.json();
        } catch (_) {
            payload = null;
        }

        if (response.status === 401) {
            session = "";
            auth.unlocked = 0;
            announce();
        }

        if (!response.ok) throw new Error((payload && payload.error) || `Request failed (${response.status})`);
        return payload;
    }

    const lockButton = el("lock-toggle");
    let session = "";
    const listeners = [];

    function announce() {
        paintLock();
        listeners.forEach((fn) => fn());
    }

    function paintLock() {
        lockButton.hidden = !auth.required || Boolean(auth.readonly);
        lockButton.textContent = auth.unlocked ? "Lock" : "Unlock to manage";
        lockButton.classList.toggle("open", Boolean(auth.unlocked));
    }

    async function readAuth() {
        try {
            const headers = session ? {"X-muOS-Session": session} : {};
            const state = await (await fetch("api/auth", {headers, cache: "no-store"})).json();
            Object.assign(auth, state, {at: Date.now()});
        } catch (_) {
            auth.at = Date.now();
        }
    }

    async function unlock() {
        await readAuth();

        const entered = await askCode("");
        if (!entered) return;

        try {
            const opened = await (await fetch("api/session", {
                method: "POST",
                headers: {"X-muOS-Code": entered},
                cache: "no-store"
            })).json();

            if (!opened.token) throw new Error(opened.error || "That code was not accepted");

            session = opened.token;
            auth.unlocked = 1;
            showToast("Unlocked");
        } catch (error) {
            showToast(error.message);
        }

        announce();
    }

    async function lock() {
        const held = session;
        session = "";
        auth.unlocked = 0;
        announce();

        try {
            await fetch("api/session", {method: "DELETE", headers: {"X-muOS-Session": held}, cache: "no-store"});
        } catch (_) {
        }
        showToast("Locked");
    }

    lockButton.addEventListener("click", () => (auth.unlocked ? lock() : unlock()));

    function ready() {
        return readAuth().then(paintLock);
    }

    MU.canManage = () => !auth.readonly && Boolean(auth.unlocked);
    MU.onAuthChange = (fn) => listeners.push(fn);

    Object.assign(MU, {
        api,
        ready
    });
}());
