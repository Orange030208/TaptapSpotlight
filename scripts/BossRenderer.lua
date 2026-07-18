local BossConfig = require "Data.BossConfig"
local EnemyConfig = require "Data.EnemyConfig"
local PlayerConfig = require "Data.PlayerConfig"
local Boss = require "Boss"

local BossRenderer = {}

local BOSS_SPRITE_PATH = "image/boss_hui_an.png"
local bossImageHandle = 0
local bossImageWidth = 1
local bossImageHeight = 1
local bossSpriteLoaded = false

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Fill(ctx, color, alpha)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

local function Stroke(ctx, color, alpha)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

local function WorldPoint(worldToScreen, width, height, x, y)
    return worldToScreen(width, height, x, y)
end

function BossRenderer.LoadAssets(ctx)
    BossRenderer.UnloadAssets(ctx)
    bossImageHandle = nvgCreateImage(ctx, BOSS_SPRITE_PATH, 0)
    if bossImageHandle == nil or bossImageHandle <= 0 then
        bossImageHandle = 0
        bossSpriteLoaded = false
        print("WARNING: Failed to load Boss sprite: " .. BOSS_SPRITE_PATH .. "; using vector fallback")
        return false
    end

    bossImageWidth, bossImageHeight = nvgImageSize(ctx, bossImageHandle)
    if bossImageWidth <= 0 or bossImageHeight <= 0 then
        nvgDeleteImage(ctx, bossImageHandle)
        bossImageHandle = 0
        bossImageWidth, bossImageHeight = 1, 1
        bossSpriteLoaded = false
        print("WARNING: Boss sprite has invalid dimensions; using vector fallback")
        return false
    end

    bossSpriteLoaded = true
    print("Loaded Boss sprite: " .. BOSS_SPRITE_PATH .. " ("
        .. tostring(bossImageWidth) .. "x" .. tostring(bossImageHeight) .. ")")
    return true
end

function BossRenderer.UnloadAssets(ctx)
    if bossImageHandle ~= nil and bossImageHandle > 0 then
        nvgDeleteImage(ctx, bossImageHandle)
    end
    bossImageHandle = 0
    bossImageWidth, bossImageHeight = 1, 1
    bossSpriteLoaded = false
end

local function GetSpriteMotion(boss, time)
    local scaleX, scaleY = 1, 1
    local offsetX, offsetY = 0, 0
    local rotation = 0
    local alpha = 1
    local glow = 0
    local phase = boss.phase == 2 and 1 or 0

    if boss.state == "telegraph" then
        local spec = BossConfig.attacks[boss.attack]
        local progress = Clamp(1 - boss.stateTimer / math.max(0.001, spec.telegraph), 0, 1)
        if boss.attack == "sweep" then
            scaleX = 1 + progress * 0.16
            scaleY = 1 - progress * 0.08
            rotation = -progress * (boss.facing == "left" and -0.10 or 0.10)
        elseif boss.attack == "skewer" then
            scaleX = 1 + progress * 0.22
            scaleY = 1 - progress * 0.10
            rotation = progress * (boss.facing == "left" and -0.06 or 0.06)
        elseif boss.attack == "charge" then
            scaleX = 1 - progress * 0.13
            scaleY = 1 + progress * 0.17
            offsetX = (boss.facing == "left" and 1 or -1) * progress * 5
        elseif boss.attack == "quake" then
            scaleX = 1 + progress * 0.11
            scaleY = 1 - progress * 0.13
            offsetY = progress * 4
        elseif boss.attack == "feathers" then
            scaleX = 1 + progress * 0.08
            scaleY = 1 + progress * 0.08
            offsetY = -progress * 4
            glow = progress
        end
    elseif boss.state == "active" then
        if boss.attack == "charge" then
            scaleX = 1.17
            scaleY = 0.88
            offsetX = boss.vx < 0 and -4 or 4
        elseif boss.attack == "quake" then
            scaleX = 1.08
            scaleY = 0.92
            offsetY = 3
        elseif boss.attack == "feathers" then
            local pulse = boss.featherPulse or 1
            glow = 0.55 + 0.45 * math.sin(time * 30 + pulse)
            scaleX = 1 + glow * 0.05
            scaleY = 1 + glow * 0.05
        end
    elseif boss.state == "recovery" then
        local recovery = Clamp(boss.stateTimer / math.max(0.001, BossConfig.recoveryDuration), 0, 1)
        scaleX = 1 - recovery * 0.06
        scaleY = 1 - recovery * 0.12
        offsetY = recovery * 5
        alpha = 0.72 + (1 - recovery) * 0.28
    elseif boss.state == "phase_transition" then
        local progress = Clamp(1 - boss.stateTimer / BossConfig.phaseTransitionDuration, 0, 1)
        scaleX = 1 + progress * 0.25
        scaleY = 1 + progress * 0.25
        offsetY = -progress * 8
        glow = progress
        alpha = 0.85 + progress * 0.15
    elseif boss.state == "purifying" then
        local progress = Clamp(boss.purificationProgress or 0, 0, 1)
        scaleX = 1 - progress * 0.45
        scaleY = 1 - progress * 0.45
        offsetY = -progress * 12
        glow = progress
        alpha = 1 - progress * 0.35
    end

    local bob = math.sin(time * (boss.state == "active" and 7 or 4) + (boss.id or 0))
    offsetY = offsetY + bob * (boss.state == "idle" and 2.5 or 1.2)
    if phase == 1 then glow = math.max(glow, 0.35 + 0.2 * math.sin(time * 5)) end
    return scaleX, scaleY, offsetX, offsetY, rotation, alpha, glow
