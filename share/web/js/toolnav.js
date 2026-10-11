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

    runtimeSettings().then((runtime) => {
        if (address) address.textContent = window.location.hostname || runtime.localName || "muos.local";
        if (remote) remote.hidden = !runtime.remoteView;
    });
}());
