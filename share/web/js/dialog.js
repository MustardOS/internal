(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {el, holdFocus, onDismiss} = MU;
    const askBox = el("ask-box");
    const askTitle = el("ask-title");
    const askMessage = el("ask-message");
    const askConfirm = el("ask-confirm");
    const askInput = el("ask-input");
    const askSelect = el("ask-select");
    let asking = null;

    function ask({title, message, confirm, danger, input, choices}) {
        if (asking) closeAsk(false);

        askTitle.textContent = title;
        askMessage.textContent = message || "";
        askConfirm.textContent = confirm || "Confirm";
        askConfirm.classList.toggle("danger", Boolean(danger));

        const field = input ? askInput : choices ? askSelect : null;
        askInput.hidden = !input;
        askSelect.hidden = !choices;
        if (input) {
            askInput.value = input.value || "";
            askInput.placeholder = input.placeholder || "";
        }
        if (choices) {
            askSelect.replaceChildren(...choices.map((choice) => {
                const option = document.createElement("option");
                option.value = choice.value;
                option.textContent = choice.label;
                return option;
            }));
        }

        const restore = holdFocus();
        askBox.hidden = false;
        if (field) {
            field.focus();
            if (input) askInput.select();
        } else {
            askConfirm.focus();
        }

        let settle;
        const promise = new Promise((resolve) => { settle = resolve; });
        asking = {settle, restore, field};
        return promise;
    }

    function closeAsk(answer) {
        if (!asking) return;
        const {settle, restore, field} = asking;
        asking = null;
        askBox.hidden = true;
        restore();
        if (!field) settle(answer);
        else settle(answer ? field.value : null);
    }

    if (askBox) {
        onDismiss(() => closeAsk(false));
        askConfirm.addEventListener("click", () => closeAsk(true));
        askInput.addEventListener("keydown", (event) => {
            if (event.key !== "Enter") return;
            event.preventDefault();
            closeAsk(true);
        });
        el("ask-cancel").addEventListener("click", () => closeAsk(false));
        askBox.addEventListener("click", (event) => {
            if (event.target === askBox) closeAsk(false);
        });
    }

    Object.assign(MU, {
        ask
    });
}());
