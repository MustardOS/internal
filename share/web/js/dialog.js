(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {el, holdFocus, onDismiss} = MU;
    const askBox = el("ask-box");
    const askTitle = el("ask-title");
    const askMessage = el("ask-message");
    const askConfirm = el("ask-confirm");
    const askAlternate = el("ask-alternate");
    const askInput = el("ask-input");
    const askSelect = el("ask-select");
    const askCancel = el("ask-cancel");
    let asking = null;
    let actionButtons = [];

    function clearActions() {
        actionButtons.forEach((button) => button.remove());
        actionButtons = [];
        askConfirm.hidden = false;
        askCancel.hidden = false;
    }

    function ask({title, message, confirm, danger, input, choices, alternate, actions}) {
        if (asking) closeAsk(false);

        askTitle.textContent = title;
        askMessage.textContent = message || "";
        askConfirm.textContent = confirm || "Confirm";
        askConfirm.classList.toggle("danger", Boolean(danger));
        askAlternate.textContent = alternate || "";
        askAlternate.hidden = !alternate;

        clearActions();
        if (actions && actions.length) {
            askConfirm.hidden = true;
            askCancel.hidden = true;
            actionButtons = actions.map((action) => {
                const button = document.createElement("button");
                button.type = "button";
                button.className = action.danger ? "link danger" : "link";
                button.textContent = action.label;
                button.addEventListener("click", () => closeAsk(action.value));
                askConfirm.before(button);
                return button;
            });
        }

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
        } else if (actionButtons.length) {
            actionButtons[0].focus();
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
        clearActions();
        restore();
        if (answer === "alternate" || !field) settle(answer);
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
        askCancel.addEventListener("click", () => closeAsk(false));
        askAlternate.addEventListener("click", () => closeAsk("alternate"));
        askBox.addEventListener("click", (event) => {
            if (event.target === askBox) closeAsk(false);
        });
    }

    Object.assign(MU, {
        ask
    });
}());
