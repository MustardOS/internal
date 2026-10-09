(function () {
    "use strict";

    const base = document.querySelector('script[src*="profile-builder.js"]').src.replace(/assets\/js\/profile-builder\.js.*$/, "");
    const byId = (id) => document.getElementById(id);

    const groupsHost = byId("profile-groups");
    const status = byId("profile-status");
    const count = byId("profile-count");
    const search = byId("profile-search");
    const onlyIncluded = byId("profile-only");
    const presetSelect = byId("profile-preset");
    const nameInput = byId("profile-name");
    const descriptionInput = byId("profile-description");
    const unknownBox = byId("profile-unknown");

    let schema = null;
    const rows = new Map();
    const groupRows = new Map();
    let networkKeys = new Set();
    let wasFiltering = false;
    let openBeforeFilter = new Map();

    function setStatus(text, tone) {
        status.textContent = text;
        status.classList.toggle("good", tone === "good");
        status.classList.toggle("bad", tone === "bad");
    }

    function humanise(key) {
        return key.split("/").pop().split("_").filter(Boolean)
            .map((word) => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
    }

    function isToggle(setting) {
        return setting.type === "int" && !setting.options && setting.min === 0 && setting.max === 1;
    }

    function makeControl(setting) {
        if (setting.options && setting.options.length) {
            const select = document.createElement("select");
            for (const option of setting.options) {
                select.add(new Option(option.label, option.value));
            }
            return select;
        }

        if (isToggle(setting)) {
            const select = document.createElement("select");
            select.add(new Option("Disabled", "0"));
            select.add(new Option("Enabled", "1"));
            return select;
        }

        const input = document.createElement("input");
        if (setting.type === "int") {
            input.type = "number";
            input.step = "1";
            if (typeof setting.min === "number") input.min = setting.min;
            if (typeof setting.max === "number") input.max = setting.max;
        } else {
            input.type = "text";
            input.maxLength = 255;
        }
        return input;
    }

    function setValue(row, value) {
        const control = row.control;
        if (control.tagName === "SELECT" && ![...control.options].some((option) => option.value === value)) {
            control.add(new Option(value, value));
        }
        control.value = value;
    }

    function valueValid(row) {
        const value = row.control.value;
        if (row.setting.type !== "int") return !/[\r\n]/.test(value);
        if (!/^-?\d+$/.test(value)) return false;
        const number = Number(value);
        if (typeof row.setting.min === "number" && number < row.setting.min) return false;
        if (typeof row.setting.max === "number" && number > row.setting.max) return false;
        return true;
    }

    function buildRows() {
        const groups = new Map(schema.groups.map((group) => [group.id, {title: group.title, settings: []}]));
        for (const setting of schema.settings) {
            if (!groups.has(setting.group)) groups.set(setting.group, {title: humanise(setting.group), settings: []});
            groups.get(setting.group).settings.push(setting);
        }

        for (const group of groups.values()) {
            if (!group.settings.length) continue;

            const details = document.createElement("details");
            details.className = "profile-group";
            const summary = document.createElement("summary");
            const summaryTitle = document.createElement("span");
            summaryTitle.textContent = group.title;
            const summaryCount = document.createElement("span");
            summaryCount.className = "profile-group-count";
            summary.append(summaryTitle, summaryCount);
            details.append(summary);

            group.settings.sort((a, b) => (a.label || humanise(a.key)).localeCompare(b.label || humanise(b.key)));

            for (const setting of group.settings) {
                const wrapper = document.createElement("div");
                wrapper.className = "profile-setting";

                const include = document.createElement("input");
                include.type = "checkbox";
                include.setAttribute("aria-label", "Include " + (setting.label || humanise(setting.key)));

                const text = document.createElement("span");
                text.className = "profile-setting-text";
                const title = document.createElement("span");
                title.className = "profile-setting-title";
                title.textContent = setting.label || humanise(setting.key);
                if (setting.help) {
                    const tipId = "profile-tip-" + rows.size;
                    const help = document.createElement("button");
                    help.type = "button";
                    help.className = "profile-help";
                    help.textContent = "?";
                    help.setAttribute("aria-label", "About " + title.textContent);
                    help.setAttribute("aria-describedby", tipId);
                    const tip = document.createElement("span");
                    tip.className = "profile-tip";
                    tip.id = tipId;
                    tip.setAttribute("role", "tooltip");
                    tip.textContent = setting.help;
                    help.addEventListener("click", () => help.classList.toggle("open"));
                    help.addEventListener("blur", () => help.classList.remove("open"));
                    title.append(help, tip);
                }
                const meta = document.createElement("code");
                meta.textContent = setting.key;
                text.append(title, meta);

                const control = makeControl(setting);
                control.disabled = true;

                wrapper.append(include, text, control);
                details.append(wrapper);

                const row = {setting, wrapper, include, control, details, search: (title.textContent + " " + setting.key).toLowerCase()};
                if (!groupRows.has(details)) groupRows.set(details, []);
                groupRows.get(details).push(row);
                setValue(row, setting.default);

                include.addEventListener("change", () => {
                    control.disabled = !include.checked;
                    wrapper.classList.toggle("included", include.checked);
                    refresh();
                });
                control.addEventListener("input", refresh);
                rows.set(setting.key, row);
            }

            groupsHost.append(details);
        }
    }

    function refresh() {
        const term = search.value.trim().toLowerCase();
        const filtering = Boolean(term) || onlyIncluded.checked;
        if (filtering && !wasFiltering) {
            openBeforeFilter = new Map([...groupsHost.children].map((details) => [details, details.open]));
        }
        let included = 0;
        let invalid = 0;

        for (const row of rows.values()) {
            if (row.include.checked) {
                included++;
                const valid = valueValid(row);
                row.wrapper.classList.toggle("invalid", !valid);
                if (!valid) invalid++;
            } else {
                row.wrapper.classList.remove("invalid");
            }

            const visible = (!term || row.search.includes(term)) && (!onlyIncluded.checked || row.include.checked);
            if (row.wrapper.hidden === visible) row.wrapper.hidden = !visible;
        }

        for (const [details, members] of groupRows) {
            const any = members.some((row) => !row.wrapper.hidden);
            if (details.hidden === any) details.hidden = !any;
            const includedHere = members.filter((row) => row.include.checked).length;
            const countText = includedHere ? includedHere + " included" : "";
            const countLabel = details.querySelector(".profile-group-count");
            if (countLabel.textContent !== countText) countLabel.textContent = countText;
            if (filtering) details.open = any;
            else if (wasFiltering) details.open = openBeforeFilter.get(details) || false;
        }
        wasFiltering = filtering;

        count.textContent = included === 1 ? "1 setting included" : included + " settings included";
        if (invalid) setStatus(invalid === 1 ? "1 value is out of range" : invalid + " values are out of range", "bad");
        else setStatus("");
    }

    function clearAll() {
        for (const row of rows.values()) {
            row.include.checked = false;
            row.control.disabled = true;
            row.wrapper.classList.remove("included");
            setValue(row, row.setting.default);
        }
        unknownBox.hidden = true;
        unknownBox.textContent = "";
    }

    function startOver() {
        clearAll();
        onlyIncluded.checked = false;
        wasFiltering = false;
        for (const details of groupsHost.children) details.open = false;
    }

    function loadProfile(text, fallbackName) {
        clearAll();
        for (const details of groupsHost.children) {
            details.open = false;
            if (wasFiltering) openBeforeFilter.set(details, false);
        }
        const unknown = [];
        const network = [];
        let name = "";
        let description = "";

        for (let line of text.replace(/^﻿/, "").split(/\r?\n/)) {
            if (!line || /^\s*#/.test(line) || !line.includes("=")) continue;
            const key = line.slice(0, line.indexOf("="));
            const value = line.slice(line.indexOf("=") + 1);

            if (!key.includes("/")) {
                if (key === "name") name = value;
                if (key === "description") description = value;
                continue;
            }

            const row = rows.get(key);
            if (!row) {
                (networkKeys.has(key) ? network : unknown).push(key);
                continue;
            }

            row.include.checked = true;
            row.control.disabled = false;
            row.wrapper.classList.add("included");
            setValue(row, value);
            row.details.open = true;
            if (wasFiltering) openBeforeFilter.set(row.details, true);
        }

        nameInput.value = name || fallbackName || "My Profile";
        descriptionInput.value = description;
        onlyIncluded.checked = [...rows.values()].some((row) => row.include.checked);

        const notes = [];
        if (network.length) {
            notes.push("Network lines were left out, because the builder never keeps network details: "
                + network.join(", ") + ". Put them in wifi.conf instead, as described at the bottom of this page.");
        }
        if (unknown.length) {
            notes.push("These lines are not settings a profile can change, so the device would refuse the profile: "
                + unknown.join(", "));
        }
        if (notes.length) {
            unknownBox.hidden = false;
            unknownBox.textContent = notes.join(" ");
        }

        refresh();
    }

    function profileText() {
        const lines = [
            "name=" + nameInput.value.replace(/[\r\n]/g, " ").trim(),
            "description=" + descriptionInput.value.replace(/[\r\n]/g, " ").trim(),
            "type=user",
        ];
        for (const setting of schema.settings) {
            const row = rows.get(setting.key);
            if (row && row.include.checked) lines.push(setting.key + "=" + row.control.value);
        }
        return lines.join("\n") + "\n";
    }

    function readyToSave() {
        const included = [...rows.values()].filter((row) => row.include.checked);
        if (!included.length) {
            setStatus("Include at least one setting first", "bad");
            return false;
        }
        if (included.some((row) => !valueValid(row))) {
            setStatus("Fix the highlighted values first", "bad");
            return false;
        }
        return true;
    }

    function download(fileName) {
        if (!readyToSave()) return;

        const blob = new Blob([profileText()], {type: "text/plain"});
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = fileName;
        document.body.append(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(link.href), 1000);
        setStatus("Saved " + fileName, "good");
    }

    function safeFileName(name) {
        const cleaned = name.replace(/[\\/:*?"<>|]+/g, "_").replace(/\s+/g, " ").trim();
        return (cleaned || "My Profile") + ".conf";
    }

    function init(data) {
        schema = data;
        networkKeys = new Set((schema.wifi || []).map((entry) => entry.key));
        const wifiTable = byId("profile-wifi-keys");
        for (const entry of schema.wifi || []) {
            const row = wifiTable.insertRow();
            const name = document.createElement("code");
            name.textContent = entry.name;
            row.insertCell().append(name);
            row.insertCell().textContent = entry.values;
            row.insertCell().textContent = entry.label;
        }
        buildRows();

        presetSelect.add(new Option("Blank Profile", ""));
        for (const [index, profile] of (schema.builtin || []).entries()) {
            presetSelect.add(new Option(profile.name, String(index)));
        }

        presetSelect.addEventListener("change", () => {
            if (presetSelect.value === "") {
                startOver();
                nameInput.value = "My Profile";
                descriptionInput.value = "";
                refresh();
                return;
            }
            const profile = schema.builtin[Number(presetSelect.value)];
            const text = Object.entries(profile.settings).map(([key, value]) => key + "=" + value).join("\n");
            loadProfile("name=" + profile.name + "\ndescription=" + profile.description + "\n" + text, profile.name);
        });

        byId("profile-open").addEventListener("change", async (event) => {
            const file = event.target.files[0];
            if (!file) return;
            presetSelect.value = "";
            loadProfile(await file.text(), file.name.replace(/\.conf$/i, ""));
            setStatus("Opened " + file.name);
            event.target.value = "";
        });

        byId("profile-clear").addEventListener("click", () => {
            presetSelect.value = "";
            startOver();
            refresh();
        });
        byId("profile-download").addEventListener("click", () => download(safeFileName(nameInput.value)));
        byId("profile-download-oem").addEventListener("click", () => download("profile.conf"));
        search.addEventListener("input", refresh);

        onlyIncluded.addEventListener("change", refresh);

        const device = window.MUTool;
        if (device) {
            device.bar(document.querySelector("#profile-tool .toolbar"), [
                ["Open from Device", async () => {
                    try {
                        const user = (await device.list("profile")).map((file) => ({label: file.path.replace(/\.conf$/i, ""), value: ["profile", file.path], hint: "Your profile"}));
                        const builtin = (await device.list("profile-builtin")).map((file) => ({label: file.path.replace(/^\d+-/, "").replace(/\.conf$/i, "").replace(/-/g, " "), value: ["profile-builtin", file.path], hint: "Built-in profile"}));
                        const picked = await device.choose("Open a profile from the device", [...user, ...builtin]);
                        if (!picked) return;
                        presetSelect.value = "";
                        loadProfile(await device.text(picked[0], picked[1]), picked[1].replace(/\.conf$/i, ""));
                        setStatus("Opened " + picked[1] + " from the device");
                    } catch (error) {
                        setStatus(error.message, "bad");
                    }
                }],
                ["Save to Device", async () => {
                    if (!readyToSave()) return;
                    const fileName = safeFileName(nameInput.value);
                    try {
                        await device.save("profile", fileName, profileText());
                        setStatus("Saved " + fileName + " to MUOS/profile. It is ready under Profiles on the device.", "good");
                    } catch (error) {
                        setStatus(error.message, "bad");
                    }
                }, true]
            ]);
        }

        refresh();
    }

    function openSectionFromHash() {
        const section = location.hash ? document.getElementById(location.hash.slice(1)) : null;
        if (section && section.tagName === "DETAILS") {
            section.open = true;
            section.scrollIntoView();
        }
    }

    window.addEventListener("hashchange", openSectionFromHash);
    openSectionFromHash();

    fetch(base + "assets/data/profile-schema.json")
        .then((response) => {
            if (!response.ok) throw new Error(response.status);
            return response.json();
        })
        .then(init)
        .catch(() => setStatus("The settings list could not be loaded", "bad"));
})();
