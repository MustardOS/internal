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
        const ratio = limit / longest;
        return {
            width: Math.max(1, Math.round(crop.width * ratio)),
            height: Math.max(1, Math.round(crop.height * ratio))
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
        return /jpe?g$/i.test(file.type) || /\.(?:jpe?g|jpe|jfif|pjpeg|pjp)$/i.test(file.name)
            ? "image/jpeg" : "image/png";
    }

    const box = el("crop-box");
    const stage = el("crop-stage");
    const frame = el("crop-frame");
    const canvas = el("crop-canvas");
    const sizeNote = el("crop-size");
    const sizePick = el("crop-limit");
    const layerPick = el("crop-layer");
    const opacity = el("crop-layer-opacity");
    const opacityValue = el("crop-layer-opacity-value");
    const transformPick = el("crop-transform");
    const addButton = el("crop-layer-add");
    const raiseButton = el("crop-layer-raise");
    const lowerButton = el("crop-layer-lower");
    const removeButton = el("crop-layer-remove");
    const layerFile = el("crop-layer-file");
    let layers = [];
    let selected = 0;
    let bounds = {width: 0, height: 0};
    let crop = {x: 0, y: 0, width: 0, height: 0};
    let scale = 1;
    let pending = null;
    let sourceUrls = [];
    let baseFile = null;

    function dimensions(layer) {
        const width = layer.image.naturalWidth || layer.image.width;
        const height = layer.image.naturalHeight || layer.image.height;
        return Math.abs(layer.rotation) % 180 === 90 ? {width: height, height: width} : {width, height};
    }

    function renderLayer(context, layer, base) {
        const nativeWidth = layer.image.naturalWidth || layer.image.width;
        const nativeHeight = layer.image.naturalHeight || layer.image.height;
        const turned = Math.abs(layer.rotation) % 180 === 90;
        const visualWidth = turned ? nativeHeight : nativeWidth;
        const visualHeight = turned ? nativeWidth : nativeHeight;
        const ratio = base ? Math.min(bounds.width / visualWidth, bounds.height / visualHeight)
            : Math.min(bounds.width * .8 / visualWidth, bounds.height * .8 / visualHeight, 1);
        const width = nativeWidth * ratio;
        const height = nativeHeight * ratio;
        context.save();
        context.globalAlpha = layer.opacity;
        context.translate(bounds.width / 2 + (base ? 0 : layer.x), bounds.height / 2 + (base ? 0 : layer.y));
        context.rotate(layer.rotation * Math.PI / 180);
        context.scale(layer.flipX ? -1 : 1, layer.flipY ? -1 : 1);
        context.drawImage(layer.image, -width / 2, -height / 2, width, height);
        context.restore();
    }

    function composite() {
        canvas.width = bounds.width;
        canvas.height = bounds.height;
        const context = canvas.getContext("2d");
        context.clearRect(0, 0, bounds.width, bounds.height);
        layers.forEach((layer, index) => renderLayer(context, layer, index === 0));
    }

    function layerControls() {
        layerPick.replaceChildren();
        layers.forEach((layer, index) => {
            const option = make("option", null, layer.name);
            option.value = String(index);
            layerPick.append(option);
        });
        selected = Math.max(0, Math.min(selected, layers.length - 1));
        layerPick.value = String(selected);
        const layer = layers[selected];
        opacity.value = String(Math.round(layer.opacity * 100));
        opacityValue.textContent = `${opacity.value}%`;
        stage.classList.toggle("moving-layer", selected > 0);
        lowerButton.disabled = selected <= 1;
        raiseButton.disabled = selected === 0 || selected >= layers.length - 1;
        removeButton.disabled = selected === 0;
    }

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

    function layout(resetCrop) {
        const base = dimensions(layers[0]);
        bounds = {width: base.width, height: base.height};
        if (resetCrop) crop = {x: 0, y: 0, ...bounds};
        else crop = clamp(crop, bounds);
        const room = stage.clientWidth || 520;
        scale = Math.min(1, room / bounds.width, 420 / bounds.height);
        composite();
        canvas.style.width = `${bounds.width * scale}px`;
        canvas.style.height = `${bounds.height * scale}px`;
        stage.style.height = `${bounds.height * scale}px`;
        layerControls();
        paint();
    }

    function transform(kind) {
        if (!kind || !layers[selected]) return;
        const layer = layers[selected];
        if (kind === "left") layer.rotation = (layer.rotation + 270) % 360;
        else if (kind === "right") layer.rotation = (layer.rotation + 90) % 360;
        else if (kind === "horizontal") layer.flipX = !layer.flipX;
        else if (kind === "vertical") layer.flipY = !layer.flipY;
        layout(selected === 0 && (kind === "left" || kind === "right"));
    }

    function loadImage(file) {
        return new Promise((resolve, reject) => {
            const image = new Image();
            const url = URL.createObjectURL(file);
            sourceUrls.push(url);
            image.addEventListener("load", () => resolve(image), {once: true});
            image.addEventListener("error", reject, {once: true});
            image.src = url;
        });
    }

    async function addLayer(file) {
        try {
            const image = await loadImage(file);
            layers.push({name: file.name, image, opacity: 1, rotation: 0, flipX: false, flipY: false, x: 0, y: 0});
            selected = layers.length - 1;
            layout(false);
        } catch (_) {
        }
    }

    function moveLayer(direction) {
        const target = selected + direction;
        if (selected === 0 || target < 1 || target >= layers.length) return;
        [layers[selected], layers[target]] = [layers[target], layers[selected]];
        selected = target;
        layout(false);
    }

    function shiftLayer(dx, dy) {
        const layer = layers[selected];
        if (!layer || selected === 0) return;
        const limitX = bounds.width / 2;
        const limitY = bounds.height / 2;
        layer.x = Math.max(-limitX, Math.min(limitX, layer.x + dx));
        layer.y = Math.max(-limitY, Math.min(limitY, layer.y + dy));
        composite();
    }

    function reset() {
        if (!layers.length) return;
        layers = [{...layers[0], opacity: 1, rotation: 0, flipX: false, flipY: false}];
        selected = 0;
        layout(true);
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
            if (event.target !== frame && event.target !== canvas) return;
            if (selected > 0) return start(event, "layer");
            if (event.target === frame) start(event, "move");
        });
        stage.addEventListener("pointermove", (event) => {
            if (!active) return;
            const dx = (event.clientX - last.x) / scale;
            const dy = (event.clientY - last.y) / scale;
            last = {x: event.clientX, y: event.clientY};
            if (active === "layer") return shiftLayer(dx, dy);
            crop = drag(crop, active, dx, dy, bounds);
            paint();
        });
        stage.tabIndex = 0;
        stage.addEventListener("keydown", (event) => {
            const steps = {ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1]};
            const step = steps[event.key];
            if (!step || selected === 0) return;
            const distance = event.shiftKey ? 10 : 1;
            shiftLayer(step[0] * distance, step[1] * distance);
            event.preventDefault();
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
        sourceUrls.forEach((url) => URL.revokeObjectURL(url));
        sourceUrls = [];
        layers = [];
        settle(result);
    }

    function save(file) {
        composite();
        const size = output(crop, Number(sizePick.value) || 0);
        const out = document.createElement("canvas");
        out.width = size.width;
        out.height = size.height;
        const context = out.getContext("2d");
        context.imageSmoothingQuality = "high";
        context.drawImage(canvas, crop.x, crop.y, crop.width, crop.height, 0, 0, size.width, size.height);
        const type = outputType(file);
        out.toBlob((blob) => {
            if (!blob) return close(file);
            close(new File([blob], file.name, {type}));
        }, type, type === "image/jpeg" ? .92 : undefined);
    }

    function edit(file) {
        if (pending) close(null);
        return new Promise(async (settle) => {
            pending = {settle, restore: holdFocus()};
            baseFile = file;
            try {
                const image = await loadImage(file);
                layers = [{name: file.name, image, opacity: 1, rotation: 0, flipX: false, flipY: false, x: 0, y: 0}];
                selected = 0;
                box.hidden = false;
                layout(true);
                el("crop-save").focus();
            } catch (_) {
                close(file);
                return;
            }
            el("crop-save").onclick = () => save(baseFile);
            el("crop-reset").onclick = reset;
            el("crop-cancel").onclick = () => close(null);
        });
    }

    SIZES.forEach((size) => {
        const option = make("option", null, size.label);
        option.value = String(size.limit);
        sizePick.append(option);
    });
    sizePick.addEventListener("change", paint);
    layerPick.addEventListener("change", () => { selected = Number(layerPick.value) || 0; layerControls(); });
    opacity.addEventListener("input", () => {
        if (!layers[selected]) return;
        layers[selected].opacity = Number(opacity.value) / 100;
        opacityValue.textContent = `${opacity.value}%`;
        composite();
    });
    transformPick.addEventListener("change", () => {
        transform(transformPick.value);
        transformPick.value = "";
    });
    addButton.addEventListener("click", () => layerFile.click());
    layerFile.addEventListener("change", () => {
        if (layerFile.files.length) addLayer(layerFile.files[0]);
        layerFile.value = "";
    });
    raiseButton.addEventListener("click", () => moveLayer(1));
    lowerButton.addEventListener("click", () => moveLayer(-1));
    removeButton.addEventListener("click", () => {
        if (selected === 0) return;
        layers.splice(selected, 1);
        selected = Math.min(selected, layers.length - 1);
        layout(false);
    });
    wire();
    onDismiss(() => close(null));
    window.MU.cropImage = edit;
    window.MU.cropGeometry = {clamp, drag, output, outputType, MIN_EDGE};
}());
