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
        if (!limit) return {width: crop.width, height: crop.height};
        const ratio = limit / longest;
        return {
            width: Math.max(1, Math.round(crop.width * ratio)),
            height: Math.max(1, Math.round(crop.height * ratio))
        };
    }

    const SIZES = [
        {label: "Crop size", limit: 0},
        {label: "640px output", limit: 640},
        {label: "480px output", limit: 480},
        {label: "320px output", limit: 320}
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
    const layerScale = el("crop-layer-scale");
    const layerScaleValue = el("crop-layer-scale-value");
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
    let displayScale = 1;
    let pending = null;
    let sourceUrls = [];
    let baseFile = null;
    let baseLayer = null;

    function renderLayer(context, layer) {
        const nativeWidth = layer.image.naturalWidth || layer.image.width;
        const nativeHeight = layer.image.naturalHeight || layer.image.height;
        const ratio = layer.fit * layer.size;
        const width = nativeWidth * ratio;
        const height = nativeHeight * ratio;
        context.save();
        context.globalAlpha = layer.opacity;
        context.translate(bounds.width / 2 + layer.x, bounds.height / 2 + layer.y);
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
        layers.forEach((layer) => renderLayer(context, layer));
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
        layerScale.value = String(Math.round(layer.size * 100));
        layerScaleValue.textContent = `${layerScale.value}%`;
        opacity.value = String(Math.round(layer.opacity * 100));
        opacityValue.textContent = `${opacity.value}%`;
        stage.classList.add("moving-layer");
        lowerButton.disabled = selected <= 0;
        raiseButton.disabled = selected >= layers.length - 1;
        removeButton.disabled = layers.length <= 1;
    }

    function paint() {
        const imageWidth = bounds.width * displayScale;
        const offsetX = Math.max(0, (stage.clientWidth - imageWidth) / 2);
        frame.style.left = `${offsetX + crop.x * displayScale}px`;
        frame.style.top = `${crop.y * displayScale}px`;
        frame.style.width = `${crop.width * displayScale}px`;
        frame.style.height = `${crop.height * displayScale}px`;
        const size = output(crop, Number(sizePick.value) || 0);
        sizeNote.textContent = `Crop ${crop.width} × ${crop.height} · Output ${size.width} × ${size.height}`;
    }

    function layout(resetCrop) {
        if (resetCrop) crop = {x: 0, y: 0, ...bounds};
        else crop = clamp(crop, bounds);
        const room = stage.clientWidth || 520;
        displayScale = Math.min(1, room / bounds.width, 420 / bounds.height);
        composite();
        canvas.style.width = `${bounds.width * displayScale}px`;
        canvas.style.height = `${bounds.height * displayScale}px`;
        stage.style.height = `${bounds.height * displayScale}px`;
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
        layout(false);
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
            const nativeWidth = image.naturalWidth || image.width;
            const nativeHeight = image.naturalHeight || image.height;
            const fit = Math.min(bounds.width * .8 / nativeWidth, bounds.height * .8 / nativeHeight);
            layers.push({name: file.name, image, opacity: 1, size: 1, fit, rotation: 0, flipX: false, flipY: false, x: 0, y: 0});
            selected = layers.length - 1;
            layout(false);
        } catch (_) {
        }
    }

    function moveLayer(direction) {
        const target = selected + direction;
        if (target < 0 || target >= layers.length) return;
        [layers[selected], layers[target]] = [layers[target], layers[selected]];
        selected = target;
        layout(false);
    }

    function shiftLayer(dx, dy) {
        const layer = layers[selected];
        if (!layer) return;
        const limitX = bounds.width / 2;
        const limitY = bounds.height / 2;
        layer.x = Math.max(-limitX, Math.min(limitX, layer.x + dx));
        layer.y = Math.max(-limitY, Math.min(limitY, layer.y + dy));
        composite();
    }

    function reset() {
        if (!layers.length) return;
        layers = [{...baseLayer}];
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
            start(event, "layer");
        });
        stage.addEventListener("pointermove", (event) => {
            if (!active) return;
            const dx = (event.clientX - last.x) / displayScale;
            const dy = (event.clientY - last.y) / displayScale;
            last = {x: event.clientX, y: event.clientY};
            if (active === "layer") return shiftLayer(dx, dy);
            crop = drag(crop, active, dx, dy, bounds);
            paint();
        });
        stage.tabIndex = 0;
        stage.addEventListener("keydown", (event) => {
            const steps = {ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1]};
            const step = steps[event.key];
            if (!step) return;
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
                bounds = {width: image.naturalWidth || image.width, height: image.naturalHeight || image.height};
                baseLayer = {name: file.name, image, opacity: 1, size: 1, fit: 1, rotation: 0, flipX: false, flipY: false, x: 0, y: 0};
                layers = [{...baseLayer}];
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
    layerScale.addEventListener("input", () => {
        if (!layers[selected]) return;
        layers[selected].size = Number(layerScale.value) / 100;
        layerScaleValue.textContent = `${layerScale.value}%`;
        composite();
    });
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
        if (layers.length <= 1) return;
        layers.splice(selected, 1);
        selected = Math.min(selected, layers.length - 1);
        layout(false);
    });
    wire();
    onDismiss(() => close(null));
    window.MU.cropImage = edit;
    window.MU.cropGeometry = {clamp, drag, output, outputType, MIN_EDGE};
}());
