local Config = require "Config"

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
    return {
        backLeft = width * 0.22,
        backRight = width * 0.78,
        frontLeft = width * 0.06,
        frontRight = width * 0.94,
        backY = height * 0.18,
        frontY = height * 0.87,
    }
end

function Renderer.WorldToScreen(width, height, x, y)
    local arena = Renderer.GetArena(width, height)
    local left = Lerp(arena.backLeft, arena.frontLeft, y)
    local right = Lerp(arena.backRight, arena.frontRight, y)
    return Lerp(left, right, x), Lerp(arena.backY, arena.frontY, y), Lerp(0.55, 1.16, y)
end

local function DrawBackground(ctx, width, height, time)
    local gradient = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(19, 21, 40, 255), nvgRGBA(44, 18, 48, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)

    for index = 1, 18 do
        local x = (index * 97) % width
        local y = 20 + ((index * 61) % math.max(1, math.floor(height * 0.65)))
        local pulse = 100 + math.floor(65 * math.sin(time * 1.4 + index))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, 1 + (index % 3))
        nvgFillColor(ctx, nvgRGBA(135, 165, 255, pulse))
        nvgFill(ctx)
    end
end

local function DrawArena(ctx, width, height, state)
    local arena = Renderer.GetArena(width, height)
    local floorGradient = nvgLinearGradient(ctx, 0, arena.backY, 0, arena.frontY,
        nvgRGBA(65, 55, 88, 255), nvgRGBA(29, 26, 52, 255))

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, arena.backLeft, arena.backY)
    nvgLineTo(ctx, arena.backRight, arena.backY)
    nvgLineTo(ctx, arena.frontRight, arena.frontY)
    nvgLineTo(ctx, arena.frontLeft, arena.frontY)
    nvgClosePath(ctx)
    nvgFillPaint(ctx, floorGradient)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, arena.backLeft, arena.backY)
    nvgLineTo(ctx, arena.backRight, arena.backY)
    nvgLineTo(ctx, arena.frontRight, arena.frontY)
    nvgLineTo(ctx, arena.frontLeft, arena.frontY)
    nvgClosePath(ctx)
    nvgStrokeWidth(ctx, 3)
    StrokeColor(ctx, state == "battle" and { 173, 126, 245 } or { 110, 135, 190 }, 230)
    nvgStroke(ctx)

    for row = 1, 7 do
        local y = row / 8
        local left = Lerp(arena.backLeft, arena.frontLeft, y)
        local right = Lerp(arena.backRight, arena.frontRight, y)
        local screenY = Lerp(arena.backY, arena.frontY, y)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, screenY)
        nvgLineTo(ctx, right, screenY)
        nvgStrokeWidth(ctx, 1)
        StrokeColor(ctx, { 180, 155, 255 }, 35)
        nvgStroke(ctx)
    end

    local doorColor = state == "clear" and { 95, 235, 165 } or { 255, 105, 130 }
    local doorX = (arena.backLeft + arena.backRight) * 0.5
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, doorX - 34, arena.backY - 9, 68, 18, 5)
    Color(ctx, doorColor, 210)
    nvgFill(ctx)
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

    if enemy.kind == "boss" then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x - size * 0.66, y - size * 1.36, size * 1.32, 5 * scale, 2 * scale)
        Color(ctx, { 36, 22, 56 }, 220)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x - size * 0.62, y - size * 1.32, size * 1.24 * math.max(0, enemy.hp / Config.Enemy.boss.hp), 2.5 * scale, 1 * scale)
        Color(ctx, { 255, 120, 74 }, 255)
        nvgFill(ctx)
    end
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
        local worldX = player.x + math.cos(angle) * Config.Player.parryRange
        local worldY = player.y + math.sin(angle) * Config.Player.parryRange
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

    local title = game.state == "menu" and "弹反之室" or (game.state == "victory" and "成功逃离" or "本局失败")
    local subtitle = game.state == "menu" and "WASD 移动  •  空格招架  •  回车开始" or "按 R 回到第一间房"
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
    if game.message == nil or game.message == "" or game.state == "menu" or game.state == "dead" or game.state == "victory" then
        return
    end

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, math.min(24, width * 0.032))
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(244, 241, 255, 245))
    nvgText(ctx, width * 0.5, height * 0.11, game.message, nil)
end

function Renderer.Draw(ctx, game, width, height)
    DrawBackground(ctx, width, height, game.time)
    DrawArena(ctx, width, height, game.state)
    if game.state == "intro" then
        DrawSpawnMarkers(ctx, width, height, game)
    end

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
            DrawEnemy(ctx, width, height, drawable.value, game.player, game.time)
        else
            DrawPlayer(ctx, width, height, drawable.value, game.time)
        end
    end

    if game.player ~= nil then
        DrawParryCone(ctx, width, height, game.player)
    end
    DrawParticles(ctx, width, height, game.particles)
    DrawChestPauseDim(ctx, width, height, game)
    DrawMessage(ctx, width, height, game)
    DrawDebug(ctx, width, height, game)
    DrawOverlay(ctx, width, height, game)
end

return Renderer
