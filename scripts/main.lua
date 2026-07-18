-- 弹反之室：原生 NanoVG 负责游戏画面，UI 组件负责响应式中文 HUD 与宝箱选择。

local UI = require("urhox-libs/UI")
local AudioManager = require "AudioManager"
local GameConfig = require "Data.GameConfig"
local Feedback = require "Feedback"
local Game = require "Game"
local Renderer = require "Renderer"
local CrystalRenderer = require "CrystalRenderer"

---@type any
local nvgContext = nil
local game = nil
local physicalWidth = 0
local physicalHeight = 0
local devicePixelRatio = 1.0
local logicalWidth = 0
local logicalHeight = 0
local hudTimer = 0
local chestPanelWasVisible = false
local feedback = nil

---@type Widget|nil
local combatHud = nil
---@type Widget|nil
local healthPanel = nil
---@type ProgressBar|nil
local healthProgressBar = nil
---@type Widget|nil
local roomLabel = nil
---@type Widget|nil
local roomProgressLabel = nil
---@type Widget|nil
local parryPanel = nil
---@type Widget|nil
local parryLabel = nil
---@type Widget|nil
local comboPanel = nil
---@type Widget|nil
local comboLabel = nil
---@type Widget|nil
local overdriveLabel = nil
---@type Widget|nil
local buffLabel = nil
---@type Widget|nil
---@type ProgressBar|nil
local gaugeProgressBar = nil
---@type Widget|nil
local gaugeStatusLabel = nil
---@type Widget|nil
local messagePanel = nil
---@type Widget|nil
local messageLabel = nil
---@type Widget|nil
local bossPanel = nil
---@type Widget|nil
local bossNameLabel = nil
---@type Widget|nil
local bossObjectiveLabel = nil
---@type ProgressBar|nil
local bossProgressBar = nil
---@type Widget|nil
local chestPanel = nil
---@type Widget|nil
local stateOverlay = nil
---@type Widget|nil
local stateKickerLabel = nil
---@type Widget|nil
local stateTitleLabel = nil
---@type Widget|nil
local stateSubtitleLabel = nil
---@type Widget|nil
local stateActionButton = nil
local chestTitleLabels = {}
local chestDescriptionLabels = {}
local chestIconLabels = {}
local chestCards = {}
local chestAccentPanels = {}
local chestIconPanels = {}
local chestLiftPanels = {}
local chestFloatPanels = {}
local chestFacePanels = {}

local CHEST_CARD_IDLE_ROTATIONS = { 0, 0, 0 }
local CHEST_CARD_IDLE_DURATIONS = { 3.4, 3.8, 3.6 }
local CHEST_CARD_MAX_POINTER_TILT = 3.2

local COLORS = {
    panelTop = { 28, 31, 50, 238 },
    panelBottom = { 13, 16, 31, 246 },
    cream = { 255, 244, 218, 255 },
    muted = { 190, 196, 218, 235 },
    gold = { 239, 190, 105, 255 },
    coral = { 244, 112, 112, 255 },
    cyan = { 105, 225, 221, 255 },
    violet = { 170, 142, 238, 255 },
}

local function RefreshCanvasMetrics()
    physicalWidth = graphics:GetWidth()
    physicalHeight = graphics:GetHeight()
    devicePixelRatio = graphics:GetDPR()
    logicalWidth = physicalWidth / devicePixelRatio
    logicalHeight = physicalHeight / devicePixelRatio
end

local function ChooseChestOption(index)
    if game ~= nil and Game.SelectCrystal(game, index) then
        hudTimer = 1.0
    end
end

local function TryParryAtLogicalPosition(screenX, screenY, allowBirthTutorial)
    if game == nil then
        return false
    end
    local worldX, worldY = Renderer.ScreenToWorld(logicalWidth, logicalHeight, screenX, screenY)
    return Game.TryParry(game, worldX, worldY, allowBirthTutorial)
end

local function TryParryAtCursor()
    local mousePosition = input:GetMousePosition()
    return TryParryAtLogicalPosition(
        mousePosition.x / devicePixelRatio,
        mousePosition.y / devicePixelRatio
    )
end

local function StartOrRestartRun()
    if game == nil then
        return
    end
    Game.StartOrRestart(game)
    hudTimer = 1.0
end

local function StartChestCardIdle(card)
    local idleDuration = card.state.idleDuration or 3.0
    local floatPanel = card.state.floatPanel

    if floatPanel == nil then
        return
    end

    floatPanel:Animate({
        keyframes = {
            [0] = { translateY = 0 },
            [0.46] = { translateY = -2.4 },
            [1] = { translateY = 0 },
        },
        duration = idleDuration,
        easing = "easeInOut",
        loop = true,
        fillMode = "both",
    })
end

local function StartChestCardEntrance(card, index)
    local delayRatio = (index - 1) * 0.12
    local keyframes = {
        [0] = { opacity = 0, scale = 0.965, translateY = 22 },
        [1] = { opacity = 1, scale = 1.0, translateY = 0 },
    }
    if delayRatio > 0 then
        keyframes[delayRatio] = { opacity = 0, scale = 0.965, translateY = 22 }
    end

    card:Animate({
        keyframes = keyframes,
        duration = 0.42 + (index - 1) * 0.07,
        easing = "easeOutCubic",
        fillMode = "both",
    })
end

