(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {el, holdFocus, onDismiss, showToast, t} = MU;
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

        codeExpiry.textContent = seconds <= 1 ? t("A new code now") : t("Changes in %ss", seconds);
    }

    async function askCode(message) {
        if (codePrompt) return codePrompt.promise;

        codeNote.textContent = message ? t(message) : "";
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
            remember("");
            auth.unlocked = 0;
            announce();
        }

        if (!response.ok) throw new Error(t((payload && payload.error) || "Request failed (%s)", response.status));
        return payload;
    }

    async function fetchAuthed(path, options) {
        const response = await fetch(path, Object.assign({
            headers: session ? {"X-muOS-Session": session} : {},
            cache: "no-store"
        }, options || {}));
        if (response.status === 401) {
            session = "";
            remember("");
            auth.unlocked = 0;
            announce();
        }
        return response;
    }

    const lockButton = el("lock-toggle");
    const SESSION_KEY = "muos-session";
    let session = "";
    try {
        session = sessionStorage.getItem(SESSION_KEY) || "";
    } catch (_) {
        session = "";
    }

    function remember(token) {
        try {
            if (token) sessionStorage.setItem(SESSION_KEY, token);
            else sessionStorage.removeItem(SESSION_KEY);
        } catch (_) {
        }
    }
    const listeners = [];

    function announce() {
        paintLock();
        listeners.forEach((fn) => fn());
    }

    function paintLock() {
        lockButton.hidden = !auth.required || Boolean(auth.readonly);
        lockButton.textContent = auth.unlocked ? t("Lock") : t("Unlock to manage");
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

            if (!opened.token) throw new Error(t(opened.error || "That code was not accepted"));

            session = opened.token;
            remember(session);
            auth.unlocked = 1;
            showToast(t("Unlocked"), "good");
        } catch (error) {
            showToast(error.message, "bad");
        }

        announce();
    }

    async function lock() {
        const held = session;
        session = "";
        remember("");
        auth.unlocked = 0;
        announce();

        try {
            await fetch("api/session", {method: "DELETE", headers: {"X-muOS-Session": held}, cache: "no-store"});
        } catch (_) {
        }
        showToast(t("Locked"));
    }

    lockButton.addEventListener("click", () => (auth.unlocked ? lock() : unlock()));

    function ready() {
        return readAuth().then(announce);
    }

    MU.canManage = () => !auth.readonly && Boolean(auth.unlocked);
    MU.canManageLists = () => Boolean(auth.lists_open) || MU.canManage();
    MU.canControlPlayer = () => Boolean(auth.player_open) || MU.canManage();
    MU.onAuthChange = (fn) => listeners.push(fn);

    Object.assign(MU, {
        api,
        fetchAuthed,
        unlock: () => unlock(),
        ready
    });
}());
