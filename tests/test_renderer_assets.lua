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
assert(spineCreateCalls == 1, "startup must create the compressed Spine player")
assert(loadedSpinePath == "Characters/bard_cat/bard_cat.json")
assert(imagePaths[1] == "image/soot_monster.png")

Renderer.UnloadAssets({})
assert(disposed)
print("PASS test_renderer_assets")
