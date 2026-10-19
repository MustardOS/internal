(function () {
    "use strict";

    const {loadLanguage, ready, show} = window.MU;

    loadLanguage().then(ready).then(() => {
        const requested = location.hash.slice(1);
        try {
            history.replaceState({view: "dash", where: null}, "");
        } catch (_) {
        }
        const start = requested && document.getElementById(`view-${requested}`) ? requested : "dash";
        show(start, false);
    });
}());
