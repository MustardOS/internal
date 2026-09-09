(function () {
    "use strict";

    const MU = window.MU = window.MU || {};
    const {runtime} = MU;
    const hex = (value) => {
        const m = /^#?([\da-f]{6})$/i.exec(String(value || ""));
        return m ? [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16)) : null;
    };

    const toHex = (rgb) => `#${rgb.map((v) => Math.round(Math.max(0, Math.min(255, v)))
        .toString(16).padStart(2, "0")).join("")}`;

    const mix = (a, b, amount) => a.map((v, i) => v + (b[i] - v) * amount);

    const luminance = (rgb) => {
        const [r, g, b] = rgb.map((v) => {
            const c = v / 255;
            return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        });
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };

    const contrast = (a, b) => {
        const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
        return (x + 0.05) / (y + 0.05);
    };

    function readable(colour, against, target) {
        if (contrast(colour, against) >= target) return colour;

        const white = [255, 255, 255];
        const black = [0, 0, 0];
        const towards = contrast(white, against) >= contrast(black, against) ? white : black;

        let result = colour;
        for (let step = 0; step < 40 && contrast(result, against) < target; step += 1) {
            result = mix(result, towards, 0.08);
        }
        return contrast(result, against) < target ? towards : result;
    }

    function applyTheme(palette) {
        const background = hex(palette && palette.background);
        if (!background) return;

        const shade = hex(palette.shade) || mix(background, [0, 0, 0], 0.4);
        const lift = luminance(background) > 0.5 ? [0, 0, 0] : [255, 255, 255];

        const page = mix(background, shade, 0.55);
        const panel = mix(page, lift, 0.05);
        const raised = mix(panel, lift, 0.05);
        const line = mix(panel, lift, 0.15);

        const heading = readable(hex(palette.heading) || [255, 255, 255], panel, 7);
        const text = readable(hex(palette.text) || mix(heading, panel, 0.25), panel, 4.5);
        const accent = hex(palette.accent);

        const set = (name, value) => document.documentElement.style.setProperty(name, value);

        set("--bg", toHex(page));
        set("--box", toHex(panel));
        set("--box-alt", toHex(raised));
        set("--line", toHex(line));
        set("--head", toHex(heading));
        set("--text", toHex(text));
        set("--muted", toHex(readable(mix(text, panel, 0.45), panel, 3)));
        if (accent) set("--accent", toHex(readable(accent, panel, 3.5)));
        if (hex(palette.warn)) set("--warn", toHex(readable(hex(palette.warn), panel, 3.5)));
        if (hex(palette.good)) set("--good", toHex(readable(hex(palette.good), panel, 3.5)));

        const meta = document.querySelector('meta[name="theme-color"]');
        if (meta) meta.setAttribute("content", toHex(page));
    }

    applyTheme(runtime.theme);

    Object.assign(MU, {
        applyTheme
    });
}());
