(function () {
    "use strict";

    const nav = document.getElementById("site-nav");
    const menuButton = document.getElementById("menu-button");
    const address = document.getElementById("dashboard-address");
    const remote = document.getElementById("nav-remote");

    if (menuButton && nav) {
        menuButton.addEventListener("click", () => {
            const open = !nav.classList.contains("nav-open");
            nav.classList.toggle("nav-open", open);
            menuButton.classList.toggle("nav-open", open);
            menuButton.setAttribute("aria-expanded", String(open));
        });
    }

    function runtimeSettings() {
        if (window.MUOS_RUNTIME) return Promise.resolve(window.MUOS_RUNTIME);
        return new Promise((resolve) => {
            const script = document.createElement("script");
            script.src = "../js/runtime.js";
            script.onload = () => resolve(window.MUOS_RUNTIME || {});
            script.onerror = () => resolve({});
            document.head.append(script);
        });
    }

    const lockButton = document.getElementById("lock-toggle");
    const SESSION_KEY = "muos-session";

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
        }
    }

    async function paintLock() {
        if (!lockButton) return;
        let auth = {};
        try {
            const token = session();
            const headers = token ? {"X-muOS-Session": token} : {};
            auth = await (await fetch("/api/auth", {headers, cache: "no-store"})).json();
        } catch (_) {
            auth = {};
        }
        if (!auth.unlocked && session()) remember("");
        lockButton.hidden = !auth.required || Boolean(auth.readonly);
        lockButton.textContent = auth.unlocked ? "Lock" : "Unlock";
        lockButton.classList.toggle("open", Boolean(auth.unlocked));
    }

    async function unlock() {
        if (!window.MUTool) return;
        let note = "Enter the six digit code from Configuration > Connectivity > Web Dashboard Code on the device.";
        for (;;) {
            const code = await window.MUTool.ask("Unlock the dashboard", "Web Dashboard Code", "", note);
            if (!code) return;
            let opened = {};
            try {
                opened = await (await fetch("/api/session", {
                    method: "POST",
                    headers: {"X-muOS-Code": code},
                    cache: "no-store"
                })).json();
            } catch (_) {
                opened = {};
            }
            if (opened.token) {
                remember(opened.token);
                return;
            }
            note = opened.error || "That code was not accepted";
        }
    }

    async function lock() {
        const held = session();
        remember("");
        try {
            await fetch("/api/session", {method: "DELETE", headers: {"X-muOS-Session": held}, cache: "no-store"});
        } catch (_) {
        }
    }

    if (lockButton) {
        lockButton.addEventListener("click", async () => {
            if (lockButton.classList.contains("open")) await lock();
            else await unlock();
            paintLock();
        });
        window.addEventListener("pageshow", paintLock);
    }

    runtimeSettings().then((runtime) => {
        if (address) address.textContent = window.location.hostname || runtime.localName || "muos.local";
        if (remote) remote.hidden = !runtime.remoteView;
    });
}());
