package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Renderer = require "Renderer"
local spineCreateCalls = 0
local imagePaths = {}
local loadedSpinePath = nil
local disposed = false

nvgSpineCreate = function()
    spineCreateCalls = spineCreateCalls + 1
    return {
        Load = function(_, path)
            loadedSpinePath = path
            return true
        end,
        SetDefaultMix = function() end,
        SetAnimation = function() end,
        IsLoaded = function()
            return true
        end,
        Unload = function() end,
        Dispose = function()
            disposed = true
        end,
    }
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
assert(loadedSpinePath == nil)
assert(imagePaths[1] == "Characters/player.png")
assert(imagePaths[2] == "image/soot_monster.png")

Renderer.UnloadAssets({})
assert(not disposed, "no Spine instance should exist while the static fallback is enabled")
print("PASS test_renderer_assets")
