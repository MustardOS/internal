(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {el, holdFocus, onDismiss} = MU;
    const askBox = el("ask-box");
    const askTitle = el("ask-title");
    const askMessage = el("ask-message");
    const askConfirm = el("ask-confirm");
    let asking = null;

    function ask({title, message, confirm, danger}) {
        if (asking) closeAsk(false);

        askTitle.textContent = title;
        askMessage.textContent = message;
        askConfirm.textContent = confirm || "Confirm";
        askConfirm.classList.toggle("danger", Boolean(danger));
        const restore = holdFocus();
        askBox.hidden = false;
        askConfirm.focus();

        let settle;
        const promise = new Promise((resolve) => { settle = resolve; });
        asking = {settle, restore};
        return promise;
    }

    function closeAsk(answer) {
        if (!asking) return;
        const {settle, restore} = asking;
        asking = null;
        askBox.hidden = true;
        restore();
        settle(answer);
    }

    if (askBox) {
        onDismiss(() => closeAsk(false));
        askConfirm.addEventListener("click", () => closeAsk(true));
        el("ask-cancel").addEventListener("click", () => closeAsk(false));
        askBox.addEventListener("click", (event) => {
            if (event.target === askBox) closeAsk(false);
        });
    }

    Object.assign(MU, {
        ask
    });
}());
