local PlayerConfig = require "Data.PlayerConfig"
local EnemyConfig = require "Data.EnemyConfig"
local Feedback = require "Feedback"
local BossRenderer = require "BossRenderer"

local Renderer = {}
local SOOT_SPRITE_PATH = "image/soot_monster.png"
local PLAYER_SPINE_PATH = "Characters/bard_cat/bard_cat.json"
local PLAYER_IDLE_ANIMATION = "move/STAND"
local PLAYER_MOVE_ANIMATION = "move/MOVE"
-- All Spine pages are repacked within the 2048px device texture budget.
local ENABLE_SPINE_PLAYER = true
local playerImageHandle = 0
local playerImageWidth = 1
local playerImageHeight = 1
local sootImageHandle = 0
local sootImageWidth = 1
local sootImageHeight = 1
---@type SpineInstance|nil
local playerSpine = nil
---@type string|nil
local playerSpineAnimation = nil
---@type number|nil
local playerSpineLastTime = nil

function Renderer.LoadAssets(ctx)
    local playerLoaded = false
    if ENABLE_SPINE_PLAYER then
        playerSpine = nvgSpineCreate(ctx)
    end
    if playerSpine ~= nil and playerSpine:Load(PLAYER_SPINE_PATH) then
        playerSpine:SetDefaultMix(0.12)
        playerSpine:SetAnimation(0, PLAYER_IDLE_ANIMATION, true)
        playerSpineAnimation = PLAYER_IDLE_ANIMATION
        playerSpineLastTime = nil
        playerLoaded = true
        print("Loaded Spine player character: " .. PLAYER_SPINE_PATH)
    else
        if playerSpine ~= nil then
            playerSpine:Unload()
            playerSpine:Dispose()
            playerSpine = nil
        end

        playerImageHandle = nvgCreateImage(ctx, "Characters/player.png", 0)
        if playerImageHandle == nil or playerImageHandle <= 0 then
            playerImageHandle = 0
            print("WARNING: Failed to load Spine player and static fallback: Characters/player.png")
        else
            playerImageWidth, playerImageHeight = nvgImageSize(ctx, playerImageHandle)
            if playerImageWidth <= 0 or playerImageHeight <= 0 then
                nvgDeleteImage(ctx, playerImageHandle)
                playerImageHandle = 0
                playerImageWidth, playerImageHeight = 1, 1
                print("WARNING: Player sprite fallback has invalid dimensions")
            else
                playerLoaded = true
            end
        end
    end

    local sootLoaded = true
    sootImageHandle = nvgCreateImage(ctx, SOOT_SPRITE_PATH, 0)
    if sootImageHandle == nil or sootImageHandle <= 0 then
        sootImageHandle = 0
        sootLoaded = false
        print("WARNING: Failed to load soot sprite: " .. SOOT_SPRITE_PATH .. "; using vector fallback")
    else
        sootImageWidth, sootImageHeight = nvgImageSize(ctx, sootImageHandle)
        if sootImageWidth <= 0 or sootImageHeight <= 0 then
            nvgDeleteImage(ctx, sootImageHandle)
            sootImageHandle = 0
            sootImageWidth, sootImageHeight = 1, 1
            sootLoaded = false
            print("WARNING: Soot sprite has invalid dimensions; using vector fallback")
        end
    end

    return playerLoaded and sootLoaded
end

function Renderer.UnloadAssets(ctx)
    if playerSpine ~= nil then
        playerSpine:Unload()
        playerSpine:Dispose()
        playerSpine = nil
    end
    playerSpineAnimation = nil
    playerSpineLastTime = nil

    if playerImageHandle ~= nil and playerImageHandle > 0 then
        nvgDeleteImage(ctx, playerImageHandle)
    end
    playerImageHandle = 0
    playerImageWidth, playerImageHeight = 1, 1
    if sootImageHandle ~= nil and sootImageHandle > 0 then
        nvgDeleteImage(ctx, sootImageHandle)
    end
    sootImageHandle = 0
    sootImageWidth, sootImageHeight = 1, 1
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function Atan2(y, x)
    return math.atan(y, x)
end

local function Color(ctx, color, alpha)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

local function StrokeColor(ctx, color, alpha)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

function Renderer.GetArena(width, height)
    local left = width * 0.09
    local right = width * 0.91
    local top = height * 0.20
    local bottom = height * 0.86
    local wallThickness = math.max(16, math.min(width, height) * 0.035)
    return {
        left = left,
        right = right,
        top = top,
        bottom = bottom,
        wallTop = height * 0.085,
        wallThickness = wallThickness,
    }
end

function Renderer.WorldToScreen(width, height, x, y)
    local arena = Renderer.GetArena(width, height)
    local scale = Clamp(math.min(width / 960, height / 720), 0.72, 1.35)
    return Lerp(arena.left, arena.right, x), Lerp(arena.top, arena.bottom, y), scale
end

function Renderer.ScreenToWorld(width, height, x, y)
    local arena = Renderer.GetArena(width, height)
    local arenaWidth = math.max(0.0001, arena.right - arena.left)
    local arenaHeight = math.max(0.0001, arena.bottom - arena.top)
    return (x - arena.left) / arenaWidth, (y - arena.top) / arenaHeight
end

local function DrawBackground(ctx, width, height, time)
    local gradient = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(18, 18, 25, 255), nvgRGBA(31, 24, 35, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)

    local drift = (time * 6) % 42
    for index = -2, math.ceil(width / 42) + 2 do
        local x = index * 42 + drift
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, 0)
        nvgLineTo(ctx, x - height * 0.16, height)
        nvgStrokeWidth(ctx, 1)
        nvgStrokeColor(ctx, nvgRGBA(145, 120, 160, 18))
        nvgStroke(ctx)
    end
end

