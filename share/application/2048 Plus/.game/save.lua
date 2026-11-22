-- Save file persistence

local save = {}

local real_io = io

local function smart_io_open(path, mode)
    -- Atomic write handler writing to temp file before rename
    if mode == "w" or mode == "wb" then
        local tmp_path = path .. ".tmp"
        local f = real_io.open(tmp_path, mode)
        if f then
            local closed = false
            return {
                write = function(self, ...)
                    if not closed then return f:write(...) end
                end,
                flush = function(self)
                    if not closed then return f:flush() end
                end,
                close = function(self)
                    if not closed then
                        closed = true
                        f:flush()
                        f:close()
                        local ok = os.rename(tmp_path, path)
                        if not ok then
                            os.remove(path)
                            ok = os.rename(tmp_path, path)
                        end
                        if not ok then
                            pcall(os.remove, tmp_path)
                        end
                        return ok
                    end
                end
            }
        end

        -- Fallback for sandboxed mobile platforms using love filesystem
        if love and love.filesystem then
            local basename = path:match("[^/\\]+$") or path
            local buffer = {}
            local closed = false
            return {
                write = function(self, data)
                    if not closed then table.insert(buffer, tostring(data)) end
                end,
                flush = function(self)
                end,
                close = function(self)
                    if not closed then
                        closed = true
                        local payload = table.concat(buffer)
                        local tmp_basename = basename .. ".tmp"
                        local ok = pcall(love.filesystem.write, tmp_basename, payload)
                        if ok then
                            local rename_ok = false
                            if love.filesystem.rename then
                                local res, r_ok = pcall(love.filesystem.rename, tmp_basename, basename)
                                rename_ok = res and r_ok
                            end
                            if not rename_ok then
                                pcall(love.filesystem.remove, basename)
                                pcall(love.filesystem.write, basename, payload)
                                pcall(love.filesystem.remove, tmp_basename)
                            end
                        else
                            pcall(love.filesystem.write, basename, payload)
                        end
                    end
                end
            }
        end
        return nil
    end

    local f = real_io.open(path, mode)
    if f then return f end

    -- Fallback for sandboxed mobile platforms using love filesystem
    if love and love.filesystem then
        local basename = path:match("[^/\\]+$") or path
        if mode == "r" or mode == "rb" then
            local ok, content = pcall(love.filesystem.read, basename)
            if ok and content then
                local closed = false
                return {
                    read = function(self, fmt)
                        if closed then return nil end
                        return content
                    end,
                    close = function(self)
                        closed = true
                    end
                }
            end
        end
    end
    return nil
end

local io = {
    open = smart_io_open,
    read = real_io.read,
    write = real_io.write,
    close = real_io.close,
}

local SAVE_DIR = ""
local SAVE_FILE = "highscore.dat"
local STATE_FILE = "gamestate.dat"
local ACHIEVEMENTS_FILE = "achievements.dat"
local THEME_FILE = "theme.dat"
local high_score_cache = {}

local function getFilePath(filename)
    if SAVE_DIR == "" or SAVE_DIR == nil then
        return filename
    elseif SAVE_DIR == "/" then
        return "/" .. filename
    else
        local clean_dir = SAVE_DIR:gsub("/+$", "")
        return clean_dir .. "/" .. filename
    end
end

function save.init(dir)
    high_score_cache = {}
    local is_android = love and love.system and love.system.getOS and love.system.getOS() == "Android"
    if not dir or dir == "" or is_android or _G.android_console then
        pcall(function()
            if love and love.filesystem then
                love.filesystem.setIdentity("2048plus")
                love.filesystem.createDirectory("")
            end
        end)
        SAVE_DIR = (love and love.filesystem and love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()) or dir or ""
    else
        SAVE_DIR = dir
    end
    -- Ensure save directory exists
    local is_web = love and love.system and love.system.getOS and love.system.getOS() == "Web"
    if SAVE_DIR ~= "" and SAVE_DIR ~= "/" and not is_web then
        pcall(function() os.execute('mkdir -p "' .. SAVE_DIR .. '"') end)
        if love and love.filesystem and love.filesystem.createDirectory then
            pcall(function() love.filesystem.createDirectory("") end)
        end
    end
end

