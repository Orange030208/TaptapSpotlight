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
local chestPanelIsFadingOut = false
local feedback = nil

---@type Widget|nil
local combatHud = nil
---@type Widget|nil
local healthPanel = nil
---@type ProgressBar|nil
local healthProgressBar = nil
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
---@type Widget|nil
local creditsOverlay = nil
---@type Widget|nil
local creditsPanel = nil
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
    panelTop = { 28, 55, 104, 246 },
    panelBottom = { 9, 18, 38, 250 },
    cream = { 246, 250, 255, 255 },
    muted = { 188, 210, 239, 238 },
    gold = { 255, 199, 58, 255 },
    coral = { 255, 82, 92, 255 },
    cyan = { 54, 207, 255, 255 },
    violet = { 204, 80, 255, 255 },
    border = { 6, 12, 27, 255 },
    surface = { 19, 48, 101, 246 },
    surfaceDeep = { 8, 22, 52, 250 },
}

local HUD_SHADOW = {
    { x = 6, y = 6, blur = 0, spread = 0, color = { 0, 0, 0, 78 } },
}

local EchoCombatTheme = UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
    fonts = {
        { family = "sans", weights = {
            normal = "Fonts/XiaoLangTianQiong.ttf",
            bold = "Fonts/XiaoLangTianQiong.ttf",
        } },
    },
    colors = {
        primary = { 31, 162, 255, 255 },
        primaryHover = { 70, 183, 255, 255 },
        primaryPressed = { 13, 126, 230, 255 },
        secondary = { 204, 80, 255, 255 },
        secondaryHover = { 220, 112, 255, 255 },
        secondaryPressed = { 157, 42, 207, 255 },
        background = { 8, 22, 52, 255 },
        surface = { 19, 48, 101, 255 },
        surfaceHover = { 30, 75, 145, 255 },
        text = { 246, 250, 255, 255 },
        textSecondary = { 188, 210, 239, 255 },
        border = { 6, 12, 27, 255 },
        borderFocus = { 101, 232, 255, 255 },
        success = { 69, 226, 157, 255 },
        warning = { 255, 199, 58, 255 },
        error = { 255, 82, 92, 255 },
        info = { 54, 207, 255, 255 },
        overlay = { 4, 10, 25, 210 },
    },
    componentDefaults = {
        borderRadius = 0,
        fontWeight = "bold",
    },
    components = {
        Button = {
            borderRadius = 0,
            borderWidth = { 2, 4, 5, 2 },
            borderColor = { 6, 12, 27, 255 },
            fontWeight = "bold",
            boxShadow = HUD_SHADOW,
        },
        Card = {
            borderRadius = 0,
            borderWidth = 2,
            boxShadow = HUD_SHADOW,
        },
        Chip = { borderRadius = 0, borderWidth = 2, fontWeight = "bold" },
        ProgressBar = { borderRadius = 0, height = 10 },
    },
})

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

local function ShowCredits()
    if creditsOverlay == nil or creditsPanel == nil then
        return
    end

    creditsOverlay:SetVisible(true)
    creditsPanel:Animate({
        keyframes = {
            [0] = { opacity = 0, scale = 0.94, translateY = 28 },
            [1] = { opacity = 1, scale = 1.0, translateY = 0 },
        },
        duration = 0.48,
        easing = "easeOutCubic",
        fillMode = "both",
    })
end

