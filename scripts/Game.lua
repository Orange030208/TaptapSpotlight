local ChestConfig = require "Data.ChestConfig"
local ComboConfig = require "Data.ComboConfig"
local EnemyConfig = require "Data.EnemyConfig"
local GaugeConfig = require "Data.GaugeConfig"
local PlayerConfig = require "Data.PlayerConfig"
local ProjectileConfig = require "Data.ProjectileConfig"
local RoomConfig = require "Data.RoomConfig"
local RoomData = require "Data.RoomData"
local CrystalConfig = require "Data.CrystalConfig"
local CrystalAbilities = require "CrystalAbilities"
local Entities = require "Entities"
local Boss = require "Boss"

local Game = {}

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function EmitEvent(game, name, data)
    table.insert(game.events, { name = name, data = data })
end

local OPPOSITE_DIRECTION = {
    north = "south",
    south = "north",
    west = "east",
    east = "west",
}

local function GetRoomCount()
    local count = 0
    for _ in pairs(RoomData.rooms) do
        count = count + 1
    end
    return count
end

local function GetRoomState(game, roomId)
    local state = game.roomStates[roomId]
    if state == nil then
        state = { visited = false, cleared = false, chests = {} }
        game.roomStates[roomId] = state
    end
    return state
end

local function CopyColor(color)
    return { color[1], color[2], color[3] }
end

local function AddParticles(game, x, y, color, count)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 0.05 + math.random() * 0.18
        table.insert(game.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.3 + math.random() * 0.35,
            maxLife = 0.65,
            color = CopyColor(color),
        })
    end
end

local function SetMessage(game, text, duration)
    game.message = text
    game.messageTimer = duration or 1.2
end

local function CreateGauge()
    return {
        value = 0,
        threshold = GaugeConfig.threshold,
        pulse = 0,
    }
end

local function CreateRecovery()
    return { remaining = 0 }
end

local function CreateCombo()
    return {
        count = 0,
        tier = 0,
        timeout = 0,
        overdriveRemaining = 0,
    }
end

local function CreatePerfectStreak()
    return {
        count = 0,
        timer = 0,
    }
end

local function GetComboTier(count)
    local tier = 0
    for index, definition in ipairs(ComboConfig.tiers) do
        if count >= definition.threshold then
            tier = index
        end
    end
    return tier
end

local function EmitComboChanged(game)
    local combo = game.combo
    local definition = ComboConfig.tiers[combo.tier]
    EmitEvent(game, "combo_changed", {
        count = combo.count,
        tier = combo.tier,
        tierName = definition ~= nil and definition.name or nil,
        color = definition ~= nil and CopyColor(definition.color) or { 190, 196, 218 },
        overdriveRemaining = combo.overdriveRemaining,
    })
end

local function ResetCombo(game)
    local combo = game.combo
    if combo == nil or combo.count <= 0 then
        return
    end
    local hadOverdrive = combo.overdriveRemaining > 0
    combo.count = 0
    combo.tier = 0
    combo.timeout = 0
    combo.overdriveRemaining = 0
    if hadOverdrive then
        EmitEvent(game, "overdrive_end", { x = game.player.x, y = game.player.y })
    end
    EmitComboChanged(game)
end

local function ResetPerfectStreak(game)
    local streak = game.perfectStreak
    if streak == nil then
        return
    end
    streak.count = 0
    streak.timer = 0
end

local function RegisterPerfectStreak(game)
    local streak = game.perfectStreak
    if streak == nil then
        streak = CreatePerfectStreak()
        game.perfectStreak = streak
    end
    streak.count = streak.count + 1
    streak.timer = ComboConfig.perfectStreakWindow
    return streak.count
end

local function UpdatePerfectStreak(game, dt)
    local streak = game.perfectStreak
    if streak == nil or streak.count <= 0 then
        return
    end
    streak.timer = math.max(0, streak.timer - dt)
    if streak.timer <= 0 then
        ResetPerfectStreak(game)
    end
end

local function UpdateCombo(game, dt)
    local combo = game.combo
    if combo == nil or combo.count <= 0 then
        return
    end

    if combo.overdriveRemaining > 0 then
        combo.overdriveRemaining = math.max(0, combo.overdriveRemaining - dt)
        if combo.overdriveRemaining <= 0 then
            combo.timeout = ComboConfig.decayDuration
            EmitEvent(game, "overdrive_end", { x = game.player.x, y = game.player.y })
            EmitComboChanged(game)
        end
        return
    end

    combo.timeout = math.max(0, combo.timeout - dt)
    if combo.timeout <= 0 then
        ResetCombo(game)
    end
end

local function AddComboProgress(game, perfect, x, y, canShockwave)
    local combo = game.combo
    local previousTier = combo.tier
    combo.count = combo.count + (perfect and ComboConfig.perfectGain or ComboConfig.normalGain)
    combo.timeout = ComboConfig.decayDuration
    combo.tier = GetComboTier(combo.count)

    if combo.tier > previousTier then
        for tier = previousTier + 1, combo.tier do
            local definition = ComboConfig.tiers[tier]
            EmitEvent(game, "combo_tier_up", {
                x = x,
                y = y,
                tier = tier,
                count = combo.count,
                color = CopyColor(definition.color),
            })
        end
    end

    if combo.count >= ComboConfig.overdriveThreshold and combo.overdriveRemaining <= 0 then
        combo.overdriveRemaining = ComboConfig.overdriveDuration
        EmitEvent(game, "overdrive_start", {
            x = x,
            y = y,
            tier = combo.tier,
            count = combo.count,
            color = CopyColor(ComboConfig.tiers[combo.tier].color),
        })
        CrystalAbilities.OnOverdrive(game)
    end

    if perfect and canShockwave and combo.tier >= ComboConfig.shockwaveTier then
        EmitEvent(game, "combo_shockwave", {
            x = x,
            y = y,
            tier = combo.tier,
            color = CopyColor(ComboConfig.tiers[combo.tier].color),
        })
    end
    EmitComboChanged(game)