function save.getPath(mode)
    local file
    if mode == "plus" then
        file = "highscore_plus.dat"
    elseif mode == "timeattack" then
        file = "highscore_timeattack.dat"
    elseif mode == "huge" then
        file = "highscore_huge.dat"
    elseif mode == "nomercy" then
        file = "highscore_nomercy.dat"
    elseif mode == "goose" then
        file = "highscore_goose.dat"
    elseif mode == "dino" then
        file = "dino_hiscore.dat"
    else
        file = SAVE_FILE  -- classic
    end
    return getFilePath(file)
end

function save.getStatePath(mode)
    local file
    if mode == "plus" then
        file = "gamestate_plus.dat"
    elseif mode == "timeattack" then
        file = "gamestate_timeattack.dat"
    elseif mode == "huge" then
        file = "gamestate_huge.dat"
    elseif mode == "nomercy" then
        file = "gamestate_nomercy.dat"
    elseif mode == "goose" then
        file = "gamestate_goose.dat"
    else
        file = STATE_FILE  -- classic
    end
    return getFilePath(file)
end

function save.getAchievementsPath()
    return getFilePath(ACHIEVEMENTS_FILE)
end

-- Table serialization
local function serializeToParts(o, parts)
    local t = type(o)
    if t == "number" then
        parts[#parts + 1] = tostring(o)
    elseif t == "string" then
        parts[#parts + 1] = string.format("%q", o)
    elseif t == "boolean" then
        parts[#parts + 1] = tostring(o)
    elseif t == "table" then
        parts[#parts + 1] = "{"
        for k, v in pairs(o) do
            if type(k) == "string" then
                parts[#parts + 1] = "["
                parts[#parts + 1] = string.format("%q", k)
                parts[#parts + 1] = "]="
            else
                parts[#parts + 1] = "["
                parts[#parts + 1] = tostring(k)
                parts[#parts + 1] = "]="
            end
            serializeToParts(v, parts)
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = "}"
    else
        parts[#parts + 1] = "nil"
    end
end

local function serializeTable(o)
    local parts = {"return "}
    serializeToParts(o, parts)
    return table.concat(parts)
end

-- Save protection and integrity
local SAVE_SECRET = "2048plus_k9$w8#m2!v7x4_sec"

local bit_mod = nil
pcall(function() bit_mod = require("bit") end)

local function bit_bxor(a, b)
    if bit_mod and bit_mod.bxor then
        return bit_mod.bxor(a, b)
    end
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local ra, rb = a % 2, b % 2
        if ra ~= rb then c = c + p end
        a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
    end
    if a > 0 then c = c + a * p end
    if b > 0 then c = c + b * p end
    return c
end

local function computeHash(data, salt)
    local s = salt .. data
    local len = #s
    local h1 = 0x811c9dc5
    local h2 = 0x537f3a8b
    if bit_mod and bit_mod.bxor and bit_mod.tobit and bit_mod.tohex then
        for i = 1, len do
            local b = s:byte(i)
            h1 = bit_mod.bxor(h1, b)
            h1 = bit_mod.tobit(h1 * 0x01000193)
            h2 = bit_mod.bxor(h2, b * 31)
            h2 = bit_mod.tobit(h2 * 33 + b)
        end
        return bit_mod.tohex(h1) .. bit_mod.tohex(h2)
    else
        for i = 1, len do
            local b = s:byte(i)
            h1 = (h1 * 33 + b) % 4294967296
            h2 = (b + (h2 * 65599)) % 4294967296
        end
        return string.format("%08x%08x", h1, h2)
    end
end

local function cipher(data, key)
    local key_len = #key
    local out = {}
    for i = 1, #data do
        local b = data:byte(i)
        local kb = key:byte(((i - 1) % key_len) + 1)
        local shift = (i * 7) % 256
        local enc = bit_bxor(b, bit_bxor(kb, shift))
        out[i] = string.char(enc)
    end
    return table.concat(out)
end

local function toHex(str)
    return (str:gsub(".", function(c)
        return string.format("%02x", string.byte(c))
    end))
end

local function fromHex(hex)
    if #hex % 2 ~= 0 then return nil end
    local ok, res = pcall(function()
        return (hex:gsub("..", function(cc)
            local n = tonumber(cc, 16)
            if not n then error("invalid hex") end
            return string.char(n)
        end))
    end)
    return ok and res or nil
end

local function packProtected(plain)
    local hash = computeHash(plain, SAVE_SECRET)
    local enc = cipher(plain, SAVE_SECRET)
    return "SEC1:" .. hash .. ":" .. toHex(enc)
end

local function unpackProtected(content)
    if not content or content == "" then return nil, false end
    if content:sub(1, 5) == "SEC1:" then
        local hash_stored, hex_payload = content:match("^SEC1:([0-9a-fA-F]+):([0-9a-fA-F]+)$")
        if not hash_stored or not hex_payload then
            return nil, false
        end
        local enc = fromHex(hex_payload)
        if not enc then return nil, false end
        local plain = cipher(enc, SAVE_SECRET)
        local expected = computeHash(plain, SAVE_SECRET)
        if hash_stored ~= expected then
            return nil, false
        end
        return plain, false
    else
        return content, true
    end
end

local function writeProtectedFile(path, plain_text)
    local file = io.open(path, "w")
    if file then
        local packed = packProtected(plain_text)
        file:write(packed)
        file:close()
        return true
    end
    return false
end

local function readProtectedFile(path)
    local file = io.open(path, "r")
    local content = nil
    if file then
        content = file:read("*all")
        file:close()
    end
    if not content or content == "" then
        -- Check if interrupted temp file exists
        local tmp_file = io.open(path .. ".tmp", "r")
        if tmp_file then
            local tmp_content = tmp_file:read("*all")
            tmp_file:close()
            if tmp_content and tmp_content ~= "" then
                local res, is_leg = unpackProtected(tmp_content:match("^%s*(.-)%s*$"))
                if res then
                    pcall(os.rename, path .. ".tmp", path)
                    return res, is_leg
                end
            end
        end
        return nil, false
    end
    content = content:match("^%s*(.-)%s*$")
    return unpackProtected(content)
end

save.writeProtected = writeProtectedFile
save.readProtected = readProtectedFile
save.packProtected = packProtected
save.unpackProtected = unpackProtected

function save.saveTheme(themeName)
    local path = getFilePath(THEME_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(themeName)
        file:close()
    end
end

function save.loadTheme()
    local path = getFilePath(THEME_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return nil
end

local CUSTOM_THEMES_FILE = "custom_themes.dat"

-- Custom themes persistence
function save.saveCustomThemes(themes_data)
    if not themes_data or type(themes_data) ~= "table" then return end
    local path = getFilePath(CUSTOM_THEMES_FILE)
    writeProtectedFile(path, serializeTable(themes_data))
end

function save.loadCustomThemes()
    local path = getFilePath(CUSTOM_THEMES_FILE)
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local chunk = (loadstring or load)(plain)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                if is_legacy then
                    save.saveCustomThemes(result)
                end
                return result
            end
        end
    end
    return nil
end

local TEXT_SIZE_FILE = "text_size.dat"

function save.saveTextSize(size)
    local path = getFilePath(TEXT_SIZE_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(size)
        file:close()
    end
end

local MERGE_FX_FILE = "merge_fx.dat"

function save.saveMergeFX(fx)
end

function save.loadMergeFX()
    return "default"
end

local BOARD_SKIN_FILE = "board_skin.dat"

function save.saveBoardSkin(skin)
    local path = getFilePath(BOARD_SKIN_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(skin or "default")
        file:close()
    end
end

function save.loadBoardSkin()
    local path = getFilePath(BOARD_SKIN_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return "default"
end

local COMPANION_FILE = "companion.dat"

function save.saveCompanion(companion)
    local path = getFilePath(COMPANION_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(companion or "none")
        file:close()
    end
end

function save.loadCompanion()
    local path = getFilePath(COMPANION_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return "none"
end

local DOG_BREED_FILE = "dog_breed.dat"

function save.saveDogBreed(breed)
    local path = getFilePath(DOG_BREED_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(breed or "roxy")
        file:close()
    end
end

function save.loadDogBreed()
    local path = getFilePath(DOG_BREED_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return "roxy"
end

function save.loadTextSize()
    local path = getFilePath(TEXT_SIZE_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return "normal"
end

local SOUND_FILE = "sound.dat"

function save.saveSound(enabled)
    local path = getFilePath(SOUND_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(enabled and "1" or "0")
        file:close()
    end
end

function save.loadSound()
    local path = getFilePath(SOUND_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content == "1"
    end
    return true -- default to enabled
end

local MUSIC_FILE = "music.dat"

function save.saveMusic(enabled)
    local path = getFilePath(MUSIC_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(enabled and "1" or "0")
        file:close()
    end
end

function save.loadMusic()
    local path = getFilePath(MUSIC_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content == "1"
    end
    return true -- default to enabled
end



local CHEATS_FILE = "cheats.dat"

function save.saveCheats(unlocked)
    local path = getFilePath(CHEATS_FILE)
    writeProtectedFile(path, unlocked and "1" or "0")
end

function save.loadCheats()
    local path = getFilePath(CHEATS_FILE)
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local unlocked = (plain == "1")
        if is_legacy then
            save.saveCheats(unlocked)
        end
        return unlocked
    end
    return false
end

local CHEAT_OPTIONS_FILE = "cheat_options.dat"

function save.saveCheatOptions(opts)
    local path = getFilePath(CHEAT_OPTIONS_FILE)
    writeProtectedFile(path, serializeTable(opts or {}))
end

function save.loadCheatOptions()
    local path = getFilePath(CHEAT_OPTIONS_FILE)
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local chunk = (loadstring or load)(plain)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                if is_legacy then
                    save.saveCheatOptions(result)
                end
                return result
            end
        end
    end
    return {}
end

function save.loadHighScore(mode)
    local m = mode or "classic"
    if high_score_cache[m] ~= nil then
        return high_score_cache[m]
    end

    local path = save.getPath(m)
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local score = math.floor(tonumber(plain) or 0)
        if score > 0 then
            if is_legacy then
                writeProtectedFile(path, tostring(score))
            end
            high_score_cache[m] = score
            return score
        end
    end
    high_score_cache[m] = 0
    return 0
end

function save.saveHighScore(score, mode)
    local new_score = math.floor(tonumber(score) or 0)
    if new_score <= 0 then
        return
    end

    local m = mode or "classic"
    local current_score = high_score_cache[m]
    if current_score == nil then
        current_score = save.loadHighScore(m) or 0
    end

    if new_score <= current_score then
        return
    end

    high_score_cache[m] = new_score
    local path = save.getPath(m)
    writeProtectedFile(path, tostring(new_score))
end

function save.loadDinoHighScore()
    return save.loadHighScore("dino")
end

function save.saveDinoHighScore(score)
    save.saveHighScore(score, "dino")
end

function save.loadAchievements()
    local path = save.getAchievementsPath()
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local chunk = (loadstring or load)(plain)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                if is_legacy then
                    save.saveAchievements(result)
                end
                return result
            end
        end
    end
    return nil
end

function save.saveAchievements(achievements)
    if not achievements or type(achievements) ~= "table" then return end
    local path = save.getAchievementsPath()
    writeProtectedFile(path, serializeTable(achievements))
end

local cached_has_last_active_game = nil

function save.saveState(state, mode)
    cached_has_last_active_game = nil
    if not state or type(state) ~= "table" then return end
    local path = save.getStatePath(mode)
    writeProtectedFile(path, serializeTable(state))
end

function save.loadState(mode)
    local path = save.getStatePath(mode)
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local chunk = (loadstring or load)(plain)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                if is_legacy then
                    save.saveState(result, mode)
                end
                return result
            end
        end
    end
    return nil
end

function save.clearState(mode)
    cached_has_last_active_game = nil
    local path = save.getStatePath(mode)
    os.remove(path)
    os.remove(path .. ".tmp")
    if love and love.filesystem and love.filesystem.remove then
        local basename = path:match("[^/\\]+$") or path
        pcall(love.filesystem.remove, basename)
        pcall(love.filesystem.remove, basename .. ".tmp")
    end
end

local ANIM_SPEED_FILE = "anim_speed.dat"
function save.saveAnimationSpeed(speed)
    local path = getFilePath(ANIM_SPEED_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(speed)
        file:close()
    end
end

function save.loadAnimationSpeed()
    local path = getFilePath(ANIM_SPEED_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return "normal"
end

local TRANSITIONS_FILE = "transitions.dat"
function save.saveScreenTransitions(enabled)
    local path = getFilePath(TRANSITIONS_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(enabled and "1" or "0")
        file:close()
    end
end

function save.loadScreenTransitions()
    local path = getFilePath(TRANSITIONS_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content ~= "0"
    end
    return true
end

local UNDO_MODE_FILE = "undo_mode.dat"
function save.saveUndoMode(mode)
    local path = getFilePath(UNDO_MODE_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(mode)
        file:close()
    end
end

function save.loadUndoMode()
    local path = getFilePath(UNDO_MODE_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return "classic"
end

local TIME_ATTACK_TIME_FILE = "time_attack_time.dat"
function save.saveTimeAttackTime(time)
    local path = getFilePath(TIME_ATTACK_TIME_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(tostring(time))
        file:close()
    end
end

function save.loadTimeAttackTime()
    local path = getFilePath(TIME_ATTACK_TIME_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local time = tonumber(content)
        if time then
            return time
        end
    end
    return 60
end

local VIBRATION_FILE = "vibration.dat"
function save.saveVibration(enabled)
    local path = getFilePath(VIBRATION_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(enabled and "1" or "0")
        file:close()
    end
end

function save.loadVibration()
    local path = getFilePath(VIBRATION_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content ~= "0"
    end
    return true
end

local BUTTON_VIBRATION_FILE = "button_vibration.dat"
local CONSOLE_HAPTICS_FILE = "console_haptics.dat"
function save.saveButtonVibration(enabled)
    local path = getFilePath(BUTTON_VIBRATION_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(enabled and "1" or "0")
        file:close()
    end
end
save.saveConsoleHaptics = save.saveButtonVibration

function save.loadButtonVibration()
    local path = getFilePath(BUTTON_VIBRATION_FILE)
    local file = io.open(path, "r")
    if not file then
        path = getFilePath(CONSOLE_HAPTICS_FILE)
        file = io.open(path, "r")
    end
    if file then
        local content = file:read("*all")
        file:close()
        return content ~= "0"
    end
    return true
end
save.loadConsoleHaptics = save.loadButtonVibration

local CRT_FILE = "crt_filter.dat"
function save.saveCrtFilter(enabled)
    local path = getFilePath(CRT_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(enabled and "1" or "0")
        file:close()
    end
end

function save.loadCrtFilter()
    local path = getFilePath(CRT_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content == "1"
    end
    return false -- default to off
end


local STATS_FILE = "stats.dat"

function save.saveStats(stats)
    if not stats or type(stats) ~= "table" then return end
    local path = getFilePath(STATS_FILE)
    writeProtectedFile(path, serializeTable(stats))
end

function save.loadStats()
    local path = getFilePath(STATS_FILE)
    local plain, is_legacy = readProtectedFile(path)
    if plain then
        local chunk = (loadstring or load)(plain)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                if is_legacy then
                    save.saveStats(result)
                end
                return result
            end
        end
    end
    return nil
end

local LAST_MODE_FILE = "last_mode.dat"

function save.saveLastMode(mode)
    cached_has_last_active_game = nil
    local path = getFilePath(LAST_MODE_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(mode)
        file:close()
    end
end

function save.loadLastMode()
    local path = getFilePath(LAST_MODE_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return nil
end

function save.hasLastActiveGame()
    if cached_has_last_active_game ~= nil then
        return cached_has_last_active_game
    end
    local mode = save.loadLastMode()
    if not mode then
        cached_has_last_active_game = false
        return false
    end
    local state = save.loadState(mode)
    if not state or not state.gridState then
        cached_has_last_active_game = false
        return false
    end
    local s = state.state or 0
    local has_game = (s ~= 1 and s ~= 2)
    cached_has_last_active_game = has_game
    return has_game
end

local ANDROID_VIEW_MODE_FILE = "android_view_mode.dat"

function save.saveAndroidViewMode(mode)
    local path = getFilePath(ANDROID_VIEW_MODE_FILE)
    local file = io.open(path, "w")
    if file then
        file:write(mode)
        file:close()
    end
end

function save.loadAndroidViewMode()
    local path = getFilePath(ANDROID_VIEW_MODE_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            return content
        end
    end
    return nil
end

local FULLSCREEN_TUTORIAL_FILE = "fullscreen_tutorial_seen.dat"

function save.saveFullscreenTutorialSeen()
    local path = getFilePath(FULLSCREEN_TUTORIAL_FILE)
    local file = io.open(path, "w")
    if file then
        file:write("1")
        file:close()
    end
end

function save.loadFullscreenTutorialSeen()
    local path = getFilePath(FULLSCREEN_TUTORIAL_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content == "1"
    end
    return false
end

return save
