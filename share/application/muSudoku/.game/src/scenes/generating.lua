local ui = require("src.ui")
local theme = require("src.theme")
local sudoku = require("src.sudoku")

local Generating = {}
Generating.__index = Generating

local NAMES = { easy = "an easy", medium = "a medium", hard = "a hard", expert = "an expert" }
local FRAME_BUDGET = 0.010 -- seconds of generator work per frame
local MIN_SHOWN = 0.45     -- keep the screen up briefly so it doesn't flicker

function Generating.new(app, difficulty)
    local self = setmetatable({ app = app, difficulty = difficulty, t = 0 }, Generating)
    local rng = love.math.newRandomGenerator(os.time(), math.floor(love.timer.getTime() * 1e6) % 2147483647)
    local function random(n) return rng:random(n) end

    local frameStart = 0
    self.co = coroutine.create(function()
        return sudoku.generate(difficulty, random, function()
            if love.timer.getTime() - frameStart > FRAME_BUDGET then
                coroutine.yield()
            end
        end, app.settings.generator)
    end)
    self.beginFrame = function() frameStart = love.timer.getTime() end
    return self
end

function Generating:update(dt)
    self.t = self.t + dt
    if not self.result and self.co then
        self.beginFrame()
        local ok, result = coroutine.resume(self.co)
        if not ok then
            error(result)
        elseif coroutine.status(self.co) == "dead" then
            self.result = result
            self.co = nil
        end
    end
    if self.result and self.t >= MIN_SHOWN then
        self.app.startGame(self.result, self.difficulty)
    end
end

function Generating:busy()
    return true
end

function Generating:action(a)
    if a == "b" then
        self.app.setScene("title")
    end
end

function Generating:draw()
    -- A 3x3 block whose cells light up in turn while the puzzle is built.
    local size, gap = 22, 6
    local total = size * 3 + gap * 2
    local x0, y0 = (ui.W - total) / 2, 168
    local step = math.floor(self.t * 9) % 9
    for k = 0, 8 do
        local x = x0 + (k % 3) * (size + gap)
        local y = y0 + math.floor(k / 3) * (size + gap)
        local age = (step - k) % 9
        local glow = math.max(0, 1 - age / 4)
        theme.mix("panel", "accent", glow)
        ui.rect("fill", x, y, size, size, 4)
    end

    theme.set("text")
    ui.text("Building " .. NAMES[self.difficulty] .. " puzzle", 0, 262, 26, "bold", "center", ui.W)
    theme.set("muted")
    local method = self.app.settings.generator == "dlx" and "Dancing Links" or "Classic"
    ui.text(method .. " generator. Every puzzle has exactly one solution.", 0, 302, 16, "regular", "center", ui.W)

    ui.hints({ { "B", "Cancel" } }, 696, 452, "right")
end

return Generating