local function DrawDoor(ctx, arena, direction, isOpen, time)
    local floorWidth = arena.right - arena.left
    local floorHeight = arena.bottom - arena.top
    local doorColor = isOpen and { 92, 224, 155 } or { 215, 76, 92 }
    local pulse = 185 + math.floor(35 * math.sin(time * 4.5))
    local x, y, w, h

    if direction == "north" then
        w = floorWidth * 0.14
        h = arena.top - arena.wallTop + 3
        x = (arena.left + arena.right - w) * 0.5
        y = arena.wallTop + 8
    elseif direction == "south" then
        w = floorWidth * 0.14
        h = arena.wallThickness + 8
        x = (arena.left + arena.right - w) * 0.5
        y = arena.bottom - 3
    elseif direction == "west" then
        w = arena.wallThickness + 8
        h = floorHeight * 0.18
        x = arena.left - arena.wallThickness - 3
        y = (arena.top + arena.bottom - h) * 0.5
    else
        w = arena.wallThickness + 8
        h = floorHeight * 0.18
        x = arena.right - 5
        y = (arena.top + arena.bottom - h) * 0.5
    end

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 4)
    nvgFillColor(ctx, nvgRGBA(9, 10, 15, 255))
    nvgFill(ctx)
    nvgStrokeWidth(ctx, isOpen and 3 or 2)
    StrokeColor(ctx, doorColor, isOpen and pulse or 235)
    nvgStroke(ctx)

    if not isOpen then
        nvgBeginPath(ctx)
        if direction == "north" or direction == "south" then
            nvgMoveTo(ctx, x + w * 0.18, y + h * 0.34)
            nvgLineTo(ctx, x + w * 0.82, y + h * 0.66)
            nvgMoveTo(ctx, x + w * 0.82, y + h * 0.34)
            nvgLineTo(ctx, x + w * 0.18, y + h * 0.66)
        else
            nvgMoveTo(ctx, x + w * 0.28, y + h * 0.15)
            nvgLineTo(ctx, x + w * 0.72, y + h * 0.85)
            nvgMoveTo(ctx, x + w * 0.72, y + h * 0.15)
            nvgLineTo(ctx, x + w * 0.28, y + h * 0.85)
        end
        nvgStrokeWidth(ctx, 4)
        StrokeColor(ctx, { 225, 94, 97 }, 235)
        nvgStroke(ctx)
    end
end

local function DrawArena(ctx, width, height, game)
    local arena = Renderer.GetArena(width, height)
    local floorGradient = nvgLinearGradient(ctx, 0, arena.top, 0, arena.bottom,
        nvgRGBA(71, 64, 78, 255), nvgRGBA(43, 39, 50, 255))

    nvgBeginPath(ctx)
    nvgRect(ctx, arena.left, arena.top, arena.right - arena.left, arena.bottom - arena.top)
    nvgFillPaint(ctx, floorGradient)
    nvgFill(ctx)

    -- Tile grid stays rectangular: no forced-perspective tapering.
    for column = 1, 9 do
        local x = Lerp(arena.left, arena.right, column / 10)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, arena.top)
        nvgLineTo(ctx, x, arena.bottom)
        nvgStrokeWidth(ctx, 1)
        StrokeColor(ctx, { 196, 181, 205 }, 26)
        nvgStroke(ctx)
    end
    for row = 1, 7 do
        local y = Lerp(arena.top, arena.bottom, row / 8)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, arena.left, y)
        nvgLineTo(ctx, arena.right, y)
        nvgStrokeWidth(ctx, 1)
        StrokeColor(ctx, { 196, 181, 205 }, 30)
        nvgStroke(ctx)
    end

    -- Tall back wall makes the upper wall face visible in the 2.5D view.
    local backWallGradient = nvgLinearGradient(ctx, 0, arena.wallTop, 0, arena.top,
        nvgRGBA(104, 86, 108, 255), nvgRGBA(65, 53, 72, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, arena.left - arena.wallThickness, arena.wallTop,
        arena.right - arena.left + arena.wallThickness * 2, arena.top - arena.wallTop)
    nvgFillPaint(ctx, backWallGradient)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, arena.left - arena.wallThickness, arena.top,
        arena.wallThickness, arena.bottom - arena.top + arena.wallThickness)
    nvgRect(ctx, arena.right, arena.top,
        arena.wallThickness, arena.bottom - arena.top + arena.wallThickness)
    nvgRect(ctx, arena.left, arena.bottom,
        arena.right - arena.left, arena.wallThickness)
    nvgFillColor(ctx, nvgRGBA(73, 60, 78, 255))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, arena.left - arena.wallThickness, arena.top)
    nvgLineTo(ctx, arena.right + arena.wallThickness, arena.top)
    nvgStrokeWidth(ctx, 4)
    StrokeColor(ctx, { 143, 118, 142 }, 210)
    nvgStroke(ctx)

    if game.room ~= nil then
        for _, direction in ipairs({ "north", "south", "west", "east" }) do
            if game.room.connections[direction] ~= nil then
                DrawDoor(ctx, arena, direction, game.roomCleared, game.time)
            end
        end
    end
end

local function DrawSpawnMarkers(ctx, width, height, game)
    if game.room == nil then
        return
    end

    for _, spawn in ipairs(game.room.spawns) do
        local x, y, scale = Renderer.WorldToScreen(width, height, spawn.x, spawn.y)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, 20 * scale)
        nvgStrokeWidth(ctx, 2)
        StrokeColor(ctx, { 255, 210, 115 }, 180)
        nvgStroke(ctx)
    end
end

local function DrawShadow(ctx, x, y, scale, width, alpha)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, y + 10 * scale, width * scale, 5 * scale)
    nvgFillColor(ctx, nvgRGBA(5, 5, 16, alpha))
    nvgFill(ctx)
end

