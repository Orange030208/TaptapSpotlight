-- Each room owns its safe spawn positions and one or more enemy-group choices.
-- Game.lua chooses one group at random, so room pacing stays authorable.
local RoomData = {
    {
        name = "Threshold",
        spawns = {
            { x = 0.25, y = 0.29 }, { x = 0.72, y = 0.3 }, { x = 0.5, y = 0.24 },
        },
        groups = {
            { "melee", "ranged" },
            { "melee", "melee" },
        },
    },
    {
        name = "Crossfire",
        spawns = {
            { x = 0.2, y = 0.28 }, { x = 0.8, y = 0.28 }, { x = 0.32, y = 0.43 }, { x = 0.68, y = 0.43 },
        },
        groups = {
            { "melee", "ranged", "ranged" },
            { "melee", "melee", "ranged" },
        },
    },
    {
        name = "Pressure",
        spawns = {
            { x = 0.17, y = 0.36 }, { x = 0.83, y = 0.36 }, { x = 0.38, y = 0.22 }, { x = 0.62, y = 0.22 },
        },
        groups = {
            { "melee", "melee", "ranged" },
            { "melee", "ranged", "ranged" },
        },
    },
    {
        name = "Last Stand",
        spawns = {
            { x = 0.16, y = 0.29 }, { x = 0.84, y = 0.29 }, { x = 0.25, y = 0.52 }, { x = 0.75, y = 0.52 },
        },
        groups = {
            { "melee", "melee", "ranged", "ranged" },
            { "melee", "melee", "melee", "ranged" },
        },
    },
    {
        name = "The Warden",
        boss = true,
        spawns = { { x = 0.5, y = 0.28 } },
        groups = { { "boss" } },
    },
}

return RoomData
