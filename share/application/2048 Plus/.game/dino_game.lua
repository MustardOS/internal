--[[
    dino_game.lua
    Chrome Dino runner
    Based on Google-Dino-Love2D by SLAYKIN6_TTV
]]

local dino_game = {}

local SCREEN_W, SCREEN_H = 640, 480
local GROUND_MARGIN_BOTTOM = 100
local GROUND_Y = SCREEN_H - GROUND_MARGIN_BOTTOM
local GRAVITY = 2900

local JUMP_VELOCITY = -1060
local DINO_X = 80
local DINO_W, DINO_H = 88, 94
local PLAYER_HITBOX_H = 75

local DUCK_W, DUCK_H = 118, 60
local DUCK_HITBOX_H = 50

local INTRO_DURATION = 0.4

local SPEED_BASE = 360
local SPEED_MAX = 780
local SPEED_ACCEL = 3.6

local SCORE_COEFFICIENT = 0.025 / 2
local CLEAR_TIME = 3.0

local RUN_FRAME_TIME = 6 / 60
local DUCK_FRAME_TIME = 6 / 60
local PTERO_FRAME_TIME = 0.15

local SMALL_UNIT_W, SMALL_H = 34, 70
local BIG_UNIT_W, BIG_H = 49, 100

local CACTUS_SMALL_MULTI_SPEED = 240
local CACTUS_LARGE_MULTI_SPEED = 420
local SMALL_PARK_OFFSET = 100
local BIG_PARK_OFFSET = 200
local STALK_GAP_MIN, STALK_GAP_MAX = 0, 14

local PTERO_W, PTERO_H = 92, 64
local PTERO_LOW_OFFSET = 150
local PTERO_HIGH_OFFSET = 240
local PTERO_GROUND_OFFSET = PTERO_H + 8

local PTERO_LOW_Y = GROUND_Y - PTERO_LOW_OFFSET
local PTERO_HIGH_Y = GROUND_Y - PTERO_HIGH_OFFSET
local PTERO_GROUND_Y = GROUND_Y - PTERO_GROUND_OFFSET
local PTERO_PARK_OFFSET = 150
local PTERO_SPAWN_MIN_EARLY, PTERO_SPAWN_MAX_EARLY = 4.5, 9.0
local PTERO_SPAWN_MIN_LATE, PTERO_SPAWN_MAX_LATE = 3.0, 5.5

local PTERO_MIN_GAP_TIME = 0.5
local OBSTACLE_MIN_GAP_TIME = PTERO_MIN_GAP_TIME
local PTERO_MIN_SPEED = 510

local GAP_COEFFICIENT = 0.6
local GAP_BASE_MIN = 120
local GAP_RANDOM_MAX_MULT = 1.5

local CLOUD_W, CLOUD_H = 92, 27
local CLOUD_SPEED_FACTOR = 0.2
local CLOUD_FREQUENCY = 0.5
local MAX_CLOUDS = 6
local MIN_CLOUD_GAP, MAX_CLOUD_GAP = 100, 400
local CLOUD_SKY_MIN_FRAC, CLOUD_SKY_MAX_FRAC = 0.15, 0.45

local HISCORE_FILE = "dino_hiscore.dat"

local DIGIT_GLYPHS = {
    ["0"] = { 954, 18 }, ["1"] = { 976, 16 }, ["2"] = { 994, 18 },
    ["3"] = { 1014, 18 }, ["4"] = { 1034, 18 }, ["5"] = { 1054, 18 },
    ["6"] = { 1074, 18 }, ["7"] = { 1094, 18 }, ["8"] = { 1114, 18 },
    ["9"] = { 1134, 18 }, ["H"] = { 1154, 18 }, ["I"] = { 1176, 16 },
}
local DIGIT_Y, DIGIT_H = 2, 21

local ACHIEVEMENT_DISTANCE = 100
local FLASH_DURATION = 0.25
local FLASH_ITERATIONS = 3

local JUMP_BUFFER_TIME = 0.12
local GAMEOVER_CLEAR_TIME = 0.5