local function DrawFallbackPlayer(ctx, width, height, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, player.x, player.y)
    local bodyW = 19 * scale
    local bodyH = 29 * scale
    local flip = player.facing == "left" and -1 or 1
    local bob = math.sin(time * 10) * 1.2 * scale

    DrawShadow(ctx, x, y, scale, 16, 125)
    nvgSave(ctx)
    nvgTranslate(ctx, x, y + bob)
    nvgScale(ctx, flip, 1)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, -bodyW * 0.5, -bodyH, bodyW, bodyH, 7 * scale)
    Color(ctx, { 100, 210, 255 }, player.invulnerabilityTimer > 0 and 160 or 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, { 220, 248, 255 }, 255)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, bodyW * 0.18, -bodyH * 0.68, 3.4 * scale)
    Color(ctx, { 22, 30, 62 }, 255)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, bodyW * 0.15, -bodyH * 0.42, bodyW * 0.8, 5 * scale, 2 * scale)
    Color(ctx, { 255, 235, 132 }, 255)
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function DrawSpritePlayer(ctx, width, height, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, player.x, player.y)
    local displayHeight = 58 * scale
    local displayWidth = displayHeight * playerImageWidth / playerImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local flip = player.facing == "left" and -1 or 1
    local bob = math.sin(time * 10) * 1.2 * scale
    local imageAlpha = 1.0
    if player.invulnerabilityTimer > 0 then
        imageAlpha = 0.42 + 0.38 * math.abs(math.sin(time * 24))
    end

    DrawShadow(ctx, x, y, scale, 23, 135)
    nvgSave(ctx)
    nvgTranslate(ctx, x, y + bob)
    nvgScale(ctx, flip, 1)

    if player.parryTimer > 0 then
        nvgSave(ctx)
        nvgScale(ctx, 1.08, 1.08)
        nvgTranslate(ctx, 0, displayHeight * 0.07)
        nvgBeginPath(ctx)
        nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
        nvgFillPaint(ctx, nvgImagePatternTinted(
            ctx, drawX, drawY, displayWidth, displayHeight, 0, playerImageHandle,
            nvgRGBA(110, 235, 255, 125)
        ))
        nvgFill(ctx)
        nvgRestore(ctx)
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, playerImageHandle, imageAlpha))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function UpdatePlayerSpineAnimation(player, time)
    if playerSpine == nil or not playerSpine:IsLoaded() then
        return
    end

    local animation = player.isMoving and PLAYER_MOVE_ANIMATION or PLAYER_IDLE_ANIMATION
    if playerSpineAnimation ~= animation then
        if not playerSpine:SetAnimation(0, animation, true) then
            print("WARNING: Missing player Spine animation: " .. animation)
        end
        playerSpineAnimation = animation
    end

    local deltaTime = 0
    if playerSpineLastTime ~= nil then
        deltaTime = Clamp(time - playerSpineLastTime, 0, 0.1)
    end
    playerSpineLastTime = time
    if deltaTime > 0 then
        playerSpine:Update(deltaTime)
    end
end

local function DrawSpinePose(ctx, displayHeight, flip, red, green, blue, alpha)
    if playerSpine == nil then
        return false
    end

    local dataWidth = playerSpine:GetDataWidth()
    local dataHeight = playerSpine:GetDataHeight()
    if dataWidth <= 0 or dataHeight <= 0 then
        return false
    end

    local scale = displayHeight / dataHeight
    local displayWidth = dataWidth * scale
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local dataX = playerSpine:GetDataX()
    local dataY = playerSpine:GetDataY()

    playerSpine:SetScale(scale * flip, -scale)
    playerSpine:SetPosition(
        drawX + (flip < 0 and (dataWidth + dataX) or -dataX) * scale,
        drawY + (dataHeight + dataY) * scale
    )
    playerSpine:SetColor(red, green, blue, alpha)
    nvgSpineRender(ctx, playerSpine)
    return true
end

local function DrawSpinePlayer(ctx, width, height, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, player.x, player.y)
    local displayHeight = 58 * scale
    local flip = player.facing == "left" and -1 or 1
    local bob = math.sin(time * 10) * 1.2 * scale
    local alpha = 1.0
    if player.invulnerabilityTimer > 0 then
        alpha = 0.42 + 0.38 * math.abs(math.sin(time * 24))
    end

    UpdatePlayerSpineAnimation(player, time)
    DrawShadow(ctx, x, y, scale, 23, 135)
    nvgSave(ctx)
    nvgTranslate(ctx, x, y + bob)
    if player.parryTimer > 0 then
        DrawSpinePose(ctx, displayHeight * 1.08, flip, 110 / 255, 235 / 255, 1.0, 0.49)
    end
    DrawSpinePose(ctx, displayHeight, flip, 1.0, 1.0, 1.0, alpha)
    nvgRestore(ctx)
end

local function DrawPlayer(ctx, width, height, player, time)
    if playerSpine ~= nil and playerSpine:IsLoaded() then
        DrawSpinePlayer(ctx, width, height, player, time)
    elseif playerImageHandle ~= nil and playerImageHandle > 0 then
        DrawSpritePlayer(ctx, width, height, player, time)
    else
        DrawFallbackPlayer(ctx, width, height, player, time)
    end
end

local function EnemyColor(kind)
    local spec = EnemyConfig[kind]
    if spec ~= nil and spec.visual ~= nil then
        return spec.visual.primary
    end
    return { 255, 145, 74 }
end

