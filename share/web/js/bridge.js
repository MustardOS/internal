(function () {
    "use strict";

    const {el, t, loadLanguage} = window.MU;
    const ORIGINS = ["https://muos.dev", "http://localhost:4000", "http://127.0.0.1:4000"];
    const PATHS = [/^\/api\/tools(\/|$)/, /^\/api\/studio(\/|$)/, /^\/api\/files\//, /^\/api\/screen(\/image)?$/, /^\/media\//];
    const METHODS = ["GET", "POST", "PUT", "DELETE"];
    const SESSION_KEY = "muos-session";

    const status = el("bridge-status");
    const ask = el("bridge-ask");
    const codeForm = el("bridge-code");
    const codeInput = el("bridge-code-input");
    const codeNote = el("bridge-code-note");
    let allowed = "";
    let asking = "";

    function session() {
        try {
            return sessionStorage.getItem(SESSION_KEY) || "";
        } catch (_) {
            return "";
        }
    }

    function remember(token) {
        try {
            if (token) sessionStorage.setItem(SESSION_KEY, token);
            else sessionStorage.removeItem(SESSION_KEY);
        } catch (_) {
            return;
        }
    }

    function tell(message) {
        if (allowed && window.opener) window.opener.postMessage(message, allowed);
    }

    function announce() {
        tell({type: "mustardos-bridge", state: "ready", host: location.host});
    }

    function connected() {
        ask.hidden = true;
        codeForm.hidden = true;
        status.textContent = t("Connected to %s. You can go back to the website.", allowed);
        announce();
    }

    async function unlockState() {
        const headers = session() ? {"X-muOS-Session": session()} : {};
        const state = await (await fetch("api/auth", {headers, cache: "no-store"})).json();
        if (state.readonly) throw new Error(t("The dashboard is running read only"));
        return !state.required || state.unlocked;
    }

    async function begin() {
        ask.hidden = true;
        try {
            if (await unlockState()) {
                connected();
                return;
            }
            status.textContent = t("This device needs its Web Dashboard Code.");
            codeForm.hidden = false;
            codeInput.focus();
        } catch (error) {
            status.textContent = error.message;
        }
    }

    codeForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        codeNote.textContent = "";
        const response = await fetch("api/session", {
            method: "POST",
            headers: {"X-muOS-Code": codeInput.value.trim()},
            cache: "no-store"
        });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok || !payload.token) {
            codeNote.textContent = t(payload.error || "That code was not accepted");
            return;
        }
        remember(payload.token);
        connected();
    });

    el("bridge-allow").addEventListener("click", () => {
        allowed = asking;
        begin();
    });

    el("bridge-deny").addEventListener("click", () => window.close());

    async function relay(data) {
        const reply = (message, transfer) => window.opener && window.opener.postMessage(
            Object.assign({type: "mustardos-response", id: data.id}, message), allowed, transfer || []);

        const method = String(data.method || "GET").toUpperCase();
        const path = `/${String(data.path || "").replace(/^\/+/, "")}`;
        if (!METHODS.includes(method) || path.includes("..") || !PATHS.some((rule) => rule.test(path.split("?")[0]))) {
            reply({status: 403, ok: false, error: t("The website cannot use that part of the device")});
            return;
        }

        const headers = {};
        if (data.contentType) headers["Content-Type"] = data.contentType;
        if (session()) headers["X-muOS-Session"] = session();

        try {
            const response = await send(method, path, headers, data);
            if (response.status === 401) {
                remember("");
                codeForm.hidden = false;
                status.textContent = t("This device needs its Web Dashboard Code again.");
            }
            reply({status: response.status, ok: response.ok, contentType: response.type, body: response.body},
                [response.body]);
        } catch (error) {
            reply({status: 0, ok: false, error: error.message});
        }
    }

    function send(method, path, headers, data) {
        return new Promise((resolve, reject) => {
            const request = new XMLHttpRequest();
            request.open(method, path);
            request.responseType = "arraybuffer";
            request.setRequestHeader("Cache-Control", "no-store");
            Object.entries(headers).forEach(([name, value]) => request.setRequestHeader(name, value));
            if (data.progress && request.upload) {
                request.upload.addEventListener("progress", (event) => {
                    if (event.lengthComputable) tell({type: "mustardos-progress", id: data.id, loaded: event.loaded,
                        total: event.total});
                });
            }
            request.addEventListener("load", () => resolve({
                status: request.status,
                ok: request.status >= 200 && request.status < 300,
                type: request.getResponseHeader("Content-Type") || "",
                body: request.response || new ArrayBuffer(0)
            }));
            request.addEventListener("error", () => reject(new Error(t("The device did not answer."))));
            request.send(data.body === undefined ? null : data.body);
        });
    }

    window.addEventListener("message", (event) => {
        if (!ORIGINS.includes(event.origin) || event.source !== window.opener) return;
        const data = event.data || {};

        if (data.type === "mustardos-hello") {
            if (allowed === event.origin) {
                announce();
            } else if (!allowed && asking !== event.origin) {
                asking = event.origin;
                const origin = document.createElement("strong");
                origin.textContent = event.origin;
                const [before, after = ""] = t("The MustardOS website at %s wants to use this device. It can open and save files with its editors and tools, and change your own themes in the Theme Lab.").split("%s");
                el("bridge-ask-text").replaceChildren(before, origin, after);
                status.textContent = "";
                ask.hidden = false;
            }
            return;
        }

        if (data.type === "mustardos-request" && allowed === event.origin) relay(data);
    });

    setInterval(() => {
        if (!window.opener || window.opener.closed) {
            status.textContent = t("The website was closed. You can close this window.");
            return;
        }
        if (allowed && codeForm.hidden) announce();
    }, 1000);

    loadLanguage();
}());