local function GetChestCardPointerMotion(card, event)
    if event == nil then
        return 0, 0, 0
    end

    local layout = card:GetAbsoluteLayout()
    if layout.w <= 0 or layout.h <= 0 then
        return 0, 0, 0
    end

    local normalizedX = (event.x - layout.x) / layout.w * 2 - 1
    local normalizedY = (event.y - layout.y) / layout.h * 2 - 1
    normalizedX = math.max(-1, math.min(1, normalizedX))
    normalizedY = math.max(-1, math.min(1, normalizedY))
    return normalizedX * CHEST_CARD_MAX_POINTER_TILT, normalizedX * 2.2, normalizedY * 1.6
end

local function UpdateChestCardHoverTilt(card, event)
    if not card.state.hovered or card.state.pressed then
        return
    end

    local hoverRotation, iconOffsetX, iconOffsetY = GetChestCardPointerMotion(card, event)
    local idleRotation = card.state.idleRotation or 0
    local facePanel = card.state.facePanel
    card:SetState({ hoverRotation = hoverRotation })
    if facePanel ~= nil then
        facePanel:SetStyle({ rotate = idleRotation + hoverRotation })
    end
    if card.state.iconPanel ~= nil then
        card.state.iconPanel:SetStyle({
            translateX = iconOffsetX,
            translateY = -3 + iconOffsetY,
            rotate = -hoverRotation * 0.24,
        })
    end
end

local function SetChestCardRest(card)
    local accentColor = card.state.accentColor or { 236, 202, 105 }
    local borderColor = card.state.borderColor or { accentColor[1], accentColor[2], accentColor[3], 210 }
    local iconBorderColor = card.state.iconBorderColor or { accentColor[1], accentColor[2], accentColor[3], 190 }
    local idleRotation = card.state.idleRotation or 0
    local liftPanel = card.state.liftPanel
    local facePanel = card.state.facePanel
    local iconPanel = card.state.iconPanel

    if liftPanel ~= nil then
        liftPanel:SetStyle({
            transition = "scale 0.20s easeOutCubic, translateY 0.22s easeOutCubic",
            scale = 1.0,
            translateY = 0,
        })
    end
    if facePanel ~= nil then
        facePanel:SetStyle({
            transition = "rotate 0.20s easeOutCubic, borderColor 0.20s easeOut, shadowBlur 0.22s easeOut, shadowOffsetY 0.22s easeOut, shadowColor 0.22s easeOut",
            rotate = idleRotation,
            borderColor = borderColor,
            shadowBlur = 18,
            shadowOffsetY = 7,
            shadowColor = { 0, 0, 0, 175 },
        })
    end
    if iconPanel ~= nil then
        iconPanel:SetStyle({
            transition = "scale 0.20s easeOutCubic, translateX 0.20s easeOutCubic, translateY 0.20s easeOutCubic, rotate 0.20s easeOutCubic, borderColor 0.20s easeOut, shadowBlur 0.22s easeOut, shadowColor 0.22s easeOut",
            scale = 1.0,
            translateX = 0,
            translateY = 0,
            rotate = 0,
            borderColor = iconBorderColor,
            shadowBlur = 12,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 78 },
        })
    end
end

local function SetChestCardHover(card, hovered, event)
    local accentColor = card.state.accentColor or { 236, 202, 105 }
    local idleRotation = card.state.idleRotation or 0
    local liftPanel = card.state.liftPanel
    local facePanel = card.state.facePanel
    local iconPanel = card.state.iconPanel

    if not hovered then
        card:SetState({ hovered = false, pressed = false, hoverRotation = 0 })
        SetChestCardRest(card)
        return
    end

    local hoverRotation, iconOffsetX, iconOffsetY = GetChestCardPointerMotion(card, event)
    card:SetState({ hovered = true, hoverRotation = hoverRotation })
    if liftPanel ~= nil then
        liftPanel:SetStyle({
            transition = "scale 0.16s easeOutCubic, translateY 0.18s easeOutCubic",
            scale = 1.03,
            translateY = -9,
        })
    end
    if facePanel ~= nil then
        facePanel:SetStyle({
            transition = "rotate 0.13s easeOutCubic, borderColor 0.18s easeOut, shadowBlur 0.18s easeOut, shadowOffsetY 0.18s easeOut, shadowColor 0.18s easeOut",
            rotate = idleRotation + hoverRotation,
            borderColor = { math.min(255, accentColor[1] + 22), math.min(255, accentColor[2] + 22), math.min(255, accentColor[3] + 22), 255 },
            shadowBlur = 28,
            shadowOffsetY = 12,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 112 },
        })
    end
    if iconPanel ~= nil then
        iconPanel:SetStyle({
            transition = "scale 0.16s easeOutCubic, translateX 0.13s easeOutCubic, translateY 0.13s easeOutCubic, rotate 0.13s easeOutCubic, borderColor 0.18s easeOut, shadowBlur 0.18s easeOut, shadowColor 0.18s easeOut",
            scale = 1.065,
            translateX = iconOffsetX,
            translateY = -3 + iconOffsetY,
            rotate = -hoverRotation * 0.24,
            borderColor = { math.min(255, accentColor[1] + 28), math.min(255, accentColor[2] + 28), math.min(255, accentColor[3] + 28), 255 },
            shadowBlur = 19,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 135 },
        })
    end
end

