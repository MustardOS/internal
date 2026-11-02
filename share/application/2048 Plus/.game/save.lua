-- Save file persistence

local save = {}

local real_io = io

local function smart_io_open(path, mode)
    local f = real_io.open(path, mode)
    if f then return f end

    -- Fallback for sandboxed mobile platforms like Android using love.filesystem
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
        elseif mode == "w" or mode == "wb" then
            local buffer = {}
            local closed = false
            return {
                write = function(self, data)
                    if not closed then table.insert(buffer, tostring(data)) end
                end,
                close = function(self)
                    if not closed then
                        closed = true
                        pcall(love.filesystem.write, basename, table.concat(buffer))
                    end
                end
            }
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
    if not dir or dir == "" or (love.system and love.system.getOS() == "Android") or _G.android_console then
        pcall(function()
            if love.filesystem then
                love.filesystem.setIdentity("2048plus")
                love.filesystem.createDirectory("")
            end
        end)
        SAVE_DIR = (love.filesystem and love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()) or dir or ""
    else
        SAVE_DIR = dir
    end
    -- Ensure save directory exists
    if SAVE_DIR ~= "" and SAVE_DIR ~= "/" and love.system.getOS() ~= "Web" then
        pcall(function() os.execute('mkdir -p "' .. SAVE_DIR .. '"') end)
        if love.filesystem and love.filesystem.createDirectory then
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
    local file = io.open(path, "w")
    if file then
        file:write(unlocked and "1" or "0")
        file:close()
    end
end

function save.loadCheats()
    local path = getFilePath(CHEATS_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content == "1"
    end
    return false
end

local CHEAT_OPTIONS_FILE = "cheat_options.dat"

function save.saveCheatOptions(opts)
    local path = getFilePath(CHEAT_OPTIONS_FILE)
    local file = io.open(path, "w")
    if file then
        local function serialize(o)
            if type(o) == "number" then return tostring(o)
            elseif type(o) == "string" then return string.format("%q", o)
            elseif type(o) == "boolean" then return tostring(o)
            elseif type(o) == "table" then
                local s = "{"
                for k, v in pairs(o) do
                    local key = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
                    s = s .. key .. "=" .. serialize(v) .. ","
                end
                return s .. "}"
            end
            return "nil"
        end
        file:write("return " .. serialize(opts or {}))
        file:close()
    end
end

function save.loadCheatOptions()
    local path = getFilePath(CHEAT_OPTIONS_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local chunk = (loadstring or load)(content)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                return result
            end
        end
    end
    return {}
end

function save.loadHighScore(mode)
    local path = save.getPath(mode)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local score = tonumber(content)
        if score then
            return score
        end
    end
    return 0
end

function save.saveHighScore(score, mode)
    local path = save.getPath(mode)
    local file = io.open(path, "w")
    if file then
        file:write(tostring(math.floor(score)))
        file:close()
    end
end

function save.loadAchievements()
    local path = save.getAchievementsPath()
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        -- Use basic load implementation to parse serialized table
        local chunk = (loadstring or load)(content)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                return result
            end
        end
    end
    return nil
end

function save.saveAchievements(achievements)
    local path = save.getAchievementsPath()
    local file = io.open(path, "w")
    if file then
        local function serialize(o)
            if type(o) == "number" then
                return tostring(o)
            elseif type(o) == "string" then
                return string.format("%q", o)
            elseif type(o) == "boolean" then
                return tostring(o)
            elseif type(o) == "table" then
                local s = "{"
                for k, v in pairs(o) do
                    local key = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
                    s = s .. key .. "=" .. serialize(v) .. ","
                end
                return s .. "}"
            end
            return "nil"
        end
        file:write("return " .. serialize(achievements))
        file:close()
    end
end

function save.saveState(state, mode)
    local path = save.getStatePath(mode)
    local file = io.open(path, "w")
    if file then
        local function serialize(o)
            if type(o) == "number" then
                return tostring(o)
            elseif type(o) == "string" then
                return string.format("%q", o)
            elseif type(o) == "boolean" then
                return tostring(o)
            elseif type(o) == "table" then
                local s = "{"
                for k, v in pairs(o) do
                    -- Skip mixed tables or complex keys for simplicity, assume string or number keys
                    local key = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
                    s = s .. key .. "=" .. serialize(v) .. ","
                end
                return s .. "}"
            end
            return "nil"
        end

        file:write("return " .. serialize(state))
        file:close()
    end
end

function save.loadState(mode)
    local path = save.getStatePath(mode)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        -- Parse saved state
        -- But for a local game save, this works as long as the file isn't tampered with maliciously.
        local chunk = (loadstring or load)(content)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                return result
            end
        end
    end
    return nil
end

function save.clearState(mode)
    local path = save.getStatePath(mode)
    os.remove(path)
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
    local path = getFilePath(STATS_FILE)
    local file = io.open(path, "w")
    if file then
        local function serialize(o)
            if type(o) == "number" then
                return tostring(o)
            elseif type(o) == "string" then
                return string.format("%q", o)
            elseif type(o) == "boolean" then
                return tostring(o)
            elseif type(o) == "table" then
                local s = "{"
                for k, v in pairs(o) do
                    local key = type(k) == "string" and string.format("[%q]", k) or "[" .. tostring(k) .. "]"
                    s = s .. key .. "=" .. serialize(v) .. ","
                end
                return s .. "}"
            end
            return "nil"
        end
        file:write("return " .. serialize(stats))
        file:close()
    end
end

function save.loadStats()
    local path = getFilePath(STATS_FILE)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local chunk = (loadstring or load)(content)
        if chunk then
            local success, result = pcall(chunk)
            if success and type(result) == "table" then
                return result
            end
        end
    end
    return nil
end

local LAST_MODE_FILE = "last_mode.dat"

function save.saveLastMode(mode)
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
    local mode = save.loadLastMode()
    if not mode then return false end
    local state = save.loadState(mode)
    if not state or not state.gridState then return false end
    local s = state.state or 0
    return s ~= 1 and s ~= 2
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
