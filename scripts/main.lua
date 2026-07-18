-- 弹反之室：原生 NanoVG 负责游戏画面，UI 组件负责响应式中文 HUD 与宝箱选择。

local UI = require("urhox-libs/UI")
local AudioManager = require "AudioManager"
local GameConfig = require "Data.GameConfig"
local Feedback = require "Feedback"
local Game = require "Game"
local Renderer = require "Renderer"

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
local healthLabel = nil
---@type Widget|nil
local roomLabel = nil
---@type Widget|nil
local parryLabel = nil
---@type Widget|nil
local buffLabel = nil
---@type Widget|nil
local abilityLabel = nil
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
local chestTitleLabels = {}
local chestDescriptionLabels = {}
local chestIconLabels = {}
local chestCards = {}
local chestAccentPanels = {}
local chestIconPanels = {}

local CHEST_CARD_IDLE_ROTATIONS = { 0, 0, 0 }
local CHEST_CARD_IDLE_DURATIONS = { 3.4, 3.8, 3.6 }
local CHEST_CARD_MAX_POINTER_TILT = 2.2

local function RefreshCanvasMetrics()
    physicalWidth = graphics:GetWidth()
    physicalHeight = graphics:GetHeight()
    devicePixelRatio = graphics:GetDPR()
    logicalWidth = physicalWidth / devicePixelRatio
    logicalHeight = physicalHeight / devicePixelRatio
end

local function ChooseChestOption(index)
    if game ~= nil and Game.SelectUpgrade(game, index) then
        hudTimer = 1.0
    end
end

local function StartChestCardIdle(card)
    local idleRotation = card.state.idleRotation or 0
    local idleDuration = card.state.idleDuration or 3.0
    local iconPanel = card.state.iconPanel

    card:Animate({
        keyframes = {
            [0] = { scale = 1.0, translateY = 0, rotate = idleRotation },
            [0.5] = { scale = 1.006, translateY = -2, rotate = idleRotation },
            [1] = { scale = 1.0, translateY = 0, rotate = idleRotation },
        },
        duration = idleDuration,
        easing = "easeInOut",
        loop = true,
        fillMode = "both",
    })

    if iconPanel ~= nil then
        iconPanel:Animate({
            keyframes = {
                [0] = { scale = 1.0, translateY = 0, rotate = 0 },
                [0.5] = { scale = 1.012, translateY = -1, rotate = 0 },
                [1] = { scale = 1.0, translateY = 0, rotate = 0 },
            },
            duration = idleDuration * 0.9,
            easing = "easeInOut",
            loop = true,
            fillMode = "both",
        })
    end
end

local function GetChestCardPointerTilt(card, event)
    if event == nil then
        return 0
    end

    local layout = card:GetAbsoluteLayout()
    if layout.w <= 0 then
        return 0
    end

    local normalizedX = (event.x - layout.x) / layout.w * 2 - 1
    normalizedX = math.max(-1, math.min(1, normalizedX))
    return normalizedX * CHEST_CARD_MAX_POINTER_TILT
end

local function UpdateChestCardHoverTilt(card, event)
    if not card.state.hovered then
        return
    end

    local hoverRotation = GetChestCardPointerTilt(card, event)
    card:SetState({ hoverRotation = hoverRotation })
    card:SetStyle({ rotate = hoverRotation })
    if card.state.iconPanel ~= nil then
        card.state.iconPanel:SetStyle({ rotate = -hoverRotation * 0.28 })
    end
end

