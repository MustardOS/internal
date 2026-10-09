(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const A = window.MUOS_ACTIVITY;
  const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
    "November", "December"];
  const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  let items = [];
  let current = null;

  function sessionsFor(year) {
    const list = [];
    for (const item of items) {
      for (const session of item.sessions || []) {
        if (session.start <= 0 || session.length <= 0) continue;
        const when = new Date(session.start * 1000);
        if (when.getFullYear() === year) list.push({...session, when, item});
      }
    }
    return list;
  }

  function busiest(map) {
    let best = null;
    let most = -1;
    map.forEach((value, key) => { if (value > most) { most = value; best = key; } });
    return best === null ? null : [best, most];
  }

  function streak(sessions) {
    const days = [...new Set(sessions.map(session => {
      const when = session.when;
      return Date.UTC(when.getFullYear(), when.getMonth(), when.getDate()) / 86400000;
    }))].sort((a, b) => a - b);
    let longest = 0;
    let run = 0;
    for (let index = 0; index < days.length; index++) {
      run = index && days[index] === days[index - 1] + 1 ? run + 1 : 1;
      longest = Math.max(longest, run);
    }
    return {longest, days: days.length};
  }

  function review(year) {
    const sessions = sessionsFor(year);
    if (!sessions.length) return null;
    const byTitle = new Map();
    const byCore = new Map();
    const byMonth = new Map();
    const byDay = new Map();
    let total = 0;
    let longest = sessions[0];
    for (const session of sessions) {
      total += session.length;
      byTitle.set(session.item.name, (byTitle.get(session.item.name) || 0) + session.length);
      const core = A.coreName(session.core || session.item.core);
      byCore.set(core, (byCore.get(core) || 0) + session.length);
      byMonth.set(session.when.getMonth(), (byMonth.get(session.when.getMonth()) || 0) + session.length);
      byDay.set(session.when.getDay(), (byDay.get(session.when.getDay()) || 0) + 1);
      if (session.length > longest.length) longest = session;
    }
    const fresh = items.filter(item => item.first > 0 && new Date(item.first * 1000).getFullYear() === year).length;
    const days = streak(sessions);
    return {
      year, total, sessions: sessions.length, titles: byTitle.size, fresh,
      top: busiest(byTitle), core: busiest(byCore), month: busiest(byMonth), day: busiest(byDay),
      longest, streak: days.longest, daysPlayed: days.days
    };
  }

  function cards(stats) {
    return [
      ["Time played", A.duration(stats.total), `${stats.sessions} sessions across ${stats.daysPlayed} days`],
      ["Most played", stats.top[0], A.duration(stats.top[1])],
      ["Longest session", A.duration(stats.longest.length), stats.longest.item.name],
      ["Favourite core", stats.core[0], A.duration(stats.core[1])],
      ["Busiest month", MONTHS[stats.month[0]], A.duration(stats.month[1])],
      ["Favourite day", DAYS[stats.day[0]], `${stats.day[1]} sessions`],
      ["Longest streak", `${stats.streak} ${stats.streak === 1 ? "day" : "days"}`, "Playing on consecutive days"],
      ["Titles played", String(stats.titles), stats.fresh ? `${stats.fresh} new this year` : "Old favourites only"]
    ];
  }

  function render() {
    const holder = $("#review-cards");
    holder.replaceChildren();
    const year = Number($("#review-year").value);
    current = review(year);
    $("#review-save").disabled = !current;
    if (!current) {
      const empty = document.createElement("div");
      empty.className = "empty";
      empty.textContent = `No sessions recorded in ${year}.`;
      holder.append(empty);
      return;
    }
    for (const [label, value, detail] of cards(current)) {
      const card = document.createElement("div");
      card.className = "review-card";
      const caption = document.createElement("span");
      caption.className = "help";
      caption.textContent = label;
      const strong = document.createElement("strong");
      strong.textContent = value;
      const small = document.createElement("span");
      small.textContent = detail;
      card.append(caption, strong, small);
      holder.append(card);
    }
  }

  function fit(context, text, width) {
    if (context.measureText(text).width <= width) return text;
    let cut = text;
    while (cut.length > 1 && context.measureText(`${cut}…`).width > width) cut = cut.slice(0, -1);
    return `${cut}…`;
  }

  function saveImage() {
    if (!current) return;
    const canvas = $("#review-canvas");
    const context = canvas.getContext("2d");
    const accent = getComputedStyle(document.querySelector("a")).color;
    const font = getComputedStyle(document.body).fontFamily;
    context.fillStyle = "#1f1f1f";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.strokeStyle = accent;
    context.lineWidth = 6;
    context.strokeRect(36, 36, canvas.width - 72, canvas.height - 72);

    context.fillStyle = accent;
    context.font = `600 34px ${font}`;
    context.fillText("MUSTARDOS YEAR IN REVIEW", 90, 140);
    context.fillStyle = "#ffffff";
    context.font = `800 120px ${font}`;
    context.fillText(String(current.year), 84, 270);

    const list = cards(current);
    list.forEach(([label, value, detail], index) => {
      const column = index % 2;
      const row = Math.floor(index / 2);
      const x = 90 + column * 470;
      const y = 380 + row * 220;
      context.fillStyle = "#959396";
      context.font = `500 28px ${font}`;
      context.fillText(label.toUpperCase(), x, y);
      context.fillStyle = "#ffffff";
      context.font = `700 46px ${font}`;
      context.fillText(fit(context, value, 420), x, y + 58);
      context.fillStyle = accent;
      context.font = `400 26px ${font}`;
      context.fillText(fit(context, detail, 420), x, y + 100);
    });

    context.fillStyle = "#959396";
    context.font = `400 26px ${font}`;
    context.fillText("muos.dev", 90, canvas.height - 80);

    canvas.toBlob(blob => {
      if (!blob) return;
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = `mustardos-${current.year}-in-review.png`;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(link.href), 5000);
    }, "image/png");
  }

  document.addEventListener("activity-loaded", event => {
    items = event.detail || [];
    const years = [...new Set(items.flatMap(item => (item.sessions || [])
      .filter(session => session.start > 0)
      .map(session => new Date(session.start * 1000).getFullYear())))].sort((a, b) => b - a);
    const select = $("#review-year");
    const previous = Number(select.value);
    select.replaceChildren(...years.map(year => {
      const option = document.createElement("option");
      option.value = String(year);
      option.textContent = String(year);
      return option;
    }));
    $("#review-panel").hidden = years.length === 0;
    if (!years.length) return;
    select.value = String(years.includes(previous) ? previous : years[0]);
    render();
  });

  $("#review-year").addEventListener("change", render);
  $("#review-save").addEventListener("click", saveImage);
})();