local function DrawEnemyTelegraph(ctx, width, height, enemy, player)
    if enemy.state ~= "telegraph" then
        return
    end
    local x, y, scale = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local spec = EnemyConfig[enemy.kind]
    local radius = (enemy.radius * 180 + 6) * scale
    local pulse = 120 + math.floor(100 * math.abs(math.sin(enemy.stateTimer * 13)))
    local directionX, directionY = enemy.attackX or 1, enemy.attackY or 0
    local behavior = spec and spec.behavior or ""

    if behavior == "aoe_pulse" then
        radius = (spec.attack.range * 180 + 6) * scale
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, { 255, 230, 120 }, pulse)
    nvgStroke(ctx)

    if behavior == "tree_swing" then
        local arc = math.rad(enemy.attackArc or spec.attack.narrowArc)
        local startAngle = Atan2(directionY, directionX) - arc * 0.5
        for index = 0, 5 do
            local angle = startAngle + arc * index / 5
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, x, y)
            nvgLineTo(ctx, x + math.cos(angle) * radius * 1.8, y + math.sin(angle) * radius * 1.8)
            nvgStrokeWidth(ctx, 1.2 * scale)
            StrokeColor(ctx, { 222, 150, 255 }, math.floor(pulse * 0.72))
            nvgStroke(ctx)
        end
    elseif behavior == "ranged_fan" then
        local spread = math.rad(spec.projectile.spread)
        local startAngle = Atan2(directionY, directionX) - spread * 0.5
        for index = 0, spec.projectile.count - 1 do
            local angle = startAngle + spread * index / (spec.projectile.count - 1)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, x, y)
            nvgLineTo(ctx, x + math.cos(angle) * radius * 2.5, y + math.sin(angle) * radius * 2.5)
            nvgStrokeWidth(ctx, 1.4 * scale)
            StrokeColor(ctx, { 202, 174, 235 }, math.floor(pulse * 0.7))
            nvgStroke(ctx)
        end
    elseif player ~= nil then
        local playerX, playerY = Renderer.WorldToScreen(width, height, player.x, player.y)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, y)
        nvgLineTo(ctx, playerX, playerY)
        nvgStrokeWidth(ctx, 1.5 * scale)
        StrokeColor(ctx, { 255, 220, 115 }, math.floor(pulse * 0.55))
        nvgStroke(ctx)
    end
end

local function DrawEnemyMotionTrail(ctx, width, height, enemy)
    if enemy.state ~= "idle" then
        return
    end
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    if speed <= 0.01 then
        return
    end
    local tailX = enemy.x - enemy.vx * 0.25
    local tailY = enemy.y - enemy.vy * 0.25
    local x, y = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local previousX, previousY = Renderer.WorldToScreen(width, height, tailX, tailY)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, previousX, previousY)
    nvgLineTo(ctx, x, y)
    nvgStrokeWidth(ctx, 2)
    StrokeColor(ctx, EnemyColor(enemy.kind), 85)
    nvgStroke(ctx)
end

local function DrawEyes(ctx, x, y, scale, spacing, eyeColor)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x - spacing, y, 3.6 * scale)
    nvgCircle(ctx, x + spacing, y, 3.6 * scale)
    Color(ctx, eyeColor or { 255, 249, 231 }, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x - spacing + scale, y + scale * 0.5, 1.25 * scale)
    nvgCircle(ctx, x + spacing + scale, y + scale * 0.5, 1.25 * scale)
    Color(ctx, { 25, 26, 39 }, 255)
    nvgFill(ctx)
end

local function DrawSoot(ctx, x, y, size, scale, time, color, secondary)
    local centerY = y - size * 0.58
    for index = 1, 6 do
        local angle = index * math.pi * 2 / 6 + time * 0.5
        local radius = size * (0.16 + (index % 3) * 0.025)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + math.cos(angle) * size * 0.32, centerY + math.sin(angle) * size * 0.25, radius)
        Color(ctx, index % 2 == 0 and secondary or color, 245)
        nvgFill(ctx)
    end
    DrawEyes(ctx, x, centerY - size * 0.04, scale, size * 0.14)
end

local function GetSootSpriteHeight(scale)
    return 42 * scale
end

local function GetSootSquashStretch(enemy, time)
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    local rhythm = math.sin(time * (4.8 + math.min(speed, 1) * 12) + enemy.id * 0.67)
    local scaleX = 1 + rhythm * (speed > 0.01 and 0.055 or 0.025)
    local scaleY = 1 - rhythm * (speed > 0.01 and 0.045 or 0.02)
    local spec = EnemyConfig.soot

    if enemy.state == "telegraph" then
        local duration = math.max(0.001, spec.attack.telegraph)
        local progress = 1 - Clamp(enemy.stateTimer / duration, 0, 1)
        scaleX = 1 + progress * 0.14
        scaleY = 1 - progress * 0.12
    elseif enemy.state == "dash" then
        scaleX = 0.91
        scaleY = 1.14
    elseif enemy.state == "recovery" then
        local duration = math.max(0.001, spec.attack.recovery)
        local progress = Clamp(enemy.stateTimer / duration, 0, 1)
        scaleX = 1 + progress * 0.1
        scaleY = 1 - progress * 0.08
    end

    return scaleX, scaleY
end

local function DrawSpriteSoot(ctx, x, y, enemy, time, scale)
    local displayHeight = GetSootSpriteHeight(scale)
    local displayWidth = displayHeight * sootImageWidth / sootImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local scaleX, scaleY = GetSootSquashStretch(enemy, time)
    local flip = enemy.facing == "left" and -1 or 1

    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    nvgScale(ctx, flip * scaleX, scaleY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, sootImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function DrawBlueSwarm(ctx, x, y, size, scale, time, color, secondary)
    local centerY = y - size * 0.58
    for index = 1, 12 do
        local angle = index * 2.39 + time * (1.3 + (index % 3) * 0.17)
        local orbit = size * (0.18 + (index % 4) * 0.08)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + math.cos(angle) * orbit, centerY + math.sin(angle * 1.3) * orbit * 0.62,
            (1.6 + (index % 3) * 0.7) * scale)
        Color(ctx, index % 2 == 0 and secondary or color, 235)
        nvgFill(ctx)
    end
    DrawEyes(ctx, x, centerY, scale, size * 0.1, { 225, 248, 255 })
end

