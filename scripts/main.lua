-- 弹反之室：原生 NanoVG 负责游戏画面，UI 组件负责响应式中文 HUD 与宝箱选择。

local UI = require("urhox-libs/UI")
local AudioManager = require "AudioManager"
local Config = require "Config"
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
local chestPanel = nil
local chestTitleLabels = {}
local chestDescriptionLabels = {}
local chestIconLabels = {}
local chestCards = {}
local chestAccentPanels = {}
local chestIconPanels = {}

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

local function SetChestCardHover(card, hovered)
    local accentColor = card.state.accentColor or { 236, 202, 105 }
    local borderColor = card.state.borderColor or { accentColor[1], accentColor[2], accentColor[3], 210 }
    if hovered then
        card:SetStyle({
            scale = 1.035,
            translateY = -8,
            borderColor = { math.min(255, accentColor[1] + 22), math.min(255, accentColor[2] + 22), math.min(255, accentColor[3] + 22), 255 },
            shadowBlur = 30,
            shadowOffsetY = 14,
            shadowColor = { accentColor[1], accentColor[2], accentColor[3], 125 },
        })
        return
    end

    card:SetStyle({
        scale = 1.0,
        translateY = 0,
        borderColor = borderColor,
        shadowBlur = 18,
        shadowOffsetY = 7,
        shadowColor = { 0, 0, 0, 175 },
    })
end

local function CreateChestCard(index)
    local optionIndex = index
    local accent = UI.Panel {
        width = "100%",
        height = 3,
        borderRadius = 2,
        backgroundColor = { 236, 202, 105, 255 },
    }
    local choiceLabel = UI.Label {
        text = "遗物 " .. string.format("%02d", optionIndex),
        fontSize = 11,
        fontWeight = "bold",
        fontColor = { 205, 207, 209, 220 },
    }
    local categoryLabel = UI.Label {
        text = "战斗强化",
        fontSize = 10,
        fontColor = { 176, 179, 183, 195 },
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
        transition = "scale 0.18s easeOut, translateY 0.18s easeOut, borderColor 0.18s easeOut, shadowBlur 0.18s easeOut, shadowOffsetY 0.18s easeOut, shadowColor 0.18s easeOut",
        onPointerEnter = function(event, widget)
            SetChestCardHover(widget, true)
        end,
        onPointerLeave = function(event, widget)
            SetChestCardHover(widget, false)
        end,
        onClick = function()
            ChooseChestOption(optionIndex)
        end,
        children = {
            accent,
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = { choiceLabel, categoryLabel },
            },
            iconPanel,
            title,
            UI.Divider {
                width = "100%",
                color = { 255, 255, 255, 42 },
                spacing = 0,
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
                padding = { 20, 18, 16, 18 },
                alignItems = "center",
                gap = 14,
                children = {
                    UI.Panel {
                        width = "100%",
                        maxWidth = 900,
                        alignItems = "center",
                        gap = 4,
                        children = {
                            UI.Label {
                                text = "遗物抉择",
                                fontSize = 27,
                                fontWeight = "bold",
                                textStroke = { width = 1, color = { 18, 18, 20, 240 } },
                                fontColor = { 246, 235, 199, 255 },
                            },
                            UI.Label {
                                text = "一项强化，将成为这场战斗的偏向",
                                fontSize = 12,
                                fontColor = { 208, 209, 209, 215 },
                            },
                        },
                    },
                    UI.ScrollView {
                        width = "100%",
                        flexGrow = 1,
                        flexBasis = 0,
                        scrollX = false,
                        scrollY = true,
                        showScrollbar = false,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                flexWrap = "wrap",
                                justifyContent = "center",
                                alignItems = "flex-start",
                                columnGap = 26,
                                rowGap = 20,
                                padding = { 10, 8, 20, 8 },
                                children = { CreateChestCard(1), CreateChestCard(2), CreateChestCard(3) },
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
                })
                card:SetStyle({
                    borderColor = borderColor,
                    shadowBlur = 18,
                    shadowOffsetY = 7,
                    shadowColor = { 0, 0, 0, 175 },
                })
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
    healthLabel:SetText(hud.health)
    roomLabel:SetText(hud.room)
    parryLabel:SetText(hud.parry)
    buffLabel:SetText("临时增益\n" .. hud.buffs)
    abilityLabel:SetText("构筑\n" .. hud.upgrades)
    RefreshChestPanel()
end

function Start()
    graphics.windowTitle = Config.Title
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

    Game.Update(game, dt, moveX, moveY)
    AudioManager.Update(dt)
    AudioManager.ProcessEvents(Game.ConsumeEvents(game))
    hudTimer = hudTimer + dt
    if hudTimer >= 0.08 then
        UpdateHud()
        hudTimer = hudTimer - 0.08
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
    Renderer.Draw(nvgContext, game, logicalWidth, logicalHeight)
    nvgEndFrame(nvgContext)
end
