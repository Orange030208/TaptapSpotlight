package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Renderer = require "Renderer"

local width, height = 1280, 720
local samples = {
    { 0, 0 },
    { 0.5, 0.5 },
    { 1, 1 },
    { 0.25, 0.8 },
}

for _, sample in ipairs(samples) do
    local screenX, screenY = Renderer.WorldToScreen(width, height, sample[1], sample[2])
    local worldX, worldY = Renderer.ScreenToWorld(width, height, screenX, screenY)
    assert(math.abs(worldX - sample[1]) < 0.000001, "screen-to-world X must invert world-to-screen")
    assert(math.abs(worldY - sample[2]) < 0.000001, "screen-to-world Y must invert world-to-screen")
end

print("PASS test_renderer_math")