local function DrawTree(ctx, x, y, size, scale, color, secondary)
    local centerY = y - size * 0.52
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size * 0.2, centerY - size * 0.02, size * 0.4, size * 0.64, size * 0.12)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, secondary, 240)
    nvgStroke(ctx)
    for side = -1, 1, 2 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x + side * size * 0.12, centerY + size * 0.17)
        nvgLineTo(ctx, x + side * size * 0.5, centerY - size * 0.2)
        nvgLineTo(ctx, x + side * size * 0.66, centerY - size * 0.08)
        nvgStrokeWidth(ctx, 2.4 * scale)
        StrokeColor(ctx, color, 245)
        nvgStroke(ctx)
    end
    DrawEyes(ctx, x, centerY + size * 0.12, scale, size * 0.11, { 188, 130, 232 })
end

local function DrawSap(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.55
    local shine = nvgRadialGradient(ctx, x - size * 0.17, centerY - size * 0.18, size * 0.04, size * 0.72,
        nvgRGBA(244, 255, 250, 230), nvgRGBA(color[1], color[2], color[3], 205))
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, centerY, size * 0.53, size * 0.42)
    nvgFillPaint(ctx, shine)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 240)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x - size * 0.12, centerY - size * 0.18)
    nvgLineTo(ctx, x + size * 0.03, centerY + size * 0.02)
    nvgLineTo(ctx, x - size * 0.02, centerY + size * 0.2)
    nvgStrokeWidth(ctx, 1.35 * scale)
    StrokeColor(ctx, secondary, 185)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY - size * 0.03, scale, size * 0.12)
end

local function DrawGhost(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.58
    local glow = nvgRadialGradient(ctx, x, centerY, size * 0.28, size * 1.18,
        nvgRGBA(outline[1], outline[2], outline[3], 120), nvgRGBA(outline[1], outline[2], outline[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 1.18)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x - size * 0.45, centerY + size * 0.38)
    nvgBezierTo(ctx, x - size * 0.64, centerY, x - size * 0.38, centerY - size * 0.55, x, centerY - size * 0.48)
    nvgBezierTo(ctx, x + size * 0.48, centerY - size * 0.62, x + size * 0.62, centerY + size * 0.04, x + size * 0.42, centerY + size * 0.42)
    nvgBezierTo(ctx, x + size * 0.16, centerY + size * 0.18, x - size * 0.08, centerY + size * 0.65, x - size * 0.45, centerY + size * 0.38)
    Color(ctx, color, 174)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.2 * scale)
    StrokeColor(ctx, outline, 255)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY - size * 0.03, scale, size * 0.12, secondary)
end

local function DrawStone(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.52
    nvgBeginPath(ctx)
    for index = 0, 5 do
        local angle = math.pi * 0.166 + index * math.pi * 2 / 6
        local px = x + math.cos(angle) * size * 0.48
        local py = centerY + math.sin(angle) * size * 0.45
        if index == 0 then nvgMoveTo(ctx, px, py) else nvgLineTo(ctx, px, py) end
    end
    nvgClosePath(ctx)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 255)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x - size * 0.26, centerY - size * 0.08)
    nvgLineTo(ctx, x + size * 0.24, centerY - size * 0.26)
    nvgStrokeWidth(ctx, 1.3 * scale)
    StrokeColor(ctx, secondary, 170)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY + size * 0.04, scale, size * 0.13, { 255, 255, 255 })
end

local function DrawMushroom(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.54
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size * 0.14, centerY, size * 0.28, size * 0.43, size * 0.08)
    Color(ctx, secondary, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, centerY - size * 0.06, size * 0.55, size * 0.28)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 255)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY + size * 0.17, scale, size * 0.1)
end

local function DrawDandelion(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.66
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, centerY + size * 0.18)
    nvgLineTo(ctx, x, y)
    nvgStrokeWidth(ctx, 2.2 * scale)
    StrokeColor(ctx, secondary, 235)
    nvgStroke(ctx)
    for index = 0, 11 do
        local angle = index * math.pi * 2 / 12
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, centerY)
        nvgLineTo(ctx, x + math.cos(angle) * size * 0.48, centerY + math.sin(angle) * size * 0.42)
        nvgStrokeWidth(ctx, 1.1 * scale)
        StrokeColor(ctx, secondary, 200)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 0.26)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 1.7 * scale)
    StrokeColor(ctx, outline, 250)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY, scale, size * 0.08)
end

local function DrawOrb(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.56
    local glow = nvgRadialGradient(ctx, x, centerY, size * 0.2, size * 1.35,
        nvgRGBA(secondary[1], secondary[2], secondary[3], 165), nvgRGBA(secondary[1], secondary[2], secondary[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 1.25)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 0.43)
    Color(ctx, color, 245)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 250)
    nvgStroke(ctx)
    for index = 0, 7 do
        local angle = index * math.pi * 2 / 8
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + math.cos(angle) * size * 0.67, centerY + math.sin(angle) * size * 0.58, 1.4 * scale)
        Color(ctx, secondary, 210)
        nvgFill(ctx)
    end
end

local function DrawMoss(ctx, x, y, size, scale, color, secondary, outline)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, y - size * 0.08, size * 0.7, size * 0.24)
    Color(ctx, outline, 200)
    nvgFill(ctx)
    for index = 0, 4 do
        local angle = index * math.pi * 2 / 5
        nvgBeginPath(ctx)
        nvgEllipse(ctx, x + math.cos(angle) * size * 0.35, y - size * 0.08 + math.sin(angle) * size * 0.12,
            size * 0.28, size * 0.13)
        Color(ctx, index % 2 == 0 and secondary or color, 235)
        nvgFill(ctx)
    end
end

