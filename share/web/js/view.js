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

    function show(name, push = true) {
        current = name;
        paintTabs(name);
        if (push) navigate(null);

        const view = views[name];
        if (view && view.load) view.load();
    }

    document.querySelectorAll("[data-view]").forEach((tab) => {
        tab.addEventListener("click", () => show(tab.dataset.view));
    });

    Object.assign(MU, {
        register,
        show,
        navigate
    });
}());
