-- Parry Room: a room-based 2.5D Game Jam prototype.
-- Raw NanoVG renders the world; urhox-libs/UI renders the responsive HUD above it.

local UI = require("urhox-libs/UI")
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
local abilityLabel = nil

local function RefreshCanvasMetrics()
    physicalWidth = graphics:GetWidth()
    physicalHeight = graphics:GetHeight()
    devicePixelRatio = graphics:GetDPR()
    logicalWidth = physicalWidth / devicePixelRatio
    logicalHeight = physicalHeight / devicePixelRatio
end

local function CreateHud()
    healthLabel = UI.Label {
        text = "●●●",
        fontSize = 21,
        fontColor = { 255, 132, 154, 255 },
    }
    roomLabel = UI.Label {
        text = "RUN NOT STARTED",
        fontSize = 14,
        fontColor = { 232, 237, 255, 245 },
    }
    parryLabel = UI.Label {
        text = "PARRY READY",
        fontSize = 14,
        fontColor = { 130, 232, 255, 255 },
    }
    abilityLabel = UI.Label {
        text = "ABILITIES 0",
        fontSize = 12,
        fontColor = { 197, 175, 255, 235 },
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
                        children = { parryLabel, abilityLabel },
                    },
                    UI.Label {
                        text = "WASD MOVE   SPACE PARRY   F1 DEBUG",
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
        },
    })
end

local function UpdateHud()
    if game == nil or healthLabel == nil then
        return
    end

    local hud = Game.GetHud(game)
    healthLabel:SetText(hud.health)
    roomLabel:SetText(hud.room)
    parryLabel:SetText(hud.parry)
    abilityLabel:SetText("ABILITIES " .. tostring(hud.abilityCount))
end

function Start()
    graphics.windowTitle = Config.Title
    math.randomseed(os.time())
    RefreshCanvasMetrics()

    UI.Init({
        theme = "default-dark",
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
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

    game = Game.New()
    UpdateHud()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleNanoVGRender")

    print("Parry Room ready: press Enter to begin")
end

function Stop()
    UI.Shutdown()
    if nvgContext ~= nil then
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
    local moveX = 0
    local moveY = 0
    if input:GetKeyDown(KEY_A) then moveX = moveX - 1 end
    if input:GetKeyDown(KEY_D) then moveX = moveX + 1 end
    if input:GetKeyDown(KEY_W) then moveY = moveY - 1 end
    if input:GetKeyDown(KEY_S) then moveY = moveY + 1 end

    Game.Update(game, dt, moveX, moveY)
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

    -- Mode B: logical drawing coordinates plus DPR-aware output.
    nvgBeginFrame(nvgContext, logicalWidth, logicalHeight, devicePixelRatio)
    Renderer.Draw(nvgContext, game, logicalWidth, logicalHeight)
    nvgEndFrame(nvgContext)
end
