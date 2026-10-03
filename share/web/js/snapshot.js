(function () {
    "use strict";

    const MU = window.MU;
    const {t, showToast} = MU;

    const WIDTH = 1200;
    const SCALE = 2;
    const PAD = 40;
    const GAP = 20;
    const BOX_PAD = 22;
    const ROW = 30;
    const LABEL_SHARE = 0.42;

    function palette() {
        const style = getComputedStyle(document.documentElement);
        const read = (name, fallback) => style.getPropertyValue(name).trim() || fallback;
        return {
            bg: read("--bg", "#1f1f1f"),
            box: read("--box", "#27262b"),
            line: read("--line", "#44434d"),
            text: read("--text", "#b8b8b8"),
            head: read("--head", "#ffffff"),
            muted: read("--muted", "#959396"),
            accent: read("--accent", "#c7af26"),
            sans: read("--sans", "system-ui, sans-serif"),
            mono: read("--mono", "monospace")
        };
    }

    function loadLogo() {
        return new Promise((resolve) => {
            const image = new Image();
            image.onload = () => resolve(image);
            image.onerror = () => resolve(null);
            image.src = "logo.svg";
        });
    }

    async function deviceName() {
        try {
            const response = await fetch(`state/status.json?_=${Date.now()}`, {cache: "no-store"});
            if (!response.ok) return "";
            const status = await response.json();
            const device = status.device || {};
            return [device.name ? device.name.toUpperCase() : "", device.version].filter(Boolean).join(" · ");
        } catch (_) {
            return "";
        }
    }

    function fit(context, text, width) {
        const value = String(text);
        if (context.measureText(value).width <= width) return value;
        let low = 0;
        let high = value.length;
        while (low < high) {
            const middle = Math.ceil((low + high) / 2);
            if (context.measureText(`${value.slice(0, middle)}…`).width <= width) low = middle;
            else high = middle - 1;
        }
        return `${value.slice(0, low)}…`;
    }

    function roundBox(context, x, y, width, height, colours, accentTop) {
        context.beginPath();
        context.roundRect(x, y, width, height, 10);
        context.fillStyle = colours.box;
        context.fill();
        context.lineWidth = 1;
        context.strokeStyle = colours.line;
        context.stroke();

        if (!accentTop) return;
        context.save();
        context.clip();
        context.fillStyle = colours.accent;
        context.fillRect(x, y, width, 2);
        context.restore();
    }

    function sectionHeight(section) {
        return BOX_PAD * 2 + 26 + section.rows.length * ROW;
    }

    function layoutColumns(sections, columns) {
        if (!sections.length) return {placed: [], height: 0};

        const rowHeight = columns > 1 ? Math.max(...sections.map(sectionHeight)) : 0;
        let top = 0;
        const placed = sections.map((section, index) => {
            const column = index % columns;
            const height = columns > 1 ? rowHeight : sectionHeight(section);
            if (column === 0 && index) top += (columns > 1 ? rowHeight : sectionHeight(sections[index - 1])) + GAP;
            return {section, column, top, height};
        });

        const last = placed[placed.length - 1];
        return {placed, height: last.top + last.height};
    }

    async function render(spec) {
        const colours = palette();
        const rtl = document.documentElement.dir === "rtl";
        const inner = WIDTH - PAD * 2;
        const columns = spec.columns || 1;
        const columnWidth = (inner - GAP * (columns - 1)) / columns;
        const tiles = spec.tiles || [];
        const sections = (spec.sections || []).filter((section) => section.rows.length);
        const layout = layoutColumns(sections, columns);

        const headerHeight = 96;
        const tilesHeight = tiles.length ? 118 + GAP : 0;
        const footerHeight = 44;
        const height = PAD + headerHeight + tilesHeight + layout.height + footerHeight + PAD;

        const canvas = document.createElement("canvas");
        canvas.width = WIDTH * SCALE;
        canvas.height = height * SCALE;
        const context = canvas.getContext("2d");
        context.scale(SCALE, SCALE);
        context.direction = rtl ? "rtl" : "ltr";
        context.textBaseline = "middle";

        const at = (x, width = 0) => (rtl ? WIDTH - x - width : x);
        const write = (text, x, y, font, colour, align = "start") => {
            context.font = font;
            context.fillStyle = colour;
            context.textAlign = align;
            context.fillText(text, at(x), y);
        };

        context.fillStyle = colours.bg;
        context.fillRect(0, 0, WIDTH, height);

        const logo = await loadLogo();
        let titleX = PAD;
        if (logo) {
            context.drawImage(logo, at(PAD, 52), PAD + 4, 52, 52);
            titleX = PAD + 68;
        }

        context.font = `700 34px ${colours.sans}`;
        write(fit(context, spec.title, inner - 68), titleX, PAD + 20, `700 34px ${colours.sans}`, colours.head);
        write(spec.subtitle, titleX, PAD + 54, `14px ${colours.mono}`, colours.muted);

        let y = PAD + headerHeight;

        if (tiles.length) {
            const tileWidth = (inner - GAP * (tiles.length - 1)) / tiles.length;
            tiles.forEach(([label, value, note, text], index) => {
                const x = PAD + index * (tileWidth + GAP);
                roundBox(context, at(x, tileWidth), y, tileWidth, 118, colours, true);
                const centre = x + tileWidth / 2;
                write(label.toLocaleUpperCase(), centre, y + 30, `600 12px ${colours.sans}`, colours.head, "center");
                const valueFont = text ? `20px ${colours.sans}` : `28px ${colours.mono}`;
                context.font = valueFont;
                write(fit(context, value, tileWidth - 24), centre, y + 64, valueFont, colours.head, "center");
                if (note) write(note, centre, y + 94, `12px ${colours.mono}`, colours.muted, "center");
            });
            y += 118 + GAP;
        }

        layout.placed.forEach(({section, column, top, height: boxHeight}) => {
            const x = PAD + column * (columnWidth + GAP);
            const boxTop = y + top;
            roundBox(context, at(x, columnWidth), boxTop, columnWidth, boxHeight, colours, false);

            write(section.title.toLocaleUpperCase(), x + BOX_PAD, boxTop + BOX_PAD + 8, `600 12px ${colours.sans}`,
                colours.head);

            const labelWidth = Math.min((columnWidth - BOX_PAD * 2) * LABEL_SHARE, 240);
            const valueWidth = columnWidth - BOX_PAD * 2 - labelWidth - 12;
            section.rows.forEach(([label, value], index) => {
                const rowY = boxTop + BOX_PAD + 26 + index * ROW + ROW / 2;
                context.font = `14px ${colours.sans}`;
                write(fit(context, label, labelWidth), x + BOX_PAD, rowY, `14px ${colours.sans}`, colours.muted);
                context.font = `14px ${colours.mono}`;
                write(fit(context, value, valueWidth), x + BOX_PAD + labelWidth + 12, rowY, `14px ${colours.mono}`,
                    colours.head);
            });
        });

        write(t("Made with the MustardOS Web Dashboard"), PAD, height - PAD - 10, `12px ${colours.sans}`,
            colours.muted);
        write(new Date().toLocaleString(), WIDTH - PAD, height - PAD - 10, `12px ${colours.mono}`, colours.muted,
            "end");

        return canvas;
    }

    function fileStamp() {
        const now = new Date();
        const pad = (value) => String(value).padStart(2, "0");
        return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}`;
    }

    async function saveImage(spec) {
        try {
            const device = await deviceName();
            const canvas = await render({...spec, subtitle: [device, spec.subtitle].filter(Boolean).join(" · ")});
            const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
            if (!blob) throw new Error("no image");

            const link = document.createElement("a");
            link.href = URL.createObjectURL(blob);
            link.download = `${spec.file}-${fileStamp()}.png`;
            document.body.append(link);
            link.click();
            link.remove();
            setTimeout(() => URL.revokeObjectURL(link.href), 10000);
            showToast(t("Image saved"), "good");
        } catch (_) {
            showToast(t("Could not create the image"), "bad");
        }
    }

    MU.saveImage = saveImage;
}());
