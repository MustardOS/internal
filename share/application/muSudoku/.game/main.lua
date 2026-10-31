-- muSudoku: Sudoku for muOS (MustardOS)
-- Entry point: owns the scene stack, settings, statistics and saving.

local ui = require("src.ui")
local theme = require("src.theme")
local input = require("src.input")
local sound = require("src.sound")
local storage = require("src.storage")
local Game = require("src.game")
local packs = require("src.packs")
local sudoku = require("src.sudoku")

local VERSION = "1.2.3"

local SCENES = {
    title = require("src.scenes.title"),
    difficulty = require("src.scenes.difficulty"),
    generating = require("src.scenes.generating"),
    play = require("src.scenes.play"),
    pause = require("src.scenes.pause"),
    win = require("src.scenes.win"),
    settings = require("src.scenes.settings"),
    stats = require("src.scenes.stats"),
    confirm = require("src.scenes.confirm"),
    packs = require("src.scenes.packs"),
    pack = require("src.scenes.pack"),
    about = require("src.scenes.about"),
}

local app = {
    version = VERSION,
    stack = {},
    fade = 0,
    dirty = false,
    lastSave = 0,
    focused = true,
    packCache = {},     -- [path] = scanned index, kept for this session
    redrawRequested = true,
    activeUntil = 0,
    framesDrawn = 0,
}
_G.app = app

-- Scene stack ---------------------------------------------------------------