local function SetChestCardPressed(card, pressed, event)
    local accentColor = card.state.accentColor or { 236, 202, 105 }
    local liftPanel = card.state.liftPanel
    local facePanel = card.state.facePanel
    local iconPanel = card.state.iconPanel

    if not pressed then
        card:SetState({ pressed = false })
        if event ~= nil and event.pointerType == "touch" then
            SetChestCardHover(card, false)
        elseif card.state.hovered then
            SetChestCardHover(card, true, event)
        else
            SetChestCardRest(card)
        end
        return
    end

    card:SetState({ hovered = true, pressed = true })
    if liftPanel ~= nil then
        liftPanel:SetStyle({
            transition = "scale 0.07s easeOut, translateY 0.07s easeOut",
            scale = 0.985,
            translateY = -3,
        })
    end
    if facePanel ~= nil then
        facePanel:SetStyle({
            transition = "shadowBlur 0.07s easeOut, shadowOffsetY 0.07s easeOut, shadowColor 0.07s easeOut",
            shadowBlur = 12,
            shadowOffsetY = 4,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 82 },
        })
    end
    if iconPanel ~= nil then
        iconPanel:SetStyle({
            transition = "scale 0.07s easeOut, translateY 0.07s easeOut",
            scale = 0.96,
            translateY = 1,
        })
    end
end

local function CreateChestCard(index)
    local optionIndex = index
    local accent = UI.Panel {
        width = "100%",
        height = 3,
        borderRadius = 2,
        backgroundColor = { 236, 202, 105, 255 },
        pointerEvents = "none",
    }
    local icon = UI.Label {
        text = "✦",
        width = "100%",
        fontSize = 46,
        fontWeight = "bold",
        textAlign = "center",
        verticalAlign = "middle",
        fontColor = { 236, 202, 105, 255 },
        textShadow = { offsetX = 0, offsetY = 2, blur = 5, color = { 0, 0, 0, 170 } },
    }
    local iconPanel = UI.Panel {
        width = 88,
        height = 88,
        alignSelf = "center",
        justifyContent = "center",
        alignItems = "center",
        borderRadius = 6,
        borderWidth = 1,
        borderColor = { 236, 202, 105, 175 },
        backgroundGradient = {
            type = "radial",
            innerRadius = 0,
            outerRadius = 72,
            from = { 74, 69, 69, 255 },
            to = { 28, 30, 35, 255 },
        },
        shadowBlur = 12,
        shadowColor = { 0, 0, 0, 150 },
        scale = 1.0,
        translateX = 0,
        translateY = 0,
        rotate = 0,
        transition = "scale 0.20s easeOutCubic, translateX 0.20s easeOutCubic, translateY 0.20s easeOutCubic, rotate 0.20s easeOutCubic, borderColor 0.20s easeOut, shadowBlur 0.22s easeOut, shadowColor 0.22s easeOut",
        pointerEvents = "none",
        children = { icon },
    }
    local title = UI.Label {
        text = "水晶能力",
        width = "100%",
        fontSize = 21,
        fontWeight = "bold",
        textAlign = "center",
        maxLines = 2,
        whiteSpace = "normal",
        wordBreak = "break-word",
        fontColor = { 245, 242, 232, 255 },
        textShadow = { offsetX = 0, offsetY = 2, blur = 2, color = { 0, 0, 0, 190 } },
    }
    local description = UI.Label {
        text = "能力说明",
        width = "100%",
        fontSize = 13,
        textAlign = "center",
        whiteSpace = "normal",
        wordBreak = "break-word",
        maxLines = 4,
        lineHeight = 1.35,
        fontColor = { 216, 218, 221, 225 },
    }
    local facePanel = UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        padding = { 12, 14, 14, 14 },
        gap = 11,
        borderRadius = 7,
        borderWidth = { 2, 2, 4, 2 },
        borderColor = { 236, 202, 105, 210 },
        overflow = "hidden",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 56, 50, 53, 254 },
            to = { 20, 23, 29, 254 },
        },
        shadowBlur = 18,
        shadowOffsetY = 7,
        shadowColor = { 0, 0, 0, 175 },
        rotate = CHEST_CARD_IDLE_ROTATIONS[optionIndex],
        transformOrigin = "bottom",
        transition = "rotate 0.20s easeOutCubic, borderColor 0.20s easeOut, shadowBlur 0.22s easeOut, shadowOffsetY 0.22s easeOut, shadowColor 0.22s easeOut",
        pointerEvents = "none",
        children = {
            accent,
            iconPanel,
            title,
            UI.Divider {
                width = "100%",
                color = { 255, 255, 255, 42 },
                spacing = 0,
                pointerEvents = "none",
            },
            description,
        },
    }
    local floatPanel = UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        pointerEvents = "none",
        children = { facePanel },
    }
    local liftPanel = UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        scale = 1.0,
        translateY = 0,
        transition = "scale 0.20s easeOutCubic, translateY 0.22s easeOutCubic",
        pointerEvents = "none",
        children = { floatPanel },
    }
    local card = UI.Panel {
        width = 226,
        minWidth = 196,
        aspectRatio = 2 / 3,
        minHeight = 294,
        overflow = "visible",
        pointerEvents = "box-only",
        onPointerEnter = function(event, widget)
            SetChestCardHover(widget, true, event)
        end,
        onPointerMove = function(event, widget)
            UpdateChestCardHoverTilt(widget, event)
        end,
        onPointerLeave = function(event, widget)
            SetChestCardHover(widget, false)
        end,
        onPointerDown = function(event, widget)
            SetChestCardPressed(widget, true, event)
        end,
        onPointerUp = function(event, widget)
            SetChestCardPressed(widget, false, event)
        end,
        onPointerCancel = function(event, widget)
            SetChestCardHover(widget, false)
        end,
        onClick = function()
            ChooseChestOption(optionIndex)
        end,
        children = { liftPanel },
    }

    chestTitleLabels[index] = title
    chestDescriptionLabels[index] = description
    chestIconLabels[index] = icon
    chestCards[index] = card
    chestAccentPanels[index] = accent
    chestIconPanels[index] = iconPanel
    chestLiftPanels[index] = liftPanel
    chestFloatPanels[index] = floatPanel
    chestFacePanels[index] = facePanel
    card:SetState({
        idleRotation = CHEST_CARD_IDLE_ROTATIONS[optionIndex],
        hoverRotation = 0,
        idleDuration = CHEST_CARD_IDLE_DURATIONS[optionIndex],
        liftPanel = liftPanel,
        floatPanel = floatPanel,
        facePanel = facePanel,
        iconPanel = iconPanel,
        hovered = false,
        pressed = false,
    })
    return card
