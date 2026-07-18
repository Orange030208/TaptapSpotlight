local GaugeConfig = require "Data.GaugeConfig"
local PlayerConfig = require "Data.PlayerConfig"
local Feedback = require "Feedback"
local BossRenderer = require "BossRenderer"

local Renderer = {}
local playerImageHandle = 0
local playerImageWidth = 1
local playerImageHeight = 1

function Renderer.LoadAssets(ctx)
    playerImageHandle = nvgCreateImage(ctx, "Characters/player.png", 0)
    if playerImageHandle == nil or playerImageHandle <= 0 then
        playerImageHandle = 0
        print("WARNING: Failed to load player sprite: Characters/player.png; using vector fallback")
        return false
    end

    playerImageWidth, playerImageHeight = nvgImageSize(ctx, playerImageHandle)
    if playerImageWidth <= 0 or playerImageHeight <= 0 then
        nvgDeleteImage(ctx, playerImageHandle)
        playerImageHandle = 0
        playerImageWidth, playerImageHeight = 1, 1
        print("WARNING: Player sprite has invalid dimensions; using vector fallback")
        return false
    end

    print("Loaded player sprite: " .. tostring(playerImageWidth) .. "x" .. tostring(playerImageHeight))
    return true
end

function Renderer.UnloadAssets(ctx)
    if playerImageHandle ~= nil and playerImageHandle > 0 then
        nvgDeleteImage(ctx, playerImageHandle)
    end
    playerImageHandle = 0
    playerImageWidth, playerImageHeight = 1, 1
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
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

local function DrawPlayer(ctx, width, height, player, time)
    if playerImageHandle ~= nil and playerImageHandle > 0 then
        DrawSpritePlayer(ctx, width, height, player, time)
    else
        DrawFallbackPlayer(ctx, width, height, player, time)
    end
end

local function EnemyColor(kind)
    if kind == "melee" then
        return { 255, 105, 130 }
    elseif kind == "ranged" then
        return { 185, 125, 255 }
    end
    return { 255, 145, 74 }
end

local function DrawEnemyTelegraph(ctx, width, height, enemy, player)
    if enemy.state ~= "telegraph" then
        return
    end
    local x, y, scale = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local radius = (enemy.radius * 180 + 6) * scale
    local pulse = 120 + math.floor(100 * math.abs(math.sin(enemy.stateTimer * 13)))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, { 255, 230, 120 }, pulse)
    nvgStroke(ctx)

    if player ~= nil then
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

local function DrawEnemy(ctx, width, height, enemy, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local color = EnemyColor(enemy.kind)
    local size = (enemy.kind == "boss" and 34 or 22) * scale
    local pulse = math.sin(time * 7 + enemy.id) * 1.4 * scale

    DrawEnemyMotionTrail(ctx, width, height, enemy)
    DrawEnemyTelegraph(ctx, width, height, enemy, player)
    DrawShadow(ctx, x, y, scale, size * 0.68, 130)

    nvgBeginPath(ctx)
    if enemy.kind == "ranged" then
        nvgCircle(ctx, x, y - size * 0.46 + pulse, size * 0.52)
    else
        nvgRoundedRect(ctx, x - size * 0.5, y - size + pulse, size, size, size * 0.25)
    end
    Color(ctx, color, enemy.state == "recovery" and 135 or 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, { 35, 20, 55 }, 230)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, x - size * 0.17, y - size * 0.57 + pulse, 3.2 * scale)
    nvgCircle(ctx, x + size * 0.17, y - size * 0.57 + pulse, 3.2 * scale)
    Color(ctx, { 255, 247, 225 }, 255)
    nvgFill(ctx)

    local healthWidth = enemy.kind == "boss" and size * 1.32 or size * 1.06
    local healthHeight = enemy.kind == "boss" and 5 * scale or 3.5 * scale
    local healthY = y - size * (enemy.kind == "boss" and 1.36 or 1.18)
    local healthRatio = math.max(0, enemy.hp / math.max(0.001, enemy.maxHp))

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - healthWidth * 0.5, healthY, healthWidth, healthHeight, healthHeight * 0.5)
    Color(ctx, { 28, 21, 43 }, 225)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - healthWidth * 0.5 + scale, healthY + scale,
        math.max(0, (healthWidth - scale * 2) * healthRatio), math.max(1, healthHeight - scale * 2), healthHeight * 0.4)
    Color(ctx, enemy.kind == "boss" and { 255, 120, 74 } or color, 255)
    nvgFill(ctx)
end

