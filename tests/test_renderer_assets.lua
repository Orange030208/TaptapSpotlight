package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Renderer = require "Renderer"
local spineCreateCalls = 0
local imagePaths = {}

nvgSpineCreate = function()
    spineCreateCalls = spineCreateCalls + 1
    error("startup must not load an incompatible Spine asset")
end

nvgCreateImage = function(_, path)
    table.insert(imagePaths, path)
    return #imagePaths
end

nvgImageSize = function()
    return 64, 64
end

nvgDeleteImage = function() end

assert(Renderer.LoadAssets({}))
assert(spineCreateCalls == 0, "incompatible Spine 3.8 asset must not be loaded by the 4.2 runtime")
assert(imagePaths[1] == "Characters/player.png")
assert(imagePaths[2] == "image/soot_monster.png")
assert(imagePaths[3] == "image/luminous_wraith_solid_alpha_20260718134330.png")
assert(imagePaths[4] == "image/stone_monster_rolling_20260718145411.png")
assert(imagePaths[5] == "image/spawn_room_wasd_floor_guide_20260718145203.png")

Renderer.UnloadAssets({})

local scaleCalls = {}
local rotationCalls = {}
local noop = function() end
setmetatable(_G, {
    __index = function(_, name)
        if type(name) == "string" and name:sub(1, 3) == "nvg" then
            return noop
        end
    end,
})
nvgScale = function(_, x, y)
    table.insert(scaleCalls, { x = x, y = y })
end
nvgRotate = function(_, angle)
    table.insert(rotationCalls, angle)
end

assert(Renderer.LoadAssets({}))
local soot = {
    kind = "soot", id = 1, x = 0.5, y = 0.5,
    vx = 0.1, vy = 0, facing = "left", state = "idle", stateTimer = 0,
    hp = 2, maxHp = 2, radius = 0.04,
}
local game = {
    time = 0, state = "battle", transition = nil, room = nil, map = nil,
    enemies = { soot }, chests = {}, projectiles = {}, particles = {}, player = nil,
}
Renderer.Draw({}, game, 960, 540, nil)
assert(scaleCalls[#scaleCalls].x > 0, "left-facing soot must keep the source sprite orientation")

soot.facing = "right"
Renderer.Draw({}, game, 960, 540, nil)
assert(scaleCalls[#scaleCalls].x < 0, "right-facing soot must mirror the source sprite")

local stone = {
    kind = "stone", id = 2, x = 0.5, y = 0.5,
    vx = 1.45, vy = 0, dashX = 1, dashY = 0,
    facing = "right", state = "dash", stateTimer = 0,
    hp = 3, maxHp = 3, radius = 0.052,
}
game.enemies = { stone }
Renderer.Draw({}, game, 960, 540, nil)
assert(#rotationCalls > 0, "rolling stone sprite must rotate during its charge")

local birthRoomGame = {
    time = 0, state = "clear", transition = nil, room = { isBirthRoom = true, connections = {} }, map = nil,
    enemies = {}, chests = {}, particles = {}, player = nil, spawnGuideAlpha = 1,
    projectiles = {
        { owner = "player", x = 0.5, y = 0.5, vx = 0.1, vy = 0, radius = 0.01, reflected = false },
    },
}
Renderer.Draw({}, birthRoomGame, 960, 540, nil)

Renderer.UnloadAssets({})
print("PASS test_renderer_assets")