end

local function CreateHud()
    healthProgressBar = UI.ProgressBar {
        value = 1,
        max = 1,
        width = "100%",
        height = 14,
        showLabel = false,
        borderRadius = 7,
        borderWidth = 1,
        borderColor = { 255, 180, 145, 120 },
        backgroundColor = { 8, 10, 20, 220 },
        fillGradient = {
            direction = "to-right",
            from = { 225, 72, 92, 255 },
            to = { 255, 177, 100, 255 },
        },
        transition = "value 0.18s easeOut",
    }
    roomLabel = UI.Label {
        text = "尚未开始",
        fontSize = 14,
        fontWeight = "bold",
        fontColor = COLORS.cream,
    }
    roomProgressLabel = UI.Label {
        text = "探索 0/7",
        fontSize = 10,
        fontColor = COLORS.muted,
        textAlign = "right",
    }
    healthPanel = UI.Panel {
        width = "40%",
        minWidth = 150,
        maxWidth = 282,
        padding = { 10, 13, 11, 13 },
        gap = 7,
        borderRadius = 15,
        borderWidth = 1,
        borderLeftWidth = 3,
        borderColor = { 239, 190, 105, 105 },
        borderLeftColor = COLORS.coral,
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom-right",
            from = COLORS.panelTop,
            to = COLORS.panelBottom,
        },
        boxShadow = {
            { x = 0, y = 6, blur = 18, spread = 0, color = { 0, 0, 0, 125 } },
            { x = 0, y = 1, blur = 2, spread = 0, color = { 255, 219, 164, 24 }, inset = true },
        },
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 7,
                children = {
                    UI.Label {
                        text = "♥",
                        fontSize = 16,
                        fontColor = COLORS.coral,
                        textShadow = { offsetX = 0, offsetY = 1, blur = 6, color = { 244, 112, 112, 150 } },
                    },
                    UI.Label {
                        text = "生命律动",
                        fontSize = 12,
                        fontWeight = "bold",
                        letterSpacing = 1,
                        fontColor = COLORS.cream,
                    },
                },
            },
            healthProgressBar,
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "baseline",
                children = { roomLabel, UI.Spacer(), roomProgressLabel },
            },
        },
    }
    parryLabel = UI.Label {
        text = "招架 就绪",
        fontSize = 12,
        fontWeight = "bold",
        letterSpacing = 1,
        fontColor = COLORS.cyan,
    }
    parryPanel = UI.Panel {
        padding = { 7, 12, 7, 12 },
        borderRadius = 16,
        borderWidth = 1,
        borderColor = { 105, 225, 221, 145 },
        backgroundColor = { 15, 38, 48, 225 },
        shadowBlur = 12,
        shadowColor = { 48, 197, 205, 65 },
        pointerEvents = "none",
        children = { parryLabel },
    }
    comboLabel = UI.Label {
        text = "连击 x0",
        width = 88,
        fontSize = 19,
        fontWeight = "bold",
        fontColor = COLORS.muted,
    }
    overdriveLabel = UI.Label {
        text = "蓄势",
        width = 70,
        fontSize = 10,
        textAlign = "right",
        fontColor = COLORS.muted,
    }
    comboPanel = UI.Panel {
        width = 170,
        padding = { 7, 10, 7, 10 },
        borderRadius = 16,
        borderWidth = 1,
        borderColor = { 190, 196, 218, 95 },
        backgroundColor = { 20, 24, 41, 225 },
        shadowBlur = 12,
        shadowColor = { 0, 0, 0, 90 },
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "baseline",
                children = { comboLabel, UI.Spacer(), overdriveLabel },
            },
        },
    }
    buffLabel = UI.Label {
        text = "暂无回响",
        width = "100%",
        fontSize = 10,
        whiteSpace = "normal",
        fontColor = { 132, 244, 184, 240 },
    }
    bossNameLabel = UI.Label {
        text = "晦暗低鸣", width = "100%", fontSize = 16, fontWeight = "bold",
        letterSpacing = 2, textAlign = "center", fontColor = COLORS.cream,
        textShadow = { offsetX = 0, offsetY = 2, blur = 4, color = { 0, 0, 0, 180 } },
    }
    bossObjectiveLabel = UI.Label {
        text = "第一阶段 · 黑影", width = "100%", fontSize = 10,
        letterSpacing = 1, textAlign = "center", fontColor = { 214, 202, 225, 235 },
    }
    bossProgressBar = UI.ProgressBar {
        value = 100, max = 100, width = "100%", height = 10, borderRadius = 5,
        showLabel = false,
        backgroundColor = { 8, 8, 17, 220 },
        borderColor = { 243, 190, 126, 95 }, borderWidth = 1,
        fillGradient = {
            direction = "to-right", from = { 105, 42, 66, 255 }, to = { 220, 98, 104, 255 },
        },
        transition = "value 0.16s easeOut",
    }
    bossPanel = UI.Panel {
        visible = false, width = "52%", maxWidth = 500, minWidth = 240,
        padding = { 9, 16, 11, 16 }, gap = 5, borderRadius = 15,
        borderWidth = { 1, 1, 3, 1 }, borderColor = { 188, 145, 120, 135 },
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = { 39, 24, 39, 238 }, to = { 16, 13, 27, 244 },
        },
        shadowBlur = 20, shadowOffsetY = 7, shadowColor = { 0, 0, 0, 140 },
        pointerEvents = "none",
        children = { bossNameLabel, bossObjectiveLabel, bossProgressBar },
    }

    gaugeStatusLabel = UI.Label {
        text = "等待弹反",
        fontSize = 10,
        fontColor = COLORS.muted,
        textAlign = "right",
    }
    gaugeProgressBar = UI.ProgressBar {
        value = 0,
        max = 1,
        width = "100%",
        height = 12,
        showLabel = false,
        borderRadius = 6,
        borderWidth = 1,
        borderColor = { 255, 196, 112, 110 },
        backgroundColor = { 8, 9, 20, 225 },
        fillGradient = {
            direction = "to-right",
            from = { 247, 137, 79, 255 },
            to = { 255, 225, 126, 255 },
        },
        transition = "value 0.16s easeOut",
    }
    local gaugePanel = UI.Panel {
        width = "62%",
        minWidth = 260,
        maxWidth = 560,
        padding = { 9, 14, 11, 14 },
        gap = 7,
        borderRadius = 16,
        borderWidth = { 1, 1, 3, 1 },
        borderColor = { 225, 164, 91, 130 },
        backgroundGradient = {
            type = "linear", direction = "to-bottom",
            from = { 38, 27, 41, 235 }, to = { 16, 16, 31, 245 },
        },
        shadowBlur = 18, shadowOffsetY = 7, shadowColor = { 0, 0, 0, 135 },
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "baseline",
                children = {
                    UI.Label {
                        text = "✦  弹反共鸣",
                        fontSize = 12,
                        fontWeight = "bold",
                        letterSpacing = 1,
                        fontColor = COLORS.gold,
                    },
                    UI.Spacer(),
                    gaugeStatusLabel,
                },
            },
            gaugeProgressBar,
        },
    }

    local insightPanel = UI.Panel {
        width = "40%",
        minWidth = 150,
        maxWidth = 282,
        padding = { 9, 12, 10, 12 },
        gap = 6,
        borderRadius = 14,
        borderWidth = 1,
        borderColor = { 164, 139, 211, 95 },
        backgroundGradient = {
            type = "linear", direction = "to-bottom-left",
            from = { 29, 29, 51, 230 }, to = { 14, 17, 31, 242 },
        },
        boxShadow = { { x = 0, y = 6, blur = 18, spread = 0, color = { 0, 0, 0, 115 } } },
        pointerEvents = "none",
        children = {
            UI.Label { text = "临时回响", fontSize = 9, letterSpacing = 1, fontColor = { 112, 225, 175, 220 } },
            buffLabel,
        },
    }

    messageLabel = UI.Label {
        text = "",
        fontSize = 14,
        fontWeight = "bold",
        textAlign = "center",
        whiteSpace = "normal",
        fontColor = COLORS.cream,
        textShadow = { offsetX = 0, offsetY = 2, blur = 4, color = { 0, 0, 0, 175 } },
    }
    messagePanel = UI.Panel {
        visible = false,
        maxWidth = 520,
        padding = { 8, 16, 8, 16 },
        borderRadius = 16,
        borderWidth = 1,
        borderColor = { 239, 190, 105, 95 },
        backgroundColor = { 17, 18, 34, 218 },
        shadowBlur = 14,
        shadowColor = { 0, 0, 0, 115 },
        pointerEvents = "none",
        children = { messageLabel },
    }

    combatHud = UI.SafeAreaView {
        visible = false,
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute", top = 14, left = 16,
                width = "100%", pointerEvents = "box-none", children = { healthPanel },
            },
            UI.Panel {
                position = "absolute", top = 14, right = 16,
                width = "100%", alignItems = "flex-end", gap = 8,
                pointerEvents = "box-none", children = { parryPanel, comboPanel, insightPanel },
            },
            UI.Panel {
                position = "absolute", top = 30, left = 0, right = 0,
                alignItems = "center", pointerEvents = "none", children = { bossPanel },
            },
            UI.Panel {
                position = "absolute", top = 108, left = 0, right = 0,
                alignItems = "center", pointerEvents = "none", children = { messagePanel },
            },
            UI.Panel {
                position = "absolute", bottom = 14, left = 0, right = 0,
                alignItems = "center", pointerEvents = "none", children = { gaugePanel },
            },
        },
    }

    chestPanel = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundGradient = {
            type = "radial", innerRadius = 60, outerRadius = 760,
            from = { 45, 34, 53, 230 }, to = { 5, 7, 17, 246 },
        },
        backdropBlur = 10,
        pointerEvents = "auto",
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                children = {
                    UI.Label {
                        text = "水晶能力  ·  选择一枚晶核",
                        position = "absolute",
                        top = 22,
                        left = 0,
                        right = 0,
                        fontSize = 27,
                        fontWeight = "bold",
                        textAlign = "center",
                        textStroke = { width = 1, color = { 18, 18, 20, 240 } },
                        letterSpacing = 2,
                        fontColor = COLORS.cream,
                        pointerEvents = "none",
                    },
                    UI.ScrollView {
                        width = "100%",
                        height = "100%",
                        scrollX = false,
                        scrollY = true,
                        showScrollbar = false,
                        children = {
                            UI.Panel {
                                width = "100%",
                                minHeight = "100%",
                                justifyContent = "center",
                                alignItems = "center",
                                padding = { 64, 18, 64, 18 },
                                pointerEvents = "box-none",
                                children = {
                                    UI.Panel {
                                        width = "100%",
                                        maxWidth = 900,
                                        flexDirection = "row",
                                        flexWrap = "wrap",
                                        justifyContent = "center",
                                        alignItems = "flex-start",
                                        columnGap = 36,
                                        rowGap = 20,
                                        pointerEvents = "box-none",
                                        children = { CreateChestCard(1), CreateChestCard(2), CreateChestCard(3) },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    stateKickerLabel = UI.Label {
        text = "绘本奇幻 · 弹反冒险",
        fontSize = 12,
        fontWeight = "bold",
        letterSpacing = 2,
        fontColor = COLORS.gold,
    }
    stateTitleLabel = UI.Label {
        text = "弹反之室",
        width = "100%",
        fontSize = 52,
        fontWeight = "bold",
        lineHeight = 1.05,
        whiteSpace = "normal",
        letterSpacing = 3,
        fontColor = COLORS.cream,
        textStroke = { width = 1, color = { 81, 45, 55, 230 } },
        textShadow = { offsetX = 0, offsetY = 5, blur = 10, color = { 0, 0, 0, 170 } },
    }
    stateSubtitleLabel = UI.Label {
        text = "拨动琴弦般把握节奏，弹回每一枚诅咒。",
        width = "100%",
        maxWidth = 500,
        fontSize = 16,
        lineHeight = 1.5,
        whiteSpace = "normal",
        fontColor = { 214, 219, 235, 245 },
    }
    stateActionButton = UI.Button {
        text = "踏入房间",
        width = 220,
        height = 52,
        fontSize = 16,
        textColor = { 40, 25, 30, 255 },
        backgroundGradient = {
            type = "linear", direction = "to-right",
            from = { 255, 191, 102, 255 }, to = { 244, 116, 105, 255 },
        },
        hoverBackgroundColor = { 255, 205, 125, 255 },
        pressedBackgroundColor = { 226, 103, 91, 255 },
        borderRadius = 15,
        borderWidth = { 1, 1, 4, 1 },
        borderColor = { 255, 222, 157, 220 },
        shadowBlur = 22,
        shadowOffsetY = 9,
        shadowColor = { 232, 105, 91, 105 },
        transition = "scale 0.16s easeOutBack, shadowBlur 0.16s easeOut, backgroundColor 0.16s easeOut",
        onPointerEnter = function(_, widget)
            widget:SetStyle({ scale = 1.035, shadowBlur = 28 })
        end,
        onPointerLeave = function(_, widget)
            widget:SetStyle({ scale = 1.0, shadowBlur = 22 })
        end,
        onClick = function()
            StartOrRestartRun()
        end,
    }

    local portraitPanel = UI.Panel {
        width = "38%",
        minWidth = 238,
        maxWidth = 390,
        height = 390,
        justifyContent = "center",
        alignItems = "center",
        backgroundGradient = {
            type = "radial", innerRadius = 10, outerRadius = 190,
            from = { 116, 220, 211, 58 }, to = { 17, 20, 37, 0 },
        },
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = "94%", height = "94%",
                backgroundImage = "Characters/player.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
        },
    }

    stateOverlay = UI.Panel {
        visible = true,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundGradient = {
            type = "linear", direction = "to-bottom-right",
            from = { 25, 29, 52, 250 }, to = { 7, 8, 19, 252 },
        },
        pointerEvents = "auto",
        children = {
            UI.Panel {
                position = "absolute", top = -140, right = -100,
                width = 430, height = 430, borderRadius = 215,
                backgroundGradient = {
                    type = "radial", innerRadius = 0, outerRadius = 215,
                    from = { 244, 123, 105, 52 }, to = { 244, 123, 105, 0 },
                },
                pointerEvents = "none",
            },
            UI.Panel {
                position = "absolute", bottom = -170, left = -110,
                width = 500, height = 500, borderRadius = 250,
                backgroundGradient = {
                    type = "radial", innerRadius = 0, outerRadius = 250,
                    from = { 76, 205, 205, 42 }, to = { 76, 205, 205, 0 },
                },
                pointerEvents = "none",
            },
            UI.SafeAreaView {
                width = "100%", height = "100%",
                children = {
                    UI.ScrollView {
                        width = "100%", height = "100%",
                        scrollX = false, scrollY = true,
                        showScrollbar = false,
                        children = {
                            UI.Panel {
                                width = "100%", minHeight = "100%",
                                justifyContent = "center", alignItems = "center",
                                padding = { 26, 18, 28, 18 },
                                children = {
                                    UI.Panel {
                                        width = "94%", maxWidth = 1020,
                                        minHeight = 450,
                                        flexDirection = "row", flexWrap = "wrap",
                                        alignItems = "center", justifyContent = "center",
                                        columnGap = 24, rowGap = 10,
                                        padding = { 28, 32, 28, 32 },
                                        borderRadius = 28,
                                        borderWidth = { 1, 1, 4, 1 },
                                        borderColor = { 239, 190, 105, 115 },
                                        backgroundGradient = {
                                            type = "linear", direction = "to-bottom-right",
                                            from = { 39, 42, 65, 228 }, to = { 15, 17, 33, 244 },
                                        },
                                        boxShadow = {
                                            { x = 0, y = 18, blur = 42, spread = 0, color = { 0, 0, 0, 150 } },
                                            { x = 0, y = 1, blur = 2, spread = 0, color = { 255, 229, 180, 26 }, inset = true },
                                        },
                                        children = {
                                            UI.Panel {
                                                width = "55%", minWidth = 270,
                                                flexGrow = 1,
                                                gap = 16,
                                                children = {
                                                    stateKickerLabel,
                                                    stateTitleLabel,
                                                    UI.Divider { width = 86, thickness = 3, color = COLORS.coral, spacing = 1 },
                                                    stateSubtitleLabel,
                                                    UI.Panel {
                                                        flexDirection = "row", flexWrap = "wrap", gap = 8,
                                                        children = {
                                                            UI.Chip { label = "精准弹反", variant = "soft", color = "warning", size = "sm" },
                                                            UI.Chip { label = "反射弹幕", variant = "soft", color = "primary", size = "sm" },
                                                            UI.Chip { label = "净化诅咒", variant = "soft", color = "success", size = "sm" },
                                                        },
                                                    },
                                                    stateActionButton,
                                                    UI.Label {
                                                        text = "WASD 移动  ·  左键招架  ·  回车开始",
                                                        fontSize = 11,
                                                        fontColor = { 177, 184, 207, 205 },
                                                    },
                                                },
                                            },
                                            portraitPanel,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            combatHud,
            chestPanel,
            stateOverlay,
        },
    })
end

local function RefreshChestPanel()
    if chestPanel == nil or game == nil then
        return
    end
    chestPanel:SetVisible(false)
end

local function RefreshStateOverlay()
    if game == nil or stateOverlay == nil then
        return
    end

    local visible = game.state == "menu" or game.state == "dead" or game.state == "victory"
    stateOverlay:SetVisible(visible)
    if not visible then
        return
    end

    if game.state == "menu" then
        stateKickerLabel:SetText("绘本奇幻 · 弹反冒险")
        stateTitleLabel:SetText("弹反之室")
        stateSubtitleLabel:SetText("拨动琴弦般把握节奏，弹回每一枚诅咒，在幽暗房间中收集水晶能力与回响。")
        stateActionButton:SetText("踏入房间")
    elseif game.state == "victory" then
        stateKickerLabel:SetText("诅咒已净化 · 回响仍在延续")
        stateTitleLabel:SetText("晦暗消散")
        stateSubtitleLabel:SetText("最后一段低鸣已经安静。带着这次旅途的节奏，再奏响一轮新的挑战。")
        stateActionButton:SetText("再次挑战")
    else
        stateKickerLabel:SetText("旅途暂歇 · 节奏尚未终止")
        stateTitleLabel:SetText("回响未尽")
        stateSubtitleLabel:SetText("这次失手只是一枚休止符。重新握紧节拍，把袭来的诅咒一一弹回。")
        stateActionButton:SetText("重新踏入")
    end
end

local function UpdateHud()
    if game == nil or healthProgressBar == nil then
        return
    end

    local hud = Game.GetHud(game)
    local hurtPulse = Feedback.GetHudPulse(feedback)
    combatHud:SetVisible(hud.hudVisible)
    healthProgressBar:SetValue(hud.healthRatio)
    healthPanel:SetStyle({
        scale = 1 + 0.035 * hurtPulse,
        borderColor = {
            239,
            math.floor(190 + 38 * hurtPulse),
            math.floor(105 + 40 * hurtPulse),
            math.floor(105 + 95 * hurtPulse),
        },
    })
    if hud.healthRatio <= 0.34 then
        healthProgressBar:SetStyle({
            fillGradient = { direction = "to-right", from = { 169, 34, 67, 255 }, to = { 255, 102, 102, 255 } },
        })
    else
        healthProgressBar:SetStyle({
            fillGradient = { direction = "to-right", from = { 225, 72, 92, 255 }, to = { 255, 177, 100, 255 } },
        })
    end
    roomLabel:SetText(hud.room)
    roomProgressLabel:SetText(hud.roomProgress)
    parryLabel:SetText(hud.parry)
    parryLabel:SetFontColor(hud.parryReady and COLORS.cyan or COLORS.violet)
    parryPanel:SetStyle({
        borderColor = hud.parryReady and { 105, 225, 221, 145 } or { 170, 142, 238, 120 },
        backgroundColor = hud.parryReady and { 15, 38, 48, 225 } or { 31, 25, 51, 225 },
    })
    local combo = hud.combo
    local comboColor = combo.color
    comboLabel:SetText("连击 x" .. tostring(combo.count))
    comboLabel:SetFontColor({ comboColor[1], comboColor[2], comboColor[3], 255 })
    if combo.overdriveRemaining > 0 then
        overdriveLabel:SetText(string.format("超载 %.1fs", combo.overdriveRemaining))
        overdriveLabel:SetFontColor({ 255, 209, 224, 255 })
    else
        overdriveLabel:SetText(combo.tier > 0 and combo.tierName or "蓄势")
        overdriveLabel:SetFontColor({ comboColor[1], comboColor[2], comboColor[3], 220 })
    end
    comboPanel:SetStyle({
        borderColor = { comboColor[1], comboColor[2], comboColor[3], combo.tier > 0 and 165 or 95 },
        backgroundColor = combo.overdriveRemaining > 0 and { 57, 24, 49, 235 } or { 20, 24, 41, 225 },
    })
    buffLabel:SetText(hud.buffs == "暂无临时增益" and "暂无回响" or hud.buffs)
    messagePanel:SetVisible(hud.message ~= "")
    messageLabel:SetText(hud.message)
    gaugeProgressBar:SetValue(hud.gaugeRatio)
    if hud.gaugeRatio <= 0 then
        gaugeStatusLabel:SetText("等待弹反")
    elseif hud.gaugeRatio >= 0.7 then
        gaugeStatusLabel:SetText("回响渐强")
    else
        gaugeStatusLabel:SetText("共鸣聚集中")
    end
    local boss = hud.boss
    bossPanel:SetVisible(boss ~= nil)
    if boss ~= nil then
        bossNameLabel:SetText(boss.name)
        if boss.phase == 1 then
            bossObjectiveLabel:SetText("第一阶段 · 黑影")
            bossProgressBar:SetMax(100)
            bossProgressBar:SetStyle({
                fillGradient = { direction = "to-right", from = { 105, 42, 66, 255 }, to = { 220, 98, 104, 255 } },
            })
            bossProgressBar:SetValue(boss.healthRatio * 100)
        else
            local target = math.max(1, boss.target or 1)
            bossObjectiveLabel:SetText("第二阶段 · " .. (boss.targetName or "净化"))
            bossProgressBar:SetMax(target)
            bossProgressBar:SetStyle({
                fillGradient = { direction = "to-right", from = { 33, 139, 142, 255 }, to = { 231, 183, 91, 255 } },
            })
            bossProgressBar:SetValue(boss.current or 0)
        end
    end
    RefreshChestPanel()
    RefreshStateOverlay()
end

function Start()
    graphics.windowTitle = GameConfig.Title
    math.randomseed(os.time())
    AudioManager.Initialize()
    RefreshCanvasMetrics()

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })
    CreateHud()

    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end
    if nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf") == -1 then
        print("WARNING: Could not load NanoVG font")
    end
    Renderer.LoadAssets(nvgContext)

    game = Game.New()
    feedback = Feedback.New()
    UpdateHud()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseButtonDown")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleNanoVGRender")
end

function Stop()
    AudioManager.Shutdown()
    UI.Shutdown()
    if nvgContext ~= nil then
        Renderer.UnloadAssets(nvgContext)
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if game == nil then
        return
    end

    local dt = eventData:GetFloat("TimeStep")
    local cursor = input:GetMousePosition()
    game.cursorX = cursor.x / devicePixelRatio
    game.cursorY = cursor.y / devicePixelRatio
    local moveX, moveY = 0, 0
    if input:GetKeyDown(KEY_A) then moveX = moveX - 1 end
    if input:GetKeyDown(KEY_D) then moveX = moveX + 1 end
    if input:GetKeyDown(KEY_W) then moveY = moveY - 1 end
    if input:GetKeyDown(KEY_S) then moveY = moveY + 1 end

    Feedback.Update(feedback, dt)
    CrystalRenderer.Update(dt)
    local simulationDt = Feedback.GetSimulationDelta(feedback, dt)
    Game.Update(game, simulationDt, moveX, moveY, dt)
    AudioManager.Update(dt)
    local events = Game.ConsumeEvents(game)
    AudioManager.ProcessEvents(events)
    Feedback.ProcessEvents(feedback, events)
    CrystalRenderer.ProcessEvents(events)
    hudTimer = hudTimer + dt
    if Feedback.GetHudPulse(feedback) > 0 or hudTimer >= 0.08 then
        UpdateHud()
        if hudTimer >= 0.08 then
            hudTimer = hudTimer - 0.08
        end
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    if game == nil then
        return
    end

    local key = eventData:GetInt("Key")
    if game.state == "chest_select" then
        if key == KEY_1 then ChooseChestOption(1) end
        if key == KEY_2 then ChooseChestOption(2) end
        if key == KEY_3 then ChooseChestOption(3) end
        return
    end

    if key == KEY_RETURN and game.state == "menu" then
        Game.StartOrRestart(game)
        return
    end
    if key == KEY_SPACE then
        if game.state == "menu" then
            Game.StartOrRestart(game)
        else
            TryParryAtCursor()
        end
        return
    end
    if key == KEY_R and (game.state == "dead" or game.state == "victory") then
        Game.StartOrRestart(game)
    end
end


---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleMouseButtonDown(eventType, eventData)
    if game == nil or eventData:GetInt("Button") ~= MOUSEB_LEFT then
        return
    end
    local screenX = eventData:GetInt("X") / devicePixelRatio
    local screenY = eventData:GetInt("Y") / devicePixelRatio
    if game.state == "chest_select" then
        local choice = CrystalRenderer.GetChoiceAt(game, logicalWidth, logicalHeight, screenX, screenY)
        if choice ~= nil then
            ChooseChestOption(choice)
        end
        return
    end
    if CrystalRenderer.IsPointerOverStatusIcon(game, logicalWidth, logicalHeight, screenX, screenY) then
        return
    end
    local isBirthTutorial = game.state == "clear" and game.room ~= nil and game.room.isBirthRoom
        and not game.roomCleared
    if game.state ~= "battle" and not isBirthTutorial then
        return
    end

    TryParryAtLogicalPosition(screenX, screenY, true)
end

---@param eventType string
---@param eventData VariantMap
function HandleScreenMode(eventType, eventData)
    RefreshCanvasMetrics()
end

---@param eventType string
---@param eventData VariantMap
function HandleNanoVGRender(eventType, eventData)
    if nvgContext == nil or game == nil then
        return
    end

    nvgBeginFrame(nvgContext, logicalWidth, logicalHeight, devicePixelRatio)
    Renderer.Draw(nvgContext, game, logicalWidth, logicalHeight, feedback)
    CrystalRenderer.Draw(nvgContext, game, logicalWidth, logicalHeight)
    nvgEndFrame(nvgContext)
end
