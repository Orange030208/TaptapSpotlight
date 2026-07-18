local CrystalConfig = require "Data.CrystalConfig"
local Renderer = require "Renderer"

local CrystalRenderer = {}

local elapsed = 0
local pendingAcquisitions = {}
local acquireAnimations = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Color(ctx, color, alpha)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

local function StrokeColor(ctx, color, alpha)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

local function FindDefinition(id)
    for _, definition in ipairs(CrystalConfig.definitions) do
        if definition.id == id then
            return definition
        end
    end
    return nil
end

local function DrawDiamond(ctx, x, y, radius, color, alpha)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y - radius)
    nvgLineTo(ctx, x + radius * 0.72, y)
    nvgLineTo(ctx, x, y + radius)
    nvgLineTo(ctx, x - radius * 0.72, y)
    nvgClosePath(ctx)
    Color(ctx, color, alpha)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, math.max(1, radius * 0.1))
    StrokeColor(ctx, { 255, 252, 238 }, math.floor((alpha or 255) * 0.72))
    nvgStroke(ctx)
end

local function DrawCrystalGlyph(ctx, definition, x, y, size, alpha)
    local color = definition.color
    local radius = size * 0.27
    local opacity = alpha or 255
    if definition.iconKind == "dash" then
        DrawDiamond(ctx, x - size * 0.13, y, radius, color, opacity)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x - size * 0.03, y - size * 0.18)
        nvgLineTo(ctx, x + size * 0.34, y)
        nvgLineTo(ctx, x - size * 0.03, y + size * 0.18)
        nvgStrokeWidth(ctx, math.max(2, size * 0.12))
        StrokeColor(ctx, color, opacity)
        nvgStroke(ctx)
    elseif definition.iconKind == "split" then
        DrawDiamond(ctx, x - size * 0.08, y, radius, color, opacity)
        for _, offset in ipairs({ -0.22, 0.22 }) do
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, x + size * 0.05, y)
            nvgLineTo(ctx, x + size * 0.38, y + offset * size)
            nvgStrokeWidth(ctx, math.max(1.5, size * 0.075))
            StrokeColor(ctx, color, opacity)
            nvgStroke(ctx)
        end
    elseif definition.iconKind == "lightning" then
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x - size * 0.08, y - size * 0.38)
        nvgLineTo(ctx, x + size * 0.12, y - size * 0.08)
        nvgLineTo(ctx, x, y - size * 0.08)
        nvgLineTo(ctx, x + size * 0.10, y + size * 0.34)
        nvgLineTo(ctx, x - size * 0.15, y + size * 0.04)
        nvgLineTo(ctx, x - size * 0.02, y + size * 0.04)
        nvgClosePath(ctx)
        Color(ctx, color, opacity)
        nvgFill(ctx)
    elseif definition.iconKind == "orbit" then
        nvgBeginPath(ctx)
        nvgEllipse(ctx, x, y, size * 0.35, size * 0.16)
        nvgStrokeWidth(ctx, math.max(1.5, size * 0.065))
        StrokeColor(ctx, color, opacity)
        nvgStroke(ctx)
        DrawDiamond(ctx, x, y, radius * 0.7, color, opacity)
        DrawDiamond(ctx, x + size * 0.31, y - size * 0.08, radius * 0.38, color, opacity)
        DrawDiamond(ctx, x - size * 0.25, y + size * 0.12, radius * 0.32, color, opacity)
    elseif definition.iconKind == "nova" then
        for index = 0, 5 do
            local angle = index * math.pi / 3 + elapsed * 0.25
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, x + math.cos(angle) * size * 0.12, y + math.sin(angle) * size * 0.12)
            nvgLineTo(ctx, x + math.cos(angle) * size * 0.39, y + math.sin(angle) * size * 0.39)
            nvgStrokeWidth(ctx, math.max(1.5, size * 0.075))
            StrokeColor(ctx, color, opacity)
            nvgStroke(ctx)
        end
        DrawDiamond(ctx, x, y, radius * 0.8, color, opacity)
    else
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x - size * 0.23, y - size * 0.26, size * 0.46, size * 0.52, size * 0.11)
        nvgStrokeWidth(ctx, math.max(1.5, size * 0.07))
        StrokeColor(ctx, color, opacity)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, size * 0.11)
        Color(ctx, color, opacity)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, y - size * 0.38)
        nvgLineTo(ctx, x, y - size * 0.15)
        nvgStrokeWidth(ctx, math.max(1.5, size * 0.07))
        StrokeColor(ctx, color, opacity)
        nvgStroke(ctx)
    end
end

