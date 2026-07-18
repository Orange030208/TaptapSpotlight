package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Renderer = require "Renderer"
local spineCreateCalls = 0
local imagePaths = {}

nvgSpineCreate = function()
    spineCreateCalls = spineCreateCalls + 1
    error("startup must not load the oversized Spine atlas")
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
assert(spineCreateCalls == 0, "startup must not create a Spine instance")
assert(imagePaths[1] == "Characters/player.png")
assert(imagePaths[2] == "image/soot_monster.png")

Renderer.UnloadAssets({})
print("PASS test_renderer_assets")
