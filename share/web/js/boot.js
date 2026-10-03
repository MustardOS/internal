(function () {
    "use strict";

    const {loadLanguage, ready, show} = window.MU;

    loadLanguage().then(ready).then(() => {
        try {
            history.replaceState({view: "dash", where: null}, "");
        } catch (_) {
        }
        show("dash", false);
    });
}());
