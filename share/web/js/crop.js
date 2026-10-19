(function () {
    "use strict";

    const {el, make, onDismiss, holdFocus} = window.MU;
    const MIN_EDGE = 16;

    function clamp(crop, bounds) {
        const width = Math.max(MIN_EDGE, Math.min(crop.width, bounds.width));
        const height = Math.max(MIN_EDGE, Math.min(crop.height, bounds.height));

        return {
            x: Math.round(Math.max(0, Math.min(crop.x, bounds.width - width))),
            y: Math.round(Math.max(0, Math.min(crop.y, bounds.height - height))),
            width: Math.round(width),
            height: Math.round(height)
        };
    }

    function drag(crop, handle, dx, dy, bounds) {
        if (handle === "move") return clamp({...crop, x: crop.x + dx, y: crop.y + dy}, bounds);

        let {x, y, width, height} = crop;

        if (handle.includes("w")) {
            const shift = Math.min(dx, width - MIN_EDGE);
            x += shift;
            width -= shift;
        }
        if (handle.includes("e")) width += dx;
        if (handle.includes("n")) {
            const shift = Math.min(dy, height - MIN_EDGE);
            y += shift;
            height -= shift;
        }
        if (handle.includes("s")) height += dy;

        if (x < 0) { width += x; x = 0; }
        if (y < 0) { height += y; y = 0; }
        width = Math.min(width, bounds.width - x);
        height = Math.min(height, bounds.height - y);

        return clamp({x, y, width, height}, bounds);
    }

    function output(crop, limit) {
        const longest = Math.max(crop.width, crop.height);
        if (!limit || longest <= limit) return {width: crop.width, height: crop.height};

        const scale = limit / longest;
        return {
            width: Math.max(1, Math.round(crop.width * scale)),
            height: Math.max(1, Math.round(crop.height * scale))
        };
    }

    const SIZES = [
        {label: "Original size", limit: 0},
        {label: "At most 640px", limit: 640},
        {label: "At most 480px", limit: 480},
        {label: "At most 320px", limit: 320}
    ];

    function outputType(file) {
        if (/webp$/i.test(file.type) || /\.webp$/i.test(file.name)) return "image/webp";
        return /jpe?g$/i.test(file.type) || /\.(?:jpe?g|jpe|jfif|pjpeg|pjp)$/i.test(file.name) ? "image/jpeg" : "image/png";
    }

    const box = el("crop-box");
    const stage = el("crop-stage");
    const frame = el("crop-frame");
    const canvas = el("crop-canvas");
    const sizeNote = el("crop-size");
    const sizePick = el("crop-limit");
    let image = null;
    let original = null;
    let bounds = {width: 0, height: 0};
    let crop = {x: 0, y: 0, width: 0, height: 0};
    let scale = 1;
    let pending = null;
    let source = null;

    function paint() {
        const imageWidth = bounds.width * scale;
        const offsetX = Math.max(0, (stage.clientWidth - imageWidth) / 2);
        frame.style.left = `${offsetX + crop.x * scale}px`;
        frame.style.top = `${crop.y * scale}px`;
        frame.style.width = `${crop.width * scale}px`;
        frame.style.height = `${crop.height * scale}px`;

        const size = output(crop, Number(sizePick.value) || 0);
        sizeNote.textContent = `${crop.width} × ${crop.height} → ${size.width} × ${size.height}`;
    }

    function drawSource() {
        bounds = {width: image.width || image.naturalWidth, height: image.height || image.naturalHeight};
        crop = {x: 0, y: 0, ...bounds};

        const room = stage.clientWidth || 520;
        scale = Math.min(1, room / bounds.width, 420 / bounds.height);

        canvas.width = bounds.width;
        canvas.height = bounds.height;
        canvas.getContext("2d").drawImage(image, 0, 0);
        canvas.style.width = `${bounds.width * scale}px`;
        canvas.style.height = `${bounds.height * scale}px`;
        stage.style.height = `${bounds.height * scale}px`;
        paint();
    }

    function transform(kind) {
        const sourceWidth = bounds.width;
        const sourceHeight = bounds.height;
        const rotated = kind === "left" || kind === "right";
        const out = document.createElement("canvas");
        out.width = rotated ? sourceHeight : sourceWidth;
        out.height = rotated ? sourceWidth : sourceHeight;
        const context = out.getContext("2d");

        if (kind === "left") {
            context.translate(0, out.height);
            context.rotate(-Math.PI / 2);
        } else if (kind === "right") {
            context.translate(out.width, 0);
            context.rotate(Math.PI / 2);
        } else if (kind === "horizontal") {
            context.translate(out.width, 0);
            context.scale(-1, 1);
        } else {
            context.translate(0, out.height);
            context.scale(1, -1);
        }

        context.drawImage(image, 0, 0);
        image = out;
        drawSource();
    }

    function wire() {
        let active = null;
        let last = null;

        const start = (event, handle) => {
            active = handle;
            last = {x: event.clientX, y: event.clientY};
            stage.setPointerCapture(event.pointerId);
            event.preventDefault();
        };

        stage.addEventListener("pointerdown", (event) => {
            const handle = event.target.dataset ? event.target.dataset.handle : null;
            if (handle) return start(event, handle);
            if (event.target === frame) start(event, "move");
        });

        stage.addEventListener("pointermove", (event) => {
            if (!active) return;
            const dx = (event.clientX - last.x) / scale;
            const dy = (event.clientY - last.y) / scale;
            last = {x: event.clientX, y: event.clientY};
            crop = drag(crop, active, dx, dy, bounds);
            paint();
        });

        const stop = () => { active = null; };
        stage.addEventListener("pointerup", stop);
        stage.addEventListener("pointercancel", stop);
    }

    function close(result) {
        if (!pending) return;
        const {settle, restore} = pending;
        pending = null;

        box.hidden = true;
        restore();
        if (source) URL.revokeObjectURL(source);
        source = null;
        settle(result);
    }

    function save(file) {
        const size = output(crop, Number(sizePick.value) || 0);
        const out = document.createElement("canvas");
        out.width = size.width;
        out.height = size.height;

        const context = out.getContext("2d");
        context.imageSmoothingQuality = "high";
        context.drawImage(image, crop.x, crop.y, crop.width, crop.height, 0, 0, size.width, size.height);

        const type = outputType(file);
        out.toBlob((blob) => {
            if (!blob) return close(file);

            const named = new File([blob], file.name, {type});
            close(named);
        }, type, type === "image/jpeg" ? 0.92 : undefined);
    }

    function edit(file) {
        if (pending) close(null);

        return new Promise((settle) => {
            pending = {settle, restore: holdFocus()};

            original = new Image();
            source = URL.createObjectURL(file);

            original.addEventListener("load", () => {
                image = original;
                box.hidden = false;
                drawSource();
                el("crop-save").focus();
            });

            original.addEventListener("error", () => close(file));
            original.src = source;

            el("crop-save").onclick = () => save(file);
            el("crop-reset").onclick = () => { image = original; drawSource(); };
            el("crop-rotate-left").onclick = () => transform("left");
            el("crop-rotate-right").onclick = () => transform("right");
            el("crop-flip-horizontal").onclick = () => transform("horizontal");
            el("crop-flip-vertical").onclick = () => transform("vertical");
            el("crop-cancel").onclick = () => close(null);
            sizePick.onchange = paint;
        });
    }

    SIZES.forEach((size) => {
        const option = make("option", null, size.label);
        option.value = String(size.limit);
        sizePick.append(option);
    });

    wire();
    onDismiss(() => close(null));

    window.MU.cropImage = edit;
    window.MU.cropGeometry = {clamp, drag, output, outputType, MIN_EDGE};
}());