local function DrawEnemy(ctx, width, height, enemy, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local spec = EnemyConfig[enemy.kind]
    local visual = spec.visual
    local size = 24 * scale
    local pulse = math.sin(time * 7 + enemy.id) * 1.2 * scale

    DrawEnemyMotionTrail(ctx, width, height, enemy)
    DrawEnemyTelegraph(ctx, width, height, enemy, player)
    if enemy.kind ~= "toxic_moss" then
        DrawShadow(ctx, x, y, scale, size * 0.68, 125)
    end

    if enemy.kind == "soot" then
        if sootImageHandle ~= nil and sootImageHandle > 0 then
            DrawSpriteSoot(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawSoot(ctx, x, y + pulse, size, scale, time, visual.primary, visual.secondary)
        end
    elseif enemy.kind == "blue_swarm" then
        DrawBlueSwarm(ctx, x, y + pulse, size, scale, time, visual.primary, visual.secondary)
    elseif enemy.kind == "tree" then
        DrawTree(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary)
    elseif enemy.kind == "sap" then
        DrawSap(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
    elseif enemy.kind == "ghost_a" or enemy.kind == "ghost_b" then
        DrawGhost(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
    elseif enemy.kind == "stone" then
        DrawStone(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
    elseif enemy.kind == "mushroom" then
        DrawMushroom(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
    elseif enemy.kind == "dandelion" then
        DrawDandelion(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
    elseif enemy.kind == "purple_orb" then
        DrawOrb(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
    else
        DrawMoss(ctx, x, y, size, scale, visual.primary, visual.secondary, visual.outline)
    end

    if enemy.kind == "toxic_moss" then
        return
    end
    local healthWidth = size * 1.06
    local healthHeight = 3.5 * scale
    local healthY = y - size * 1.18
    if enemy.kind == "soot" and sootImageHandle ~= nil and sootImageHandle > 0 then
        healthY = y - GetSootSpriteHeight(scale) - 5 * scale
    end
    local healthRatio = math.max(0, enemy.hp / math.max(0.001, enemy.maxHp))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - healthWidth * 0.5, healthY, healthWidth, healthHeight, healthHeight * 0.5)
    Color(ctx, { 28, 21, 43 }, 225)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - healthWidth * 0.5 + scale, healthY + scale,
        math.max(0, (healthWidth - scale * 2) * healthRatio), math.max(1, healthHeight - scale * 2), healthHeight * 0.4)
    Color(ctx, visual.primary, 255)
    nvgFill(ctx)
end

local function DrawProjectile(ctx, width, height, projectile, combo)
    local x, y, scale = Renderer.WorldToScreen(width, height, projectile.x, projectile.y)
    local color = projectile.owner == "player" and { 125, 238, 255 } or { 255, 135, 205 }
    if projectile.owner == "enemy" and projectile.style == "spore" then
        color = { 208, 166, 238 }
    elseif projectile.owner == "enemy" and projectile.style == "seed" then
        color = { 192, 175, 220 }
    end
    if projectile.reflected and combo ~= nil and combo.tier > 0 then
        local tierColors = {
            { 105, 225, 221 },
            { 245, 195, 105 },
            { 255, 126, 161 },
        }
        color = tierColors[math.min(combo.tier, #tierColors)]
    end
    local radius = (5 + projectile.radius * 80) * scale
    if projectile.style == "spore" then
        radius = radius * 1.22
    elseif projectile.style == "seed" then
        radius = radius * 0.82
    end
    local speed = math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy)
    local directionX, directionY = 0, 0
    if speed > 0.0001 then
        directionX, directionY = projectile.vx / speed, projectile.vy / speed
        local tailLength = radius * (projectile.reflected and 5.4 or 3.2)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x - directionX * tailLength, y - directionY * tailLength)
        nvgLineTo(ctx, x, y)
        nvgStrokeWidth(ctx, projectile.reflected and radius * 0.9 or radius * 0.55)
        StrokeColor(ctx, color, projectile.reflected and 130 or 80)
        nvgStroke(ctx)
    end

    if projectile.reflected then
        local glow = nvgRadialGradient(ctx, x, y, radius * 0.18, radius * 3.3,
            nvgRGBA(color[1], color[2], color[3], 185), nvgRGBA(color[1], color[2], color[3], 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 3.3)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)
    end

    if projectile.turnTimer ~= nil and projectile.turnTimer > 0 and projectile.turnDuration > 0 and speed > 0.0001 then
        local turnRatio = Clamp(projectile.turnTimer / projectile.turnDuration, 0, 1)
        local fromX = projectile.turnFromX or directionX
        local fromY = projectile.turnFromY or directionY
        local arcRadius = radius * (3.2 + turnRatio * 1.6)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x - fromX * arcRadius, y - fromY * arcRadius)
        nvgBezierTo(ctx,
            x - fromX * arcRadius * 0.18, y - fromY * arcRadius * 0.18,
            x + directionX * arcRadius * 0.22, y + directionY * arcRadius * 0.22,
            x + directionX * arcRadius, y + directionY * arcRadius)
        nvgStrokeWidth(ctx, math.max(1, radius * 0.34))
        StrokeColor(ctx, color, math.floor(215 * turnRatio))
        nvgStroke(ctx)
    end

    if projectile.style == "spore" and not projectile.reflected then
        local sporeGlow = nvgRadialGradient(ctx, x, y, radius * 0.2, radius * 2.5,
            nvgRGBA(color[1], color[2], color[3], 150), nvgRGBA(color[1], color[2], color[3], 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 2.5)
        nvgFillPaint(ctx, sporeGlow)
        nvgFill(ctx)
    end
    nvgBeginPath(ctx)
    if projectile.style == "seed" and not projectile.reflected then
        nvgEllipse(ctx, x, y, radius * 0.72, radius)
    else
        nvgCircle(ctx, x, y, radius)
    end
    Color(ctx, color, 255)
    nvgFill(ctx)
    if projectile.reflected then
        nvgBeginPath(ctx)
        nvgCircle(ctx, x - directionX * radius * 0.14, y - directionY * radius * 0.14, radius * 0.42)
        Color(ctx, { 255, 252, 236 }, 245)
        nvgFill(ctx)
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius * 2.05)
    nvgStrokeWidth(ctx, 1.4 * scale)
    StrokeColor(ctx, color, 100)
    nvgStroke(ctx)
end

local function DrawChest(ctx, width, height, chest)
    local x, y, scale = Renderer.WorldToScreen(width, height, chest.x, chest.y)
    y = y + math.sin(chest.bobTime) * 4 * scale
    local size = 14 * scale
    DrawShadow(ctx, x, y, scale, 14, 120)

    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y - size * 0.3, size * 1.5)
    nvgFillColor(ctx, nvgRGBA(255, 212, 95, 45))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size, y - size * 0.78, size * 2, size * 1.2, 3 * scale)
    Color(ctx, { 230, 166, 58 }, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 1.8 * scale)
    StrokeColor(ctx, { 255, 238, 150 }, 255)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size, y - size * 1.1, size * 2, size * 0.48, 3 * scale)
    Color(ctx, { 255, 205, 85 }, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 2 * scale, y - size * 1.08, 4 * scale, size * 1.45)
    Color(ctx, { 95, 57, 35 }, 255)
    nvgFill(ctx)
end

local function DrawParryCone(ctx, width, height, player)
    if player.parryTimer <= 0 then
        return
    end

    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    local facingAngle = math.atan(directionY, directionX)
    local halfAngle = math.acos(Clamp(player.parryHalfAngleCos, -1, 1))
    local x, y = Renderer.WorldToScreen(width, height, player.x, player.y)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    for step = 0, 12 do
        local angle = facingAngle - halfAngle + (halfAngle * 2 * step / 12)
        local worldX = player.x + math.cos(angle) * PlayerConfig.parryRange
        local worldY = player.y + math.sin(angle) * PlayerConfig.parryRange
        local pointX, pointY = Renderer.WorldToScreen(width, height, worldX, worldY)
        nvgLineTo(ctx, pointX, pointY)
    end
    nvgClosePath(ctx)
    Color(ctx, { 110, 235, 255 }, 70)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2)
    StrokeColor(ctx, { 190, 250, 255 }, 220)
    nvgStroke(ctx)
end

local function DrawParticles(ctx, width, height, particles)
    for _, particle in ipairs(particles) do
        local x, y, scale = Renderer.WorldToScreen(width, height, particle.x, particle.y)
        local alpha = math.floor(255 * Clamp(particle.life / particle.maxLife, 0, 1))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, 2.2 * scale)
        Color(ctx, particle.color, alpha)
        nvgFill(ctx)
    end
