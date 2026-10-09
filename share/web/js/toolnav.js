(function () {
    "use strict";

    const nav = document.getElementById("site-nav");
    const menuButton = document.getElementById("menu-button");
    const current = location.pathname.split("/").pop();

    if (menuButton && nav) {
        menuButton.addEventListener("click", () => {
            const open = !nav.classList.contains("nav-open");
            nav.classList.toggle("nav-open", open);
            menuButton.classList.toggle("nav-open", open);
            menuButton.setAttribute("aria-expanded", String(open));
        });
    }

    function link(className, href, text) {
        const anchor = document.createElement("a");
        anchor.className = className;
        anchor.href = href;
        anchor.textContent = text;
        return anchor;
    }

    async function build() {
        const response = await fetch("../index.html", {cache: "no-store"});
        if (!response.ok) return;

        const source = new DOMParser().parseFromString(await response.text(), "text/html").getElementById("site-nav");
        if (!source) return;

        source.querySelectorAll("[data-library-tools]").forEach((node) => node.remove());
        source.querySelectorAll("button[data-view]").forEach((button) => {
            button.replaceWith(link(button.className, `../#${button.dataset.view}`, button.textContent.trim()));
        });

        const tools = source.querySelector("#nav-tools");
        if (tools) {
            try {
                const listed = await (await fetch("tools.json", {cache: "no-store"})).json();
                for (const tool of listed) {
                    const item = document.createElement("li");
                    item.className = "nav-list-item";
                    const anchor = link("nav-list-link", `${encodeURIComponent(tool.slug)}.html`, tool.title);
                    if (`${tool.slug}.html` === current) {
                        anchor.classList.add("active");
                        anchor.setAttribute("aria-current", "page");
                    }
                    item.append(anchor);
                    tools.append(item);
                }
            } catch (_) {
            }
        }

        nav.replaceChildren(...[...source.childNodes].map((node) => document.importNode(node, true)));
    }

    build().catch(() => {});
}());