local function DrawIconFrame(ctx, definition, x, y, size, pulse, alpha)
    local opacity = alpha or 255
    local glowRadius = size * (0.82 + pulse * 0.22)
    local glow = nvgRadialGradient(ctx, x, y, size * 0.12, glowRadius,
        nvgRGBA(definition.color[1], definition.color[2], definition.color[3], math.floor(opacity * 0.48)),
        nvgRGBA(definition.color[1], definition.color[2], definition.color[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, glowRadius)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size * 0.5, y - size * 0.5, size, size, size * 0.17)
    nvgFillColor(ctx, nvgRGBA(17, 20, 38, math.floor(opacity * 0.95)))
    nvgFill(ctx)
    nvgStrokeWidth(ctx, math.max(1.25, size * 0.045))
    StrokeColor(ctx, definition.color, opacity)
    nvgStroke(ctx)
    DrawCrystalGlyph(ctx, definition, x, y, size, opacity)
end

local function GetStatusPosition(index, width)
    return 20, 124 + (index - 1) * 56
end

local function GetChoiceLayout(width, height, optionCount)
    local count = math.max(1, optionCount or 3)
    local cardWidth = Clamp(width * 0.235, 162, 246)
    local cardHeight = Clamp(height * 0.42, 216, 284)
    local gap = Clamp(width * 0.025, 12, 28)
    local totalWidth = count * cardWidth + (count - 1) * gap
    local startX = (width - totalWidth) * 0.5
    local y = Clamp(height * 0.5 - cardHeight * 0.34, 78, height - cardHeight - 28)
    local cards = {}
    for index = 1, count do
        cards[index] = {
            x = startX + (index - 1) * (cardWidth + gap),
            y = y,
            w = cardWidth,
            h = cardHeight,
        }
    end
    return cards
end

local function IsInside(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function CrystalRenderer.Update(dt)
    elapsed = elapsed + math.max(0, dt or 0)
    for index = #acquireAnimations, 1, -1 do
        local animation = acquireAnimations[index]
        animation.timer = math.max(0, animation.timer - dt)
        if animation.timer <= 0 then
            table.remove(acquireAnimations, index)
        end
    end
end

function CrystalRenderer.ProcessEvents(events)
    for _, event in ipairs(events or {}) do
        if event.name == "crystal_acquired" and event.data ~= nil then
            table.insert(pendingAcquisitions, { id = event.data.id, choiceIndex = event.data.choiceIndex })
        end
    end
end

function CrystalRenderer.GetChoiceAt(game, width, height, x, y)
    if game == nil or game.state ~= "chest_select" or game.chestOptions == nil then
        return nil
    end
    local cards = GetChoiceLayout(width, height, #game.chestOptions)
    for index, card in ipairs(cards) do
        if game.chestOptions[index] ~= nil and IsInside(x, y, card) then
            return index
        end
    end
    return nil
end

function CrystalRenderer.IsPointerOverStatusIcon(game, width, height, x, y)
    if game == nil or game.player == nil or game.state ~= "battle" then
        return false
    end
    for index, _ in ipairs(game.player.crystalOrder or {}) do
        local iconX, iconY = GetStatusPosition(index, width)
        if x >= iconX and x <= iconX + 38 and y >= iconY and y <= iconY + 38 then
            return true
        end
    end
    return false
end

local function QueuePendingAcquisitions(game, width, height)
    if #pendingAcquisitions == 0 or game.player == nil then
        return
    end
    for _, pending in ipairs(pendingAcquisitions) do
        local definition = FindDefinition(pending.id)
        if definition ~= nil then
            local source = GetChoiceLayout(width, height, 3)[pending.choiceIndex or 1]
            local slot = 1
            for index, id in ipairs(game.player.crystalOrder or {}) do
                if id == pending.id then
                    slot = index
                    break
                end
            end
            local targetX, targetY = GetStatusPosition(slot, width)
            table.insert(acquireAnimations, {
                definition = definition,
                startX = source.x + source.w * 0.5,
                startY = source.y + source.h * 0.34,
                endX = targetX + 19,
                endY = targetY + 19,
                timer = 0.52,
                maxTimer = 0.52,
            })
        end
    end
    pendingAcquisitions = {}
end

local function DrawTooltip(ctx, definition, x, y, width, height)
    local tooltipWidth = math.min(248, width - x - 14)
    if tooltipWidth < 150 then
        x = math.max(12, width - 260)
        tooltipWidth = width - x - 12
    end
    local tooltipHeight = 92
    y = Clamp(y - 10, 12, height - tooltipHeight - 12)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, tooltipWidth, tooltipHeight, 8)
    nvgFillColor(ctx, nvgRGBA(11, 14, 29, 242))
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 1)
    StrokeColor(ctx, definition.color, 205)
    nvgStroke(ctx)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 15)
    Color(ctx, definition.color, 255)
    nvgText(ctx, x + 13, y + 12, definition.name, nil)
    nvgFontSize(ctx, 11)
    Color(ctx, { 226, 229, 239 }, 235)
    local lines = {}
    for line in string.gmatch(definition.shortDescription, "[^\n]+") do table.insert(lines, line) end
    for index, line in ipairs(lines) do
        nvgText(ctx, x + 13, y + 40 + (index - 1) * 17, line, nil)
    end