end

local function DrawBossSprite(ctx, x, y, boss, time, scale)
    local scaleX, scaleY, offsetX, offsetY, rotation, alpha, glow = GetSpriteMotion(boss, time)
    local displayHeight = 138 * scale
    local displayWidth = displayHeight * bossImageWidth / bossImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local flip = boss.facing == "left" and -1 or 1

    if glow > 0.01 then
        local radius = math.max(displayWidth, displayHeight) * (0.62 + glow * 0.18)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + offsetX, y - displayHeight * 0.52 + offsetY, radius)
        nvgFillPaint(ctx, nvgRadialGradient(ctx, x + offsetX, y - displayHeight * 0.52 + offsetY,
            radius * 0.16, radius, nvgRGBA(132, 214, 255, math.floor(70 + glow * 100)), nvgRGBA(38, 20, 70, 0)))
        nvgFill(ctx)
    end

    nvgSave(ctx)
    nvgTranslate(ctx, x + offsetX, y + offsetY)
    nvgRotate(ctx, rotation)
    nvgScale(ctx, flip * scaleX, scaleY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePatternTinted(ctx, drawX, drawY, displayWidth, displayHeight, 0,
        bossImageHandle, nvgRGBA(255, 255, 255, math.floor(alpha * 255))))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function BuildSectorPath(ctx, centerX, centerY, radiusX, radiusY, startAngle, arcRadians)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, centerX, centerY)
    for step = 0, 28 do
        local angle = startAngle + arcRadians * step / 28
        nvgLineTo(ctx, centerX + math.cos(angle) * radiusX, centerY + math.sin(angle) * radiusY)
    end
    nvgClosePath(ctx)
end

local function DrawSector(ctx, width, height, boss, range, arc, reverse, worldToScreen, alpha, debug, progress)
    local facingX = boss.facing == "left" and -1 or 1
    if reverse then facingX = facingX * -1 end
    local centerX, centerY = WorldPoint(worldToScreen, width, height, boss.x, boss.y)
    local attackRange = range + PlayerConfig.radius
    local edgeX = WorldPoint(worldToScreen, width, height, boss.x + facingX * attackRange, boss.y)
    local radiusX = math.abs(edgeX - centerX)
    local _, verticalY = WorldPoint(worldToScreen, width, height, boss.x, boss.y + attackRange)
    local radiusY = math.abs(verticalY - centerY)
    local half = math.rad(arc * 0.5)
    local startAngle = facingX < 0 and math.pi - half or -half
    local arcRadians = math.rad(arc)

    BuildSectorPath(ctx, centerX, centerY, radiusX, radiusY, startAngle, arcRadians)
    Fill(ctx, debug and { 255, 80, 95 } or { 255, 126, 92 }, alpha)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, debug and 2 or 1.4)
    Stroke(ctx, debug and { 255, 235, 120 } or { 255, 186, 118 }, math.min(255, alpha + 95))
    nvgStroke(ctx)

    if progress > 0 then
        BuildSectorPath(ctx, centerX, centerY, radiusX * progress, radiusY * progress, startAngle, arcRadians)
        Fill(ctx, debug and { 255, 80, 95 } or { 255, 126, 92 }, math.min(150, alpha + 70))
        nvgFill(ctx)
    end
end

