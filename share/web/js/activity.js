(function () {
    "use strict";

    const t = (window.MU && window.MU.t) || ((text, ...values) => {
        let index = 0;
        return String(text).replace(/%s/g, () => (index < values.length ? String(values[index++]) : "%s"));
    });

    const MINUTE = 60;
    const HOUR = 60 * MINUTE;

    const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

    const LIBRETRO_CORES = {
        "mame": "MAME Current",
        "mame078plus": "MAME .78 Plus",
        "mame0139": "MAME .139",
        "mame2000": "MAME 2000",
        "mame2003": "MAME 2003",
        "mame2003_plus": "MAME 2003 Plus",
        "mame2003_midway": "MAME 2003 Midway",
        "mame2010": "MAME 2010",
        "km_mame2003_xtreme_amped": "MAME 2003 Xtreme",
        "fbneo": "FBNeo",
        "km_fbneo_xtreme_amped": "FBNeo Xtreme",
        "fbalpha2012": "FBA 2012",
        "fbalpha2012_cps1": "FBA CPS-1",
        "fbalpha2012_cps2": "FBA CPS-2",
        "fbalpha2012_cps3": "FBA CPS-3",
        "fbalpha2012_neogeo": "FBA Neo Geo",
        "nestopia": "Nestopia",
        "fceumm": "FCEUmm",
        "quicknes": "QuickNES",
        "mesen": "Mesen",
        "mesen-s": "Mesen-S",
        "snes9x": "Snes9x",
        "snes9x2002": "Snes9x 2002",
        "snes9x2005": "Snes9x 2005",
        "snes9x2005_plus": "Snes9x 2005+",
        "snes9x2010": "Snes9x 2010",
        "snes9x_next": "Snes9x Next",
        "bsnes": "BSNES",
        "bsnes2014_performance": "BSNES 2014",
        "bsnes_cplusplus98": "BSNES C++98",
        "bsnes_mercury_performance": "BSNES Mercury",
        "chimerasnes": "ChimeraSNES",
        "mednafen_supafaust": "Beetle Supafaust",
        "mupen64plus_next": "Mupen64+ Next",
        "gambatte": "Gambatte",
        "gearboy": "GearBoy",
        "sameboy": "SameBoy",
        "mgba": "mGBA",
        "mgba_rumble": "mGBA Rumble",
        "gpsp": "GpSP",
        "vbam": "VBA M",
        "vba_next": "VBA Next",
        "DoubleCherryGB": "Double Cherry",
        "fixgb": "FixGB",
        "tgbdual": "TGB Dual",
        "mednafen_gba": "Beetle GBA",
        "mednafen_vb": "Beetle VB",
        "genesis_plus_gx": "Gen Plus GX",
        "genesis_plus_gx_wide": "Gen Plus GX Wide",
        "genesis_plus_gx_expanded": "Gen Plus GX Exp.",
        "picodrive": "PicoDrive",
        "gearsystem": "GearSystem",
        "smsplus": "SMS Plus GX",
        "yabause": "Yabause",
        "yabasanshiro": "YabaSanshiro",
        "mednafen_saturn": "Beetle Saturn",
        "flycast": "Flycast",
        "flycastvl": "Flycast VL",
        "flycast-xtreme": "Flycast Xtreme",
        "morpheuscast": "MorpheusCast",
        "duckstation": "DuckStation",
        "pcsx_rearmed": "PCSX ReARMed",
        "swanstation": "SwanStation",
        "ppsspp": "PPSSPP",
        "mednafen_psx": "Beetle PSX",
        "stella": "Stella",
        "stella2014": "Stella 2014",
        "mednafen_lynx": "Beetle Lynx",
        "handy": "Handy",
        "a5200": "Atari 5200",
        "atari800": "Atari 800",
        "prosystem": "ProSystem",
        "virtualjaguar": "Virtual Jaguar",
        "cap32": "Caprice32",
        "crocods": "CrocoDS",
        "hatari": "Hatari",
        "hatarib": "HatariB",
        "bluemsx": "blueMSX",
        "fmsx": "fMSX",
        "px68k": "PX68k",
        "x1": "Sharp X1",
        "quasi88": "Quasi88",
        "np2kai": "Neko II Kai",
        "nekop2": "Neko II",
        "vice_x64": "VICE x64",
        "vice_x64sc": "VICE x64SC",
        "vice_xscpu64": "VICE xSCPU64",
        "vice_x128": "VICE x128",
        "vice_xpet": "VICE xPET",
        "vice_xvic": "VICE xVIC",
        "vice_xcbm2": "VICE xCBM-II",
        "vice_xcbm5x0": "VICE xCBM-5x0",
        "puae": "PUAE",
        "puae2021": "PUAE 2021",
        "uae4arm": "UAE4ARM",
        "km_puae_xtreme_amped_2k24": "PUAE Xtreme",
        "dosbox_pure": "DOSBox Pure",
        "dosbox_svn": "DOSBox SVN",
        "scummvm": "ScummVM",
        "prboom": "PrBoom",
        "ecwolf": "ECWolf",
        "nxengine": "NXEngine",
        "tic80": "TIC-80",
        "lutro": "Lutro",
        "freeintv": "FreeIntv",
        "o2em": "O2EM",
        "vecx": "VecX",
        "pokemini": "PokeMini",
        "opera": "Opera",
        "vircon32": "Vircon32",
        "uzem": "Uzem",
        "potator": "Potator",
        "wasm4": "WASM-4",
        "fake08": "Fake-08",
        "retro8": "Retro8",
        "neocd": "NeoCD",
        "race": "RACE",
        "geolith": "Geolith",
        "mednafen_wswan": "Beetle WonderSwan",
        "mednafen_ngp": "Beetle NeoPop",
        "mednafen_pce": "Beetle PCE",
        "mednafen_pce_fast": "Beetle PCE Fast",
        "mednafen_supergrafx": "Beetle SuperGrafx",
        "same_cdi": "SameCD-i",
        "easyrpg": "EasyRPG",
        "onscripter": "ONScripter",
        "onsyuri": "ONS Yuri",
        "numero": "Numero",
        "lowresnx": "LowRes NX",
        "dice": "DICE",
        "freechaf": "FreeChaF",
        "galaksija": "Galaksija",
        "jaxe": "JAXE",
        "chailove": "ChaiLove",
        "ardens": "Ardens",
        "arduous": "Arduous",
        "libgametank": "GameTank",
        "vemulator": "VeMUlator",
        "sameduck": "SameDuck",
        "tyrquake": "TyrQuake",
        "vitaquake2": "VitaQuake II",
        "2048": "2048",
        "81": "EightyOne",
        "bennugd": "BennuGD",
        "bk": "BK",
        "bnes": "BNES",
        "bsnes-jg": "bsnes-jg",
        "cannonball": "Cannonball",
        "daphne": "Daphne",
        "desmume2015": "DeSmuME 2015",
        "dirksimple": "DirkSimple",
        "dosbox_core": "DOSBox-core",
        "emuscv": "EmuSCV",
        "emux_chip8": "Emux CHIP-8",
        "emux_gb": "Emux GB",
        "emux_nes": "Emux NES",
        "emux_sms": "Emux SMS",
        "ep128emu_core": "ep128emu",
        "fbalpha": "FB Alpha",
        "fceunext": "FCEUNext",
        "freej2me": "FreeJ2ME - RetroArch",
        "frodo": "Frodo",
        "fuse": "Fuse",
        "gearcoleco": "Gearcoleco",
        "geargrafx": "Geargrafx",
        "gme": "Game Music Emu",
        "gw": "Handheld Electronic",
        "km_ludicrousn64_2k22_xtreme_amped": "Ludicrous N64 2k22 Xtreme Amped",
        "km_morpheuscast_xtreme": "MorpheusCast Xtreme",
        "mednafen_pcfx": "Beetle PC-FX",
        "melonds": "melonDS",
        "melondsds": "melonDS-DS",
        "minivmac": "Mini vMac",
        "mu": "Mu",
        "mupen64plus": "Mupen64Plus",
        "openlara": "OpenLara",
        "parallel_n64": "ParaLLel N64",
        "pcfx": "PC-FX",
        "pocketcdg": "PocketCDG",
        "pocketsnes": "PocketSNES",
        "press_f": "Press F",
        "puzzlescript": "PuzzleScript",
        "superbroswar": "Super Mario War",
        "theodore": "Theodore",
        "uw8": "MicroW8",
        "vb": "VB",
        "vice_x64dtv": "VICE x64 DTV",
        "vice_xplus4": "VICE xplus4",
        "vitaquake2-rogue": "VitaQuake2 - Rogue Mission Pack",
        "vitaquake2-xatrix": "VitaQuake2 - Xatrix Mission Pack",
        "vitaquake2-zaero": "VitaQuake2 - Zaero Mission Pack",
        "zc210": "Zelda Classic 2.10",
        "zc250x": "Zelda Classic 2.50x"
    };

    const EXTERNAL_CORES = {
        "external": "PortMaster",
        "ffplay": "FFPlay",
        "mpv-livetv": "MPV LiveTV",
        "mpv-general": "MPV",
        "mreader-landscape": "mReader Ln.",
        "mreader-portrait": "mReader Pt.",
        "freej2me-128": "J2ME 128x128",
        "freej2me-176": "J2ME 176x208",
        "freej2me-240": "J2ME 240x320",
        "freej2me-320": "J2ME 320x240",
        "freej2me-640": "J2ME 640x360",
        "drastic": "DraStic Advanced",
        "drastic-legacy": "DraStic Legacy",
        "mupen64plus-gliden64": "Mupen64+ Glide",
        "mupen64plus-gliden64-full": "Mupen64+ Glide - Full",
        "mupen64plus-glidemk2": "Mupen64+ GlideMK2",
        "mupen64plus-glidemk2-full": "Mupen64+ GlideMK2 - Full",
        "mupen64plus-rice": "Mupen64+ Rice",
        "mupen64plus-rice-full": "Mupen64+ Rice - Full",
        "openbor4432": "OpenBOR v4432",
        "openbor6412": "OpenBOR v6412",
        "openbor7142": "OpenBOR v7142",
        "openbor7530": "OpenBOR v7530",
        "yabasanshiro-hle": "YabaSanshiro HLE",
        "yabasanshiro-bios": "YabaSanshiro BIOS",
        "pico8-pixel": "PICO-8 Pixel",
        "pico8-scale": "PICO-8 Scaled",
        "azahar": "Azahar",
        "scummvm": "ScummVM",
        "flycast": "Flycast",
        "ppsspp": "PPSSPP",
        "pyxel": "Pyxel",
        "crisp": "Crisp Game Lib",
        "terminal": "Linux Script",
        "frotz": "Frotz - Z-Machine",
        "gen-overlay": "PortMaster + Overlay"
    };

    const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
    const plain = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

    function positive(value) {
        const number = Math.floor(Number(value));
        return Number.isFinite(number) && number > 0 ? number : 0;
    }

    function text(value) {
        return typeof value === "string" ? value : "";
    }

    function baseName(path) {
        const file = path.slice(path.lastIndexOf("/") + 1);
        const dot = file.lastIndexOf(".");
        return dot > 0 ? file.slice(0, dot) : file;
    }

    const ENDINGS = {
        normal: "Normal",
        switch: "Switched",
        error: "Crashed",
        interrupted: "Interrupted",
        lost: "Lost",
        poweroff: "Power Off"
    };

    const GROUPS = [
        {key: "all", label: "All Media"},
        {key: "pickles", label: "Pickles"},
        {key: "wasabi", label: "Wasabi"},
        {key: "retroarch", label: "RetroArch"},
        {key: "external", label: "External"}
    ];

    function runtimeOf(runtime, core) {
        if (runtime !== "all" && GROUPS.some((group) => group.key === runtime)) return runtime;
        if (core === "ext-video") return "wasabi";
        if (core.startsWith("ext-")) return "external";
        return "retroarch";
    }

    function launches(map, key) {
        if (!plain(map) || !key || !own(map, key)) return 0;
        return plain(map[key]) ? positive(map[key].launches) : positive(map[key]);
    }

    function sessionList(value) {
        if (!Array.isArray(value)) return [];

        return value.filter(plain).map((session) => ({
            start: positive(session.start),
            length: positive(session.length),
            core: text(session.core),
            runtime: runtimeOf(text(session.runtime), text(session.core)),
            device: text(session.device),
            mode: text(session.mode),
            battery: Number.isFinite(session.battery) ? session.battery : null,
            temperature: Number.isFinite(session.temperature) ? session.temperature : null,
            governor: text(session.governor),
            suspends: positive(session.suspends),
            ended: text(session.ended)
        }));
    }

    function contentKey(path) {
        const index = path.indexOf("/ROMS/");
        return (index >= 0 ? path.slice(index + 6) : path).toLowerCase();
    }

    function toItem(path, value) {
        if (!plain(value) || !("total_time" in value) || !("launches" in value)) return null;

        const core = text(value.last_core);
        const device = text(value.last_device);
        const mode = text(value.last_mode);
        const total = positive(value.total_time);
        const count = positive(value.launches);
        const last = positive(value.last_session);

        return {
            key: text(value.key) || contentKey(path),
            path,
            name: text(value.name).trim() || baseName(path),
            system: text(value.system),
            launches: count,
            total,
            average: count ? Math.floor(total / count) : 0,
            last,
            longest: Math.max(positive(value.longest_session), last),
            first: positive(value.first_played),
            started: positive(value.last_played) || positive(value.start_time),
            core,
            coreCount: launches(value.cores || value.core_launches, core),
            device,
            deviceCount: launches(value.devices || value.device_launches, device),
            mode,
            modeCount: launches(value.modes || value.mode_launches, mode),
            runtime: runtimeOf(text(value.last_runtime), core),
            endings: plain(value.endings) ? value.endings : {},
            sessions: sessionList(value.sessions)
        };
    }

    function isRecord(value) {
        return plain(value) && typeof value.path === "string" && "launches" in value;
    }

    function parse(data) {
        let items;

        if (Array.isArray(data)) {
            items = data.filter(isRecord).map((value) => toItem(value.path, value));
        } else if (isRecord(data)) {
            items = [toItem(data.path, data)];
        } else if (plain(data)) {
            items = Object.entries(data).map(([path, value]) => toItem(path, value));
        } else {
            throw new Error("This is not an Activity Tracker file.");
        }

        return items.filter((entry) => entry && entry.launches > 0);
    }

    function combine(lists) {
        const byKey = new Map();

        lists.flat().forEach((entry) => {
            const known = byKey.get(entry.key);
            if (!known || entry.launches > known.launches
                || (entry.launches === known.launches && entry.started > known.started))
                byKey.set(entry.key, entry);
        });

        return [...byKey.values()];
    }

    function localStyle(launches, total) {
        if (launches <= 0 || total <= 0) return "Unique";

        const average = Math.floor(total / launches);

        if (launches === 1 && total < 2 * HOUR) return "One and Done";
        if (launches <= 2 && total < 30 * MINUTE) return "Abandoned";
        if (launches >= 3 && total < HOUR) return "Sampler";
        if (total >= 100 * HOUR && launches >= 10) return "Marathoner";
        if (total >= 20 * HOUR && launches >= 5 && average >= 2 * HOUR) return "Completionist";
        if (launches <= 6 && average >= 3 * HOUR && total >= 8 * HOUR) return "Weekend Warrior";
        if (launches >= 10 && average < 15 * MINUTE && total >= 2 * HOUR) return "Short Bursts";
        if (launches >= 15 && average < 45 * MINUTE && total < 10 * HOUR) return "Returner";
        if (launches >= 3 && launches <= 8 && average < 30 * MINUTE) return "On and Off";
        if (launches >= 15 && average >= 20 * MINUTE && average <= 90 * MINUTE && total >= 15 * HOUR
            && total <= 80 * HOUR)
            return "Comfort Game";
        if (launches >= 5 && average >= 30 * MINUTE && average <= 2 * HOUR) return "Regular Play";
        if (launches <= 5 && average >= 2 * HOUR) return "Long Sessions";

        return "Unique";
    }

    function globalStyle(stats) {
        if (stats.total <= 0) return "Unique";

        const average = stats.average;

        if (stats.devices >= 3) return "Device Nomad";
        if (stats.launches >= 200 && stats.cores >= 10) return "Power Player";
        if (stats.cores <= 2 && stats.total >= 80 * HOUR) return "Specialist";
        if (stats.titles <= 5 && stats.total >= 100 * HOUR && average >= 2 * HOUR) return "Completionist";
        if (average >= 2 * HOUR) return "Binger";
        if (stats.titles >= 45 && average < 20 * MINUTE) return "Content Collector";
        if (stats.titles >= 20 && average < 30 * MINUTE && stats.total < 50 * HOUR) return "Window Shopper";
        if (stats.titles >= 10 && stats.titles < 45 && average < 45 * MINUTE && stats.total < 80 * HOUR)
            return "Explorer";
        if (stats.launches >= 75 && average >= 20 * MINUTE && average <= 90 * MINUTE && stats.titles >= 5
            && stats.titles <= 15)
            return "Routine Player";
        if (stats.launches >= 100 && average >= 30 * MINUTE) return "Core Gamer";
        if (stats.launches >= 50 && average >= 30 * MINUTE) return "Habitual Player";
        if (stats.total < 10 * HOUR && stats.launches < 100) return "Casual";

        return "Unique";
    }

    function tally(map, key, amount) {
        const normal = key.trim().toLowerCase();
        if (!normal) return;
        map.set(normal, (map.get(normal) || 0) + amount);
    }

    function busiest(map) {
        let best = "";
        let most = -1;
        map.forEach((amount, key) => {
            if (amount > most) {
                most = amount;
                best = key;
            }
        });
        return best;
    }

    function peak(buckets) {
        let best = -1;
        let most = 0;
        buckets.forEach((amount, index) => {
            if (amount > most) {
                most = amount;
                best = index;
            }
        });
        return best;
    }

    function summarise(items) {
        const cores = new Map();
        const devices = new Map();
        const modes = new Map();
        const hours = new Array(24).fill(0);
        const days = new Array(7).fill(0);

        const stats = {
            titles: items.length,
            launches: 0,
            total: 0,
            topTime: "",
            topTimeValue: 0,
            topLaunch: "",
            topLaunchValue: 0,
            oldest: "",
            longest: "",
            longestValue: 0,
            sessions: 0,
            unexpected: 0
        };

        let oldestTime = Infinity;
        let longestValue = 0;
        let drainUsed = 0;
        let drainTime = 0;
        let heatSum = 0;
        let heatCount = 0;

        items.forEach((item) => {
            stats.launches += item.launches;
            stats.total += item.total;

            if (item.total >= stats.topTimeValue) {
                stats.topTimeValue = item.total;
                stats.topTime = item.name;
            }

            if (item.launches >= stats.topLaunchValue) {
                stats.topLaunchValue = item.launches;
                stats.topLaunch = item.name;
            }

            const first = item.first || item.started;
            if (first > 0 && first < oldestTime) {
                oldestTime = first;
                stats.oldest = item.name;
            }

            const timed = item.sessions.filter((session) => session.start > 0 && session.length > 0);
            const spans = timed.length ? timed : (item.started > 0 ? [{start: item.started, length: item.total}] : []);
            spans.forEach((session) => {
                const when = new Date(session.start * 1000);
                hours[when.getHours()] += session.length;
                days[when.getDay()] += session.length;
            });

            item.sessions.forEach((session) => {
                stats.sessions += 1;
                if (session.ended === "error" || session.ended === "lost") stats.unexpected += 1;
                if (session.battery !== null && session.length >= 5 * MINUTE) {
                    drainUsed += session.battery;
                    drainTime += session.length;
                }
                if (session.temperature !== null) {
                    heatSum += session.temperature;
                    heatCount += 1;
                }
            });

            if (item.longest >= longestValue) {
                longestValue = item.longest;
                stats.longest = item.name;
                stats.longestValue = item.longest;
            }

            tally(cores, item.core, item.coreCount);
            tally(devices, item.device, item.deviceCount);
            tally(modes, item.mode, item.modeCount);
        });

        stats.core = busiest(cores);
        stats.device = busiest(devices);
        stats.mode = busiest(modes);
        stats.cores = cores.size;
        stats.devices = devices.size;
        stats.modes = modes.size;
        stats.activeHour = peak(hours);
        stats.favouriteDay = peak(days);
        stats.average = stats.launches > 0 ? Math.floor(stats.total / stats.launches) : 0;
        stats.style = globalStyle(stats);
        stats.oldestTime = Number.isFinite(oldestTime) ? oldestTime : 0;
        stats.drain = drainTime > 0 ? Math.round((drainUsed / drainTime) * HOUR * 10) / 10 : null;
        stats.temperature = heatCount ? Math.round((heatSum / heatCount) * 10) / 10 : null;

        return stats;
    }

    function coreName(core) {
        if (!core) return t("Unknown");
        if (core === "ext-video") return "Wasabi";
        if (core === "external") return t("%s (External)", EXTERNAL_CORES.external);
        if (core.startsWith("ext-") && own(EXTERNAL_CORES, core.slice(4)))
            return t("%s (External)", EXTERNAL_CORES[core.slice(4)]);

        const id = core.replace(/_libretro\.so$/, "");
        if (own(LIBRETRO_CORES, id)) return LIBRETRO_CORES[id];

        const spaced = id.replace(/_/g, " ");
        return spaced.charAt(0).toUpperCase() + spaced.slice(1);
    }

    function deviceName(device) {
        return device ? device.toUpperCase() : t("Unknown");
    }

    function modeName(mode) {
        return mode ? t(mode.charAt(0).toUpperCase() + mode.slice(1)) : t("Unknown");
    }

    function duration(seconds) {
        const total = positive(seconds);
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);

        if (days) return `${days}d ${hours}h ${minutes}m`;
        if (hours) return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    function stamp(epoch) {
        if (positive(epoch) <= 0) return t("Unknown");

        const when = new Date(epoch * 1000);
        const pad = (value) => String(value).padStart(2, "0");
        return `${when.getFullYear()}-${pad(when.getMonth() + 1)}-${pad(when.getDate())} `
            + `${pad(when.getHours())}:${pad(when.getMinutes())}`;
    }

    function hourName(hour) {
        if (hour < 0 || hour > 23) return t("Unknown");
        return `${hour % 12 || 12} ${hour < 12 ? "AM" : "PM"}`;
    }

    function dayName(day) {
        return DAYS[day] ? t(DAYS[day]) : t("Unknown");
    }

    function groupItems(items) {
        const groups = new Map(GROUPS.map((group) => [group.key, []]));
        groups.set("all", items.slice());
        items.forEach((entry) => groups.get(entry.runtime).push(entry));
        return groups;
    }

    const CORE_ROWS = ["Most Frequent Core", "Unique Cores Used"];
    const CORE_COLUMNS = ["core", "sessionCore"];

    function hasCores(group) {
        return group !== "wasabi";
    }

    function summaryRows(stats, group) {
        return summaryList(stats).filter(([label]) => hasCores(group) || !CORE_ROWS.includes(label));
    }

    function columnsFor(group) {
        return COLUMNS.filter((column) => hasCores(group) || !CORE_COLUMNS.includes(column.key));
    }

    function sessionColumnsFor(group) {
        return SESSION_COLUMNS.filter((column) => hasCores(group) || !CORE_COLUMNS.includes(column.key));
    }

    function summaryList(stats) {
        return [
            ["Top Content by Time", stats.topTime ? `${stats.topTime} (${duration(stats.topTimeValue)})` : ""],
            ["Top Content by Launch", stats.topLaunch ? `${stats.topLaunch} (${stats.topLaunchValue})` : ""],
            ["Most Frequent Core", stats.core ? coreName(stats.core) : t("Unknown")],
            ["Most Used Device", deviceName(stats.device)],
            ["Most Used Mode", modeName(stats.mode)],
            ["Total Launch Count", String(stats.launches)],
            ["Total Play Time", duration(stats.total)],
            ["Average Play Time", duration(stats.average)],
            ["Oldest Session", stats.oldest ? `${stats.oldest} (${stamp(stats.oldestTime)})` : ""],
            ["Longest Session", stats.longest ? `${stats.longest} (${duration(stats.longestValue)})` : ""],
            ["Overall Play Style", t(stats.style)],
            ["Unique Content Played", String(stats.titles)],
            ["Unique Cores Used", String(stats.cores)],
            ["Most Active Time", hourName(stats.activeHour)],
            ["Favourite Day", dayName(stats.favouriteDay)],
            ["Sessions Recorded", String(stats.sessions)],
            ["Unexpected Endings", String(stats.unexpected)],
            ["Battery Drain", stats.drain === null ? t("Unknown") : t("%s per hour", `${stats.drain}%`)],
            ["Average Temperature", stats.temperature === null ? t("Unknown") : `${stats.temperature} °C`]
        ];
    }

    function endingName(ended) {
        return own(ENDINGS, ended) ? t(ENDINGS[ended]) : t("Unknown");
    }

    function recentSessions(items, limit) {
        return items
            .flatMap((entry) => entry.sessions.map((session) => ({...session, name: entry.name})))
            .filter((session) => session.start > 0)
            .sort((a, b) => b.start - a.start)
            .slice(0, limit);
    }

    const SESSION_COLUMNS = [
        {label: "Content Name", show: (session) => session.name},
        {label: "Started", show: (session) => stamp(session.start)},
        {label: "Length", show: (session) => duration(session.length), number: true},
        {key: "sessionCore", label: "Core Used", show: (session) => coreName(session.core)},
        {label: "Battery Used", show: (session) => (session.battery === null ? "" : `${session.battery}%`), number: true},
        {label: "Temperature", show: (session) => (session.temperature === null ? "" : `${session.temperature} °C`), number: true},
        {label: "Suspends", show: (session) => String(session.suspends), number: true},
        {label: "Ending", show: (session) => endingName(session.ended)}
    ];

    const COLUMNS = [
        {key: "name", label: "Content Name", sort: (item) => item.name.toLowerCase(), show: (item) => item.name},
        {key: "core", label: "Core Used", sort: (item) => coreName(item.core).toLowerCase(), show: (item) => coreName(item.core)},
        {key: "device", label: "Last Device", sort: (item) => item.device, show: (item) => deviceName(item.device)},
        {key: "launches", label: "Launch Count", sort: (item) => item.launches, show: (item) => String(item.launches), number: true},
        {key: "first", label: "First Played", sort: (item) => item.first, show: (item) => stamp(item.first), number: true},
        {key: "started", label: "Last Played", sort: (item) => item.started, show: (item) => stamp(item.started), number: true},
        {key: "average", label: "Average Time", sort: (item) => item.average, show: (item) => duration(item.average), number: true},
        {key: "total", label: "Total Time", sort: (item) => item.total, show: (item) => duration(item.total), number: true},
        {key: "last", label: "Last Session", sort: (item) => item.last, show: (item) => duration(item.last), number: true},
        {key: "longest", label: "Longest Session", sort: (item) => item.longest, show: (item) => duration(item.longest), number: true},
        {key: "style", label: "Play Style", sort: (item) => localStyle(item.launches, item.total), show: (item) => t(localStyle(item.launches, item.total))}
    ];

    const collator = new Intl.Collator(undefined, {numeric: true, sensitivity: "base"});

    function sortItems(items, key, descending) {
        const column = COLUMNS.find((entry) => entry.key === key) || COLUMNS[0];
        const direction = descending ? -1 : 1;
        return [...items].sort((a, b) => {
            const left = column.sort(a);
            const right = column.sort(b);
            const order = typeof left === "number" ? left - right : collator.compare(left, right);
            return order * direction || collator.compare(a.name, b.name);
        });
    }

    window.MUOS_ACTIVITY = {
        parse,
        combine,
        groups: GROUPS,
        groupItems,
        columnsFor,
        sessionColumnsFor,
        recentSessions,
        summarise,
        summaryRows,
        sortItems,
        localStyle,
        coreName,
        deviceName,
        modeName,
        duration,
        stamp,
        columns: COLUMNS,
        sessionColumns: SESSION_COLUMNS
    };
}());
