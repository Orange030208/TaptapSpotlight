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

Renderer.UnloadAssets({})

local scaleCalls = {}
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

Renderer.UnloadAssets({})
print("PASS test_renderer_assets")