local function DrawSkewer(ctx, width, height, boss, worldToScreen, alpha, debug, progress)
    local spec = BossConfig.attacks.skewer
    local facingX = boss.facing == "left" and -1 or 1
    local centerX, centerY = WorldPoint(worldToScreen, width, height, boss.x, boss.y)
    local attackLength = spec.length + PlayerConfig.radius
    local attackHalfWidth = spec.halfWidth + PlayerConfig.radius
    local edgeX = WorldPoint(worldToScreen, width, height, boss.x + facingX * attackLength, boss.y)
    local _, topY = WorldPoint(worldToScreen, width, height, boss.x, boss.y - attackHalfWidth)
    local _, bottomY = WorldPoint(worldToScreen, width, height, boss.x, boss.y + attackHalfWidth)
    local halfLength = math.abs(edgeX - centerX)
    local halfWidth = math.abs(bottomY - topY) * 0.5
    local left = centerX - halfLength
    local top = centerY - halfWidth
    local totalWidth = halfLength * 2
    local totalHeight = halfWidth * 2
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, left, top, totalWidth, totalHeight, math.min(5, halfWidth))
    Fill(ctx, debug and { 255, 80, 95 } or { 225, 102, 148 }, alpha)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, debug and 2 or 1.4)
    Stroke(ctx, { 255, 215, 130 }, math.min(255, alpha + 100))
    nvgStroke(ctx)

    if progress > 0 then
        local fillWidth = totalWidth * progress
        local fillLeft = facingX < 0 and left + totalWidth - fillWidth or left
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, fillLeft, top, fillWidth, totalHeight, math.min(5, halfWidth))
        Fill(ctx, { 225, 102, 148 }, math.min(150, alpha + 70))
        nvgFill(ctx)
    end
end

local function DrawAttackRegion(ctx, width, height, boss, worldToScreen, debug)
    if boss.state ~= "telegraph" and boss.state ~= "active" then return end
    local spec = BossConfig.attacks[boss.attack]
    local progress = boss.state == "telegraph" and Clamp(1 - boss.stateTimer / math.max(0.001, spec.telegraph), 0, 1) or 1
    local alpha = boss.state == "telegraph" and (debug and 58 or 34) or (debug and 86 or 48)
    if boss.attack == "sweep" then
        DrawSector(ctx, width, height, boss, BossConfig.attacks.sweep.range, 180, false, worldToScreen, alpha, debug, progress)
    elseif boss.attack == "skewer" then
        DrawSkewer(ctx, width, height, boss, worldToScreen, alpha, debug, progress)
    elseif boss.attack == "charge" then
        local x, y = WorldPoint(worldToScreen, width, height, boss.x, boss.y)
        local hitRadius = BossConfig.attacks.charge.hitRadius + boss.radius
        local edgeX = WorldPoint(worldToScreen, width, height, boss.x + hitRadius, boss.y)
        local _, edgeY = WorldPoint(worldToScreen, width, height, boss.x, boss.y + hitRadius)
        local radiusX = math.abs(edgeX - x)
        local radiusY = math.abs(edgeY - y)
        local radius = math.max(radiusX, radiusY)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius)
        Fill(ctx, { 255, 92, 126 }, alpha)
        nvgFill(ctx)
        nvgStrokeWidth(ctx, debug and 2 or 1.5)
        Stroke(ctx, { 255, 220, 120 }, math.min(255, alpha + 110))
        nvgStroke(ctx)
        if progress > 0 then
            nvgBeginPath(ctx)
            nvgCircle(ctx, x, y, radius * progress)
            Fill(ctx, { 255, 92, 126 }, math.min(150, alpha + 70))
            nvgFill(ctx)
        end
    elseif boss.attack == "quake" then
        DrawSector(ctx, width, height, boss, BossConfig.attacks.quake.range, 270, false, worldToScreen, alpha, debug, progress)
    elseif boss.attack == "feathers" then
        local reverse = boss.state == "telegraph" or boss.featherPulse <= 4
        DrawSector(ctx, width, height, boss, BossConfig.attacks.feathers.range, BossConfig.attacks.feathers.arc, reverse, worldToScreen, alpha, debug, progress)
    end
end

local function DrawThornRegion(ctx, width, height, thorn, worldToScreen, debug)
    if thorn == nil or (thorn.state ~= "telegraph" and thorn.state ~= "active") then return end
    local spec = BossConfig.mechanisms.thorns
    local startX = thorn.direction < 0 and thorn.x - spec.reach or thorn.x
    local endX = thorn.direction < 0 and thorn.x or thorn.x + spec.reach
    local left, top = WorldPoint(worldToScreen, width, height, startX, thorn.y - spec.halfWidth)
    local right, bottom = WorldPoint(worldToScreen, width, height, endX, thorn.y + spec.halfWidth)
    local alpha = thorn.state == "active" and 100 or 42
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, left, top, right - left, bottom - top, 5)
    Fill(ctx, debug and { 255, 75, 95 } or { 126, 32, 84 }, alpha)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, thorn.state == "active" and 2.5 or 1.4)
    Stroke(ctx, { 235, 88, 148 }, thorn.state == "active" and 245 or 155)
    nvgStroke(ctx)