end

local function DrawStatusBar(ctx, game, width, height)
    if game.player == nil or game.state == "menu" or game.state == "dead" or game.state == "victory" or game.state == "chest_select" then
        return
    end
    local cursorX, cursorY = game.cursorX or -1, game.cursorY or -1
    for index, id in ipairs(game.player.crystalOrder or {}) do
        local definition = FindDefinition(id)
        if definition ~= nil then
            local x, y = GetStatusPosition(index, width)
            local pulse = 0.08 + math.sin(elapsed * 2.8 + index) * 0.05
            DrawIconFrame(ctx, definition, x + 19, y + 19, 38, pulse, 255)
            if cursorX >= x and cursorX <= x + 38 and cursorY >= y and cursorY <= y + 38 then
                DrawTooltip(ctx, definition, x + 49, y, width, height)
            end
        end
    end
end

local function DrawChoiceCards(ctx, game, width, height)
    if game.state ~= "chest_select" or game.chestOptions == nil then
        return
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(7, 8, 20, 222))
    nvgFill(ctx)

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 27)
    Color(ctx, { 245, 241, 226 }, 255)
    nvgText(ctx, width * 0.5, 43, "水晶能力", nil)
    nvgFontSize(ctx, 12)
    Color(ctx, { 182, 188, 216 }, 230)
    nvgText(ctx, width * 0.5, 69, "选择一枚，为这一局注入新的战斗节奏", nil)

    local cards = GetChoiceLayout(width, height, #game.chestOptions)
    local cursorX, cursorY = game.cursorX or -1, game.cursorY or -1
    for index, card in ipairs(cards) do
        local definition = game.chestOptions[index]
        if definition ~= nil then
            local hovered = IsInside(cursorX, cursorY, card)
            local lift = hovered and -8 or 0
            local borderAlpha = hovered and 255 or 165
            local glow = hovered and 0.32 or 0.15
            local shadow = nvgBoxGradient(ctx, card.x, card.y + lift, card.w, card.h, 10, 14,
                nvgRGBA(definition.color[1], definition.color[2], definition.color[3], math.floor(100 * glow)),
                nvgRGBA(0, 0, 0, 0))
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, card.x - 4, card.y + lift - 4, card.w + 8, card.h + 8, 12)
            nvgFillPaint(ctx, shadow)
            nvgFill(ctx)

            local background = nvgLinearGradient(ctx, card.x, card.y + lift, card.x, card.y + card.h + lift,
                nvgRGBA(42, 43, 68, 252), nvgRGBA(17, 18, 34, 252))
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, card.x, card.y + lift, card.w, card.h, 8)
            nvgFillPaint(ctx, background)
            nvgFill(ctx)
            nvgStrokeWidth(ctx, hovered and 2.4 or 1.25)
            StrokeColor(ctx, definition.color, borderAlpha)
            nvgStroke(ctx)

            DrawIconFrame(ctx, definition, card.x + card.w * 0.5, card.y + lift + card.h * 0.29,
                math.min(card.w, card.h) * 0.34, hovered and 0.2 or 0.04, 255)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(ctx, 18)
            Color(ctx, definition.color, 255)
            nvgText(ctx, card.x + card.w * 0.5, card.y + lift + card.h * 0.53, definition.name, nil)
            nvgFontSize(ctx, 12)
            Color(ctx, { 225, 228, 239 }, 235)
            local lineY = card.y + lift + card.h * 0.67
            for line in string.gmatch(definition.shortDescription, "[^\n]+") do
                nvgText(ctx, card.x + card.w * 0.5, lineY, line, nil)
                lineY = lineY + 19
            end
            nvgFontSize(ctx, 11)
            Color(ctx, hovered and definition.color or { 170, 176, 199 }, 230)
            nvgText(ctx, card.x + card.w * 0.5, card.y + lift + card.h - 23, "[" .. tostring(index) .. "]  获取", nil)
        end
    end
end