local function DrawProjectile(ctx, width, height, projectile)
    local x, y, scale = Renderer.WorldToScreen(width, height, projectile.x, projectile.y)
    local color = projectile.owner == "player" and { 125, 238, 255 } or { 255, 135, 205 }
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, (5 + projectile.radius * 80) * scale)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, (10 + projectile.radius * 110) * scale)
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

    local facingAngle = player.facing == "left" and math.pi or 0
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

local function DrawGauge(ctx, x, y, width, height, gauge, definition)
    local ratio = Clamp(gauge.value / gauge.threshold, 0, 1)
    local pulse = gauge.pulse
    local fillWidth = math.max(0, (width - 4) * ratio)
    local label = definition.label .. "  " .. string.format("%d/%d", math.floor(gauge.value + 0.001), gauge.threshold)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    nvgFillColor(ctx, nvgRGBA(235, 240, 255, 230))
    nvgText(ctx, x, y - 4, label, nil)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, width, height, height * 0.5)
    Color(ctx, { 18, 16, 31 }, 225)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, pulse > 0 and 2.4 or 1.2)
    StrokeColor(ctx, definition.color, pulse > 0 and 255 or 155)
    nvgStroke(ctx)

    if fillWidth > 0 then
        local fill = nvgLinearGradient(ctx, x, y, x + width, y,
            nvgRGBA(definition.color[1], definition.color[2], definition.color[3], 245),
            nvgRGBA(255, 247, 220, pulse > 0 and 255 or 190))
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 2, y + 2, fillWidth, math.max(1, height - 4), math.max(1, (height - 4) * 0.5))
        nvgFillPaint(ctx, fill)
        nvgFill(ctx)
    end
end

local function DrawGaugeBar(ctx, width, height, game)
    if game.state == "menu" or game.state == "dead" or game.state == "victory" then
        return
    end

    local gauge = game.gauge
    local barHeight = Clamp(height * 0.017, 8, 12)
    local barWidth = math.min(520, width * 0.78)
    local x = (width - barWidth) * 0.5
    local y = height * 0.895
    DrawGauge(ctx, x, y, barWidth, barHeight, gauge, GaugeConfig)
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

local function DrawDebug(ctx, width, height, game)
    if not game.debug or game.room == nil then
        return
    end

    DrawSpawnMarkers(ctx, width, height, game)
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 13)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(225, 235, 255, 230))
    nvgText(ctx, 14, 14, string.format("状态=%s 敌人=%d 投射物=%d 宝箱=%d", game.state, #game.enemies, #game.projectiles, #game.chests), nil)
end

local function DrawOverlay(ctx, width, height, game)
    if game.state ~= "menu" and game.state ~= "dead" and game.state ~= "victory" then
        return
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(8, 8, 20, 155))
    nvgFill(ctx)

    local title = game.state == "menu" and "弹反之室" or (game.state == "victory" and "诅咒消散" or "本局失败")
    local subtitle = game.state == "menu" and "WASD 移动  •  空格招架  •  回车开始"
        or (game.state == "victory" and "晦暗低鸣已获净化 · 按 R 重新开始" or "按 R 回到第一间房")
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, math.min(52, width * 0.065))
    nvgFillColor(ctx, nvgRGBA(240, 246, 255, 255))
    nvgText(ctx, width * 0.5, height * 0.44, title, nil)
    nvgFontSize(ctx, math.min(20, width * 0.027))
    nvgFillColor(ctx, nvgRGBA(165, 220, 255, 245))
    nvgText(ctx, width * 0.5, height * 0.53, subtitle, nil)
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

local function DrawMessage(ctx, width, height, game)
    if game.message == nil or game.message == "" or game.state == "menu" or game.state == "dead" or game.state == "victory" or game.state == "chest_select" then
        return
    end

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, math.min(24, width * 0.032))
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(244, 241, 255, 245))
    local hasBoss = false
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then hasBoss = true; break end
    end
    nvgText(ctx, width * 0.5, height * (hasBoss and 0.17 or 0.11), game.message, nil)
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
    BossRenderer.DrawGround(ctx, width, height, boss, game.player, game.time, Renderer.WorldToScreen, game.debug)

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
            DrawProjectile(ctx, width, height, drawable.value)
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
    DrawDebug(ctx, width, height, game)
    nvgRestore(ctx)

    BossRenderer.DrawFog(ctx, width, height, boss, game.player, Renderer.WorldToScreen)

    DrawFeedbackFlash(ctx, width, height, feedback)
    DrawChestPauseDim(ctx, width, height, game)
    DrawGaugeBar(ctx, width, height, game)
    DrawMinimap(ctx, width, height, game)
    DrawMessage(ctx, width, height, game)
    DrawOverlay(ctx, width, height, game)
end

return Renderer