end

local function UpdateGaugeRecovery(game, dt)
    local recovery = game.recovery
    if recovery.remaining > 0 then
        if game.player.hp > 0 then
            Entities.HealPlayer(game.player, GaugeConfig.recovery.healPerSecond * dt)
        end
        recovery.remaining = math.max(0, recovery.remaining - dt)
    end
    game.gauge.pulse = math.max(0, game.gauge.pulse - dt)
end

local function AddGaugeProgress(game, amount, x, y)
    local gauge = game.gauge
    gauge.value = gauge.value + amount
    local rewarded = false
    while gauge.value >= gauge.threshold do
        gauge.value = gauge.value - gauge.threshold
        gauge.pulse = 0.6
        game.recovery.remaining = GaugeConfig.recovery.duration
        AddParticles(game, x, y, GaugeConfig.recovery.color, 18)
        SetMessage(game, GaugeConfig.label .. "充满 - 生命恢复中", 1.4)
        EmitEvent(game, "gauge_full", { recoveryDuration = GaugeConfig.recovery.duration })
        rewarded = true
    end
    return rewarded
end

local function GetAvailableCrystals(player)
    local available = {}
    for _, definition in ipairs(CrystalConfig.definitions) do
        if player.crystals[definition.id] < definition.maxStacks then
            table.insert(available, definition)
        end
    end
    return available
end