local JUMP_NATURAL_APEX = JUMP_VELOCITY * JUMP_VELOCITY / (2 * GRAVITY)
local MIN_JUMP_HEIGHT_RISE = 0.36 * JUMP_NATURAL_APEX
local MAX_JUMP_HEIGHT_RISE = 0.756 * JUMP_NATURAL_APEX
local JUMP_DROP_VELOCITY = 0.5 * JUMP_VELOCITY
local SPEED_DROP_COEFFICIENT = 3
local SPEED_DROP_INITIAL_VY = 60

local sheet = nil
local sheetData = nil
local quads = {}
local ground = {}
local dino = {}
local game = {}
local clouds = {}
local sounds = {}

local function newQuad(x, y, w, h)
    if not sheet then return nil end
    return love.graphics.newQuad(x, y, w, h, sheet:getDimensions())
end

local function loadHiscore()
    if love.filesystem.getInfo(HISCORE_FILE) then
        local contents = love.filesystem.read(HISCORE_FILE)
        return tonumber(contents) or 0
    end
    return 0
end

local function saveHiscore(score)
    love.filesystem.write(HISCORE_FILE, tostring(math.floor(score)))
end

local function buildQuads()
    if not sheet then return end
    quads.groundFlat = newQuad(0, 104, 1202, 18)
    quads.groundBump = newQuad(1202, 104, 1202, 18)

    quads.dinoRunA = newQuad(1514, 0, DINO_W, DINO_H)
    quads.dinoRunB = newQuad(1602, 0, DINO_W, DINO_H)
    quads.dinoIdle = newQuad(1338, 0, DINO_W, DINO_H)
    quads.dinoBlink = newQuad(1690, 0, DINO_W, DINO_H)

    quads.duckA = newQuad(1866, 36, 119, 60)
    quads.duckB = newQuad(1985, 36, 117, 60)

    quads.icon = newQuad(2, 2, 72, 64)
    quads.cloud = newQuad(166, 2, CLOUD_W, CLOUD_H)

    quads.pteroA = newQuad(260, 14, 92, 68)
    quads.pteroB = newQuad(352, 2, 92, 60)

    quads.gameOverText = newQuad(954, 29, 386, 26)

    quads.digits = {}
    for char, def in pairs(DIGIT_GLYPHS) do
        quads.digits[char] = newQuad(def[1], DIGIT_Y, def[2], DIGIT_H)
    end

    quads.small = {}
    quads.big = {}
    local smallX = { 446, 548 }
    local bigX = { 652, 802 }
    for variant = 1, 2 do
        quads.small[variant] = {}
        quads.big[variant] = {}
        for count = 1, 3 do
            quads.small[variant][count] = newQuad(smallX[variant], 2, SMALL_UNIT_W * count, SMALL_H)
            quads.big[variant][count] = newQuad(bigX[variant], 2, BIG_UNIT_W * count, BIG_H)
        end
    end
end

local function loadSounds()
    local ok1, s1 = pcall(love.audio.newSource, "assets/dino/jump.ogg", "static")
    if ok1 and s1 then sounds.jump = s1 sounds.jump:setVolume(0.55) end

    local ok2, s2 = pcall(love.audio.newSource, "assets/dino/hit.ogg", "static")
    if ok2 and s2 then sounds.hit = s2 sounds.hit:setVolume(0.60) end

    local ok3, s3 = pcall(love.audio.newSource, "assets/dino/reached.ogg", "static")
    if ok3 and s3 then sounds.reached = s3 sounds.reached:setVolume(0.55) end
end

local function playSound(source)
    if source then
        local cl = source:clone()
        cl:setVolume(source:getVolume())
        cl:play()
    end
end

local function updateScreenSize()
    SCREEN_W, SCREEN_H = love.graphics.getDimensions()
    GROUND_Y = SCREEN_H - GROUND_MARGIN_BOTTOM
    PTERO_LOW_Y = GROUND_Y - PTERO_LOW_OFFSET
    PTERO_HIGH_Y = GROUND_Y - PTERO_HIGH_OFFSET
    PTERO_GROUND_Y = GROUND_Y - PTERO_GROUND_OFFSET
end

local function drawPixelText(text, x, y, scale_factor)
    scale_factor = scale_factor or 1
    local cursor = x
    for i = 1, #text do
        local ch = text:sub(i, i)
        local def = DIGIT_GLYPHS[ch]
        if def and quads.digits and quads.digits[ch] then
            love.graphics.draw(sheet, quads.digits[ch], cursor, y, 0, scale_factor, scale_factor)
            cursor = cursor + (def[2] + 2) * scale_factor
        end
    end
    return cursor - x