end

local function DrawFeedbackWorld(ctx, width, height, feedback)
    if feedback == nil then
        return
    end

    for _, impact in ipairs(feedback.impacts) do
        local progress = 1 - Clamp(impact.life / math.max(0.001, impact.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, impact.x, impact.y)
        local radius = Lerp(impact.startRadius, impact.endRadius, math.sqrt(progress)) * scale
        local alpha = math.floor(225 * (1 - progress) * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius)
        nvgStrokeWidth(ctx, math.max(1, impact.stroke * scale * (1 - progress * 0.35)))
        StrokeColor(ctx, impact.color, alpha)
        nvgStroke(ctx)
    end

    for _, shockwave in ipairs(feedback.shockwaves or {}) do
        local progress = 1 - Clamp(shockwave.life / math.max(0.001, shockwave.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, shockwave.x, shockwave.y)
        local radius = Lerp(shockwave.startRadius, shockwave.endRadius, math.sqrt(progress)) * scale
        local alpha = math.floor(200 * (1 - progress) * (1 - progress))
        local glow = nvgRadialGradient(ctx, x, y, radius * 0.20, radius * 1.35,
            nvgRGBA(shockwave.color[1], shockwave.color[2], shockwave.color[3], math.floor(alpha * 0.38)),
            nvgRGBA(shockwave.color[1], shockwave.color[2], shockwave.color[3], 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 1.35)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius)
        nvgStrokeWidth(ctx, math.max(1, shockwave.stroke * scale * (1 - progress * 0.25)))
        StrokeColor(ctx, shockwave.color, alpha)
        nvgStroke(ctx)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, floatingText in ipairs(feedback.floatingTexts) do
        local progress = 1 - Clamp(floatingText.life / math.max(0.001, floatingText.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, floatingText.x, floatingText.y)
        local alpha = math.floor(255 * (1 - progress) * (1 - progress))
        nvgFontSize(ctx, floatingText.size * scale * (1 + 0.18 * (1 - progress)))
        nvgFillColor(ctx, nvgRGBA(8, 8, 18, math.floor(alpha * 0.72)))
        nvgText(ctx, x + scale, y - floatingText.rise * progress * scale + scale, floatingText.text, nil)
        Color(ctx, floatingText.color, alpha)
        nvgText(ctx, x, y - floatingText.rise * progress * scale, floatingText.text, nil)
    end
end

local function DrawFeedbackFlash(ctx, width, height, feedback)
    if feedback == nil or feedback.flash == nil then
        return
    end

    local flash = feedback.flash
    local progress = Clamp(flash.timer / math.max(0.001, flash.maxTimer), 0, 1)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    Color(ctx, flash.color, math.floor(flash.alpha * progress * progress))
    nvgFill(ctx)
end

local function DrawChestPauseDim(ctx, width, height, game)
    if game.state ~= "chest_select" then
        return
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(6, 6, 16, 100))
    nvgFill(ctx)
end

local function IsRoomMapped(game, roomId)
    if game.discoveredRooms[roomId] then
        return true
    end
    if game.room ~= nil then
        for _, targetRoomId in pairs(game.room.connections) do
            if targetRoomId == roomId then
                return true
            end
        end
    end
    return false
end

local function DrawMinimap(ctx, width, height, game)
    if game.room == nil or game.map == nil then
        return
    end

    local minX, maxX, minY, maxY = 0, 0, 0, 0
    for _, room in pairs(game.map.rooms) do
        minX, maxX = math.min(minX, room.mapX), math.max(maxX, room.mapX)
        minY, maxY = math.min(minY, room.mapY), math.max(maxY, room.mapY)
    end

    local cell = Clamp(math.min(width, height) * 0.021, 10, 15)
    local gap = 4
    local step = cell + gap
    local mapWidth = (maxX - minX) * step + cell
    local originX = width * 0.5 - mapWidth * 0.5
    local originY = math.max(10, height * 0.018)

    for _, room in pairs(game.map.rooms) do
        if IsRoomMapped(game, room.id) then
            local x = originX + (room.mapX - minX) * step
            local y = originY + (room.mapY - minY) * step
            for _, targetId in pairs(room.connections) do
                local target = game.map.rooms[targetId]
                if target ~= nil and IsRoomMapped(game, targetId) then
                    local targetX = originX + (target.mapX - minX) * step
                    local targetY = originY + (target.mapY - minY) * step
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, x + cell * 0.5, y + cell * 0.5)
                    nvgLineTo(ctx, targetX + cell * 0.5, targetY + cell * 0.5)
                    nvgStrokeWidth(ctx, 2)
                    StrokeColor(ctx, { 150, 146, 160 }, 105)
                    nvgStroke(ctx)
                end
            end
        end
    end

    for roomId, room in pairs(game.map.rooms) do
        if IsRoomMapped(game, roomId) then
            local x = originX + (room.mapX - minX) * step
            local y = originY + (room.mapY - minY) * step
            local state = game.roomStates[roomId]
            local fill = { 68, 64, 76 }
            local alpha = 145
            if roomId == game.currentRoomId then
                fill, alpha = { 244, 210, 112 }, 255
            elseif state ~= nil and state.cleared then
                fill, alpha = { 112, 196, 151 }, 220
            elseif game.discoveredRooms[roomId] then
                fill, alpha = { 182, 108, 120 }, 220
            end

            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, x, y, cell, cell, 2)
            Color(ctx, fill, alpha)
            nvgFill(ctx)
            if room.boss then
                nvgStrokeWidth(ctx, 2)
                StrokeColor(ctx, { 235, 91, 92 }, 245)
                nvgStroke(ctx)
            end
        end
    end
