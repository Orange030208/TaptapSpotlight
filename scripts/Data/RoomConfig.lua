-- Shared room-space tuning. Gameplay coordinates use normalized room space: 0..1.
local RoomConfig = {
    minX = 0.045,
    maxX = 0.955,
    minY = 0.055,
    maxY = 0.945,
    introDuration = 0.7,
    doorwayWidth = 0.14,
    doorTriggerDepth = 0.012,
    doorEntryInset = 0.075,
    transitionDuration = 0.52,
}

-- The forest-map tree line, read from left to right in normalized room space.
-- Above this curve is solid wall, except for the marked north doorway.
RoomConfig.topWallPoints = {
    { x = 0.045, y = 0.405 },
    { x = 0.110, y = 0.320 },
    { x = 0.205, y = 0.255 },
    { x = 0.350, y = 0.225 },
    { x = 0.415, y = 0.215 },
    { x = 0.585, y = 0.215 },
    { x = 0.690, y = 0.235 },
    { x = 0.805, y = 0.270 },
    { x = 0.905, y = 0.335 },
    { x = 0.955, y = 0.405 },
}
RoomConfig.northDoorMinX = 0.415
RoomConfig.northDoorMaxX = 0.585

function RoomConfig.GetTopWallY(x)
    local points = RoomConfig.topWallPoints
    for index = 1, #points - 1 do
        local left, right = points[index], points[index + 1]
        if x <= right.x then
            local progress = (x - left.x) / math.max(0.0001, right.x - left.x)
            return left.y + (right.y - left.y) * math.max(0, math.min(1, progress))
        end
    end
    return points[#points].y
end

function RoomConfig.ClampPlayerPosition(x, y, radius)
    x = math.max(RoomConfig.minX, math.min(RoomConfig.maxX, x))
    y = math.max(RoomConfig.minY, math.min(RoomConfig.maxY, y))
    if x < RoomConfig.northDoorMinX or x > RoomConfig.northDoorMaxX then
        y = math.max(y, RoomConfig.GetTopWallY(x) + radius)
    end
    return x, y
end

return RoomConfig
