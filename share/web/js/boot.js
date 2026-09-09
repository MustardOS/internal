(function () {
    "use strict";

    const {ready, show} = window.MU;

    ready().then(() => {
        try {
            history.replaceState({view: "dash", where: null}, "");
        } catch (_) {
        }
        show("dash", false);
    });
}());