end

local function GetTransitionOffset(game, width, height)
    local transition = game.transition
    if transition == nil or transition.duration <= 0 then
        return 0, 0
    end

    local progress = Clamp(transition.elapsed / transition.duration, 0, 1)
    local incomingX, incomingY = 0, 0
    if transition.direction == "north" then
        incomingY = -height
    elseif transition.direction == "south" then
        incomingY = height
    elseif transition.direction == "west" then
        incomingX = -width
    else
        incomingX = width
    end

    if not transition.switched then
        local outgoingProgress = math.min(1, progress * 2)
        return -incomingX * outgoingProgress, -incomingY * outgoingProgress
    end

    local incomingProgress = math.min(1, (progress - 0.5) * 2)
    return incomingX * (1 - incomingProgress), incomingY * (1 - incomingProgress)
end

function Renderer.Draw(ctx, game, width, height, feedback)
    DrawBackground(ctx, width, height, game.time)
    local offsetX, offsetY = GetTransitionOffset(game, width, height)
    local shakeX, shakeY = Feedback.GetScreenShake(feedback)
    nvgSave(ctx)
    nvgTranslate(ctx, shakeX, shakeY)
    nvgTranslate(ctx, offsetX, offsetY)
    DrawArena(ctx, width, height, game)
    if game.state == "intro" then
        DrawSpawnMarkers(ctx, width, height, game)
    end

    local boss = nil
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then boss = enemy; break end
    end
    BossRenderer.DrawGround(ctx, width, height, boss, game.player, game.time, Renderer.WorldToScreen, false)

    local drawables = {}
    for _, chest in ipairs(game.chests) do table.insert(drawables, { kind = "chest", value = chest, y = chest.y }) end
    for _, projectile in ipairs(game.projectiles) do table.insert(drawables, { kind = "projectile", value = projectile, y = projectile.y }) end
    for _, enemy in ipairs(game.enemies) do table.insert(drawables, { kind = "enemy", value = enemy, y = enemy.y }) end
    if game.player ~= nil then table.insert(drawables, { kind = "player", value = game.player, y = game.player.y }) end
    table.sort(drawables, function(a, b) return a.y < b.y end)

    for _, drawable in ipairs(drawables) do
        if drawable.kind == "chest" then
            DrawChest(ctx, width, height, drawable.value)
        elseif drawable.kind == "projectile" then
            DrawProjectile(ctx, width, height, drawable.value, game.combo)
        elseif drawable.kind == "enemy" then
            if drawable.value.kind == "boss" then
                BossRenderer.DrawBoss(ctx, width, height, drawable.value, game.time, Renderer.WorldToScreen)
            else
                DrawEnemy(ctx, width, height, drawable.value, game.player, game.time)
            end
        else
            DrawPlayer(ctx, width, height, drawable.value, game.time)
        end
    end

    if game.player ~= nil then
        DrawParryCone(ctx, width, height, game.player)
    end
    DrawParticles(ctx, width, height, game.particles)
    BossRenderer.DrawMechanismTarget(ctx, width, height, boss, game.player, game.time, Renderer.WorldToScreen)
    DrawFeedbackWorld(ctx, width, height, feedback)
    nvgRestore(ctx)

    BossRenderer.DrawFog(ctx, width, height, boss, game.player, Renderer.WorldToScreen)

    DrawFeedbackFlash(ctx, width, height, feedback)
    DrawChestPauseDim(ctx, width, height, game)
    DrawMinimap(ctx, width, height, game)
end

return Renderer
