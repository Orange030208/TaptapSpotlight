-- Fixed floor graph from the room-layout design. Coordinates drive the minimap;
-- connections drive doors. Every connection is declared on both linked rooms.
local function Spawn(kind, x, y)
    return { kind = kind, x = x, y = y }
end

return {
    startRoomId = "room_1",
    rooms = {
        room_1 = {
            id = "room_1", name = "初醒之间", mapX = 0, mapY = 0, mapImage = "image/forest_room.png",
            connections = { north = "room_2" },
            -- Keep the original movement and parry onboarding before the first combat room.
            isBirthRoom = true,
            spawns = {},
            groups = {},
        },
        room_2 = {
            id = "room_2", name = "交错之间", mapX = 0, mapY = -1, mapImage = "image/forest_room.png",
            connections = { north = "room_4", east = "room_6", south = "room_1", west = "room_3" },
            -- Fixed: two soot enemies.
            fixedSpawns = {
                Spawn("soot", 0.36, 0.48), Spawn("soot", 0.64, 0.48),
            },
        },
        room_3 = {
            id = "room_3", name = "幽影之间", mapX = -1, mapY = -1, mapImage = "image/forest_room.png",
            connections = { east = "room_2" },
            -- Fixed: three shadow wraiths and one tree monster.
            fixedSpawns = {
                Spawn("shadow_wraith", 0.22, 0.28), Spawn("shadow_wraith", 0.78, 0.28),
                Spawn("shadow_wraith", 0.30, 0.70), Spawn("tree", 0.70, 0.64),
            },
        },
        room_4 = {
            id = "room_4", name = "伏击之间", mapX = 0, mapY = -2, mapImage = "image/forest_room.png",
            connections = { north = "room_5", east = "room_7", south = "room_2" },
            spawns = {
                { x = 0.20, y = 0.30 }, { x = 0.80, y = 0.30 }, { x = 0.32, y = 0.65 },
                { x = 0.68, y = 0.65 }, { x = 0.50, y = 0.48 },
            },
            groups = {
                { "stone", "mushroom" },
                { "stone", "dandelion" },
            },
        },
        room_5 = {
            id = "room_5", name = "回响之间", mapX = 0, mapY = -3, mapImage = "image/forest_room.png",
            connections = { east = "room_8", south = "room_4" },
            spawns = {
                { x = 0.22, y = 0.30 }, { x = 0.50, y = 0.26 }, { x = 0.78, y = 0.30 },
                { x = 0.32, y = 0.68 }, { x = 0.68, y = 0.68 },
            },
            groups = {
                { "soot", "sap", "mushroom" },
                { "soot", "mushroom", "dandelion" },
            },
        },
        room_6 = {
            id = "room_6", name = "重压之间", mapX = 1, mapY = -1, mapImage = "image/forest_room.png",
            connections = { north = "room_7", west = "room_2" },
            spawns = {
                { x = 0.20, y = 0.32 }, { x = 0.50, y = 0.26 }, { x = 0.80, y = 0.32 },
                { x = 0.30, y = 0.70 }, { x = 0.70, y = 0.70 },
            },
            groups = {
                { "stone", "soot", "sap" },
            },
        },
        room_7 = {
            id = "room_7", name = "守望之间", mapX = 1, mapY = -2, mapImage = "image/forest_room.png",
            connections = { north = "room_8", south = "room_6", west = "room_4" },
            spawns = {
                { x = 0.20, y = 0.30 }, { x = 0.80, y = 0.30 }, { x = 0.28, y = 0.66 },
                { x = 0.72, y = 0.66 }, { x = 0.50, y = 0.50 },
            },
            groups = {
                { "soot", "sap", "mushroom" },
                { "soot", "mushroom", "dandelion" },
            },
        },
        room_8 = {
            id = "room_8", name = "毒苔之间", mapX = 1, mapY = -3, mapImage = "image/forest_room.png",
            connections = { east = "boss", south = "room_7", west = "room_5" },
            -- The clear cross (0.40..0.60) joins the west, south, and east doors.
            -- Toxic moss stays outside it, so hazards never seal the route to the next door.
            fixedSpawns = {
                Spawn("purple_orb", 0.22, 0.24), Spawn("purple_orb", 0.78, 0.24),
                Spawn("purple_orb", 0.22, 0.76),
                Spawn("toxic_moss", 0.12, 0.18), Spawn("toxic_moss", 0.28, 0.18),
                Spawn("toxic_moss", 0.72, 0.18), Spawn("toxic_moss", 0.88, 0.18),
                Spawn("toxic_moss", 0.14, 0.36), Spawn("toxic_moss", 0.86, 0.36),
                Spawn("toxic_moss", 0.14, 0.64), Spawn("toxic_moss", 0.86, 0.64),
                Spawn("toxic_moss", 0.12, 0.82), Spawn("toxic_moss", 0.28, 0.82),
                Spawn("toxic_moss", 0.72, 0.82), Spawn("toxic_moss", 0.88, 0.82),
            },
        },
        boss = {
            id = "boss", name = "首领之间", mapX = 2, mapY = -3, boss = true, mapImage = "image/forest_room.png",
            connections = { west = "room_8" },
            fixedSpawns = { Spawn("boss", 0.50, 0.34) },
        },
    },
}