function app.top()
    return app.stack[#app.stack]
end

function app.find(name)
    for k = #app.stack, 1, -1 do
        if app.stack[k].name == name then return app.stack[k] end
    end
end

local function create(name, ...)
    local scene = SCENES[name].new(app, ...)
    scene.name = name
    return scene
end

-- Replace everything with a new full-screen scene.
function app.setScene(name, ...)
    for k = #app.stack, 1, -1 do
        local s = app.stack[k]
        if s.leave then s:leave() end
    end
    app.stack = { create(name, ...) }
    app.fade = 1
    input.reset()
    local s = app.top()
    if s.enter then s:enter() end
end

-- Open a scene on top of the current one (menus, dialogs).
function app.push(name, ...)
    local scene = create(name, ...)
    app.stack[#app.stack + 1] = scene
    input.reset()
    if scene.enter then scene:enter() end
    return scene
end

function app.pop()
    local s = table.remove(app.stack)
    if s and s.leave then s:leave() end
    input.reset()
    local top = app.top()
    if top and top.resume then top:resume() end
end

-- Saving ----------------------------------------------------------------------

function app.markDirty()
    app.dirty = true
end

function app.saveGame()
    app.dirty = false
    app.lastSave = love.timer.getTime()
    if app.game and not app.game.solved then
        storage.saveGame(app.game:serialize())
    else
        storage.clearGame()
    end
end

function app.saveSettings()
    storage.saveSettings(app.settings)
end

function app.saveStats()
    storage.saveStats(app.stats)
end

function app.savePackProgress()
    storage.savePackProgress(packs.saveableProgress(app.packProgress))
end

local GRADE_DIFFICULTY = { "easy", "medium", "hard", "hard", "expert" }

-- Start puzzle n of a pack. Returns true, or false and a reason to show.
function app.startPackPuzzle(file, index, n)
    local p = packs.entry(app.packProgress, file.file)
    local text = packs.fetch(index, n)
    if not text then return false, "Couldn't read puzzle " .. ui.number(n) .. "." end
    local grid = packs.toGrid(text)
    local count, solution = sudoku.solve(grid, 2)
    if count ~= 1 then
        p.invalid[n] = true
        app.savePackProgress()
        if count == 0 then
            return false, "Puzzle " .. ui.number(n) .. " has no solution, so it was skipped."
        end
        return false, "Puzzle " .. ui.number(n) .. " has more than one solution, so it was skipped."
    end
    local grade = sudoku.grade(grid)
    app.game = Game.new({ puzzle = grid, solution = solution }, GRADE_DIFFICULTY[grade] or "expert")
    app.game.pack = {
        file = file.file, name = file.name, path = file.path,
        index = n, count = index.count, size = file.size,
    }
    p.last = n
    app.savePackProgress()
    app.saveGame()
    app.setScene("play")
    return true
end

-- The pack file a saved pack game came from, if it's still there.
function app.packFileFor(game)
    if not (game and game.pack) then return nil end
    for _, file in ipairs(packs.list()) do
        if file.file == game.pack.file then return file end
    end
end

function app.applySettings()
    theme.use(app.settings.theme)
    sound.enabled = app.settings.sound
    if sound.enabled then sound.load() end -- loads the audio modules on first use
end

function app.hasGame()
    return app.game ~= nil and not app.game.solved
end

function app.newPuzzle(difficulty)
    app.lastDifficulty = difficulty
    app.setScene("generating", difficulty)
end

function app.startGame(generated, difficulty)
    app.game = Game.new(generated, difficulty)
    local entry = app.stats[difficulty]
    if entry then entry.started = entry.started + 1 end
    app.saveStats()
    app.saveGame()
    app.setScene("play")
end

-- Records a solve and returns true if it set a new best time.
function app.recordSolve()
    local g = app.game
    if g.pack then
        -- Pack puzzles track progress per pack and stay out of the
        -- per-difficulty statistics, which are for generated puzzles.
        local p = packs.entry(app.packProgress, g.pack.file)
        p.solved[g.pack.index] = true
        app.savePackProgress()
        storage.clearGame()
        return false
    end
    local entry = app.stats[g.difficulty]
    local best = false
    if entry then
        local t = math.floor(g.elapsed)
        entry.solved = entry.solved + 1
        entry.total = entry.total + t
        if g.hints == 0 and g.mistakes == 0 then entry.perfect = entry.perfect + 1 end
        if g.hints == 0 and (entry.best == 0 or t < entry.best) then
            entry.best = t
            best = true
        end
    end
    app.saveStats()
    storage.clearGame()
    return best
end

function app.quit()
    if app.game then app.saveGame() end
    love.event.quit()
end

-- Idle rendering -------------------------------------------------------------
-- A puzzle game spends most of its time showing a still picture, so the
-- screen is only redrawn when something changed: briefly after input, while
-- the top scene reports busy() (every animation does), or when a scene asks
-- via app.requestRedraw() (the timer does, once a second). Otherwise the
-- loop sleeps and checks for input 60 times a second, or 30 once nothing
-- has been pressed for a few seconds.

local AFTER_INPUT = 0.1    -- keep drawing this long after any input
local IDLE_SLEEP = 1 / 60  -- how often to check for input while idle
local QUIET_SLEEP = 1 / 30 -- ...and once nothing was pressed for QUIET_AFTER
local QUIET_AFTER = 2

function app.requestRedraw()
    app.redrawRequested = true
end

function app.wake()
    app.redrawRequested = true
    app.activeUntil = love.timer.getTime() + AFTER_INPUT
end

function app.needsFrame()
    if app.redrawRequested or app.fade > 0 then return true end
    if love.timer.getTime() < app.activeUntil then return true end
    local top = app.top()
    return top ~= nil and top.busy ~= nil and top:busy()
end

-- Events that shouldn't wake the screen by themselves. Stick movement only
-- matters once it crosses the threshold, and then input.lua fires an action.
local QUIET_EVENTS = { gamepadaxis = true, joystickaxis = true }

function love.run()
    love.load(love.arg.parseGameArguments(arg), arg)
    love.timer.step()
    local dt = 0
    return function()
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                if not love.quit() then return a or 0 end
            end
            love.handlers[name](a, b, c, d, e, f)
            if not QUIET_EVENTS[name] then app.wake() end
        end

        dt = love.timer.step()
        love.update(dt)

        if love.graphics.isActive() and app.needsFrame() then
            app.redrawRequested = false
            love.graphics.origin()
            love.draw()
            love.graphics.present()
            app.framesDrawn = app.framesDrawn + 1
            love.timer.sleep(0.001)
        else
            local quiet = love.timer.getTime() > app.activeUntil + QUIET_AFTER
            love.timer.sleep(quiet and QUIET_SLEEP or IDLE_SLEEP)
        end
    end
end

-- LÖVE callbacks --------------------------------------------------------------

local function parseResolution(args)
    for _, a in ipairs(args or {}) do
        local w, h = tostring(a):match("^(%d+)x(%d+)$")
        if w then return tonumber(w), tonumber(h) end
    end
end

function love.load(args)
    love.graphics.setDefaultFilter("linear", "linear")

    local w, h = parseResolution(args)
    if w and h and (w ~= love.graphics.getWidth() or h ~= love.graphics.getHeight()) then
        love.window.setMode(w, h, { vsync = 1 })
    end
    ui.resize(love.graphics.getWidth(), love.graphics.getHeight())

    app.settings = storage.loadSettings()
    app.stats = storage.loadStats()
    app.packProgress = packs.loadProgress(storage.loadPackProgress())
    app.applySettings()

    local saved = storage.loadGame()
    if saved then
        app.game = Game.deserialize(saved)
        if not app.game then storage.clearGame() end
    end

    input.handler = function(action)
        app.wake()
        local s = app.top()
        if s and s.action then s:action(action) end
    end

    app.setScene("title")
    app.fade = 0

    if os.getenv("MUSUDOKU_AUTOSHOT") then
        require("dev.autoshot").start(app)
    elseif os.getenv("MUSUDOKU_IDLETEST") then
        require("dev.idletest").start(app)
    elseif os.getenv("MUSUDOKU_FXSHOTS") then
        require("dev.fxshots").start(app)
    elseif os.getenv("MUSUDOKU_HINTSHOTS") then
        require("dev.hintshots").start(app)
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 15)
    input.update(dt)
    local s = app.top()
    if s and s.update then s:update(dt) end
    if app.fade > 0 then app.fade = math.max(0, app.fade - dt * 6) end

    if app.dirty and love.timer.getTime() - app.lastSave > 1.5 then
        app.saveGame()
    end
end

function love.draw()
    local bg = theme.get("bg")
    love.graphics.clear(bg[1], bg[2], bg[3], 1)

    -- Draw from the topmost full-screen scene upward, so overlays show
    -- the scene beneath them.
    local first = 1
    for k = #app.stack, 1, -1 do
        if not app.stack[k].overlay then
            first = k
            break
        end
    end

    ui.begin()
    theme.texture(0, 0, ui.W, ui.H)
    for k = first, #app.stack do
        local s = app.stack[k]
        love.graphics.setColor(1, 1, 1, 1)
        s:draw()
    end
    if app.fade > 0 then
        theme.set("bg", app.fade)
        love.graphics.rectangle("fill", 0, 0, ui.W, ui.H)
    end
    ui.finish()
end

function love.keypressed(key, scancode, isrepeat)
    input.keypressed(key, isrepeat)
end

function love.keyreleased(key)
    input.keyreleased(key)
end

function love.gamepadpressed(js, button)
    input.gamepadpressed(js, button)
end

function love.gamepadreleased(js, button)
    input.gamepadreleased(js, button)
end

function love.gamepadaxis(js, axis, value)
    input.gamepadaxis(js, axis, value)
end

function love.resize(w, h)
    ui.resize(w, h)
end

function love.focus(f)
    app.focused = f
    if not f and app.game then app.saveGame() end
end

function love.quit()
    if app.game then app.saveGame() end
    return false
end