local function HideCredits()
    if creditsOverlay == nil then
        return
    end
    creditsOverlay:SetVisible(false)
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
        height = 5,
        backgroundColor = COLORS.gold,
        pointerEvents = "none",
    }
    local icon = UI.Label {
        text = "✦",
        width = "100%",
        fontSize = 46,
        fontWeight = "bold",
        textAlign = "center",
        verticalAlign = "middle",
        fontColor = COLORS.gold,
        textShadow = { offsetX = 3, offsetY = 3, blur = 0, color = { 0, 0, 0, 185 } },
    }
    local iconPanel = UI.Panel {
        width = 88,
        height = 88,
        alignSelf = "center",
        justifyContent = "center",
        alignItems = "center",
        borderRadius = 0,
        borderWidth = { 2, 4, 5, 2 },
        borderColor = { 31, 162, 255, 220 },
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom-right",
            from = { 30, 81, 151, 255 },
            to = { 9, 26, 61, 255 },
        },
        shadowBlur = 0,
        shadowOffsetX = 5,
        shadowOffsetY = 5,
        shadowColor = { 0, 0, 0, 115 },
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
        borderRadius = 0,
        borderWidth = { 2, 4, 6, 2 },
        borderColor = { 31, 162, 255, 220 },
        overflow = "hidden",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom-right",
            from = { 28, 66, 126, 254 },
            to = { 7, 18, 43, 254 },
        },
        shadowBlur = 0,
        shadowOffsetX = 8,
        shadowOffsetY = 8,
        shadowColor = { 0, 0, 0, 150 },
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
        flexGrow = 1,
        flexBasis = 0,
        showLabel = false,
        borderRadius = 0,
        borderWidth = 2,
        borderColor = COLORS.border,
        backgroundColor = { 4, 12, 30, 235 },
        fillGradient = {
            direction = "to-right",
            from = { 225, 72, 92, 255 },
            to = { 255, 177, 100, 255 },
        },
        transition = "value 0.18s easeOut",
    }
    healthPanel = UI.Panel {
        width = "40%",
        minWidth = 150,
        maxWidth = 282,
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = 20,
                height = 20,
                flexShrink = 0,
                backgroundImage = "image/ui/heart.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                children = { healthProgressBar },
            },
        },
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
        width = 178,
        padding = { 8, 12, 10, 12 },
        borderRadius = 0,
        borderWidth = { 2, 4, 5, 2 },
        borderColor = { 31, 162, 255, 185 },
        backgroundGradient = {
            type = "linear", direction = "to-bottom-right",
            from = { 29, 78, 147, 242 }, to = { 8, 22, 52, 248 },
        },
        boxShadow = HUD_SHADOW,
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
        value = 100, max = 100, width = "100%", height = 14, borderRadius = 5,
        showLabel = false,
        backgroundColor = { 184, 45, 45, 255 },
        borderColor = { 20, 20, 20, 255 }, borderWidth = 2,
        fillGradient = {
            direction = "to-right", from = { 48, 166, 58, 255 }, to = { 88, 221, 80, 255 },
        },
        transition = "value 0.16s easeOut",
    }
    bossPanel = UI.Panel {
        visible = false, width = "52%", maxWidth = 500, minWidth = 240,
        padding = { 10, 18, 13, 18 }, gap = 5, borderRadius = 0,
        borderWidth = { 2, 4, 6, 2 }, borderColor = { 204, 80, 255, 195 },
        backgroundGradient = {
            type = "linear", direction = "to-bottom-right",
            from = { 55, 32, 96, 246 }, to = { 8, 18, 44, 250 },
        },
        boxShadow = HUD_SHADOW,
        pointerEvents = "none",
        children = { bossNameLabel, bossObjectiveLabel, bossProgressBar },
    }

    gaugeProgressBar = UI.ProgressBar {
        value = 0,
        max = 1,
        width = "100%",
        height = 10,
        showLabel = false,
        borderRadius = 5,
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
        width = "40%",
        minWidth = 150,
        maxWidth = 282,
        paddingLeft = 28,
        pointerEvents = "none",
        children = { gaugeProgressBar },
    }

    local insightPanel = UI.Panel {
        width = "40%",
        minWidth = 150,
        maxWidth = 282,
        padding = { 10, 13, 12, 13 },
        gap = 6,
        borderRadius = 0,
        borderWidth = { 2, 4, 5, 2 },
        borderColor = { 204, 80, 255, 145 },
        backgroundGradient = {
            type = "linear", direction = "to-bottom-left",
            from = { 46, 45, 111, 242 }, to = { 8, 20, 48, 248 },
        },
        boxShadow = HUD_SHADOW,
        pointerEvents = "none",
        children = {
            UI.Label { text = "临时回响", fontSize = 9, letterSpacing = 1, fontColor = { 112, 225, 175, 220 } },
            buffLabel,
        },
    }

    combatHud = UI.SafeAreaView {
        visible = false,
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute", top = 14, left = 16,
                width = "100%", gap = 6, pointerEvents = "box-none",
                children = { healthPanel, gaugePanel },
            },
            UI.Panel {
                position = "absolute", top = 30, left = 0, right = 0,
                alignItems = "center", pointerEvents = "none", children = { bossPanel },
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
            from = { 24, 64, 126, 236 }, to = { 3, 10, 27, 250 },
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
        text = "弹反之室",
        fontSize = 12,
        fontWeight = "bold",
        letterSpacing = 2,
        fontColor = { 255, 255, 255, 255 },
    }
    stateTitleLabel = UI.Label {
        text = "回响之森",
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
        text = "在幽暗房间中把握节奏，弹回每一枚袭来的诅咒。",
        width = "100%",
        maxWidth = 500,
        fontSize = 16,
        lineHeight = 1.5,
        whiteSpace = "normal",
        fontColor = { 214, 219, 235, 245 },
    }
    stateActionButton = UI.Button {
        text = "开始游戏",
        variant = "primary",
        width = 220,
        height = 54,
        fontSize = 16,
        textColor = COLORS.cream,
        backgroundGradient = {
            type = "linear", direction = "to-right",
            from = { 31, 162, 255, 255 }, to = { 42, 105, 222, 255 },
        },
        hoverBackgroundColor = { 70, 183, 255, 255 },
        pressedBackgroundColor = { 13, 126, 230, 255 },
        borderRadius = 0,
        borderWidth = { 2, 4, 6, 2 },
        borderColor = COLORS.border,
        shadowBlur = 0,
        shadowOffsetX = 7,
        shadowOffsetY = 7,
        shadowColor = { 0, 0, 0, 110 },
        transition = "scale 0.12s easeOutBack, translateY 0.12s easeOut, backgroundColor 0.12s easeOut",
        onPointerEnter = function(_, widget)
            widget:SetStyle({ scale = 1.025, translateY = -2 })
        end,
        onPointerLeave = function(_, widget)
            widget:SetStyle({ scale = 1.0, translateY = 0 })
        end,
        onClick = function()
            StartOrRestartRun()
        end,
    }

    stateOverlay = UI.Panel {
        visible = true,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundImage = "image/forest_room.png",
        backgroundFit = "cover",
        backgroundColor = { 4, 10, 20, 188 },
        pointerEvents = "auto",
        children = {
            UI.SafeAreaView {
                width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        position = "absolute", top = 24, left = 28,
                        gap = 2, pointerEvents = "none",
                        children = {
                            stateKickerLabel,
                            UI.Label { text = "ECHO CHAMBER", fontSize = 10, letterSpacing = 3, fontColor = { 210, 227, 243, 220 } },
                        },
                    },
                    UI.Panel {
                        width = "100%", height = "100%", justifyContent = "center", alignItems = "center",
                        pointerEvents = "box-none",
                        children = {
                            UI.Panel {
                                width = "86%", maxWidth = 500, alignItems = "center", gap = 18,
                                pointerEvents = "auto",
                                children = {
                                    stateTitleLabel,
                                    stateSubtitleLabel,
                                    stateActionButton,
                                    UI.Button {
                                        text = "开发者名单", variant = "secondary", width = 220, height = 46,
                                        onClick = function() ShowCredits() end,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    creditsPanel = UI.Panel {
        width = "82%", maxWidth = 430, padding = { 34, 34, 30, 34 }, gap = 16,
        alignItems = "center", borderWidth = 2, borderColor = { 255, 255, 255, 126 },
        backgroundColor = { 0, 0, 0, 238 },
        children = {
            UI.Label { text = "开发者名单", fontSize = 24, fontWeight = "bold", fontColor = COLORS.cream },
            UI.Divider { width = 84, thickness = 2, color = { 255, 255, 255, 160 } },
            UI.Label {
                text = "策划：Sen\n程序：Orange\n美术：wooji", fontSize = 18, lineHeight = 1.9,
                textAlign = "center", fontColor = { 237, 239, 245, 255 },
            },
            UI.Button { text = "关闭", variant = "secondary", width = 132, height = 42, onClick = function() HideCredits() end },
        },
    }
    creditsOverlay = UI.Panel {
        visible = false, position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center", backgroundColor = { 0, 0, 0, 186 }, pointerEvents = "auto",
        children = { creditsPanel },
    }

    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            combatHud,
            chestPanel,
            stateOverlay,
            creditsOverlay,
        },
    })
end

local function RefreshChestPanel()
    if chestPanel == nil or game == nil then
        return
    end

    local shouldShow = game.state == "chest_select" and game.chestOptions ~= nil
    if shouldShow then
        if not chestPanelWasVisible then
            for index, definition in ipairs(game.chestOptions) do
                local color = definition.color
                chestTitleLabels[index]:SetText(definition.name)
                chestTitleLabels[index]:SetFontColor({ color[1], color[2], color[3], 255 })
                chestDescriptionLabels[index]:SetText(definition.shortDescription)
                chestIconLabels[index]:SetFontColor({ color[1], color[2], color[3], 255 })
                chestAccentPanels[index]:SetStyle({ backgroundColor = { color[1], color[2], color[3], 255 } })
                chestCards[index]:SetState({
                    accentColor = color,
                    borderColor = { color[1], color[2], color[3], 210 },
                    iconBorderColor = { color[1], color[2], color[3], 190 },
                })
                SetChestCardRest(chestCards[index])
            end

            chestPanelWasVisible = true
            chestPanelIsFadingOut = false
            chestPanel:SetVisible(true)
            chestPanel:Animate({
                keyframes = {
                    [0] = { opacity = 0 },
                    [1] = { opacity = 1 },
                },
                duration = 0.28,
                easing = "easeOutCubic",
                fillMode = "both",
            })
            for index, card in ipairs(chestCards) do
                StartChestCardEntrance(card, index)
                StartChestCardIdle(card)
            end
            print("[UI] Enhancement cards fading in")
        end
        return
    end

    if chestPanelWasVisible and not chestPanelIsFadingOut then
        chestPanelWasVisible = false
        chestPanelIsFadingOut = true
        chestPanel:Animate({
            keyframes = {
                [0] = { opacity = 1 },
                [1] = { opacity = 0 },
            },
            duration = 0.24,
            easing = "easeOutCubic",
            fillMode = "both",
            onComplete = function()
                chestPanelIsFadingOut = false
                if game == nil or game.state ~= "chest_select" then
                    chestPanel:SetVisible(false)
                end
            end,
        })
        print("[UI] Enhancement cards fading out")
    elseif not chestPanelIsFadingOut then
        chestPanel:SetVisible(false)
    end
end

local function RefreshStateOverlay()
    if game == nil or stateOverlay == nil then
        return
    end

    local visible = game.state == "menu" or game.state == "dead"
    stateOverlay:SetVisible(visible)
    if not visible then
        return
    end

    if game.state == "menu" then
        stateKickerLabel:SetText("弹反之室")
        stateTitleLabel:SetText("回响之森")
        stateSubtitleLabel:SetText("在幽暗房间中把握节奏，弹回每一枚袭来的诅咒。")
        stateActionButton:SetText("开始游戏")
    else
        stateKickerLabel:SetText("旅途暂歇 · 节奏尚未终止")
        stateTitleLabel:SetText("回响未尽")
        stateSubtitleLabel:SetText("这次失手只是一枚休止符。重新握紧节拍，把袭来的诅咒一一弹回。")
        stateActionButton:SetText("重新踏入")
    end
    if not visible then
        HideCredits()
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
    gaugeProgressBar:SetValue(hud.gaugeRatio)
    local boss = hud.boss
    bossPanel:SetVisible(boss ~= nil)
    if boss ~= nil then
        bossNameLabel:SetText(boss.name)
        if boss.phase == 1 then
            bossObjectiveLabel:SetText("第一阶段 · 黑影")
            bossProgressBar:SetMax(100)
            bossProgressBar:SetStyle({
                backgroundColor = { 184, 45, 45, 255 },
                borderColor = { 20, 20, 20, 255 },
                fillGradient = { direction = "to-right", from = { 48, 166, 58, 255 }, to = { 88, 221, 80, 255 } },
            })
            bossProgressBar:SetValue(boss.healthRatio * 100)
        else
            local target = math.max(1, boss.target or 1)
            bossObjectiveLabel:SetText("第二阶段 · " .. (boss.targetName or "净化"))
            bossProgressBar:SetMax(target)
            bossProgressBar:SetStyle({
                backgroundColor = { 8, 8, 17, 220 },
                borderColor = { 243, 190, 126, 95 },
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
    AudioManager.PlayMusic(0.30)
    RefreshCanvasMetrics()

    UI.Init({
        theme = EchoCombatTheme,
        scale = UI.Scale.DEFAULT,
    })
    CreateHud()

    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end
    if nvgCreateFont(nvgContext, "sans", "Fonts/XiaoLangTianQiong.ttf") == -1 then
        print("WARNING: Could not load NanoVG font")
    end
    Renderer.LoadAssets(nvgContext)
    CrystalRenderer.LoadAssets(nvgContext)

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
        CrystalRenderer.UnloadAssets(nvgContext)
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
    if game.state == "victory" then
        local fade = math.max(0, math.min(1, (game.victoryElapsed or 0) / 2.4))
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, 0, 0, logicalWidth, logicalHeight)
        nvgFillColor(nvgContext, nvgRGBA(0, 0, 0, math.floor(255 * fade)))
        nvgFill(nvgContext)
        if fade > 0.35 then
            nvgFontFace(nvgContext, "sans")
            nvgFontSize(nvgContext, math.max(26, math.min(46, logicalWidth * 0.052)))
            nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvgContext, nvgRGBA(255, 255, 255, math.floor(255 * math.min(1, (fade - 0.35) / 0.45))))
            nvgText(nvgContext, logicalWidth * 0.5, logicalHeight * 0.38, "感谢游玩")
        end
    end
    nvgEndFrame(nvgContext)
end
