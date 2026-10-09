(function () {
    "use strict";

    const {loadLanguage, ready, show} = window.MU;

    loadLanguage().then(ready).then(() => {
        try {
            history.replaceState({view: "dash", where: null}, "");
        } catch (_) {
        }
        const requested = location.hash.slice(1);
        const start = requested && document.querySelector(`[data-view="${CSS.escape(requested)}"]`) ? requested : "dash";
        show(start, false);
    });
}());