end

local function difficultyT()
    return math.min(1, math.max(0, (game.speed - SPEED_BASE) / (SPEED_MAX - SPEED_BASE)))
end

local function rollPteroSpawnTimer()
    local t = difficultyT()
    local mn = PTERO_SPAWN_MIN_EARLY + (PTERO_SPAWN_MIN_LATE - PTERO_SPAWN_MIN_EARLY) * t
    local mx = PTERO_SPAWN_MAX_EARLY + (PTERO_SPAWN_MAX_LATE - PTERO_SPAWN_MAX_EARLY) * t
    return love.math.random() * (mx - mn) + mn
end

local function rollObstacleSpawnTimer()
    local lastObs = game.obstacles[#game.obstacles]
    local lastW = lastObs and lastObs.w or SMALL_UNIT_W
    local frameSpeed = game.speed / 60
    local minGap = math.floor(lastW * frameSpeed + GAP_BASE_MIN * GAP_COEFFICIENT)
    local gap = love.math.random(minGap, math.floor(minGap * GAP_RANDOM_MAX_MULT))
    return gap / game.speed
end

local function spawnObstacle(obstacleType)
    local variant = love.math.random(1, 2)
    local count = love.math.random(1, 3)

    local unitW, h, quadTable, parkOffset, multiSpeedThreshold
    if obstacleType == "big" then
        unitW, h = BIG_UNIT_W, BIG_H
        quadTable = quads.big
        parkOffset = BIG_PARK_OFFSET
        multiSpeedThreshold = CACTUS_LARGE_MULTI_SPEED
    else
        obstacleType = "small"
        unitW, h = SMALL_UNIT_W, SMALL_H
        quadTable = quads.small
        parkOffset = SMALL_PARK_OFFSET
        multiSpeedThreshold = CACTUS_SMALL_MULTI_SPEED
    end

    if count > 1 and multiSpeedThreshold > game.speed then
        count = 1
    end

    local singleQuad = quadTable[variant][1]
    local parts = {}
    local dx = 0
    for i = 1, count do
        table.insert(parts, { dx = dx, w = unitW, quad = singleQuad })
        dx = dx + unitW
        if i < count then
            dx = dx + love.math.random(STALK_GAP_MIN, STALK_GAP_MAX)
        end
    end
    local w = dx

    local spawnX = SCREEN_W + parkOffset
    local minGap = OBSTACLE_MIN_GAP_TIME * game.speed

    for _, o in ipairs(game.obstacles) do
        local trailingEdge = o.x + o.w
        if spawnX - trailingEdge < minGap then
            spawnX = trailingEdge + minGap
        end
    end

    if game.ptero then
        local pteroTrailingEdge = game.ptero.x + PTERO_W
        if spawnX - pteroTrailingEdge < minGap then
            spawnX = pteroTrailingEdge + minGap
        end
    end

    table.insert(game.obstacles, {
        x = spawnX,
        y = GROUND_Y - h,
        w = w,
        h = h,
        parts = parts,
    })
    game.currentType = obstacleType
end

local function spawnPterodactyl(spawnX)
    local t = difficultyT()
    local wHigh = 0.40 - 0.15 * t
    local wLow = 0.60 - 0.20 * t
    local wGround = 0.35 * t
    local roll = love.math.random() * (wHigh + wLow + wGround)

    local y
    if roll < wHigh then
        y = PTERO_HIGH_Y
    elseif roll < wHigh + wLow then
        y = PTERO_LOW_Y
    else
        y = PTERO_GROUND_Y
    end

    game.ptero = {
        x = spawnX,
        y = y,
        w = PTERO_W,
        h = PTERO_H,
        frame = 0,
        frameTimer = 0,
    }
end

local function spawnCloud()
    table.insert(clouds, {
        x = SCREEN_W,
        y = love.math.random() * (CLOUD_SKY_MAX_FRAC - CLOUD_SKY_MIN_FRAC) * SCREEN_H + CLOUD_SKY_MIN_FRAC * SCREEN_H,
        gap = love.math.random(MIN_CLOUD_GAP, MAX_CLOUD_GAP),
    })
end

local function aabbOverlap(px, py, pw, ph, ox, oy, ow, oh)
    return px < ox + ow and px + pw > ox and py < oy + oh and py + ph > oy
end

local function getPlayerHitbox()
    if game.ducking then
        return DINO_X, GROUND_Y - DUCK_HITBOX_H, DUCK_W, DUCK_HITBOX_H
    else
        return DINO_X, dino.y, DINO_W, PLAYER_HITBOX_H
    end
end

local function getPlayerVisual()
    if game.ducking and dino.onGround then
        local quad = (dino.runFrame == 0) and quads.duckA or quads.duckB
        return quad, DINO_X, GROUND_Y - DUCK_H
    end
    local quad = quads.dinoIdle
    if game.state == "play" and dino.onGround then
        quad = (dino.runFrame == 0) and quads.dinoRunA or quads.dinoRunB
    end
    return quad, DINO_X, dino.y
end

local ALPHA_THRESHOLD = 0.1
local PIXEL_STEP = 2
local function pixelsOverlap(ax, ay, aw, ah, aQuad, aDrawX, aDrawY,
                              bx, by, bw, bh, bQuad, bDrawX, bDrawY)
    if not aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh) then return false end
    if not sheetData then return true end

    local aqx, aqy, aqw, aqh = aQuad:getViewport()
    local bqx, bqy, bqw, bqh = bQuad:getViewport()

    local x1 = math.max(ax, bx)
    local y1 = math.max(ay, by)
    local x2 = math.min(ax + aw, bx + bw)
    local y2 = math.min(ay + ah, by + bh)

    for y = math.floor(y1), math.ceil(y2) - 1, PIXEL_STEP do
        for x = math.floor(x1), math.ceil(x2) - 1, PIXEL_STEP do
            local asx, asy = aqx + (x - aDrawX), aqy + (y - aDrawY)
            local bsx, bsy = bqx + (x - bDrawX), bqy + (y - bDrawY)
            if asx >= aqx and asx < aqx + aqw and asy >= aqy and asy < aqy + aqh and
               bsx >= bqx and bsx < bqx + bqw and bsy >= bqy and bsy < bqy + bqh then
                local _, _, _, aA = sheetData:getPixel(asx, asy)
                if aA > ALPHA_THRESHOLD then
                    local _, _, _, aB = sheetData:getPixel(bsx, bsy)
                    if aB > ALPHA_THRESHOLD then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function checkCollision(obs)
    local px, py, pw, ph = getPlayerHitbox()
    local pQuad, pDrawX, pDrawY = getPlayerVisual()

    if obs.parts then
        for _, part in ipairs(obs.parts) do
            local ox, oy = obs.x + part.dx, obs.y
            if pixelsOverlap(px, py, pw, ph, pQuad, pDrawX, pDrawY,
                              ox, oy, part.w, obs.h, part.quad, ox, oy) then
                return true
            end
        end
        return false
    end

    return pixelsOverlap(px, py, pw, ph, pQuad, pDrawX, pDrawY,
                          obs.x, obs.y, obs.w, obs.h, obs.quad, obs.x, obs.y)