end

function BossRenderer.DrawGround(ctx, width, height, boss, player, time, worldToScreen, debug)
    if boss == nil then return end
    DrawAttackRegion(ctx, width, height, boss, worldToScreen, debug)
    DrawThornRegion(ctx, width, height, boss.thorn, worldToScreen, debug)

    if boss.thorn ~= nil then
        local x, y, scale = WorldPoint(worldToScreen, width, height, boss.thorn.x, boss.thorn.y)
        local pulse = 1 + math.sin(time * 7) * 0.08
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, 18 * scale * pulse)
        Fill(ctx, { 80, 20, 62 }, 115)
        nvgFill(ctx)
        nvgStrokeWidth(ctx, 2 * scale)
        Stroke(ctx, { 220, 68, 136 }, 225)
        nvgStroke(ctx)
        for index = -2, 2 do
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, x + index * 5 * scale, y + 10 * scale)
            nvgLineTo(ctx, x + index * 7 * scale, y - (18 + math.abs(index) * 3) * scale)
            nvgLineTo(ctx, x + (index + 0.55) * 5 * scale, y - 9 * scale)
            nvgStrokeWidth(ctx, 2.2 * scale)
            Stroke(ctx, { 170, 42, 104 }, 245)
            nvgStroke(ctx)
        end
    end
end

local function DrawWing(ctx, side, size, lift, cross, color, outline)
    local baseX = side * size * 0.23
    local tipX = side * size * (0.95 - cross * 0.45)
    local tipY = -size * (0.34 + lift * 0.75) + cross * size * 0.20
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, baseX, -size * 0.47)
    nvgBezierTo(ctx, side * size * 0.55, -size * 0.62, tipX, tipY, tipX, tipY + size * 0.18)
    nvgLineTo(ctx, side * size * (0.58 - cross * 0.28), -size * 0.06 + cross * size * 0.18)
    nvgLineTo(ctx, baseX, -size * 0.18)
    nvgClosePath(ctx)
    Fill(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.2)
    Stroke(ctx, outline, 240)
    nvgStroke(ctx)
end

