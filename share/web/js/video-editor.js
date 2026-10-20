(function () {
    "use strict";

    const {el, holdFocus, onDismiss, showToast} = window.MU;
    const box = el("video-editor-box");
    const title = el("video-editor-title");
    const video = el("video-editor-preview");
    const start = el("video-editor-start");
    const end = el("video-editor-end");
    const fadeIn = el("video-editor-fade-in");
    const fadeOut = el("video-editor-fade-out");
    const saveButton = el("video-editor-save");
    const cancelButton = el("video-editor-cancel");
    let target = null;
    let frame = 0;

    function number(field) {
        const value = Number(field.value);
        return Number.isFinite(value) ? Math.max(0, value) : 0;
    }

    function values() {
        const duration = Number.isFinite(video.duration) ? video.duration : 0;
        const from = Math.min(number(start), Math.max(0, duration - .05));
        const until = Math.min(number(end) || duration, duration);
        const length = Math.max(0, until - from);
        return {
            start: from,
            end: until,
            fadeIn: Math.min(number(fadeIn), length),
            fadeOut: Math.min(number(fadeOut), length)
        };
    }

    function preview() {
        const edit = values();
        if (video.currentTime < edit.start || video.currentTime >= edit.end) video.currentTime = edit.start;
        const at = video.currentTime - edit.start;
        const left = edit.end - video.currentTime;
        let gain = 1;
        if (edit.fadeIn > 0 && at < edit.fadeIn) gain = Math.min(gain, at / edit.fadeIn);
        if (edit.fadeOut > 0 && left < edit.fadeOut) gain = Math.min(gain, left / edit.fadeOut);
        video.style.opacity = String(Math.max(0, gain));
        video.volume = Math.max(0, gain);
        frame = requestAnimationFrame(preview);
    }

    function close(result) {
        if (!target) return;
        const active = target;
        target = null;
        cancelAnimationFrame(frame);
        video.pause();
        video.removeAttribute("src");
        video.load();
        video.style.opacity = "";
        box.hidden = true;
        active.restore();
        active.settle(result);
    }

    async function save() {
        if (!target) return;
        const edit = values();
        if (edit.end <= edit.start) {
            showToast("The end must be after the start", "bad");
            return;
        }
        saveButton.disabled = true;
        try {
            if (await target.save({
                start_ms: Math.round(edit.start * 1000),
                end_ms: Math.round(edit.end * 1000),
                fade_in_ms: Math.round(edit.fadeIn * 1000),
                fade_out_ms: Math.round(edit.fadeOut * 1000)
            }) !== false) close(true);
        } catch (error) {
            showToast(error.message, "bad");
        } finally {
            saveButton.disabled = false;
        }
    }

    function edit({name, source, settings = {}, save: saveEdit}) {
        if (target) close(false);
        return new Promise((settle) => {
            target = {settle, restore: holdFocus(), save: saveEdit};
            title.textContent = name ? `Edit ${name}` : "Edit Video";
            video.src = source;
            box.hidden = false;
            video.addEventListener("loadedmetadata", () => {
                const duration = Number.isFinite(video.duration) ? video.duration : 0;
                start.max = end.max = fadeIn.max = fadeOut.max = String(duration);
                start.value = String((Number(settings.start_ms) || 0) / 1000);
                end.value = String((Number(settings.end_ms) || Math.round(duration * 1000)) / 1000);
                fadeIn.value = String((Number(settings.fade_in_ms) || 0) / 1000);
                fadeOut.value = String((Number(settings.fade_out_ms) || 0) / 1000);
                video.currentTime = number(start);
                video.play().catch(() => {});
                cancelAnimationFrame(frame);
                frame = requestAnimationFrame(preview);
                start.focus();
            }, {once: true});
        });
    }

    [start, end, fadeIn, fadeOut].forEach((field) => field.addEventListener("change", () => {
        if (field === start) video.currentTime = number(start);
    }));
    saveButton.addEventListener("click", save);
    cancelButton.addEventListener("click", () => close(false));
    onDismiss(() => close(false));
    window.MU.editVideo = edit;
}());
