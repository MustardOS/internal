local ui = require("src.ui")
local theme = require("src.theme")
local sound = require("src.sound")
local storage = require("src.storage")

local Stats = {}
Stats.__index = Stats

local LEVELS = {
    { key = "easy", name = "Easy" },
    { key = "medium", name = "Medium" },
    { key = "hard", name = "Hard" },
    { key = "expert", name = "Expert" },
}

local COLUMNS = {
    { label = "Started", x = 300 },
    { label = "Solved", x = 400 },
    { label = "Best", x = 510 },
    { label = "Average", x = 640 },
}

function Stats.new(app)
    return setmetatable({ app = app, t = 0 }, Stats)
end

function Stats:update(dt)
    self.t = self.t + dt
end

function Stats:action(a)
    local app = self.app
    if a == "b" or a == "start" then
        sound.play("close")
        app.pop()
    elseif a == "y" then
        sound.play("open")
        app.push("confirm", {
            title = "Reset statistics?",
            body = "Solve counts and best times for every difficulty will be cleared.",
            yes = "Reset",
            onYes = function()
                app.stats = storage.emptyStats()
                app.saveStats()
            end,
        })
    end
end

function Stats:draw()
    theme.set("text")
    ui.text("Statistics", 64, 40, 36, "bold")

    local stats = self.app.stats
    local y = 126
    theme.set("muted")
    for _, col in ipairs(COLUMNS) do
        ui.centered(col.label, col.x, y, 15, "regular", "right")
    end
    theme.set("line")
    love.graphics.setLineWidth(1)
    love.graphics.line(64, y + 18, 656, y + 18)

    local totals = { started = 0, solved = 0 }
    for k, level in ipairs(LEVELS) do
        local e = stats[level.key]
        local cy = y + 18 + k * 50 - 14
        totals.started = totals.started + e.started
        totals.solved = totals.solved + e.solved

        theme.set("text")
        ui.centered(level.name, 64, cy, 22, "bold", "left")
        local values = {
            tostring(e.started),
            tostring(e.solved),
            e.best > 0 and ui.formatTime(e.best) or "None",
            e.solved > 0 and ui.formatTime(e.total / e.solved) or "None",
        }
        for c, col in ipairs(COLUMNS) do
            local empty = values[c] == "None" or values[c] == "0"
            theme.set(empty and "muted" or "text")
            ui.centered(values[c], col.x, cy, 20, "regular", "right")
        end
        theme.set("line")
        love.graphics.line(64, cy + 25, 656, cy + 25)
    end

    theme.set("muted")
    local summary
    if totals.started == 0 then
        summary = "Solve a puzzle to start filling in this table."
    else
        summary = string.format("%d of %d puzzles solved. Best times only count solves without hints.",
            totals.solved, totals.started)
    end
    ui.text(summary, 64, 380, 16, "regular", "left", 592)

    ui.hints({ { "Y", "Reset" }, { "B", "Back" } }, 696, 452, "right")
end

return Stats
