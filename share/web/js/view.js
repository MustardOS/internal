(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const views = {};
    let current = "dash";

    function register(name, view) {
        views[name] = view;
    }

    function navigate(where) {
        try {
            history.pushState({view: current, where}, "");
        } catch (_) {
        }
    }

    window.addEventListener("popstate", (event) => {
        const state = event.state;
        if (!state || !state.view) return;

        paintTabs(state.view);
        current = state.view;

        const view = views[state.view];
        if (view && view.restore) view.restore(state.where);
    });

    function paintTabs(name) {
        document.querySelectorAll("[data-view]").forEach((tab) => {
            const active = tab.dataset.view === name;
            tab.classList.toggle("active", active);
            if (active) tab.setAttribute("aria-current", "page");
            else tab.removeAttribute("aria-current");
        });

        document.querySelectorAll(".view").forEach((section) => {
            section.hidden = section.id !== `view-${name}`;
        });
    }

    const menuButton = document.getElementById("menu-button");
    const siteNav = document.getElementById("site-nav");

    function openMenu(open) {
        siteNav.classList.toggle("nav-open", open);
        menuButton.setAttribute("aria-expanded", String(open));
    }

    menuButton.addEventListener("click", () => openMenu(!siteNav.classList.contains("nav-open")));

    function show(name, push = true) {
        current = name;
        paintTabs(name);
        openMenu(false);
        if (push) navigate(null);

        const view = views[name];
        if (view && view.load) view.load();
    }

    document.querySelectorAll("[data-view]").forEach((tab) => {
        tab.addEventListener("click", () => show(tab.dataset.view));
    });

    document.querySelector(".site-title").addEventListener("click", (event) => {
        if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
        event.preventDefault();
        show("dash");
        window.scrollTo(0, 0);
    });

    Object.assign(MU, {
        register,
        show,
        navigate
    });
}());
