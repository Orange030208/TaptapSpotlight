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
local chestCards = {}
local chestAccentPanels = {}
local chestButtons = {}

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

local function CreateChestCard(index)
    local optionIndex = index
    local accent = UI.Panel {
        width = "100%",
        height = 4,
        borderRadius = 2,
        backgroundColor = { 236, 202, 105, 255 },
    }
    local choiceLabel = UI.Label {
        text = "抉择 " .. string.format("%02d", optionIndex),
        fontSize = 10,
        fontWeight = "bold",
        textTransform = "uppercase",
        fontColor = { 187, 194, 222, 230 },
    }
    local title = UI.Label {
        text = "强化名称",
        width = "100%",
        fontSize = 20,
        fontWeight = "bold",
        textAlign = "center",
        maxLines = 2,
        whiteSpace = "normal",
        wordBreak = "break-word",
        fontColor = { 245, 235, 180, 255 },
    }
    local description = UI.Label {
        text = "强化说明",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        fontSize = 13,
        textAlign = "center",
        whiteSpace = "normal",
        wordBreak = "break-word",
        maxLines = 4,
        lineHeight = 1.35,
        fontColor = { 225, 230, 255, 220 },
    }
    local button = UI.Button {
        text = "选择 [" .. tostring(optionIndex) .. "]",
        width = "100%",
        height = 42,
        fontSize = 14,
        textColor = { 15, 14, 24, 255 },
        backgroundColor = { 236, 202, 105, 255 },
        hoverBackgroundColor = { 255, 226, 134, 255 },
        pressedBackgroundColor = { 205, 165, 77, 255 },
        transition = "backgroundColor 0.15s easeOut, scale 0.15s easeOut",
        onClick = function()
            ChooseChestOption(optionIndex)
        end,
    }
    local card = UI.Panel {
        flexGrow = 1,
        flexBasis = 220,
        flexShrink = 1,
        minWidth = 184,
        maxWidth = 280,
        minHeight = 244,
        padding = 16,
        gap = 12,
        borderRadius = 8,
        borderWidth = 2,
        borderColor = { 236, 202, 105, 185 },
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 45, 38, 72, 252 },
            to = { 24, 21, 43, 252 },
        },
        boxShadow = { { x = 0, y = 7, blur = 18, spread = 0, color = { 0, 0, 0, 115 } } },
        transition = "scale 0.15s easeOut, borderColor 0.15s easeOut",
        onPointerEnter = function(event, widget)
            widget:SetStyle({ scale = 1.015 })
        end,
        onPointerLeave = function(event, widget)
            widget:SetStyle({ scale = 1.0 })
        end,
        children = {
            accent,
            choiceLabel,
            title,
            description,
            button,
        },
    }

    chestTitleLabels[index] = title
    chestDescriptionLabels[index] = description
    chestCards[index] = card
    chestAccentPanels[index] = accent
    chestButtons[index] = button
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
            UI.Panel {
                width = "94%",
                height = "84%",
                maxWidth = 940,
                padding = 22,
                gap = 14,
                backgroundGradient = {
                    type = "linear",
                    direction = "to-bottom",
                    from = { 37, 31, 65, 253 },
                    to = { 18, 16, 35, 253 },
                },
                borderRadius = 8,
                borderWidth = 2,
                borderColor = { 246, 211, 112, 220 },
                boxShadow = { { x = 0, y = 12, blur = 32, spread = 0, color = { 0, 0, 0, 150 } } },
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "遗物抉择",
                        fontSize = 30,
                        fontWeight = "bold",
                        textStroke = { width = 1, color = { 50, 37, 9, 230 } },
                        fontColor = { 255, 226, 125, 255 },
                    },
                    UI.Label {
                        text = "选择一项强化，房间时间已暂停",
                        fontSize = 13,
                        fontColor = { 220, 226, 255, 220 },
                    },
                    UI.Divider {
                        width = "100%",
                        color = { 246, 211, 112, 95 },
                        spacing = 0,
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
                                alignItems = "stretch",
                                gap = 14,
                                padding = { 4, 2, 12, 2 },
                                children = { CreateChestCard(1), CreateChestCard(2), CreateChestCard(3) },
                            },
                        },
                    },
                    UI.Label {
                        text = "按 1 / 2 / 3 选择",
                        fontSize = 12,
                        fontColor = { 171, 181, 217, 225 },
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
        return
    end

    for index = 1, 3 do
        local option = game.chestOptions and game.chestOptions[index] or nil
        chestCards[index]:SetVisible(option ~= nil)
        if option ~= nil then
            chestTitleLabels[index]:SetText(option.name)
            chestDescriptionLabels[index]:SetText(option.description)
            local color = option.color or { 236, 202, 105 }
            chestTitleLabels[index]:SetFontColor({ color[1], color[2], color[3], 255 })
            chestAccentPanels[index]:SetStyle({ backgroundColor = { color[1], color[2], color[3], 255 } })
            chestCards[index]:SetStyle({ borderColor = { color[1], color[2], color[3], 225 } })
            chestButtons[index]:SetStyle({
                backgroundColor = { color[1], color[2], color[3], 255 },
                hoverBackgroundColor = { math.min(255, color[1] + 26), math.min(255, color[2] + 26), math.min(255, color[3] + 26), 255 },
                pressedBackgroundColor = { math.max(0, color[1] - 32), math.max(0, color[2] - 32), math.max(0, color[3] - 32), 255 },
            })
        end
    end
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