local function CreateChestOptions(player)
    local available = GetAvailableCrystals(player)
    local options = {}
    local count = math.min(3, #available)
    local selected = {}
    for _ = 1, count do
        local index = math.random(1, #available)
        local definition = table.remove(available, index)
        assert(not selected[definition.id], "Chest options must not contain duplicate crystals")
        selected[definition.id] = true
        table.insert(options, definition)
    end
    return options
end

local function SpawnChestForEnemy(game, enemy)
    if enemy.kind == "boss" or math.random() > ChestConfig.chance then
        return
    end
    if #GetAvailableCrystals(game.player) > 0 then
        table.insert(game.chests, Entities.NewChest(enemy.x, enemy.y))
    end
end

local function HandleEnemyDeaths(game)
    for index = #game.enemies, 1, -1 do
        local enemy = game.enemies[index]
        if enemy.dead then
            local isBoss = enemy.kind == "boss"
            if isBoss and enemy.purified then
                local splitChildren = Entities.GetSplitChildren(enemy)
                EmitEvent(game, "boss_defeat", {
                    x = enemy.x,
                    y = enemy.y,
                    kind = enemy.kind,
                })
                AddParticles(game, enemy.x, enemy.y, { 130, 255, 185 }, 30)
                table.remove(game.enemies, index)
            elseif isBoss and enemy.state ~= "defeat" then
                enemy.state = "defeat"
                enemy.dead = false
                enemy.stateTimer = 0.9
                enemy.attack = nil
                enemy.vx, enemy.vy = 0, 0
            else
                local splitChildren = Entities.GetSplitChildren(enemy)
                if not isBoss then
                    CrystalAbilities.OnEnemyDefeated(game, enemy)
                end
                EmitEvent(game, enemy.kind == "boss" and "boss_defeat" or "enemy_defeat", {
                    x = enemy.x,
                    y = enemy.y,
                    kind = enemy.kind,
                })
                if #splitChildren == 0 then
                    SpawnChestForEnemy(game, enemy)
                end
                AddParticles(game, enemy.x, enemy.y,
                    enemy.kind == "boss" and { 255, 120, 70 } or { 255, 215, 90 },
                    enemy.kind == "boss" and 24 or 10
                )
                table.remove(game.enemies, index)
                for _, spawn in ipairs(splitChildren) do
                    table.insert(game.enemies, Entities.NewEnemy(enemy.kind, spawn, game.nextEntityId))
                    game.nextEntityId = game.nextEntityId + 1
                end
            end
        end
    end
end

local function PlacePlayerAtEntry(player, travelDirection)
    if travelDirection == nil then
        player.x = 0.5
        player.y = 0.72
        return
    end

    local entryDirection = OPPOSITE_DIRECTION[travelDirection]
    local inset = RoomConfig.doorEntryInset
    if entryDirection == "north" then
        player.x, player.y = 0.5, RoomConfig.minY + inset
    elseif entryDirection == "south" then
        player.x, player.y = 0.5, RoomConfig.maxY - inset
    elseif entryDirection == "west" then
        player.x, player.y = RoomConfig.minX + inset, 0.5
    else
        player.x, player.y = RoomConfig.maxX - inset, 0.5
    end
end

local function GetRandomTutorialSpawn(game, tutorialSpawn)
    local area = tutorialSpawn.area
    for _ = 1, 24 do
        local spawn = {
            x = area.minX + math.random() * (area.maxX - area.minX),
            y = area.minY + math.random() * (area.maxY - area.minY),
        }
        local playerX = spawn.x - game.player.x
        local playerY = spawn.y - game.player.y
        local valid = playerX * playerX + playerY * playerY >= tutorialSpawn.minPlayerDistance ^ 2
        if valid then
            for _, enemy in ipairs(game.enemies) do
                local enemyX = spawn.x - enemy.x
                local enemyY = spawn.y - enemy.y
                if enemyX * enemyX + enemyY * enemyY < tutorialSpawn.minSeparation ^ 2 then
                    valid = false
                    break
                end
            end
        end
        if valid then
            return spawn
        end
    end
    error("Unable to find a valid tutorial spawn position")
end

local function SpawnTutorialEnemies(game, tutorialSpawn)
    assert(tutorialSpawn.randomized, "Tutorial spawns must be randomized")
    assert(tutorialSpawn.count > 0, "Tutorial spawn count must be positive")
    for _ = 1, tutorialSpawn.count do
        local spawn = GetRandomTutorialSpawn(game, tutorialSpawn)
        table.insert(game.enemies, Entities.NewEnemy(tutorialSpawn.kind, spawn, game.nextEntityId))
        game.nextEntityId = game.nextEntityId + 1
    end
end

local function SpawnFixedEnemies(game, fixedSpawns)
    assert(#fixedSpawns > 0, "Fixed enemy spawn list must not be empty")
    for _, spawn in ipairs(fixedSpawns) do
        assert(spawn.kind ~= nil, "Fixed enemy spawn is missing kind")
        assert(spawn.x ~= nil and spawn.y ~= nil, "Fixed enemy spawn is missing position")
        table.insert(game.enemies, Entities.NewEnemy(spawn.kind, spawn, game.nextEntityId))
        game.nextEntityId = game.nextEntityId + 1
    end
    print("[Room] Spawned fixed enemy layout: " .. tostring(#fixedSpawns) .. " enemies")
end

local function EnterRoom(game, roomId, travelDirection)
    local room = RoomData.rooms[roomId]
    assert(room ~= nil, "Unknown room id: " .. tostring(roomId))

    ResetPerfectStreak(game)
    game.currentRoomId = roomId
    game.room = room
    game.enemies = {}
    game.projectiles = {}
    game.chestOptions = nil
    local roomState = GetRoomState(game, roomId)
    game.chests = roomState.chests
    game.roomCleared = roomState.cleared
    local birthTutorialComplete = room.isBirthRoom and roomState.cleared
    game.spawnGuideAlpha = room.isBirthRoom and not birthTutorialComplete and 1 or 0
    game.spawnGuideDismissed = not room.isBirthRoom or birthTutorialComplete
    game.spawnParryGuideAlpha = 0
    game.spawnParryGuideDismissed = true
    game.birthTutorialMoved = birthTutorialComplete
    game.birthTutorialParried = birthTutorialComplete
    PlacePlayerAtEntry(game.player, travelDirection)

    if not roomState.visited then
        roomState.visited = true
        game.discoveredRooms[roomId] = true
        game.visitedRoomCount = game.visitedRoomCount + 1
    end

    local arrivalState = "clear"
    if not roomState.cleared and not room.isBirthRoom then
        arrivalState = "intro"
        if room.fixedSpawns ~= nil then
            SpawnFixedEnemies(game, room.fixedSpawns)
        elseif room.tutorialSpawn ~= nil then
            SpawnTutorialEnemies(game, room.tutorialSpawn)
        else
            assert(#room.groups > 0, "Room has no enemy groups: " .. tostring(roomId))
            assert(#room.spawns > 0, "Room has no enemy spawns: " .. tostring(roomId))
            local group = room.groups[math.random(1, #room.groups)]
            assert(group ~= nil, "Selected enemy group is missing: " .. tostring(roomId))
            ---@cast group string[]
            for index, kind in ipairs(group) do
                local spawn = room.spawns[((index - 1) % #room.spawns) + 1]
                table.insert(game.enemies, Entities.NewEnemy(kind, spawn, game.nextEntityId))
                game.nextEntityId = game.nextEntityId + 1
            end
        end
    end

    game.stateTimer = room.isBirthRoom and 0 or RoomConfig.introDuration
    game.message = room.isBirthRoom and "" or (room.boss and "晦暗低鸣苏醒"
        or (roomState.cleared and "返回已清理房间" or "识别到敌对目标"))
    game.messageTimer = room.isBirthRoom and 0 or (roomState.cleared and 0.8 or RoomConfig.introDuration)
    if game.transition ~= nil then
        game.transition.arrivalState = arrivalState
        game.state = "room_transition"
    else
        game.state = arrivalState
    end

end

local function FinishRoom(game)
    local roomState = GetRoomState(game, game.currentRoomId)
    if not roomState.cleared then
        roomState.cleared = true
        game.clearedRoomCount = game.clearedRoomCount + 1
    end
    game.roomCleared = true
    local hasChests = #game.chests > 0
    game.state = game.room.boss and "victory" or "clear"
    SetMessage(game,
        game.room.boss and "诅咒已净化" or (hasChests and "房间已清理 - 拾取宝箱或进入门" or "房间已清理 - 门已开启"),
        game.room.boss and 999 or 1.8
    )
    AddParticles(game, game.player.x, game.player.y, { 130, 255, 185 }, 18)
    EmitEvent(game, game.room.boss and "victory" or "room_clear")
end

local function StartRun(game)
    game.player = Entities.NewPlayer()
    game.enemies = {}
    game.projectiles = {}
    game.chests = {}
    game.chestOptions = nil
    game.stateBeforeChest = nil
    game.pendingChestRewards = {}
    game.particles = {}
    game.gauge = CreateGauge()
    game.recovery = CreateRecovery()
    game.combo = CreateCombo()
    game.perfectStreak = CreatePerfectStreak()
    game.crystalState = CrystalAbilities.NewState()
    game.currentRoomId = nil
    game.roomStates = {}
    game.discoveredRooms = {}
    game.visitedRoomCount = 0
    game.clearedRoomCount = 0
    game.roomCleared = false
    game.transition = nil
    game.doorCooldown = 0
    game.nextEntityId = 1
    game.runTime = 0
    game.victoryElapsed = 0
    game.message = ""
    game.messageTimer = 0
    game.spawnGuideAlpha = 0
    game.spawnGuideDismissed = true
    game.spawnParryGuideAlpha = 0
    game.spawnParryGuideDismissed = true
    game.birthTutorialMoved = false
    game.birthTutorialParried = false
    game.events = {}
    EnterRoom(game, RoomData.startRoomId, nil)
end

local function UpdateParticles(game, dt)
    for index = #game.particles, 1, -1 do
        local particle = game.particles[index]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vy = particle.vy + 0.04 * dt
        if particle.life <= 0 then
            table.remove(game.particles, index)
        end
    end
end

local function OpenNextChestReward(game, stateBeforeChest)
    if game.chestOptions ~= nil then
        return false
    end
    if #game.pendingChestRewards == 0 then
        return false
    end

    while #game.pendingChestRewards > 0 do
        local chest = table.remove(game.pendingChestRewards, 1)
        local options = CreateChestOptions(game.player)
        if #options > 0 then
            game.stateBeforeChest = stateBeforeChest or game.state
            game.state = "chest_select"
            game.chestOptions = options
            SetMessage(game, "选择一枚水晶能力", 999)
            AddParticles(game, chest.x, chest.y, { 255, 215, 100 }, 18)
            EmitEvent(game, "chest_open", { pendingCount = #game.pendingChestRewards })
            return true
        end
    end

    SetMessage(game, "所有水晶能力均已获得", 1.0)
    return false
end

local function UpdateChests(game, dt)
    for index = #game.chests, 1, -1 do
        local chest = game.chests[index]
        chest.bobTime = chest.bobTime + dt * 4
        if chest.state == "dropping" then
            chest.dropElapsed = chest.dropElapsed + dt
            local flightProgress = Clamp(chest.dropElapsed / ChestConfig.dropDuration, 0, 1)
            local easedProgress = 1 - (1 - flightProgress) ^ 3
            chest.x = Lerp(chest.dropStartX, chest.dropTargetX, easedProgress)
            chest.y = Lerp(chest.dropStartY, chest.dropTargetY, easedProgress)
            if not chest.landed and flightProgress >= 1 then
                chest.landed = true
                AddParticles(game, chest.x, chest.y, { 255, 215, 100 }, 12)
            end
            if chest.dropElapsed >= ChestConfig.dropDuration + ChestConfig.bounceDuration then
                chest.state = "idle"
                chest.idleElapsed = 0
            end
        elseif chest.state == "idle" then
            chest.idleElapsed = chest.idleElapsed + dt
            if chest.idleElapsed >= ChestConfig.pickupDelay and Entities.PlayerCanPickupChest(game.player, chest) then
                chest.state = "collecting"
                chest.collectElapsed = 0
                chest.collectStartX = chest.x
                chest.collectStartY = chest.y
            end
        elseif chest.state == "collecting" then
            chest.collectElapsed = chest.collectElapsed + dt
            local collectProgress = Clamp(chest.collectElapsed / ChestConfig.collectDuration, 0, 1)
            local easedProgress = 1 - (1 - collectProgress) ^ 4
            chest.x = Lerp(chest.collectStartX, game.player.x, easedProgress)
            chest.y = Lerp(chest.collectStartY, game.player.y, easedProgress)
            if collectProgress >= 1 then
                chest.x = game.player.x
                chest.y = game.player.y
                table.remove(game.chests, index)
                table.insert(game.pendingChestRewards, chest)
            end
        end

        if chest.dead then
            table.remove(game.chests, index)
        end
    end
    return OpenNextChestReward(game)
end

-- Door trigger layout in normalized room space:
--
--                 north (x centered, y = minY)
--       +--------------------[ ]--------------------+
-- west [ ]                 room                    [ ] east
--       +--------------------[ ]--------------------+
--                 south (x centered, y = maxY)
--
-- Doors are locked until the room is cleared. Arrival points are placed farther
-- inside than doorTriggerDepth so holding a movement key cannot bounce back.
local function GetTouchedDoor(player)
    local halfWidth = RoomConfig.doorwayWidth * 0.5
    local depth = RoomConfig.doorTriggerDepth
    if math.abs(player.x - 0.5) <= halfWidth then
        if player.y <= RoomConfig.minY + depth then return "north" end
        if player.y >= RoomConfig.maxY - depth then return "south" end
    end
    if math.abs(player.y - 0.5) <= halfWidth then
        if player.x <= RoomConfig.minX + depth then return "west" end
        if player.x >= RoomConfig.maxX - depth then return "east" end
    end
    return nil
end

local function TryBeginRoomTransition(game)
    if not game.roomCleared or game.doorCooldown > 0 then
        return false
    end

    local direction = GetTouchedDoor(game.player)
    local targetRoomId = direction ~= nil and game.room.connections[direction] or nil
    if targetRoomId == nil then
        return false
    end

    game.transition = {
        direction = direction,
        targetRoomId = targetRoomId,
        elapsed = 0,
        duration = RoomConfig.transitionDuration,
        switched = false,
        arrivalState = "clear",
    }
    ResetPerfectStreak(game)
    game.state = "room_transition"
    game.projectiles = {}
    SetMessage(game, "", 0)
    EmitEvent(game, "room_transition")
    return true
end

local function UpdateRoomTransition(game, dt)
    local transition = game.transition
    if transition == nil then
        return
    end

    transition.elapsed = math.min(transition.duration, transition.elapsed + dt)
    if not transition.switched and transition.elapsed >= transition.duration * 0.5 then
        transition.switched = true
        EnterRoom(game, transition.targetRoomId, transition.direction)
    end

    if transition.elapsed >= transition.duration then
        game.state = transition.arrivalState
        game.transition = nil
        game.doorCooldown = 0.2
    end
end

local function MoveProjectiles(game, dt)
    for _, projectile in ipairs(game.projectiles) do
        Entities.UpdateProjectile(projectile, dt)
    end
end

local function RemoveDeadProjectiles(game)
    for index = #game.projectiles, 1, -1 do
        if game.projectiles[index].dead then
            table.remove(game.projectiles, index)
        end
    end
end

local function ResolveProjectileContinuation(game, projectile, enemy)
    projectile.hitEnemies[enemy.id] = true

    if projectile.pierceRemaining > 0 then
        projectile.pierceRemaining = projectile.pierceRemaining - 1
        return
    end
    projectile.dead = true
end

local function CompleteBirthTutorial(game)
    if game.roomCleared then
        return
    end

    local roomState = GetRoomState(game, game.currentRoomId)
    roomState.cleared = true
    game.roomCleared = true
    SetMessage(game, "通路已开启", 1.2)
end

local function UpdateBirthTutorial(game, dt, moveX, moveY)
    if game.room == nil or not game.room.isBirthRoom or game.roomCleared then
        return
    end

    if not game.birthTutorialMoved and (moveX ~= 0 or moveY ~= 0) then
        game.birthTutorialMoved = true
        game.spawnGuideDismissed = true
        game.spawnParryGuideDismissed = false
        game.spawnParryGuideAlpha = 1
    end
    if game.spawnGuideDismissed then
        game.spawnGuideAlpha = math.max(0, game.spawnGuideAlpha - dt / 0.55)
    end
    if game.spawnParryGuideDismissed then
        game.spawnParryGuideAlpha = math.max(0, game.spawnParryGuideAlpha - dt / 0.55)
    end
    if game.birthTutorialMoved and game.birthTutorialParried then
        CompleteBirthTutorial(game)
    end
end

local function TryDamagePlayer(game, amount, invulnerabilityDuration)
    if CrystalAbilities.TrySwapDamage(game) then
        ResetPerfectStreak(game)
        return true, true, "rift"
    end
    if CrystalAbilities.TryPreventLethalDamage(game, amount) then
        ResetPerfectStreak(game)
        return true, true, "time"
    end
    local damaged = Entities.DamagePlayer(game.player, amount, invulnerabilityDuration)
    if damaged then
        ResetPerfectStreak(game)
    end
    return damaged, false, nil
end

local function EmitDamageDealt(game, x, y, damage, popupKind, killed)
    if damage == nil or damage <= 0 then
        return
    end
    EmitEvent(game, "damage_dealt", {
        x = x,
        y = y,
        damage = damage,
        popupKind = popupKind,
        killed = killed == true,
    })
end

local function ResolveProjectileContacts(game)
    for _, projectile in ipairs(game.projectiles) do
        if Entities.ProjectileHitsPlayer(projectile, game.player) then
            projectile.dead = true
            local damaged, saved, savedKind = TryDamagePlayer(game, ProjectileConfig.playerDamage)
            if damaged then
                ResetCombo(game)
                AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                SetMessage(game, saved and (savedKind == "rift" and "裂隙换位 - 残像爆裂" or "时隙之心 - 时间碎裂") or "受到伤害", 0.8)
                EmitEvent(game, "player_hurt", {
                    x = game.player.x,
                    y = game.player.y,
                    amount = ProjectileConfig.playerDamage,
                    sourceKind = projectile.sourceKind,
                })
            end
        end

        if projectile.owner == "player" and not projectile.dead then
            for _, enemy in ipairs(game.enemies) do
                if Entities.ProjectileHitsEnemy(projectile, enemy) then
                    if enemy.kind == "boss" then
                        ResolveProjectileContinuation(game, projectile, enemy)
                        EmitEvent(game, "projectile_hit", {
                            x = enemy.x, y = enemy.y, damage = 0, sourceKind = projectile.sourceKind,
                        })
                        break
                    end
                    local remainingHp = enemy.hp
                    local appliedDamage = math.min(enemy.hp, projectile.damage)
                    enemy.hp = enemy.hp - appliedDamage
                    AddParticles(game, enemy.x, enemy.y, { 255, 230, 115 }, 9)
                    EmitEvent(game, "projectile_hit", {
                        x = enemy.x,
                        y = enemy.y,
                        damage = appliedDamage,
                        sourceKind = projectile.sourceKind,
                    })
                    if enemy.hp <= 0 then
                        enemy.splitHp = remainingHp
                        enemy.mirrorGateEligible = projectile.reflected == true
                        enemy.dead = true
                    end
                    if not projectile.crystalGuard then
                        local popupKind = projectile.crystalSplit and "crystal" or "reflect"
                        EmitDamageDealt(game, enemy.x, enemy.y, appliedDamage, popupKind, enemy.dead)
                    end
                    ResolveProjectileContinuation(game, projectile, enemy)
                    break
                end
            end
        end
    end

    RemoveDeadProjectiles(game)
end

local function GetParryDamage(game, perfect)
    local damage = GaugeConfig.normalDamage
    if perfect then
        damage = damage * GaugeConfig.perfectDamageMultiplier
    end
    return damage
end

local function GetGaugeGain(game, perfect)
    local gain = perfect and GaugeConfig.perfectGain or GaugeConfig.normalGain
    return gain
end

local function AnnounceParryStart(game)
    AddParticles(game, game.player.x, game.player.y, { 110, 215, 255 }, 5)
    EmitEvent(game, "parry_start", {
        x = game.player.x,
        y = game.player.y,
        directionX = game.player.parryDirectionX,
        directionY = game.player.parryDirectionY,
    })
end

local function EmitParryResult(game, perfect, eventData)
    if perfect then
        eventData.perfectStreak = RegisterPerfectStreak(game)
        EmitEvent(game, "perfect_parry", eventData)
    else
        ResetPerfectStreak(game)
        EmitEvent(game, "parry_success", eventData)
    end
end

local function ResolveParries(game)
    if not Entities.IsParrying(game.player) then
        return
    end

    local perfect = Entities.IsPerfectParry(game.player)
    local damage = GetParryDamage(game, perfect)
    local gain = GetGaugeGain(game, perfect)
    local parriedAnything = false
    local parriedMelee = false

    for _, enemy in ipairs(game.enemies) do
        local hitX, hitY = enemy.x, enemy.y
        if enemy.kind == "boss" then
            local result = Boss.TryParry(enemy, game.player, damage)
            if result ~= nil then
                parriedAnything = true
                parriedMelee = parriedMelee or result.kind == "attack"
                local eventData = {
                    x = result.x or hitX, y = result.y or hitY, damage = result.damage,
                    sourceKind = enemy.kind, defenseOnly = result.damage <= 0,
                    originX = game.player.x, originY = game.player.y,
                    directionX = game.player.parryDirectionX, directionY = game.player.parryDirectionY,
                }
                EmitParryResult(game, perfect, eventData)
                if perfect then
                    EmitDamageDealt(game, eventData.x, eventData.y, result.damage, "perfect", false)
                end
                if perfect then
                    AddParticles(game, hitX, hitY,
                        result.kind == "mechanism" and { 245, 205, 105 } or { 255, 225, 130 }, 15)
                end
                if result.kind == "mechanism" then
                    EmitEvent(game, "projectile_reflect", eventData)
                    EmitEvent(game, "boss_mechanism_progress", {
                        x = result.x or hitX, y = result.y or hitY,
                        mechanism = result.mechanism, progress = result.progress,
                    })
                    if result.completed then
                        EmitEvent(game, "boss_mechanism_completed", { mechanism = result.mechanism })
                        EmitEvent(game, "gauge_full")
                    end
                    SetMessage(game, result.completed and "净化目标完成" or "净化进度推进", 0.7)
                elseif enemy.phaseChanged then
                    game.projectiles = {}
                    EmitEvent(game, "boss_phase_changed", { phase = 2, x = enemy.x, y = enemy.y })
                    SetMessage(game, "第二阶段 - 诅咒显形", 1.2)
                end
            end
        else
            local parried, appliedDamage = Entities.TryParryEnemy(game.player, enemy, damage)
            if parried then
                parriedAnything = true
                parriedMelee = true
                EmitParryResult(game, perfect, {
                    x = hitX, y = hitY, damage = appliedDamage, sourceKind = enemy.kind,
                    originX = game.player.x, originY = game.player.y,
                    directionX = game.player.parryDirectionX, directionY = game.player.parryDirectionY,
                })
                if perfect then
                    EmitDamageDealt(game, hitX, hitY, appliedDamage, "perfect", enemy.dead)
                end
                if perfect then
                    AddParticles(game, hitX, hitY, { 255, 225, 130 }, 15)
                end
                AddGaugeProgress(game, gain, hitX, hitY)
            end
        end
    end

    for _, projectile in ipairs(game.projectiles) do
        local hitX, hitY = projectile.x, projectile.y
        if Entities.TryParryProjectile(game.player, projectile, 1) then
            parriedAnything = true
            local eventData = {
                x = hitX,
                y = hitY,
                damage = projectile.damage,
                sourceKind = projectile.sourceKind,
                originX = game.player.x,
                originY = game.player.y,
                directionX = game.player.parryDirectionX,
                directionY = game.player.parryDirectionY,
            }
            EmitParryResult(game, perfect, eventData)
            EmitEvent(game, "projectile_reflect", eventData)
            CrystalAbilities.OnProjectileReflected(game, projectile, perfect)
            if perfect then
                AddParticles(game, hitX, hitY, { 255, 225, 130 }, 11)
            end
            AddGaugeProgress(game, gain, hitX, hitY)
        end
    end
    if parriedAnything then
        Entities.RegisterParrySuccess(game.player, perfect)
        AddComboProgress(game, perfect, game.player.x, game.player.y, parriedMelee)
        local guardData = {
            kind = perfect and "perfect" or "normal",
            comboCount = game.combo.count,
            perfectStreak = game.perfectStreak ~= nil and game.perfectStreak.count or 0,
            x = game.player.x,
            y = game.player.y,
        }
        EmitEvent(game, "guard_combo_feedback", guardData)
        CrystalAbilities.OnParryResult(game, perfect)
        if perfect then
            CrystalAbilities.OnPerfectParry(game)
        end
    end
end

local function UpdateEnemies(game, dt)
    local function EmitProjectile(projectile)
        table.insert(game.projectiles, projectile)
        EmitEvent(game, "projectile_fire")
    end

    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then
            Boss.Update(enemy, game.player, dt)
        else
            Entities.UpdateEnemy(enemy, game.player, dt, EmitProjectile)
        end
    end
end

local function ResolveEnemyContacts(game)
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then
            for _, hit in ipairs(Boss.CollectPlayerHits(enemy, game.player)) do
                EmitEvent(game, "boss_attack_hit", {
                    x = game.player.x,
                    y = game.player.y,
                    attack = enemy.attack,
                    sourceKind = hit.source,
                    originX = enemy.x,
                    originY = enemy.y,
                    directionX = game.player.x - enemy.x,
                    directionY = game.player.y - enemy.y,
                })
                local damaged, saved, savedKind = TryDamagePlayer(game, hit.amount, hit.invulnerability)
                if damaged then
                    ResetCombo(game)
                    AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                    SetMessage(game, saved and (savedKind == "rift" and "裂隙换位 - 残像爆裂" or "时隙之心 - 时间碎裂")
                        or "受到伤害", 0.8)
                    EmitEvent(game, "player_hurt", {
                        x = game.player.x, y = game.player.y, amount = hit.amount, sourceKind = hit.source,
                    })
                end
            end
        else
            local hit = Entities.CollectEnemyHit(enemy, game.player)
            local damaged, saved, savedKind = false, false, nil
            if hit ~= nil then
                damaged, saved, savedKind = TryDamagePlayer(game, hit.amount)
            end
            if damaged then
                ResetCombo(game)
                AddParticles(game, game.player.x, game.player.y, { 255, 90, 90 }, 12)
                SetMessage(game, saved and (savedKind == "rift" and "裂隙换位 - 残像爆裂" or "时隙之心 - 时间碎裂") or "受到伤害", 0.8)
                EmitEvent(game, "player_hurt", {
                    x = game.player.x,
                    y = game.player.y,
                    amount = hit.amount,
                    sourceKind = hit.sourceKind,
                })
                if enemy.kind == "shadow_wraith" then
                    local directionX = game.player.x - enemy.x
                    local directionY = game.player.y - enemy.y
                    local directionLength = math.sqrt(directionX * directionX + directionY * directionY)
                    if directionLength <= 0.0001 then
                        directionX, directionY = 1, 0
                    else
                        directionX, directionY = directionX / directionLength, directionY / directionLength
                    end
                    EmitEvent(game, "shadow_wraith_hit", {
                        x = game.player.x,
                        y = game.player.y,
                        originX = enemy.x,
                        originY = enemy.y,
                        directionX = directionX,
                        directionY = directionY,
                    })
                end
            end
        end
    end
end

local function UpdateBattle(game, dt, moveX, moveY)
    local playerMoveX, playerMoveY = moveX, moveY
    if CrystalAbilities.IsDashing(game) then
        playerMoveX, playerMoveY = 0, 0
    end
    if Entities.UpdatePlayer(game.player, dt, playerMoveX, playerMoveY, 1) then
        AnnounceParryStart(game)
    end
    CrystalAbilities.UpdateCombat(game, dt, moveX, moveY)
    CrystalAbilities.UpdatePassive(game, dt)
    UpdateEnemies(game, dt)
    MoveProjectiles(game, dt)
    ResolveParries(game)
    CrystalAbilities.ResolveOrbitGuards(game)
    ResolveEnemyContacts(game)
    ResolveProjectileContacts(game)
    HandleEnemyDeaths(game)
    if UpdateChests(game, dt) then
        return
    end

    if game.player.hp <= 0 then
        game.state = "dead"
        game.stateTimer = 0
        SetMessage(game, "本局失败", 999)
        EmitEvent(game, "game_over")
        return
    end

    if #game.enemies == 0 then
        FinishRoom(game)
    end
end

function Game.New()
    return {
        state = "menu",
        stateTimer = 0,
        time = 0,
        runTime = 0,
        victoryElapsed = 0,
        currentRoomId = nil,
        room = nil,
        roomStates = {},
        discoveredRooms = {},
        visitedRoomCount = 0,
        clearedRoomCount = 0,
        roomCount = GetRoomCount(),
        roomCleared = false,
        map = RoomData,
        transition = nil,
        doorCooldown = 0,
        player = Entities.NewPlayer(),
        enemies = {},
        projectiles = {},
        chests = {},
        chestOptions = nil,
        stateBeforeChest = nil,
        pendingChestRewards = {},
        particles = {},
        gauge = CreateGauge(),
        recovery = CreateRecovery(),
        combo = CreateCombo(),
        perfectStreak = CreatePerfectStreak(),
        crystalState = CrystalAbilities.NewState(),
        spawnGuideAlpha = 0,
        spawnGuideDismissed = true,
        spawnParryGuideAlpha = 0,
        spawnParryGuideDismissed = true,
        birthTutorialMoved = false,
        birthTutorialParried = false,
        message = "按回车开始",
        messageTimer = 999,
        nextEntityId = 1,
        events = {},
    }
end

function Game.StartOrRestart(game)
    StartRun(game)
    EmitEvent(game, "run_start")
end

function Game.ReturnToMenu(game)
    if game.state ~= "dead" then
        return false
    end

    game.state = "menu"
    game.stateTimer = 0
    game.message = "按开始踏入房间"
    game.messageTimer = 999
    print("[Game] Game over acknowledged; returning to main menu")
    return true
end

function Game.TryParry(game, targetX, targetY, allowBirthTutorial)
    local isBirthTutorial = allowBirthTutorial and game.state == "clear" and game.room ~= nil
        and game.room.isBirthRoom and not game.roomCleared and game.birthTutorialMoved
        and not game.birthTutorialParried
    if game.state ~= "battle" and not isBirthTutorial then
        return false
    end

    local accepted, started = Entities.BeginParry(game.player, targetX, targetY)
    if started then
        AnnounceParryStart(game)
    end
    if accepted and isBirthTutorial then
        game.birthTutorialParried = true
        game.spawnParryGuideDismissed = true
        game.spawnParryGuideAlpha = 0
        CompleteBirthTutorial(game)
    end
    return accepted
end

function Game.SelectCrystal(game, index)
    if game.state ~= "chest_select" or game.chestOptions == nil then
        return false
    end

    local definition = game.chestOptions[index]
    if definition == nil or not Entities.ApplyCrystal(game.player, definition) then
        return false
    end

    AddParticles(game, game.player.x, game.player.y, definition.color, 18)
    SetMessage(game, "获得水晶能力：" .. definition.name, 1.4)
    local stateBeforeChest = game.stateBeforeChest
    game.chestOptions = nil
    game.state = stateBeforeChest
    game.stateBeforeChest = nil
    EmitEvent(game, "crystal_acquired", { id = definition.id, choiceIndex = index })
    OpenNextChestReward(game, stateBeforeChest)
    return true
end

function Game.ConsumeEvents(game)
    local events = game.events
    game.events = {}
    return events
end

function Game.Update(game, dt, moveX, moveY, realDt)
    dt = math.max(0, dt or 0)
    realDt = math.max(0, realDt or dt)
    game.time = game.time + dt
    if game.messageTimer > 0 and game.messageTimer < 900 then
        game.messageTimer = math.max(0, game.messageTimer - dt)
    end
    UpdateParticles(game, dt)

    if game.state == "room_transition" or game.state == "intro" or game.state == "battle" or game.state == "clear" then
        UpdateGaugeRecovery(game, dt)
    end

    if game.state == "battle" then
        UpdateCombo(game, dt)
        UpdatePerfectStreak(game, dt)
    end

    if game.doorCooldown > 0 then
        game.doorCooldown = math.max(0, game.doorCooldown - dt)
    end

    -- A feedback hit stop freezes world simulation, but parry, cooldown, and
    -- invulnerability timers keep using real time so combat windows do not grow.
    if dt <= 0 and realDt > 0 then
        if game.player ~= nil then
            if Entities.UpdatePlayerTimers(game.player, realDt) then
                AnnounceParryStart(game)
            end
        end
        return
    end

    if game.state == "room_transition" then
        UpdateRoomTransition(game, dt)
        return
    end

    if game.state == "victory" then
        game.victoryElapsed = game.victoryElapsed + realDt
        -- Victory freezes combat, but reflected piercing projectiles should finish their flight.
        MoveProjectiles(game, dt)
        for _, enemy in ipairs(game.enemies) do
            if enemy.kind == "boss" and enemy.state == "defeat" then
                Boss.Update(enemy, game.player, dt)
            end
        end
        HandleEnemyDeaths(game)
        RemoveDeadProjectiles(game)
        if game.victoryElapsed >= 5.2 then
            game.state = "menu"
            game.message = "按开始踏入房间"
            game.messageTimer = 999
            print("[Game] Victory sequence complete; returning to main menu")
        end
        return
    end

    if game.state == "menu" or game.state == "dead" or game.state == "chest_select" then
        return
    end

    game.runTime = game.runTime + dt
    UpdateBirthTutorial(game, dt, moveX, moveY)
    if game.state == "intro" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY, 1)
        CrystalAbilities.UpdatePassive(game, dt)
        game.stateTimer = game.stateTimer - dt
        if game.stateTimer <= 0 then
            game.state = "battle"
            SetMessage(game, "敌人开始行动", 1.0)
            EmitEvent(game, game.room.boss and "boss_entrance" or "battle_start")
        end
        return
    end

    if game.state == "battle" then
        UpdateBattle(game, dt, moveX, moveY)
        return
    end

    if game.state == "clear" then
        Entities.UpdatePlayer(game.player, dt, moveX, moveY, 1)
        CrystalAbilities.UpdatePassive(game, dt)
        -- A room can be cleared by a piercing projectile; keep it moving until it expires.
        MoveProjectiles(game, dt)
        RemoveDeadProjectiles(game)
        if UpdateChests(game, dt) then
            return
        end
        TryBeginRoomTransition(game)
    end
end

function Game.GetHud(game)
    local bossHud = nil
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then
            bossHud = Boss.GetHud(enemy)
            break
        end
    end

    local healthRatio = math.max(0, math.min(1, game.player.hp / PlayerConfig.maxHp))
    local gaugeRatio = math.max(0, math.min(1, game.gauge.value / game.gauge.threshold))
    local parryCooldownRatio = 1
    if PlayerConfig.parryCooldown > 0 then
        parryCooldownRatio = math.max(0, math.min(1,
            1 - game.player.parryCooldown / PlayerConfig.parryCooldown))
    end
    local hudVisible = game.state ~= "menu" and game.state ~= "dead" and game.state ~= "victory"
        and game.state ~= "chest_select"
    local combo = game.combo or CreateCombo()
    local comboDefinition = ComboConfig.tiers[combo.tier]

    return {
        hudVisible = hudVisible,
        healthRatio = healthRatio,
        gaugeRatio = gaugeRatio,
        parryCooldownRatio = parryCooldownRatio,
        room = game.room ~= nil and game.room.name or "尚未开始",
        roomProgress = "探索 " .. tostring(game.clearedRoomCount) .. "/" .. tostring(game.roomCount),
        crystals = game.player.crystalOrder,
        boss = bossHud,
        combo = {
            count = combo.count,
            tier = combo.tier,
            tierName = comboDefinition ~= nil and comboDefinition.name or "蓄势",
            color = comboDefinition ~= nil and CopyColor(comboDefinition.color) or { 190, 196, 218 },
            overdriveRemaining = combo.overdriveRemaining,
        },
    }
end

return Game