local function SetChestCardHover(card, hovered, event)
    local accentColor = card.state.accentColor or { 236, 202, 105 }
    local borderColor = card.state.borderColor or { accentColor[1], accentColor[2], accentColor[3], 210 }
    local iconBorderColor = card.state.iconBorderColor or { accentColor[1], accentColor[2], accentColor[3], 190 }
    local idleRotation = card.state.idleRotation or 0
    local iconPanel = card.state.iconPanel

    if hovered then
        local hoverRotation = GetChestCardPointerTilt(card, event)
        card:SetState({ hovered = true, hoverRotation = hoverRotation })
        card:StopAnimation()
        if iconPanel ~= nil then
            iconPanel:StopAnimation()
        end
        card:SetStyle({
            borderColor = { math.min(255, accentColor[1] + 22), math.min(255, accentColor[2] + 22), math.min(255, accentColor[3] + 22), 255 },
            shadowBlur = 30,
            shadowOffsetY = 14,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 125 },
        })
        card:Animate({
            keyframes = {
                [0] = { scale = 1.0, translateY = 0, rotate = idleRotation },
                [1] = { scale = 1.045, translateY = -13, rotate = hoverRotation },
            },
            duration = 0.18,
            easing = "easeOutBack",
            fillMode = "forwards",
        })
        if iconPanel ~= nil then
            iconPanel:SetStyle({
                borderColor = { math.min(255, accentColor[1] + 28), math.min(255, accentColor[2] + 28), math.min(255, accentColor[3] + 28), 255 },
                shadowBlur = 20,
                shadowColor = { accentColor[1], accentColor[2], accentColor[3], 145 },
            })
            iconPanel:Animate({
                keyframes = {
                    [0] = { scale = 1.0, translateY = 0, rotate = 0 },
                    [1] = { scale = 1.08, translateY = -3, rotate = -hoverRotation * 0.28 },
                },
                duration = 0.18,
                easing = "easeOutBack",
                fillMode = "forwards",
            })
        end
        return
    end

    card:SetState({ hovered = false })
    local hoverRotation = card.state.hoverRotation or 0
    card:StopAnimation()
    if iconPanel ~= nil then
        iconPanel:StopAnimation()
    end
    card:SetStyle({
        borderColor = borderColor,
        shadowBlur = 18,
        shadowOffsetY = 7,
        shadowColor = { 0, 0, 0, 175 },
    })
    card:Animate({
        keyframes = {
            [0] = { scale = 1.045, translateY = -13, rotate = hoverRotation },
            [1] = { scale = 1.0, translateY = 0, rotate = idleRotation },
        },
        duration = 0.22,
        easing = "easeInOut",
        fillMode = "forwards",
        onComplete = function()
            card:SetState({ resumeIdle = true })
        end,
    })
    if iconPanel ~= nil then
        iconPanel:SetStyle({
            borderColor = iconBorderColor,
            shadowBlur = 12,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 78 },
        })
        iconPanel:Animate({
            keyframes = {
                [0] = { scale = 1.08, translateY = -3, rotate = -hoverRotation * 0.28 },
                [1] = { scale = 1.0, translateY = 0, rotate = 0 },
            },
            duration = 0.22,
            easing = "easeInOut",
            fillMode = "forwards",
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
        transition = "rotate 0.10s easeOut",
        pointerEvents = "none",
        children = { icon },
    }
    local title = UI.Label {
        text = "强化名称",
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
        text = "强化说明",
        width = "100%",
        fontSize = 13,
        textAlign = "center",
        whiteSpace = "normal",
        wordBreak = "break-word",
        maxLines = 4,
        lineHeight = 1.35,
        fontColor = { 216, 218, 221, 225 },
    }
    local card = UI.Panel {
        width = 226,
        minWidth = 196,
        aspectRatio = 2 / 3,
        minHeight = 294,
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
        transition = "rotate 0.10s easeOut, borderColor 0.18s easeOut, shadowBlur 0.18s easeOut, shadowOffsetY 0.18s easeOut, shadowColor 0.18s easeOut",
        onPointerEnter = function(event, widget)
            SetChestCardHover(widget, true, event)
        end,
        onPointerMove = function(event, widget)
            UpdateChestCardHoverTilt(widget, event)
        end,
        onPointerLeave = function(event, widget)
            SetChestCardHover(widget, false)
        end,
        onClick = function()
            ChooseChestOption(optionIndex)
        end,
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

    chestTitleLabels[index] = title
    chestDescriptionLabels[index] = description
    chestIconLabels[index] = icon
    chestCards[index] = card
    chestAccentPanels[index] = accent
    chestIconPanels[index] = iconPanel
    card:SetState({
        idleRotation = CHEST_CARD_IDLE_ROTATIONS[optionIndex],
        hoverRotation = 0,
        idleDuration = CHEST_CARD_IDLE_DURATIONS[optionIndex],
        iconPanel = iconPanel,
        hovered = false,
    })
    return card
end

local function CreateHud()
    healthLabel = UI.Label {
        text = "生命 ●●●",
        fontSize = 21,
        fontColor = { 255, 132, 154, 255 },
    }
    roomLabel = UI.Label {
        text = "尚未开始",
        fontSize = 14,
        fontColor = { 232, 237, 255, 245 },
    }
    parryLabel = UI.Label {
        text = "招架 就绪",
        fontSize = 14,
        fontColor = { 130, 232, 255, 255 },
    }
    buffLabel = UI.Label {
        text = "暂无临时增益",
        fontSize = 11,
        textAlign = "right",
        whiteSpace = "normal",
        fontColor = { 132, 244, 184, 240 },
    }
    abilityLabel = UI.Label {
        text = "暂无强化",
        fontSize = 11,
        textAlign = "right",
        whiteSpace = "normal",
        fontColor = { 197, 175, 255, 235 },
    }
    bossNameLabel = UI.Label {
        text = "晦暗低鸣", width = "100%", fontSize = 15, fontWeight = "bold",
        textAlign = "center", fontColor = { 238, 221, 203, 255 },
    }
    bossObjectiveLabel = UI.Label {
        text = "第一阶段 · 黑影", width = "100%", fontSize = 11,
        textAlign = "center", fontColor = { 201, 190, 214, 235 },
    }
    bossProgressBar = UI.ProgressBar {
        value = 100, max = 100, width = "100%", height = 8, borderRadius = 4,
        fillGradient = {
            direction = "to-right", from = { 105, 42, 66, 255 }, to = { 220, 98, 104, 255 },
        },
        transition = "value 0.16s easeOut",
    }
    bossPanel = UI.Panel {
        visible = false, width = "44%", maxWidth = 430, minWidth = 250,
        padding = { 7, 12, 8, 12 }, gap = 4, borderRadius = 4,
        borderWidth = 1, borderColor = { 126, 105, 132, 145 },
        backgroundColor = { 13, 12, 20, 205 }, pointerEvents = "none",
        children = { bossNameLabel, bossObjectiveLabel, bossProgressBar },
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
        backgroundColor = { 7, 7, 18, 218 },
        backdropBlur = 8,
        pointerEvents = "auto",
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                children = {
                    UI.Label {
                        text = "遗物抉择",
                        position = "absolute",
                        top = 22,
                        left = 0,
                        right = 0,
                        fontSize = 27,
                        fontWeight = "bold",
                        textAlign = "center",
                        textStroke = { width = 1, color = { 18, 18, 20, 240 } },
                        fontColor = { 246, 235, 199, 255 },
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

    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                pointerEvents = "box-none",
                children = {
                    UI.Panel {
                        position = "absolute",
                        top = 16,
                        left = 18,
                        gap = 3,
                        pointerEvents = "none",
                        children = { healthLabel, roomLabel },
                    },
                    UI.Panel {
                        position = "absolute",
                        top = 16,
                        right = 18,
                        alignItems = "flex-end",
                        gap = 3,
                        pointerEvents = "none",
                        children = { parryLabel, buffLabel, abilityLabel },
                    },
                    UI.Panel {
                        position = "absolute", top = 42, left = 0, right = 0,
                        alignItems = "center", pointerEvents = "none", children = { bossPanel },
                    },
                    UI.Label {
                        text = "WASD 移动   空格招架   量表充满后获得短时增益",
                        position = "absolute",
                        bottom = 14,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                        fontSize = 11,
                        fontColor = { 212, 215, 245, 175 },
                        pointerEvents = "none",
                    },
                },
            },
            chestPanel,
        },
    })
end

local function RefreshChestPanel()
    if chestPanel == nil or game == nil then
        return
    end

    local isChoosing = game.state == "chest_select"
    chestPanel:SetVisible(isChoosing)
    if not isChoosing then
        if chestPanelWasVisible then
            for _, card in ipairs(chestCards) do
                card:StopAnimation()
                card:SetStyle({ scale = 1.0, translateY = 0, rotate = card.state.idleRotation or 0 })
                if card.state.iconPanel ~= nil then
                    card.state.iconPanel:StopAnimation()
                    card.state.iconPanel:SetStyle({ scale = 1.0, translateY = 0, rotate = 0 })
                end
            end
        end
        chestPanelWasVisible = false
        return
    end

    for index = 1, 3 do
        local option = game.chestOptions and game.chestOptions[index] or nil
        local card = chestCards[index]
        card:SetVisible(option ~= nil)
        if option ~= nil then
            local color = option.color or { 236, 202, 105 }
            if not chestPanelWasVisible or card.state.optionId ~= option.id then
                local borderColor = { color[1], color[2], color[3], 220 }
                card:SetState({
                    optionId = option.id,
                    accentColor = color,
                    borderColor = borderColor,
                    iconBorderColor = { color[1], color[2], color[3], 190 },
                    hovered = false,
                    resumeIdle = false,
                })
                chestTitleLabels[index]:SetText(option.name)
                chestDescriptionLabels[index]:SetText(option.description)
                chestIconLabels[index]:SetText(option.icon or "✦")
                chestTitleLabels[index]:SetFontColor({ color[1], color[2], color[3], 255 })
                chestIconLabels[index]:SetFontColor({ color[1], color[2], color[3], 255 })
                chestAccentPanels[index]:SetStyle({ backgroundColor = { color[1], color[2], color[3], 255 } })
                chestIconPanels[index]:SetStyle({
                    borderColor = { color[1], color[2], color[3], 190 },
                    shadowColor = { color[1], color[2], color[3], 78 },
                    scale = 1.0,
                    translateY = 0,
                    rotate = 0,
                })
                card:SetStyle({
                    borderColor = borderColor,
                    shadowBlur = 18,
                    shadowOffsetY = 7,
                    shadowColor = { 0, 0, 0, 175 },
                    scale = 1.0,
                    translateY = 0,
                    rotate = card.state.idleRotation or 0,
                })
                StartChestCardIdle(card)
            end
            if card.state.resumeIdle then
                card:SetState({ resumeIdle = false })
                StartChestCardIdle(card)
            end
        end
    end
    chestPanelWasVisible = true
end

local function UpdateHud()
    if game == nil or healthLabel == nil then
        return
    end

    local hud = Game.GetHud(game)
    local hurtPulse = Feedback.GetHudPulse(feedback)
    healthLabel:SetText(hud.health)
    healthLabel:SetFontColor({ 255, math.floor(132 + 92 * hurtPulse), math.floor(154 + 76 * hurtPulse), 255 })
    healthLabel:SetStyle({ scale = 1 + 0.08 * hurtPulse })
    roomLabel:SetText(hud.room)
    parryLabel:SetText(hud.parry)
    buffLabel:SetText("临时增益\n" .. hud.buffs)
    abilityLabel:SetText("构筑\n" .. hud.upgrades)
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
end

function Start()
    graphics.windowTitle = GameConfig.Title
    math.randomseed(os.time())
    AudioManager.Initialize()
    RefreshCanvasMetrics()

    UI.Init({
        theme = "default-dark",
        fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } },
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
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleNanoVGRender")
    print("弹反之室准备完成：按回车开始")
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
    local moveX, moveY = 0, 0
    if input:GetKeyDown(KEY_A) then moveX = moveX - 1 end
    if input:GetKeyDown(KEY_D) then moveX = moveX + 1 end
    if input:GetKeyDown(KEY_W) then moveY = moveY - 1 end
    if input:GetKeyDown(KEY_S) then moveY = moveY + 1 end

    Feedback.Update(feedback, dt)
    local simulationDt = Feedback.GetSimulationDelta(feedback, dt)
    Game.Update(game, simulationDt, moveX, moveY, dt)
    AudioManager.Update(dt)
    local events = Game.ConsumeEvents(game)
    AudioManager.ProcessEvents(events)
    Feedback.ProcessEvents(feedback, events)
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

    if key == KEY_F1 then
        Game.ToggleDebug(game)
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
            Game.TryParry(game)
        end
        return
    end
    if key == KEY_R and (game.state == "dead" or game.state == "victory") then
        Game.StartOrRestart(game)
    end
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
    nvgEndFrame(nvgContext)
end