local function DrawAcquireAnimations(ctx)
    for _, animation in ipairs(acquireAnimations) do
        local progress = 1 - animation.timer / animation.maxTimer
        local eased = 1 - (1 - progress) * (1 - progress)
        local x = animation.startX + (animation.endX - animation.startX) * eased
        local y = animation.startY + (animation.endY - animation.startY) * eased - math.sin(progress * math.pi) * 30
        local size = 48 - progress * 18
        DrawIconFrame(ctx, animation.definition, x, y, size, 0.18, math.floor(255 * (1 - progress * 0.12)))
    end
end

local function DrawWorldEffects(ctx, game, width, height)
    local state = game.crystalState
    if state == nil then return end
    if state.dashTrail ~= nil then
        local trail = state.dashTrail
        local startX, startY, scale = Renderer.WorldToScreen(width, height, trail.startX, trail.startY)
        local endX, endY = Renderer.WorldToScreen(width, height, trail.endX, trail.endY)
        local alpha = math.floor(255 * trail.timer / trail.maxTimer)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, startX, startY)
        nvgLineTo(ctx, endX, endY)
        nvgStrokeWidth(ctx, 14 * scale)
        StrokeColor(ctx, { 104, 232, 255 }, alpha)
        nvgStroke(ctx)
        nvgStrokeWidth(ctx, 4 * scale)
        StrokeColor(ctx, { 255, 245, 255 }, alpha)
        nvgStroke(ctx)
    end
    for _, burst in ipairs(state.lightningBursts or {}) do
        local alpha = math.floor(255 * burst.timer / burst.maxTimer)
        for index = 2, #burst.points do
            local from = burst.points[index - 1]
            local to = burst.points[index]
            local fromX, fromY, scale = Renderer.WorldToScreen(width, height, from.x, from.y)
            local toX, toY = Renderer.WorldToScreen(width, height, to.x, to.y)
            local midX = (fromX + toX) * 0.5 + math.sin(index * 9.7) * 12 * scale
            local midY = (fromY + toY) * 0.5 + math.cos(index * 7.1) * 10 * scale
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, fromX, fromY)
            nvgLineTo(ctx, midX, midY)
            nvgLineTo(ctx, toX, toY)
            nvgStrokeWidth(ctx, 3.4 * scale)
            StrokeColor(ctx, { 255, 224, 104 }, alpha)
            nvgStroke(ctx)
        end
    end
    for _, shard in ipairs(state.orbitShards or {}) do
        if shard.x ~= nil then
            local x, y, scale = Renderer.WorldToScreen(width, height, shard.x, shard.y)
            local fadeDuration = CrystalConfig.orbit.fadeDuration
            local alpha = 245
            if shard.remaining ~= nil and shard.remaining < fadeDuration then
                alpha = math.floor(245 * math.max(0, shard.remaining / fadeDuration))
            end
            DrawDiamond(ctx, x, y, 7 * scale, { 150, 135, 255 }, alpha)
        end
    end
    if state.nova ~= nil then
        local nova = state.nova
        local x, y, scale = Renderer.WorldToScreen(width, height, nova.x, nova.y)
        local progress = 1 - nova.timer / nova.maxTimer
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, (18 + progress * 116) * scale)
        nvgStrokeWidth(ctx, (4 - progress * 2) * scale)
        StrokeColor(ctx, { 255, 117, 152 }, math.floor(255 * (1 - progress)))
        nvgStroke(ctx)
    end
    if state.timeBreak ~= nil then
        local pulse = state.timeBreak
        local x, y, scale = Renderer.WorldToScreen(width, height, pulse.x, pulse.y)
        local progress = 1 - pulse.timer / pulse.maxTimer
        for index = 0, 5 do
            local angle = index * math.pi / 3 + progress * 0.4
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, x + math.cos(angle) * 12 * scale, y + math.sin(angle) * 12 * scale)
            nvgLineTo(ctx, x + math.cos(angle) * (38 + progress * 96) * scale, y + math.sin(angle) * (38 + progress * 96) * scale)
            nvgStrokeWidth(ctx, 2.6 * scale)
            StrokeColor(ctx, { 111, 242, 192 }, math.floor(230 * (1 - progress)))
            nvgStroke(ctx)
        end
    end
end

function CrystalRenderer.Draw(ctx, game, width, height)
    QueuePendingAcquisitions(game, width, height)
    DrawWorldEffects(ctx, game, width, height)
    DrawChoiceCards(ctx, game, width, height)
    DrawStatusBar(ctx, game, width, height)
    DrawAcquireAnimations(ctx)
end

return CrystalRenderer
