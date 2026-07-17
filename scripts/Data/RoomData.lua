-- Fixed Isaac-style floor graph. Coordinates drive the minimap; connections drive doors.
-- Every connection must also be declared in the opposite direction on the target room.
return {
    startRoomId = "threshold",
    rooms = {
        threshold = {
            id = "threshold", name = "门槛之间", mapX = 0, mapY = 0,
            connections = { north = "crossfire", east = "pressure" },
            spawns = {
                { x = 0.28, y = 0.31 }, { x = 0.72, y = 0.31 }, { x = 0.5, y = 0.27 },
            },
            groups = {
                { "melee", "ranged" },
                { "melee", "melee" },
            },
        },
        crossfire = {
            id = "crossfire", name = "交叉火力", mapX = 0, mapY = -1,
            connections = { north = "warden", east = "ambush", south = "threshold", west = "crypt" },
            spawns = {
                { x = 0.22, y = 0.29 }, { x = 0.78, y = 0.29 },
                { x = 0.32, y = 0.48 }, { x = 0.68, y = 0.48 },
            },
            groups = {
                { "melee", "ranged", "ranged" },
                { "melee", "melee", "ranged" },
            },
        },
        pressure = {
            id = "pressure", name = "重压之间", mapX = 1, mapY = 0,
            connections = { north = "ambush", west = "threshold" },
            spawns = {
                { x = 0.19, y = 0.38 }, { x = 0.81, y = 0.38 },
                { x = 0.38, y = 0.25 }, { x = 0.62, y = 0.25 },
            },
            groups = {
                { "melee", "melee", "ranged" },
                { "melee", "ranged", "ranged" },
            },
        },
        ambush = {
            id = "ambush", name = "伏击之间", mapX = 1, mapY = -1,
            connections = { east = "treasury", south = "pressure", west = "crossfire" },
            spawns = {
                { x = 0.18, y = 0.31 }, { x = 0.82, y = 0.31 },
                { x = 0.27, y = 0.56 }, { x = 0.73, y = 0.56 },
            },
            groups = {
                { "melee", "melee", "ranged", "ranged" },
                { "melee", "melee", "melee", "ranged" },
            },
        },
        crypt = {
            id = "crypt", name = "回声墓室", mapX = -1, mapY = -1,
            connections = { east = "crossfire" },
            spawns = {
                { x = 0.25, y = 0.30 }, { x = 0.75, y = 0.30 }, { x = 0.5, y = 0.54 },
            },
            groups = {
                { "melee", "melee", "ranged" },
                { "ranged", "ranged", "ranged" },
            },
        },
        treasury = {
            id = "treasury", name = "藏宝间", mapX = 2, mapY = -1,
            connections = { west = "ambush" },
            spawns = {
                { x = 0.3, y = 0.32 }, { x = 0.7, y = 0.32 },
            },
            groups = {
                { "melee", "ranged" },
                { "melee", "melee" },
            },
        },
        warden = {
            id = "warden", name = "典狱长之间", mapX = 0, mapY = -2, boss = true,
            connections = { south = "crossfire" },
            spawns = { { x = 0.5, y = 0.34 } },
            groups = { { "boss" } },
        },
    },
}