end

local GROUND_SEGMENT_W = 1202

local function newGroundSegment(x)
    local isBump = love.math.random() < 0.5
    return { x = x, w = GROUND_SEGMENT_W, quad = isBump and quads.groundBump or quads.groundFlat }
end

local function resetGroundSegments()
    ground.segments = {}
    local x = 0
    while x < SCREEN_W + GROUND_SEGMENT_W do
        table.insert(ground.segments, newGroundSegment(x))
        x = x + GROUND_SEGMENT_W
    end
end

local function updateGround(dt)
    for _, seg in ipairs(ground.segments) do
        seg.x = seg.x - game.speed * dt
    end
    while ground.segments[1] and ground.segments[1].x + ground.segments[1].w < 0 do
        table.remove(ground.segments, 1)
        local last = ground.segments[#ground.segments]
        table.insert(ground.segments, newGroundSegment(last.x + last.w))
    end
    while true do
        local last = ground.segments[#ground.segments]
        if last.x + last.w >= SCREEN_W + GROUND_SEGMENT_W then break end
        table.insert(ground.segments, newGroundSegment(last.x + last.w))
    end
end

local function resetGame()
    dino.y = GROUND_Y - DINO_H
    dino.vy = 0
    dino.onGround = true
    dino.runFrame = 0
    dino.runTimer = 0
    dino.jumpBufferTimer = 0
    dino.speedDrop = false
    dino.reachedMinHeight = false

    game.ducking = false
    game.score = 0
    game.distance = 0
    game.playTime = 0
    game.speed = SPEED_BASE
    ground.segments = nil
    resetGroundSegments()

    game.achievement = false
    game.flashTimer = 0
    game.flashIterations = 0
    game.lastAchievementBracket = 0
    game.scoreVisible = true

    game.ptero = nil
    game.pteroSpawnTimer = rollPteroSpawnTimer()

    clouds = {}

    game.obstacles = {}
    game.obstacleSpawnTimer = 0
    game.hasSpawnedFirst = false
end

local function endJump()
    if dino.reachedMinHeight and dino.vy < JUMP_DROP_VELOCITY then
        dino.vy = JUMP_DROP_VELOCITY
    end
end

local function jump()
    if dino.onGround and not game.ducking then
        dino.vy = JUMP_VELOCITY
        dino.onGround = false
        playSound(sounds.jump)
    elseif not game.ducking then
        dino.jumpBufferTimer = JUMP_BUFFER_TIME
    end
end

local function updateDino(dt)
    local Input = package.loaded["input"]
    local allow_space = (not Input or not Input.events or Input.events.START ~= "space")
    local is_up_held = love.keyboard.isDown("up", "w") or (allow_space and love.keyboard.isDown("space"))
    if Input and Input.state then
        if (allow_space and Input.state["space"]) or Input.state["up"] or Input.state["dpup"] or (Input.events and (Input.state[Input.events.CONFIRM] or Input.state[Input.events.UP])) then
            is_up_held = true
        end
    end

    if not dino.onGround then
        local rise = (GROUND_Y - DINO_H) - dino.y
        if rise >= MIN_JUMP_HEIGHT_RISE then
            dino.reachedMinHeight = true
        end
        if rise >= MAX_JUMP_HEIGHT_RISE or dino.speedDrop or not is_up_held then
            endJump()
        end

        if dino.speedDrop then
            dino.y = dino.y + dino.vy * SPEED_DROP_COEFFICIENT * dt
        else
            dino.y = dino.y + dino.vy * dt
        end
        dino.vy = dino.vy + GRAVITY * dt
    end

    if dino.y + DINO_H >= GROUND_Y then
        dino.y = GROUND_Y - DINO_H
        dino.vy = 0
        dino.onGround = true
        dino.speedDrop = false
        dino.reachedMinHeight = false
    else
        dino.onGround = false
    end

    local is_down_held = love.keyboard.isDown("down", "s", "v")
    if Input and Input.state then
        if Input.state["down"] or Input.state["dpdown"] or Input.state["s"] or Input.state["v"] or (Input.events and Input.state[Input.events.DOWN]) then
            is_down_held = true
        end
    end
    game.ducking = dino.onGround and is_down_held

    if dino.jumpBufferTimer > 0 then
        dino.jumpBufferTimer = dino.jumpBufferTimer - dt
    end

    if dino.onGround and not game.ducking then
        if dino.jumpBufferTimer > 0 then
            dino.vy = JUMP_VELOCITY
            dino.onGround = false
            dino.jumpBufferTimer = 0
            playSound(sounds.jump)
        end
    end

    if dino.onGround then
        local frameTime = game.ducking and DUCK_FRAME_TIME or RUN_FRAME_TIME
        dino.runTimer = dino.runTimer + dt
        if dino.runTimer >= frameTime then
            dino.runTimer = 0
            dino.runFrame = 1 - dino.runFrame
        end
    end
end

local function triggerGameOver()
    game.state = "over"
    game.overTimer = 0
    playSound(sounds.hit)
    if game.score > game.hiscore then
        game.hiscore = game.score
        saveHiscore(game.hiscore)
    end
end

local function updatePtero(dt)
    game.pteroSpawnTimer = game.pteroSpawnTimer - dt
    if not game.ptero and game.pteroSpawnTimer <= 0 and game.speed >= PTERO_MIN_SPEED then
        local pteroSpawnX = SCREEN_W + PTERO_PARK_OFFSET
        local minGap = PTERO_MIN_GAP_TIME * game.speed
        for _, o in ipairs(game.obstacles) do
            local trailingEdge = o.x + o.w
            if pteroSpawnX - trailingEdge < minGap then
                pteroSpawnX = trailingEdge + minGap
            end
        end
        spawnPterodactyl(pteroSpawnX)
        game.pteroSpawnTimer = rollPteroSpawnTimer()
    end

    local p = game.ptero
    if p then
        p.x = p.x - game.speed * dt
        p.frameTimer = p.frameTimer + dt
        if p.frameTimer >= PTERO_FRAME_TIME then
            p.frameTimer = 0
            p.frame = 1 - p.frame
        end
        p.quad = (p.frame == 0) and quads.pteroA or quads.pteroB
        if checkCollision(p) then
            triggerGameOver()
        elseif p.x + p.w < 0 then
            game.ptero = nil
        end
    end
end

local function updateClouds(dt)
    local lastCloud = clouds[#clouds]
    if #clouds < MAX_CLOUDS
        and (not lastCloud or (SCREEN_W - lastCloud.x) > lastCloud.gap)
        and CLOUD_FREQUENCY > love.math.random() then
        spawnCloud()
    end
    for i = #clouds, 1, -1 do
        local c = clouds[i]
        c.x = c.x - game.speed * CLOUD_SPEED_FACTOR * dt
        if c.x + CLOUD_W < 0 then
            table.remove(clouds, i)
        end
    end
end

local function updateAchievementFlash(dt)
    if not game.achievement then
        local bracket = math.floor(game.score / ACHIEVEMENT_DISTANCE)
        if game.score > 0 and bracket > game.lastAchievementBracket then
            game.lastAchievementBracket = bracket
            game.achievement = true
            game.flashTimer = 0
            game.flashIterations = 0
            playSound(sounds.reached)
        end
        game.scoreVisible = true
        return
    end

    if game.flashIterations <= FLASH_ITERATIONS then
        game.flashTimer = game.flashTimer + dt
        if game.flashTimer < FLASH_DURATION then
            game.scoreVisible = false
        else
            game.scoreVisible = true
            if game.flashTimer > FLASH_DURATION * 2 then
                game.flashTimer = 0
                game.flashIterations = game.flashIterations + 1
            end
        end
    else
        game.achievement = false
        game.flashIterations = 0
        game.flashTimer = 0
        game.scoreVisible = true
    end
end

local function updatePlay(dt)
    game.playTime = game.playTime + dt
    game.speed = math.min(SPEED_MAX, game.speed + SPEED_ACCEL * dt)
    game.distance = game.distance + game.speed * dt
    game.score = math.floor(game.distance * SCORE_COEFFICIENT)
    updateAchievementFlash(dt)

    updateGround(dt)
    updateDino(dt)
    updateClouds(dt)

    if game.playTime < CLEAR_TIME then return end

    updatePtero(dt)
    if game.state ~= "play" then return end

    for i = #game.obstacles, 1, -1 do
        local obs = game.obstacles[i]
        obs.x = obs.x - game.speed * dt
        if checkCollision(obs) then
            triggerGameOver()
        elseif obs.x + obs.w < 0 then
            table.remove(game.obstacles, i)
        end
    end
    if game.state ~= "play" then return end

    game.obstacleSpawnTimer = game.obstacleSpawnTimer - dt
    if game.obstacleSpawnTimer <= 0 then
        local nextType
        if game.hasSpawnedFirst then
            nextType = (game.currentType == "small") and "big" or "small"
        else
            nextType = game.currentType
            game.hasSpawnedFirst = true
        end
        spawnObstacle(nextType)
        game.obstacleSpawnTimer = rollObstacleSpawnTimer()
    end
end

local function updateIdle(dt)
    if game.state == "over" then
        game.overTimer = game.overTimer + dt
        return
    end
    if game.state ~= "start" then return end
    updateClouds(dt)
end

local function updateIntro(dt)
    game.introTimer = game.introTimer + dt
    updateDino(dt)
    if game.introTimer >= INTRO_DURATION then
        game.introTimer = INTRO_DURATION
        game.state = "play"
    end
end

local function currentRevealWidth()
    if game.state == "start" then
        return DINO_W
    elseif game.state == "intro" then
        local t = math.min(1, game.introTimer / INTRO_DURATION)
        local eased = 1 - (1 - t) * (1 - t)
        return DINO_W + (SCREEN_W - DINO_X - DINO_W) * eased
    end
    return SCREEN_W
end

local function drawClouds()
    love.graphics.setColor(1, 1, 1)
    for _, c in ipairs(clouds) do
        love.graphics.draw(sheet, quads.cloud, c.x, c.y)
    end
end

local function drawGround()
    love.graphics.setColor(1, 1, 1)
    for _, seg in ipairs(ground.segments) do
        love.graphics.draw(sheet, seg.quad, seg.x, GROUND_Y - 24)
    end
end

local function drawDino()
    love.graphics.setColor(1, 1, 1)
    if game.state == "over" then
        love.graphics.draw(sheet, quads.dinoBlink, DINO_X, dino.y)
        return
    end

    if game.ducking and dino.onGround then
        local quad = (dino.runFrame == 0) and quads.duckA or quads.duckB
        love.graphics.draw(sheet, quad, DINO_X, GROUND_Y - DUCK_H)
        return
    end

    local quad = quads.dinoIdle
    if game.state == "play" and dino.onGround then
        quad = (dino.runFrame == 0) and quads.dinoRunA or quads.dinoRunB
    end
    love.graphics.draw(sheet, quad, DINO_X, dino.y)
end

local function drawObstacle()
    love.graphics.setColor(1, 1, 1)
    for _, obs in ipairs(game.obstacles) do
        for _, part in ipairs(obs.parts) do
            love.graphics.draw(sheet, part.quad, obs.x + part.dx, obs.y)
        end
    end
    if game.ptero then
        local quad = (game.ptero.frame == 0) and quads.pteroA or quads.pteroB
        love.graphics.draw(sheet, quad, game.ptero.x, game.ptero.y)
    end
end

local function drawHud()
    love.graphics.setColor(1, 1, 1)
    local hiscoreStr = ("%05d"):format(math.floor(game.hiscore))
    local scoreStr = ("%05d"):format(math.floor(game.score))

    local x, y = SCREEN_W - 320, 24
    local hiLabelW = drawPixelText("HI", x, y)
    local hiNumX = x + hiLabelW + 14
    local hiNumW = drawPixelText(hiscoreStr, hiNumX, y)

    if game.scoreVisible then
        drawPixelText(scoreStr, hiNumX + hiNumW + 20, y)
    end

    if game.state == "over" then
        love.graphics.setColor(1, 1, 1)
        local textW = 386
        local tx = (SCREEN_W - textW) / 2
        local centerY = SCREEN_H / 2
        love.graphics.draw(sheet, quads.gameOverText, tx, centerY - 60)
        love.graphics.draw(sheet, quads.icon, SCREEN_W / 2 - 36, centerY - 15)
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

function dino_game.init()
    sheet = love.graphics.newImage("assets/dino/sprite.png")
    sheet:setFilter("nearest", "nearest")
    sheetData = love.image.newImageData("assets/dino/sprite.png")

    buildQuads()
    loadSounds()
    updateScreenSize()

    game.hiscore = loadHiscore()
    game.state = "start"
    game.introTimer = 0
    game.currentType = "small"
    game.debugHitboxes = false
    game.overTimer = 0
    resetGame()
end

function dino_game.start()
    updateScreenSize()
    game.hiscore = loadHiscore()
    game.state = "start"
    game.introTimer = 0
    game.currentType = "small"
    game.debugHitboxes = false
    game.overTimer = 0
    resetGame()
end

function dino_game.resize(w, h)
    updateScreenSize()
end

function dino_game.update(dt)
    dt = math.min(dt, 1 / 30)
    updateScreenSize()

    if game.state == "play" then
        updatePlay(dt)
    elseif game.state == "intro" then
        updateIntro(dt)
    else
        updateIdle(dt)
    end
end

function dino_game.handleEvent(event)
    local Input = package.loaded["input"]
    local allow_space = (not Input or not Input.events or Input.events.START ~= "space")
    local is_confirm = (event == "return" or (allow_space and event == "space") or event == "a" or event == "up" or event == "w")
    if Input and Input.events then
        if event == Input.events.CONFIRM or event == Input.events.UP then
            is_confirm = true
        end
    end

    local is_back = (event == "backspace" or event == "b")
    if Input and Input.events then
        if event == Input.events.BACK then
            is_back = true
        end
    end

    if is_back then
        return true
    end

    if is_confirm then
        if game.state == "start" then
            jump()
            game.state = "intro"
            game.introTimer = 0
        elseif game.state == "over" then
            if game.overTimer >= GAMEOVER_CLEAR_TIME then
                resetGame()
                game.state = "play"
            end
        else
            jump()
        end
        return true
    end

    local is_duck = (event == "down" or event == "s" or event == "v")
    if Input and Input.events and event == Input.events.DOWN then
        is_duck = true
    end

    if is_duck then
        if (game.state == "play" or game.state == "intro") and not dino.onGround then
            dino.speedDrop = true
            dino.vy = SPEED_DROP_INITIAL_VY
        end
        return true
    end

    return false
end

function dino_game.keypressed(key)
    return dino_game.handleEvent(key)
end

function dino_game.keyreleased(key)
    local Input = package.loaded["input"]
    local allow_space = (not Input or not Input.events or Input.events.START ~= "space")
    if key == "up" or (allow_space and key == "space") or key == "w" or key == "return" or key == "a" then
        if not dino.onGround then
            endJump()
        end
    end
end

function dino_game.gamepadreleased(button)
    if button == "a" or button == "dpup" then
        if not dino.onGround then
            endJump()
        end
    end
end

function dino_game.draw()
    updateScreenSize()

    love.graphics.setColor(0.97, 0.97, 0.97, 1.0)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

    local clipped = (game.state == "start" or game.state == "intro")
    if clipped then
        love.graphics.setScissor(DINO_X, 0, currentRevealWidth(), SCREEN_H)
    end

    drawClouds()
    drawGround()
    drawObstacle()
    drawDino()
    drawHud()

    if clipped then
        love.graphics.setScissor()
    end

    local renderer_mod = package.loaded["renderer"] or require("renderer")
    local scale = _G.scale or 1

    local badge_h = math.floor(28 * scale)
    local badge_y = SCREEN_H - badge_h - math.floor(14 * scale)
    local item_gap = math.floor(10 * scale)
    local label_gap = math.floor(4 * scale)

    local font_lbl = (renderer_mod and renderer_mod.font_help_label) or love.graphics.getFont()
    local font_k = (renderer_mod and renderer_mod.font_help_key) or font_lbl
    love.graphics.setFont(font_lbl)

    local left_x = math.floor(16 * scale)
    if renderer_mod and renderer_mod.drawKeyBadge then
        renderer_mod.drawKeyBadge("B", left_x, badge_y, badge_h, badge_h)
    end
    left_x = left_x + badge_h + label_gap
    love.graphics.setColor(0.35, 0.35, 0.35, 0.90)
    love.graphics.print("Exit", left_x, badge_y + math.floor((badge_h - font_lbl:getHeight()) / 2))

    local a_label = "Jump"
    if game.state == "start" then
        a_label = "Start"
    elseif game.state == "over" then
        a_label = "Retry"
    end

    local actions = {}
    if game.state == "over" then
        table.insert(actions, {key = "A", label = a_label})
    else
        table.insert(actions, {key = "DOWN", label = "Duck"})
        table.insert(actions, {key = "A", label = a_label})
    end

    local right_x = SCREEN_W - math.floor(16 * scale)
    for _, action in ipairs(actions) do
        local lbl_w = font_lbl:getWidth(action.label)
        right_x = right_x - lbl_w
        love.graphics.setColor(0.35, 0.35, 0.35, 0.90)
        love.graphics.print(action.label, right_x, badge_y + math.floor((badge_h - font_lbl:getHeight()) / 2))

        right_x = right_x - label_gap
        local key_w = badge_h
        if action.key == "DOWN" then
            key_w = math.max(math.floor(28 * scale), font_k:getWidth("DOWN") + math.floor(12 * scale))
        end
        right_x = right_x - key_w
        if renderer_mod and renderer_mod.drawKeyBadge then
            renderer_mod.drawKeyBadge(action.key, right_x, badge_y, key_w, badge_h)
        end

        right_x = right_x - item_gap
    end
end

return dino_game