function BossRenderer.DrawBoss(ctx, width, height, boss, time, worldToScreen)
    local x, y, scale = WorldPoint(worldToScreen, width, height, boss.x, boss.y)
    if bossSpriteLoaded then
        DrawBossSprite(ctx, x, y, boss, time, scale)
        return
    end

    local purifiedScale = boss.state == "purifying" and (1 - 0.45 * boss.purificationProgress) or 1
    local size = 48 * scale * EnemyConfig.sizeMultiplier * purifiedScale
    local phaseTwo = boss.phase == 2
    local body = phaseTwo and { 34, 112, 116 } or { 20, 19, 28 }
    local wing = phaseTwo and { 178, 69, 92 } or { 26, 23, 34 }
    local chest = phaseTwo and { 184, 146, 72 } or { 34, 31, 43 }
    if boss.state == "purifying" then
        local p = boss.purificationProgress
        body = { math.floor(34 + 92 * p), math.floor(112 + 92 * p), math.floor(116 + 82 * p) }
        wing = { math.floor(178 + 50 * p), math.floor(69 + 93 * p), math.floor(92 + 70 * p) }
        chest = { math.floor(184 + 55 * p), math.floor(146 + 70 * p), math.floor(72 + 92 * p) }
    end

    local lift, cross, squat, airborne, headRaise = 0, 0, 0, 0, 0
    if boss.state == "telegraph" then
        if boss.attack == "sweep" then lift = 1 end
        if boss.attack == "skewer" then cross = 1 end
        if boss.attack == "charge" then airborne = 1 end
        if boss.attack == "quake" then squat = 1 end
        if boss.attack == "feathers" then headRaise = 1 end
    end
    local bob = math.sin(time * 4 + boss.id) * 2 * scale
    y = y - airborne * 18 * scale + bob + squat * 9 * scale

    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    if boss.facing == "left" then nvgScale(ctx, -1, 1) end

    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, 4 * scale, size * 0.62, size * 0.20)
    Fill(ctx, { 9, 8, 15 }, airborne > 0 and 70 or 125)
    nvgFill(ctx)

    DrawWing(ctx, -1, size, lift, cross, wing, { 12, 11, 19 })
    DrawWing(ctx, 1, size, lift, cross, wing, { 12, 11, 19 })

    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, -size * (0.32 - squat * 0.12), size * 0.42, size * (0.58 - squat * 0.14))
    Fill(ctx, body, boss.state == "recovery" and 190 or 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.5 * scale)
    Stroke(ctx, { 10, 9, 17 }, 250)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, -size * 0.27, size * 0.25, size * 0.35)
    Fill(ctx, chest, phaseTwo and 220 or 105)
    nvgFill(ctx)

    local headY = -size * (0.83 + headRaise * 0.13)
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, headY, size * 0.30)
    Fill(ctx, body, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.2 * scale)
    Stroke(ctx, { 9, 8, 15 }, 250)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, size * 0.18, headY - size * 0.03)
    nvgLineTo(ctx, size * 0.57, headY + size * 0.08)
    nvgLineTo(ctx, size * 0.18, headY + size * 0.16)
    nvgClosePath(ctx)
    Fill(ctx, phaseTwo and { 226, 159, 70 } or { 48, 42, 54 }, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 1.8 * scale)
    Stroke(ctx, { 15, 12, 20 }, 245)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, size * 0.09, headY - size * 0.06, 3.8 * scale)
    Fill(ctx, phaseTwo and { 129, 245, 226 } or { 216, 220, 205 }, 255)
    nvgFill(ctx)

    if phaseTwo and boss.mechanism == "metal" then
        local pull = Clamp(boss.metalProgress / BossConfig.mechanisms.metal.required, 0, 1)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, -size * 0.34, -size * 0.70)
        nvgLineTo(ctx, -size * (0.64 + pull * 0.22), -size * (0.88 + pull * 0.06))
        nvgStrokeWidth(ctx, 7 * scale)
        Stroke(ctx, { 20, 21, 27 }, 255)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, -size * (0.64 + pull * 0.22), -size * (0.88 + pull * 0.06), 5 * scale)
        Fill(ctx, { 226, 90, 126 }, 235)
        nvgFill(ctx)
    end

    if not phaseTwo then
        for index = 1, 4 do
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, -size * 0.38, -size * (0.12 + index * 0.18))
            nvgBezierTo(ctx, -size * 0.68, -size * index * 0.13, -size * 0.58, size * 0.18, -size * 0.83, size * 0.22)
            nvgStrokeWidth(ctx, (5 - index) * scale)
            Stroke(ctx, { 9, 8, 16 }, 145)
            nvgStroke(ctx)
        end
    end
    nvgRestore(ctx)
end

function BossRenderer.DrawMechanismTarget(ctx, width, height, boss, player, time, worldToScreen)
    if boss == nil or player == nil or boss.phase ~= 2 or boss.mechanismTransition > 0 then return end
    if boss.mechanism == "fog" then
        local targetX, targetY = Boss.GetMechanismTarget(boss, player)
        local x, y, scale = WorldPoint(worldToScreen, width, height, targetX, targetY)
        local radius = (10 + math.sin(time * 8) * 2) * scale
        local glow = nvgRadialGradient(ctx, x, y, radius * 0.2, radius * 2.6,
            nvgRGBA(200, 225, 232, 210), nvgRGBA(55, 42, 75, 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 2.6)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius)
        Fill(ctx, { 70, 60, 92 }, 245)
        nvgFill(ctx)
        nvgStrokeWidth(ctx, 2 * scale)
        Stroke(ctx, { 218, 230, 225 }, 235)
        nvgStroke(ctx)
    end
end

function BossRenderer.DrawFog(ctx, width, height, boss, player, worldToScreen)
    if boss == nil or player == nil or boss.phase ~= 2 or boss.mechanism ~= "fog" then return end
    local alphaSteps = { 230, 155, 80, 0 }
    local alpha = alphaSteps[Clamp(boss.mechanismProgress + 1, 1, 4)]
    if alpha <= 0 then return end
    local x, y = WorldPoint(worldToScreen, width, height, player.x, player.y)
    local screenScale = math.min(width, height)
    local radius = screenScale * (BossConfig.mechanisms.fog.lightRadius + boss.mechanismProgress * 0.035)
    local fog = nvgRadialGradient(ctx, x, y, radius * 0.55, radius * 1.65,
        nvgRGBA(8, 8, 15, 0), nvgRGBA(7, 6, 13, alpha))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, fog)
    nvgFill(ctx)
end

return BossRenderer
