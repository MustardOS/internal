(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const BANDS = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  const LABELS = ["Pre", "31", "62", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"];
  const LIMIT = 12;
  const STEP = 0.25;
  const PRESETS = [
    ["Flat", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]],
    ["Bass Boost", [-4, 6, 5, 4, 2, 0, 0, 0, 0, 0, 0]],
    ["Treble Boost", [-4, 0, 0, 0, 0, 0, 0, 1, 3, 5, 6]],
    ["Vocal", [-2, -2, -2, -1, 1, 3, 4, 4, 2, 0, -1]],
    ["Rock", [-3, 4, 3, 2, -1, -2, -1, 1, 3, 4, 4]],
    ["Pop", [-2, -1, 0, 2, 3, 4, 3, 1, 0, -1, -1]],
    ["Jazz", [-2, 3, 2, 1, 2, -1, -1, 0, 1, 2, 3]],
    ["Classical", [-2, 3, 2, 1, 0, 0, 0, -1, -1, 2, 3]],
    ["Electronic", [-4, 5, 4, 1, 0, -2, 1, 0, 2, 4, 5]],
    ["Spoken Word", [-2, -4, -3, -1, 1, 3, 4, 3, 1, -1, -3]],
    ["Small Speakers", [-4, -6, -4, 1, 3, 3, 2, 1, 1, 2, 2]],
    ["Headphones", [-2, 3, 2, 0, -1, -1, 0, 1, 2, 3, 2]],
    ["Loudness", [-4, 5, 4, 2, 0, -1, -1, 0, 2, 4, 4]],
    ["Late Night", [0, -4, -3, -2, 0, 1, 2, 1, 0, -2, -3]]
  ];
  let gains = new Array(11).fill(0);
  let audio = null;
  let bypass = false;

  function setStatus(text, kind = "") {
    $("#eq-status").textContent = text;
    $("#eq-status").className = `status ${kind}`.trim();
  }

  function clamp(value) {
    return Math.max(-LIMIT, Math.min(LIMIT, Math.round(value / STEP) * STEP));
  }

  function format(value) {
    if (value === 0) return "0";
    const text = String(Math.abs(value)).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "");
    return `${value > 0 ? "+" : "-"}${text}`;
  }

  function coefficients(band, decibels, rate) {
    const frequency = Math.min(BANDS[band], rate * 0.45);
    const amplitude = 10 ** (decibels / 40);
    const omega = 2 * Math.PI * frequency / rate;
    const cosine = Math.cos(omega);
    const sine = Math.sin(omega);
    let b0, b1, b2, a0, a1, a2;
    if (band === 0 || band === BANDS.length - 1) {
      const root = 2 * Math.sqrt(amplitude) * (sine / 2 * Math.SQRT2);
      const up = amplitude + 1;
      const down = amplitude - 1;
      if (band === 0) {
        b0 = amplitude * (up - down * cosine + root); b1 = 2 * amplitude * (down - up * cosine);
        b2 = amplitude * (up - down * cosine - root); a0 = up + down * cosine + root;
        a1 = -2 * (down + up * cosine); a2 = up + down * cosine - root;
      } else {
        b0 = amplitude * (up + down * cosine + root); b1 = -2 * amplitude * (down + up * cosine);
        b2 = amplitude * (up + down * cosine - root); a0 = up - down * cosine + root;
        a1 = 2 * (down - up * cosine); a2 = up - down * cosine - root;
      }
    } else {
      const alpha = sine / (2 * 1.41);
      b0 = 1 + alpha * amplitude; b1 = -2 * cosine; b2 = 1 - alpha * amplitude;
      a0 = 1 + alpha / amplitude; a1 = -2 * cosine; a2 = 1 - alpha / amplitude;
    }
    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
  }

  function response(frequency, rate) {
    let total = gains[0];
    const omega = 2 * Math.PI * frequency / rate;
    const re1 = Math.cos(omega), im1 = -Math.sin(omega);
    const re2 = Math.cos(2 * omega), im2 = -Math.sin(2 * omega);
    for (let band = 0; band < BANDS.length; band++) {
      if (!gains[band + 1]) continue;
      const [b0, b1, b2, a1, a2] = coefficients(band, gains[band + 1], rate);
      const nr = b0 + b1 * re1 + b2 * re2, ni = b1 * im1 + b2 * im2;
      const dr = 1 + a1 * re1 + a2 * re2, di = a1 * im1 + a2 * im2;
      total += 10 * Math.log10((nr * nr + ni * ni) / (dr * dr + di * di));
    }
    return total;
  }

  function drawCurve() {
    const canvas = $("#eq-curve");
    const context = canvas.getContext("2d");
    const style = getComputedStyle(document.body);
    const ink = style.color;
    const accent = getComputedStyle(document.querySelector("a")).color;
    const {width, height} = canvas;
    context.clearRect(0, 0, width, height);
    const range = 18;
    const y = value => height / 2 - value / range * (height / 2 - 8);
    const x = frequency => (Math.log10(frequency) - Math.log10(20)) / (Math.log10(20000) - Math.log10(20)) * width;
    context.globalAlpha = 0.25;
    context.strokeStyle = ink;
    context.lineWidth = 1;
    for (const value of [-12, -6, 0, 6, 12]) {
      context.beginPath();
      context.moveTo(0, y(value));
      context.lineTo(width, y(value));
      context.stroke();
    }
    context.globalAlpha = 0.6;
    context.fillStyle = ink;
    context.font = "12px sans-serif";
    BANDS.forEach((frequency, index) => {
      const text = LABELS[index + 1];
      const left = Math.min(width - context.measureText(text).width - 2, Math.max(2, x(frequency) - context.measureText(text).width / 2));
      context.fillText(text, left, height - 4);
    });
    context.globalAlpha = 1;
    context.strokeStyle = accent;
    context.lineWidth = 2.5;
    context.beginPath();
    for (let step = 0; step <= width; step += 3) {
      const frequency = 20 * (1000 ** (step / width));
      const value = Math.max(-range, Math.min(range, response(frequency, 48000)));
      if (step === 0) context.moveTo(step, y(value)); else context.lineTo(step, y(value));
    }
    context.stroke();
  }

  function buildSliders() {
    const holder = $("#eq-sliders");
    holder.replaceChildren();
    gains.forEach((gain, index) => {
      const column = document.createElement("label");
      column.className = `eq-slider${index === 0 ? " eq-pre" : ""}`;
      const value = document.createElement("output");
      value.id = `eq-value-${index}`;
      value.textContent = format(gain);
      const input = document.createElement("input");
      input.type = "range";
      input.id = `eq-band-${index}`;
      input.min = String(-LIMIT);
      input.max = String(LIMIT);
      input.step = String(STEP);
      input.value = String(gain);
      input.setAttribute("aria-label", index ? `${LABELS[index]} Hz` : "Preamp");
      input.addEventListener("input", () => setGain(index, Number(input.value)));
      const name = document.createElement("span");
      name.textContent = LABELS[index];
      column.append(value, input, name);
      holder.append(column);
    });
  }

  function syncSliders() {
    gains.forEach((gain, index) => {
      $(`#eq-band-${index}`).value = String(gain);
      $(`#eq-value-${index}`).textContent = format(gain);
    });
    drawCurve();
    applyAudio();
  }

  function setGain(index, value) {
    gains[index] = clamp(value);
    $(`#eq-value-${index}`).textContent = format(gains[index]);
    $("#eq-preset").value = "";
    drawCurve();
    applyAudio();
  }

  function fileText() {
    return `gains=${gains.map(format).map(value => value.replace(/^\+/, "")).join(",")}\n`;
  }

  function parse(text) {
    const line = (text.match(/gains=([^\n\r]*)/) || [null, text])[1];
    const values = line.split(",").map(Number);
    if (values.length < 1 || values.some(Number.isNaN)) throw new Error("This is not an equaliser profile.");
    return gains.map((_, index) => clamp(values[index] || 0));
  }

  function applyAudio() {
    if (!audio) return;
    const now = audio.context.currentTime;
    audio.pre.gain.setTargetAtTime(bypass ? 1 : 10 ** (gains[0] / 20), now, 0.02);
    audio.filters.forEach((filter, band) => filter.gain.setTargetAtTime(bypass ? 0 : gains[band + 1], now, 0.02));
  }

  function startAudio(file) {
    const player = $("#eq-player");
    if (!audio) {
      const context = new AudioContext();
      const source = context.createMediaElementSource(player);
      const pre = context.createGain();
      const filters = BANDS.map((frequency, band) => {
        const filter = context.createBiquadFilter();
        filter.type = band === 0 ? "lowshelf" : band === BANDS.length - 1 ? "highshelf" : "peaking";
        filter.frequency.value = frequency;
        if (filter.type === "peaking") filter.Q.value = 1.41;
        return filter;
      });
      const limiter = context.createDynamicsCompressor();
      limiter.threshold.value = -1;
      limiter.ratio.value = 20;
      source.connect(pre);
      filters.reduce((previous, filter) => { previous.connect(filter); return filter; }, pre).connect(limiter);
      limiter.connect(context.destination);
      audio = {context, pre, filters};
    }
    player.src = URL.createObjectURL(file);
    player.hidden = false;
    $("#eq-bypass").disabled = false;
    audio.context.resume();
    applyAudio();
    player.play().catch(() => {});
  }

  const select = $("#eq-preset");
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Custom";
  select.append(placeholder);
  PRESETS.forEach(([name], index) => {
    const option = document.createElement("option");
    option.value = String(index);
    option.textContent = name;
    select.append(option);
  });
  select.value = "0";

  select.addEventListener("change", () => {
    if (select.value === "") return;
    const [name, values] = PRESETS[Number(select.value)];
    gains = [...values];
    $("#eq-name").value = name === "Flat" ? "My Profile" : `My ${name}`;
    syncSliders();
    select.value = String(PRESETS.findIndex(([label]) => label === name));
  });

  $("#eq-reset").addEventListener("click", () => {
    gains = new Array(11).fill(0);
    select.value = "0";
    syncSliders();
  });

  $("#eq-open").addEventListener("change", async event => {
    const file = event.target.files[0];
    if (!file) return;
    try {
      gains = parse(await file.text());
      $("#eq-name").value = file.name.replace(/\.eq$/i, "");
      select.value = "";
      syncSliders();
      setStatus(`Opened ${file.name}.`, "good");
    } catch (error) {
      setStatus(error.message, "bad");
    }
    event.target.value = "";
  });

  $("#eq-download").addEventListener("click", () => {
    const name = $("#eq-name").value.replace(/[\\/:*?"<>|]/g, "").trim() || "My Profile";
    const link = document.createElement("a");
    link.href = URL.createObjectURL(new Blob([fileText()], {type: "text/plain"}));
    link.download = `${name}.eq`;
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(link.href), 5000);
    setStatus(`Downloaded ${name}.eq.`, "good");
  });

  $("#eq-audio").addEventListener("change", event => {
    const file = event.target.files[0];
    if (file) startAudio(file);
  });

  $("#eq-bypass").addEventListener("click", () => {
    bypass = !bypass;
    $("#eq-bypass").setAttribute("aria-pressed", String(bypass));
    $("#eq-bypass").classList.toggle("active", bypass);
    applyAudio();
  });

  buildSliders();
  drawCurve();

  const device = window.MUTool;
  if (device) {
    device.bar($("#eq-tool .toolbar"), [
      ["Open from Device", async () => {
        try {
          const items = (await device.list("equaliser")).map(file => ({label: file.path.replace(/\.eq$/i, ""), value: file.path}));
          const picked = await device.choose("Open a saved equaliser profile", items, "Profiles saved in Wasabi live in MUOS/save/wasabi/equaliser.");
          if (!picked) return;
          gains = parse(await device.text("equaliser", picked));
          $("#eq-name").value = picked.replace(/\.eq$/i, "");
          select.value = "";
          syncSliders();
          setStatus(`Opened ${picked} from the device.`, "good");
        } catch (error) {
          setStatus(error.message, "bad");
        }
      }],
      ["Save to Device", async () => {
        const name = $("#eq-name").value.replace(/[\\/:*?"<>|]/g, "").trim() || "My Profile";
        try {
          await device.save("equaliser", `${name}.eq`, fileText());
          setStatus(`Saved ${name}.eq. It appears under saved profiles in the Wasabi Equaliser.`, "good");
        } catch (error) {
          setStatus(error.message, "bad");
        }
      }, true]
    ]);
  }
})();
